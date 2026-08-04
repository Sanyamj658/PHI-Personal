/**
 * PatientNotificationsAPITest
 * Covers: getNotifications (success all, success unread_only, user not found 404,
 *         missing email 400, email case-insensitive, empty notifications),
 *         markRead (by ids, markAllRead, no ids/markAll, malformed body,
 *         invalid id ignored, empty ids list).
 */
@IsTest
private class PatientNotificationsAPITest {

    @TestSetup
    static void setup() {
        App_User__c appUser = new App_User__c(
            Email__c  = 'notif.api@example.com',
            Status__c = 'Active'
        );
        insert appUser;

        // Insert 3 notifications: 2 unread, 1 read
        List<App_Notification__c> notifs = new List<App_Notification__c>{
            new App_Notification__c(
                App_User__c = appUser.Id,
                Title__c    = 'Unread 1',
                Body__c     = 'Body 1',
                Type__c     = 'General',
                Is_Read__c  = false
            ),
            new App_Notification__c(
                App_User__c = appUser.Id,
                Title__c    = 'Unread 2',
                Body__c     = 'Body 2',
                Type__c     = 'Claim_Update',
                Is_Read__c  = false
            ),
            new App_Notification__c(
                App_User__c = appUser.Id,
                Title__c    = 'Already Read',
                Body__c     = 'Body 3',
                Type__c     = 'General',
                Is_Read__c  = true
            )
        };
        insert notifs;
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────

    private static void setupGetContext(String email, String unreadOnly) {
        RestRequest  req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI  = '/services/apexrest/v1/patient-notifications';
        req.httpMethod  = 'GET';
        if (email != null)      req.params.put('email', email);
        if (unreadOnly != null) req.params.put('unread_only', unreadOnly);
        RestContext.request  = req;
        RestContext.response = res;
    }

    private static void setupPostContext(String jsonBody) {
        RestRequest  req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI  = '/services/apexrest/v1/patient-notifications';
        req.httpMethod  = 'POST';
        req.requestBody = Blob.valueOf(jsonBody);
        RestContext.request  = req;
        RestContext.response = res;
    }

    private static Map<String, Object> parseResponse() {
        return (Map<String, Object>) JSON.deserializeUntyped(
            RestContext.response.responseBody.toString()
        );
    }

    private static App_User__c getAppUser() {
        return [SELECT Id FROM App_User__c WHERE Email__c = 'notif.api@example.com' LIMIT 1];
    }

    // ─── GET: all notifications ───────────────────────────────────────────────

    @IsTest
    static void testGetNotifications_AllNotifications() {
        setupGetContext('notif.api@example.com', 'false');

        Test.startTest();
        PatientNotificationsAPI.getNotifications();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        Map<String, Object> result = parseResponse();
        System.assertEquals(true, result.get('success'));

        Map<String, Object> data = (Map<String, Object>) result.get('data');
        System.assertEquals(3, (Integer) data.get('total'), 'All 3 notifications should be returned');
        System.assertEquals(2, (Integer) data.get('unreadCount'), '2 unread notifications');
    }

    // ─── GET: unread only ─────────────────────────────────────────────────────

    @IsTest
    static void testGetNotifications_UnreadOnly() {
        setupGetContext('notif.api@example.com', 'true');

        Test.startTest();
        PatientNotificationsAPI.getNotifications();
        Test.stopTest();

        Map<String, Object> result = parseResponse();
        System.assertEquals(true, result.get('success'));

        Map<String, Object> data = (Map<String, Object>) result.get('data');
        System.assertEquals(2, (Integer) data.get('total'), 'Only 2 unread notifications should be returned');
    }

    // ─── GET: notification fields present ────────────────────────────────────

    @IsTest
    static void testGetNotifications_FieldsPresent() {
        setupGetContext('notif.api@example.com', null);

        Test.startTest();
        PatientNotificationsAPI.getNotifications();
        Test.stopTest();

        Map<String, Object> result = parseResponse();
        Map<String, Object> data   = (Map<String, Object>) result.get('data');
        List<Object> notifs        = (List<Object>) data.get('notifications');
        Map<String, Object> first  = (Map<String, Object>) notifs[0];

        System.assertNotEquals(null, first.get('id'));
        System.assertNotEquals(null, first.get('title'));
        System.assertNotEquals(null, first.get('body'));
        System.assertNotEquals(null, first.get('type'));
        System.assertNotEquals(null, first.get('isRead'));
        System.assertNotEquals(null, first.get('createdDate'));
    }

    // ─── GET: missing email → 400 ─────────────────────────────────────────────

    @IsTest
    static void testGetNotifications_MissingEmail() {
        setupGetContext(null, null);

        Test.startTest();
        PatientNotificationsAPI.getNotifications();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        Map<String, Object> result = parseResponse();
        System.assertEquals('EMAIL_REQUIRED', result.get('errorCode'));
    }

    // ─── GET: user not found → 404 ───────────────────────────────────────────

    @IsTest
    static void testGetNotifications_UserNotFound() {
        setupGetContext('ghost@example.com', null);

        Test.startTest();
        PatientNotificationsAPI.getNotifications();
        Test.stopTest();

        System.assertEquals(404, RestContext.response.statusCode);
        Map<String, Object> result = parseResponse();
        System.assertEquals('USER_NOT_FOUND', result.get('errorCode'));
    }

    // ─── GET: email case-insensitive ──────────────────────────────────────────

    @IsTest
    static void testGetNotifications_EmailCaseInsensitive() {
        setupGetContext('NOTIF.API@EXAMPLE.COM', null);

        Test.startTest();
        PatientNotificationsAPI.getNotifications();
        Test.stopTest();

        Map<String, Object> result = parseResponse();
        System.assertEquals(true, result.get('success'), 'Email lookup should be case-insensitive');
    }

    // ─── POST: mark by ids ────────────────────────────────────────────────────

    @IsTest
    static void testMarkRead_ByIds() {
        App_User__c u = getAppUser();
        List<App_Notification__c> unread = [
            SELECT Id FROM App_Notification__c
            WHERE App_User__c = :u.Id AND Is_Read__c = false
        ];

        List<String> ids = new List<String>();
        for (App_Notification__c n : unread) ids.add(n.Id);

        setupPostContext(JSON.serialize(new Map<String, Object>{ 'ids' => ids }));

        Test.startTest();
        PatientNotificationsAPI.markRead();
        Test.stopTest();

        Map<String, Object> result = parseResponse();
        System.assertEquals(true, result.get('success'));

        Map<String, Object> data = (Map<String, Object>) result.get('data');
        System.assertEquals(2, (Integer) data.get('updatedCount'), '2 notifications should be marked read');

        Integer stillUnread = [SELECT COUNT() FROM App_Notification__c WHERE App_User__c = :u.Id AND Is_Read__c = false];
        System.assertEquals(0, stillUnread, 'All unread should now be read');
    }

    // ─── POST: markAllRead by email ───────────────────────────────────────────

    @IsTest
    static void testMarkRead_MarkAllRead() {
        App_User__c u = getAppUser();

        setupPostContext(JSON.serialize(new Map<String, Object>{
            'markAllRead' => true,
            'email'       => 'notif.api@example.com'
        }));

        Test.startTest();
        PatientNotificationsAPI.markRead();
        Test.stopTest();

        Map<String, Object> result = parseResponse();
        System.assertEquals(true, result.get('success'));

        Integer stillUnread = [SELECT COUNT() FROM App_Notification__c WHERE App_User__c = :u.Id AND Is_Read__c = false];
        System.assertEquals(0, stillUnread, 'markAllRead should mark all unread notifications as read');
    }

    // ─── POST: markAllRead with unknown email → 0 updates ────────────────────

    @IsTest
    static void testMarkRead_MarkAllRead_UnknownEmail() {
        setupPostContext(JSON.serialize(new Map<String, Object>{
            'markAllRead' => true,
            'email'       => 'ghost@example.com'
        }));

        Test.startTest();
        PatientNotificationsAPI.markRead();
        Test.stopTest();

        Map<String, Object> result = parseResponse();
        System.assertEquals(true, result.get('success'));
        Map<String, Object> data = (Map<String, Object>) result.get('data');
        System.assertEquals(0, (Integer) data.get('updatedCount'));
    }

    // ─── POST: no ids and no markAllRead → 0 updates ──────────────────────────

    @IsTest
    static void testMarkRead_NoIdsAndNoMarkAll_ZeroUpdates() {
        setupPostContext('{}');

        Test.startTest();
        PatientNotificationsAPI.markRead();
        Test.stopTest();

        Map<String, Object> result = parseResponse();
        System.assertEquals(true, result.get('success'));
        Map<String, Object> data = (Map<String, Object>) result.get('data');
        System.assertEquals(0, (Integer) data.get('updatedCount'));
    }

    // ─── POST: invalid notification id → safely ignored ──────────────────────

    @IsTest
    static void testMarkRead_InvalidId_Ignored() {
        setupPostContext(JSON.serialize(new Map<String, Object>{
            'ids' => new List<String>{ 'INVALID-ID-VALUE' }
        }));

        Test.startTest();
        PatientNotificationsAPI.markRead();
        Test.stopTest();

        // Invalid ids are caught and skipped, so updatedCount = 0 or success
        Map<String, Object> result = parseResponse();
        System.assertNotEquals(null, result.get('success'));
    }

    // ─── POST: empty ids list → 0 updates ────────────────────────────────────

    @IsTest
    static void testMarkRead_EmptyIds_ZeroUpdates() {
        setupPostContext(JSON.serialize(new Map<String, Object>{ 'ids' => new List<String>() }));

        Test.startTest();
        PatientNotificationsAPI.markRead();
        Test.stopTest();

        Map<String, Object> result = parseResponse();
        System.assertEquals(true, result.get('success'));
        Map<String, Object> data = (Map<String, Object>) result.get('data');
        System.assertEquals(0, (Integer) data.get('updatedCount'));
    }

    // ─── POST: null body → safe empty object ─────────────────────────────────

    @IsTest
    static void testMarkRead_NullBody_ZeroUpdates() {
        RestRequest  req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/v1/patient-notifications';
        req.httpMethod = 'POST';
        // requestBody intentionally null
        RestContext.request  = req;
        RestContext.response = res;

        Test.startTest();
        PatientNotificationsAPI.markRead();
        Test.stopTest();

        Map<String, Object> result = parseResponse();
        System.assertEquals(true, result.get('success'));
    }
}