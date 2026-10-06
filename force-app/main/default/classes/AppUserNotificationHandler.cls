public class AppUserNotificationHandler {
    // This method matches App_User__c records to Contact records based on email and date of birth, updates the status of the App_User__c records, and sends appropriate email notifications.
    public static void matchAppUserToPatients(List<App_User__c> appUsers) {
        try{
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        Set<Date> appUserDobs = new Set<Date>();
        Set<String> appUsersEmails = new Set<String>();
        // Collect lowercased emails and DOBs so matching Contacts are queried in one go.
        for (App_User__c appUser : appUsers) {
            appUsersEmails.add(appUser.Email__c.toLowerCase());
            appUserDobs.add(appUser.dob__c);

        }
        // Group matching Contacts by lowercase email for quick lookup.
        Map<String, List<Contact>> contactsByEmail = new Map<String, List<Contact>>();
        if (!appUsersEmails.isEmpty()) {
            for (Contact contactObj : [SELECT Id, Name, FirstName, LastName, Email, Date_of_Birth__c FROM Contact WHERE Email IN :appUsersEmails AND Date_of_Birth__c IN :appUserDobs]) {
                String key = contactObj.Email.toLowerCase();
                if (!contactsByEmail.containsKey(key)) {
                    contactsByEmail.put(key, new List<Contact>());
                }
                contactsByEmail.get(key).add(contactObj);
            }
        }

         // Match each App User by name, DOB and email; Active with patient link if found, otherwise InActive.
         for (App_User__c appUser : appUsers) {
            String appUserEmail = appUser.Email__c.toLowerCase();
            String appUserName = normalize(appUser.Name);
            Contact matchedContact;

            if (contactsByEmail.containsKey(appUserEmail)) {
                for (Contact contactObj : contactsByEmail.get(appUserEmail)) {
                    String contactObjName = normalize(contactObj.Name);
                    if (appUserName.equalsIgnoreCase(contactObjName)
                        && appUser.dob__c == contactObj.Date_of_Birth__c && (appUser.Email__c).equalsIgnoreCase(contactObj.Email)) {
                        matchedContact = contactObj;
                        break;
                    }
                }
            }

            if (matchedContact != null) {
                appUser.Patient__c = matchedContact.Id;
                appUser.Status__c = 'Active';
                emails.add(buildWelcomeEmail(appUser));
            } else {
                appUser.Status__c = 'InActive';
                emails.add(buildInactiveEmail(appUser));
            }
        }

         // Send all welcome/inactive emails in a single call.
         if (!emails.isEmpty()) {
                Messaging.sendEmail(emails);
            }
        } catch (Exception e) {
                System.debug('Error in matchAppUserToPatients: ' + e.getMessage());
        }
    }

    // This method builds an email notification for users whose registration could not be verified, prompting them to check their information and try again.
    private static Messaging.SingleEmailMessage buildInactiveEmail(App_User__c appUser) {
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{ appUser.Email__c });
            mail.setSubject('Action Required: Your PHI Registration Could Not Be Verified');
            mail.setHtmlBody(
                'Dear ' + appUser.Name + ',<br/><br/>' +
                'We were unable to verify the information you provided during registration against our patient records.' +
                'Please verify that all the information you entered during registration is correct, including your Name, Date of Birth, and email address, and try registering again using the correct information.<br/><br/>' +
                'If you continue to experience issues after verifying and entering the correct information, please contact our support team at PHIITDEPT@passagehi.com  so we can help resolve the issue.' +
                'Thank you,<br/>' +
                'Passage Health International Team<br/><br/>' +
                '<hr/>' +
                'This message was sent by Passage Health International<br/>' +
                'PHIITDEPT@passagehi.com<br/>' +
                ' | [INSERT PHI SUPPORT PHONE]<br/><br/>' +
                'You are receiving this message because you are a registered user of the Passage Health International Patient Portal App.<br/>' +
                'To manage your communication preferences: [App Settings Link]<br/>' +
                'To unsubscribe from marketing communications: [Unsubscribe Link]<br/>' +
                'Privacy Policy: [URL] | Terms of Use: [URL]'
            );
            return mail;
    }

    // This method builds a welcome email notification for users whose registration has been successfully verified, informing them that their account is now active and providing instructions for logging in.
    public static Messaging.SingleEmailMessage buildWelcomeEmail(App_User__c appUser) {  
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();

            mail.setToAddresses(new String[] { appUser.Email__c });
            mail.setSubject('Your Passage Health International Patient Portal Account Is Now Active');

            String firstName = String.isBlank(appUser.Name) ? 'User' : appUser.Name;
            System.debug('firstName : '+ firstName);
            String body =
                'Dear ' + firstName + ',<br/><br/>' +
                'Your account has been approved and is now active. You can now log in to the Patient Portal using your registered email address and the Date of Birth you created during registration.<br/><br/>' +
                'If you have any questions, please contact us at support@passagehi.com.<br/><br/>' +
                'Thank you,<br/>' +
                'Passage Health International Team<br/><br/>' +

                '<hr/>' +

                'This message was sent by Passage Health International<br/>' +
                'PHIITDEPT@passagehi.com<br/>' +
                ' | [INSERT PHI SUPPORT PHONE]<br/><br/>' +

                'You are receiving this message because you are a registered user of the Passage Health International Patient Portal App.<br/>' +
                'To manage your communication preferences: [App Settings Link]<br/>' +
                'To unsubscribe from marketing communications: [Unsubscribe Link]<br/>' +
                'Privacy Policy: [URL] | Terms of Use: [URL]';

            mail.setHtmlBody(body);

            return mail;
        }
        // Lowercases and strips whitespace so names compare consistently.
        private static String normalize(String val) {
            if (String.isBlank(val)) return '';
            return val.toLowerCase().replaceAll('\\s+', '').trim();
    }

}