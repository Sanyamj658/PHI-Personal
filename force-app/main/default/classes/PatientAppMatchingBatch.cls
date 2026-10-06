// Batch that matches Pending App Users to patient Contacts by email, name and DOB, then activates or deactivates them.
public with sharing class PatientAppMatchingBatch
    implements Database.Batchable<sObject>, Database.Stateful {

    // Internal recipient of the partial match report.
    private static final String INTERNAL_EMAIL = 'aabhar.gupta@concret.io';
    private static final Integer NOTIFICATION_THRESHOLD = 0;

    // Collects partial match rows for the report sent in finish().
    @TestVisible
    private List<String> csvRows = new List<String>();

    // ── Start ─────────────────────────────────────────────
    public Database.QueryLocator start(Database.BatchableContext BC) {
        System.debug('🚀 Batch Started');

        return Database.getQueryLocator([
            SELECT Id, Name, Email__c, dob__c, 
                   Street__c, City__c, State__c, Zip_Code__c,
                   Status__c, Patient__c
            FROM App_User__c
            WHERE Status__c = 'Pending'
              AND Patient__c = null
        ]);
    }

    // ── Execute ───────────────────────────────────────────
    public void execute(Database.BatchableContext BC, List<App_User__c> scope) {

        System.debug('⚙️ Execute size: ' + scope.size());

        // Collect lowercased emails of the scope so Contacts are queried once.
        Set<String> emails = new Set<String>();
        for (App_User__c au : scope) {
            if (String.isNotBlank(au.Email__c)) {
                emails.add(au.Email__c.toLowerCase());
            }
        }

        // Group Contacts with those emails by lowercase email.
        Map<String, List<Contact>> contactsByEmail = new Map<String, List<Contact>>();

        if (!emails.isEmpty()) {
            for (Contact c : [
                SELECT Id, Name, FirstName, LastName, Email,
                       Date_of_Birth__c
                FROM Contact
                WHERE Email IN :emails
            ]) {
                String key = c.Email.toLowerCase();

                if (!contactsByEmail.containsKey(key)) {
                    contactsByEmail.put(key, new List<Contact>());
                }
                contactsByEmail.get(key).add(c);
            }
        }

        // Lists used to save the App Users and send emails after processing.
        List<App_User__c> appusersToUpdate = new List<App_User__c>();
        List<Messaging.SingleEmailMessage> welcomeEmails = new List<Messaging.SingleEmailMessage>();
        List<Messaging.SingleEmailMessage> mismatchEmails = new List<Messaging.SingleEmailMessage>();

        for (App_User__c au : scope) {

            // Score each App User against Contacts with the same email: email 34% + name 33% + DOB 33%.
            Integer bestPct = 0;
            Id bestContactId;

            String key = String.isNotBlank(au.Email__c) ? au.Email__c.toLowerCase() : null;

            if (key != null && contactsByEmail.containsKey(key)) {

                String auName = normalize(au.Name);
                
                for (Contact c : contactsByEmail.get(key)) {

                    String cName = normalize(c.Name);
                    System.debug('Comparing App_User: ' + au.Name + ' with Contact: ' + c.Name);
                    System.debug('Fields - Name Match: ' + (auName == cName) + ', DOB Match: ' + (au.dob__c != null && au.dob__c == c.Date_of_Birth__c));
                    Boolean nameMatch = (auName == cName);
                    Boolean dobMatch = (au.dob__c != null &&
                                        au.dob__c == c.Date_of_Birth__c);
                    Boolean emailMatch = (
                    String.isNotBlank(au.Email__c) &&
                    String.isNotBlank(c.Email) &&
                    au.Email__c.toLowerCase() == c.Email.toLowerCase()
                    );

                    Integer pct =
                        (emailMatch ? 34 : 0) +
                        (nameMatch ? 33 : 0) +
                        (dobMatch ? 33 : 0);

                    // Integer pct = (nameMatch ? 50 : 0) +
                    //               (dobMatch ? 50 : 0);
                                 

                    // Keep the best scoring Contact and stop early on a full match.
                    if (pct > bestPct) {
                        bestPct = pct;
                        bestContactId = c.Id;
                    }

                    if (bestPct == 100) break;
                }
            }

            System.debug('📊 ' + au.Name + ' Score: ' + bestPct);

            // Save the score on the App User.
            au.Matching_Percentage__c = bestPct;

            // ✅ 100% MATCH
            if (bestPct == 100) {
                System.debug('✅ FULL MATCH');

                au.Patient__c = bestContactId;
                au.Status__c = 'Active';
                // welcomeEmails.add(buildWelcomeEmail(au));
            }

            // ✅ Less than 64% → InActive
            else if (bestPct < 66) {
                System.debug('❌ MATCH BELOW 64% → InActive');
                au.Status__c = 'InActive';
                // csvRows.add(au.Name + ',' + au.Email__c + ',' + String.valueOf(bestPct) + '%');
                // Note: AppUserNotificationHandler (via AppUserTrigger after-update) already
                // emails the user when Status__c transitions to InActive/Inactive.
            }

            // ✅ PARTIAL MATCH (50–99)
            else if (bestPct < 100) {
                System.debug('📄 PARTIAL MATCH → Adding to CSV');

              /*  csvRows.add(
                    au.Name + ',' +
                    au.Email__c + ',' +
                    String.valueOf(bestPct) + '%'
                ); 

                if (String.isNotBlank(au.Email__c)) {
                    mismatchEmails.add(buildMismatchEmail(au));
                } */ 
            }
            appusersToUpdate.add(au);
        }

        // Save all updated App Users.
        if (!appusersToUpdate.isEmpty()) {
            update appusersToUpdate;
        }

        // Send any queued emails.
        if (!welcomeEmails.isEmpty()) {
            Messaging.sendEmail(welcomeEmails);
        }

        if (!mismatchEmails.isEmpty()) {
            Messaging.sendEmail(mismatchEmails);
        }
    }

    // ── Finish ───────────────────────────────────────────
    public void finish(Database.BatchableContext BC) {

       

        // Email the partial match CSV report to the internal team when there are entries.
        if (!csvRows.isEmpty()) {

            System.debug('📧 Sending Partial Match Report with ' + csvRows.size() + ' entries');
            String header = 'Name,Email,Match %\n';
            String body = header + String.join(csvRows, '\n');

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new String[] { INTERNAL_EMAIL });
            mail.setSubject(' [INTERNAL] Partial Match Report — Action Required — Do Not Forward');

            Messaging.EmailFileAttachment att = new Messaging.EmailFileAttachment();
            att.setFileName('PartialReport.csv');
                // ✅ FIX: Add body
        mail.setHtmlBody(
            '<p>Hi Team,</p>' +
            '<p>Please find attached the partial match report.</p>' +
            '<p>Kindly review the report and take the necessary action as required.</p>' +
            '<p>Thank You,<br/>Passage HI Team </p>' + 
            '<hr/>' +
            'This message was sent by Passage Health International<br/>' +
            '[INSERT PHI PHYSICAL MAILING ADDRESS]<br/>' +
            'support@passagehi.com | [INSERT PHI SUPPORT PHONE]<br/><br/>' + 
            'You are receiving this message because you are a registered user of the Passage Health International Patient Portal App.<br/>' +
            'To manage your communication preferences: [App Settings Link]<br/>' +
            'To unsubscribe from marketing communications: [Unsubscribe Link]<br/>' +
            'Privacy Policy: [URL] | Terms of Use: [URL]'

        );
            att.setBody(Blob.valueOf(body));
            att.setContentType('text/csv');

            mail.setFileAttachments(new Messaging.EmailFileAttachment[] { att });

            Messaging.SendEmailResult[] results = Messaging.sendEmail(
                new List<Messaging.SingleEmailMessage>{ mail }
            );

            for (Messaging.SendEmailResult r : results) {
                if (!r.isSuccess()) {
                    System.debug('❌ Report Email Error: ' + r.getErrors()[0].getMessage());
                } else {
                    System.debug('✅ Report Email Sent');
                }
            }

        } else {
            System.debug('⚠️ No partial matches → No report sent');
        }
    }

    // ── Helper ───────────────────────────────────────────
//     public static Messaging.SingleEmailMessage buildWelcomeEmail(App_User__c au) {
//     Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();

//     mail.setToAddresses(new String[] { au.Email__c });
//     mail.setSubject('Your Passage Health International Patient Portal Account Is Now Active');

//     String firstName = String.isBlank(au.Name) ? 'User' : au.Name;
// 	System.debug('firstName : '+ firstName);
//     String body =
//         'Dear ' + firstName + ',<br/><br/>' +
//         'Your account has been approved and is now active. You can now log in to the Patient Portal using your registered email address and the Date of Birth you created during registration.<br/><br/>' +
//         'If you have any questions, please contact us at support@passagehi.com.<br/><br/>' +
//         'Thank you,<br/>' +
//         'Passage Health International Team<br/><br/>' +

//         '<hr/>' +

//         'This message was sent by Passage Health International<br/>' +
//         'PHIITDEPT@passagehi.com<br/>' +
//         ' | [INSERT PHI SUPPORT PHONE]<br/><br/>' +

//         'You are receiving this message because you are a registered user of the Passage Health International Patient Portal App.<br/>' +
//         'To manage your communication preferences: [App Settings Link]<br/>' +
//         'To unsubscribe from marketing communications: [Unsubscribe Link]<br/>' +
//         'Privacy Policy: [URL] | Terms of Use: [URL]';

//     mail.setHtmlBody(body);

//     return mail;
// }

  /*  public static Messaging.SingleEmailMessage buildMismatchEmail(App_User__c au) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();

        mail.setToAddresses(new String[] { au.Email__c });
        mail.setSubject('We Could Not Verify Your Passage Health International Patient Portal Registration');

        String firstName = String.isBlank(au.Name) ? 'User' : au.Name;
        String body =
            'Dear ' + firstName + ',<br/><br/>' +
            'We were unable to verify the information you provided during registration against our patient records.' +
            'Please verify that all the information you entered during registration is correct, including your Name, Date of Birth, and email address, and try registering again using the correct information.' +
            'If you continue to experience issues after verifying and entering the correct information, please contact our support team at PHIITDEPT@passagehi.com  so we can help resolve the issue.' +
            'Thank you,<br/>' +
            'Passage Health International Team<br/><br/>' +
            '<hr/>' +
            'This message was sent by Passage Health International<br/>' +
            '[INSERT PHI PHYSICAL MAILING ADDRESS]<br/>' +
            'support@passagehi.com | [INSERT PHI SUPPORT PHONE]<br/><br/>' +
            'You are receiving this message because you are a registered user of the Passage Health International Patient Portal App.<br/>' +
            'To manage your communication preferences: [App Settings Link]<br/>' +
            'To unsubscribe from marketing communications: [Unsubscribe Link]<br/>' +
            'Privacy Policy: [URL] | Terms of Use: [URL]';

        mail.setHtmlBody(body);

        return mail;
    }  */ 

    // Lowercases and strips whitespace so names compare consistently.
    private static String normalize(String val) {
        if (String.isBlank(val)) return '';
        return val.toLowerCase().replaceAll('\\s+', '').trim();
    }
}