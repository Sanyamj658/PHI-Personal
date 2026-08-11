public class NotificationService {
    public class Request {
        public String email;
        public String title;
        public String body;
        public String type;
        public String relatedRecordId;
        public String relatedRecordType;

        public Request(String email, String title, String body) {
            this.email = email;
            this.title = title;
            this.body = body;
        }
    }

    @TestVisible
    private static Set<String> processedKeys = new Set<String>();

    public static void dispatch(List<Request> requests) {
        try {
            if (requests == null || requests.isEmpty()) {
                return;
            }

            Map<String, Request> dedupedByEmail = new Map<String, Request>();
            for (Request r : requests) {
                if (String.isBlank(r.email) || String.isBlank(r.title)) {
                    continue;
                }
                String key = r.email.toLowerCase() + '|' + r.title;
                if (processedKeys.contains(key)) {
                    continue;
                }
                processedKeys.add(key);
                dedupedByEmail.put(r.email.toLowerCase(), r);
            }

            if (dedupedByEmail.isEmpty()) {
                return;
            }

            List<App_User__c> appUsers = [
                SELECT Id, Email__c, Device_Token__c
                FROM App_User__c
                WHERE Email__c IN :dedupedByEmail.keySet()
            ];

            if (appUsers.isEmpty()) {
                System.debug('[NotificationService] No app users found for: ' + dedupedByEmail.keySet());
                return;
            }

            List<App_Notification__c> toInsert = new List<App_Notification__c>();
            for (App_User__c u : appUsers) {
                String lEmail = u.Email__c.toLowerCase();
                Request r = dedupedByEmail.get(lEmail);
                if (r == null) {
                    continue;
                }

                toInsert.add(new App_Notification__c(
                    App_User__c = u.Id,
                    Title__c = r.title,
                    Body__c = r.body,
                    Related_Record_Id__c = r.relatedRecordId,
                    Is_Read__c = false
                ));
            }
            if (!toInsert.isEmpty()) {
                insert toInsert;
            }

            List<Map<String, String>> payloads = new List<Map<String, String>>();
            for (App_User__c u : appUsers) {
                if (String.isBlank(u.Device_Token__c)) {
                    continue;
                }
                String lEmail = u.Email__c.toLowerCase();
                Request r = dedupedByEmail.get(lEmail);
                if (r == null) {
                    continue;
                }

                payloads.add(new Map<String, String>{
                    'deviceToken' => u.Device_Token__c,
                    'title' => r.title,
                    'body' => r.body
                });
            }

            if (!payloads.isEmpty()) {
                FirebaseService.sendBulkNotifications(JSON.serialize(payloads));
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'NotificationService.dispatch failed: ' + ex.getMessage());
        }
    }

    public static void sendToEmail(String email, String title, String body) {
        dispatch(new List<Request>{ new Request(email, title, body) });
    }
}