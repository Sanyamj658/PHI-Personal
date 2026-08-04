public class AppUserHandler {

    public static void handleAfterUpdate(List<App_User__c> newList, Map<Id, App_User__c> oldMap) {

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for (App_User__c au : newList) {

            App_User__c oldRecord = oldMap.get(au.Id);

            // ✅ Condition: Status changed to Active
            if (au.Status__c == 'Active' && oldRecord.Status__c != 'Active') {

                if (String.isNotBlank(au.Email__c)) {

                    System.debug('📨 Sending login email to: ' + au.Email__c);

                    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();

                    mail.setToAddresses(new String[] { au.Email__c });
                    mail.setSubject('Account Approved');

                    mail.setHtmlBody(
                        '<p>Hello ' + au.Name + ',</p>' +
                        '<p>Your account is now <b>active</b>.</p>' +
                        '<p>You can now login to the application.</p>' +
                        '<p>Regards,<br/>Team</p>'
                    );

                    emails.add(mail);
                }
            }
        }

        // ✅ Send emails in bulk
        if (!emails.isEmpty()) {

            Messaging.SendEmailResult[] results = Messaging.sendEmail(emails);

            for (Messaging.SendEmailResult r : results) {
                if (!r.isSuccess()) {
                    System.debug('❌ Email Error: ' + r.getErrors()[0].getMessage());
                } else {
                    System.debug('✅ Email Sent');
                }
            }
        }
    }
}