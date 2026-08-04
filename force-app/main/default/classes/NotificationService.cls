/**
 * NotificationService
 * Central dispatcher for all notifications to the mobile app.
 *
 * Every notification is persisted as an App_Notification__c record so the
 * mobile inbox always has a complete message history regardless of push
 * permission state.  FCM push is sent in addition, only when a device token
 * is present — it is a tap-on-the-shoulder, not the source of truth.
 *
 * Usage:
 *   NotificationService.Request r = new NotificationService.Request(email, title, body);
 *   r.type             = 'Claim_Update';          // optional
 *   r.relatedRecordId  = String.valueOf(claim.Id); // optional – for deep link
 *   r.relatedRecordType = 'Claim';                 // optional
 *   NotificationService.dispatch(new List<NotificationService.Request>{ r });
 */
public class NotificationService {

    // ─── Inner types ────────────────────────────────────────────────────────

    public class Request {
        public String email;
        public String title;
        public String body;
        public String type;               // maps to App_Notification__c.Type__c
        public String relatedRecordId;    // for mobile deep linking
        public String relatedRecordType;  // e.g. 'Claim', 'Case'

        public Request(String email, String title, String body) {
            this.email = email;
            this.title = title;
            this.body  = body;
        }
    }

    // ─── Deduplication guard (per transaction) ───────────────────────────────
    @TestVisible
    private static Set<String> processedKeys = new Set<String>();

    // ─── Public API ──────────────────────────────────────────────────────────

    /**
     * Persist + dispatch notifications for a list of requests.
     * Bulk-safe: one SOQL query regardless of list size.
     * Persists App_Notification__c for every user found.
     * Fires FCM callout only for users with a device token.
     */
    public static void dispatch(List<Request> requests) {
        if (requests == null || requests.isEmpty()) return;

        // Step 1 – deduplicate within this transaction
        Map<String, Request> dedupedByEmail = new Map<String, Request>();
        for (Request r : requests) {
            if (String.isBlank(r.email) || String.isBlank(r.title)) continue;
            String key = r.email.toLowerCase() + '|' + r.title;
            if (processedKeys.contains(key)) continue;
            processedKeys.add(key);
            dedupedByEmail.put(r.email.toLowerCase(), r);
        }

        if (dedupedByEmail.isEmpty()) return;

        // Step 2 – look up App_User__c records (Id + token needed)
        List<App_User__c> appUsers = [
            SELECT Id, Email__c, Device_Token__c
            FROM   App_User__c
            WHERE  Email__c IN :dedupedByEmail.keySet()
        ];

        if (appUsers.isEmpty()) {
            System.debug('[NotificationService] No app users found for: ' + dedupedByEmail.keySet());
            return;
        }

        // Step 3 – persist App_Notification__c for every matched user
        List<App_Notification__c> toInsert = new List<App_Notification__c>();
        for (App_User__c u : appUsers) {
            String  lEmail = u.Email__c.toLowerCase();
            Request r      = dedupedByEmail.get(lEmail);
            if (r == null) continue;

            toInsert.add(new App_Notification__c(
                App_User__c            = u.Id,
                Title__c               = r.title,
                Body__c                = r.body,
                Related_Record_Id__c   = r.relatedRecordId,
                Is_Read__c             = false
            ));
        }
        if (!toInsert.isEmpty()) {
            insert toInsert;
        }

        // Step 4 – build FCM payloads only for users with a device token
        List<Map<String, String>> payloads = new List<Map<String, String>>();
        for (App_User__c u : appUsers) {
            if (String.isBlank(u.Device_Token__c)) continue;
            String  lEmail = u.Email__c.toLowerCase();
            Request r      = dedupedByEmail.get(lEmail);
            if (r == null) continue;

            payloads.add(new Map<String, String>{
                'deviceToken' => u.Device_Token__c,
                'title'       => r.title,
                'body'        => r.body
            });
        }

        if (!payloads.isEmpty()) {
            System.debug('[NotificationService] Dispatching ' + payloads.size() + ' FCM notification(s)');
            FirebaseService.sendBulkNotifications(JSON.serialize(payloads));
        }
    }

    /**
     * Convenience wrapper for a single email → notification.
     */
    public static void sendToEmail(String email, String title, String body) {
        dispatch(new List<Request>{ new Request(email, title, body) });
    }
}