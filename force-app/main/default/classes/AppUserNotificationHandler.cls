public class AppUserNotificationHandler {
    public static void handleAfterUpdate(List<App_User__c> newUsers, Map<Id, App_User__c> oldMap) {
        try {
            List<NotificationService.Request> requests = new List<NotificationService.Request>();
            List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

            for (App_User__c u : newUsers) {
                App_User__c old = oldMap != null ? oldMap.get(u.Id) : null;
                if (old == null) {
                    continue;
                }

                Boolean wasNotActive = old.Status__c != 'Active';
                Boolean isNowActive = u.Status__c == 'Active';

                if (wasNotActive && isNowActive && String.isNotBlank(u.Email__c)) {
                    emails.add(PatientAppMatchingBatch.buildWelcomeEmail(u));
                }

                if (old.Status__c != 'Inactive' && u.Status__c == 'Inactive' && String.isNotBlank(u.Email__c)) {
                    emails.add(buildInactiveEmail(u));
                }
            }

            if (!requests.isEmpty()) {
                NotificationService.dispatch(requests);
            }

            if (!emails.isEmpty()) {
                Messaging.sendEmail(emails);
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'AppUserNotificationHandler.handleAfterUpdate failed: ' + ex.getMessage());
        }
    }

    private static Messaging.SingleEmailMessage buildInactiveEmail(App_User__c user) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new List<String>{ user.Email__c });
        mail.setSubject('Action Required: Your PHI Registration Could Not Be Verified');
        mail.setHtmlBody(
            'Dear ' + user.Name + ',<br/><br/>' +
            'We were unable to verify your registration for the Passage Health International Patient Portal. This may be because the information provided does not match our records.<br/><br/>' +
            'Please contact us at <a href="mailto:support@passagehi.com">support@passagehi.com</a> or call [PHI SUPPORT PHONE] so we can assist you.<br/><br/>' +
            'Thank you,<br/>' +
            'Passage Health International Team<br/><br/>' +
            '<hr/>' +
            'This message was sent by Passage Health International<br/>' +
            '[INSERT PHI PHYSICAL MAILING ADDRESS]<br/>' +
            '<a href="mailto:support@passagehi.com</a> | [INSERT PHI SUPPORT PHONE]<br/><br/>' +
            'You are receiving this message because you are a registered user of the Passage Health International Patient Portal App.<br/>' +
            'To manage your communication preferences: [App Settings Link]<br/>' +
            'To unsubscribe from marketing communications: [Unsubscribe Link]<br/>' +
            'Privacy Policy: [URL] | Terms of Use: [URL]'
        );
        return mail;
    }
}