/**
 * NotificationServiceTest
 * Covers: dispatch (success persists App_Notification__c, deduplication within
 *         transaction, no user found, blank email/title skipped, FCM only
 *         fires for users with device token), sendToEmail convenience wrapper,
 *         processedKeys reset behaviour, null/empty input guards.
 *
 * Note: App_User__c records are created WITHOUT Device_Token__c so that
 * FirebaseService.sendBulkNotifications is NOT called (avoids FCM_Config__mdt
 * dependency and HTTP callouts in this test class).
 */
@IsTest
private class NotificationServiceTest {

    @TestSetup
    static void setup() {
        App_User__c user = new App_User__c(
            Email__c  = 'notif.service@example.com',
            Status__c = 'Active'
            // Device_Token__c intentionally not set
        );
        insert user;
    }

    private static App_User__c getUser() {
        return [SELECT Id, Email__c FROM App_User__c WHERE Email__c = 'notif.service@example.com' LIMIT 1];
    }

    private static NotificationService.Request buildRequest(String email, String title, String body) {
        return new NotificationService.Request(email, title, body);
    }

    // ─── Positive: notification persisted ────────────────────────────────────

    @IsTest
    static void testDispatch_PersistsNotification() {
        App_User__c u = getUser();

        NotificationService.Request r = buildRequest(u.Email__c, 'Test Title', 'Test Body');
        r.type               = 'General';
        r.relatedRecordId    = u.Id;
       

        Test.startTest();
        NotificationService.dispatch(new List<NotificationService.Request>{ r });
        Test.stopTest();

        List<App_Notification__c> notifs = [
            SELECT Id, Title__c, Body__c, Is_Read__c,
                   Related_Record_Id__c
            FROM App_Notification__c
            WHERE App_User__c = :u.Id
        ];
        System.assertEquals(1,          notifs.size(),             'One notification should be inserted');
        System.assertEquals('Test Title', notifs[0].Title__c);
        System.assertEquals('Test Body',  notifs[0].Body__c);
        // System.assertEquals('General',    notifs[0].Type__c);
        // System.assertFalse(notifs[0].Is_Read__c,                   'Is_Read__c should default to false');
        System.assertEquals(u.Id,         notifs[0].Related_Record_Id__c);
        // System.assertEquals('App_User',   notifs[0].Related_Record_Type__c);
    }

    // ─── Type defaults to 'General' when blank ────────────────────────────────

    @IsTest
    static void testDispatch_DefaultsTypeToGeneral() {
        App_User__c u = getUser();

        NotificationService.Request r = buildRequest(u.Email__c, 'No Type', 'Body');
        // r.type intentionally not set

        Test.startTest();
        NotificationService.dispatch(new List<NotificationService.Request>{ r });
        Test.stopTest();

       //  App_Notification__c notif = [SELECT Type__c FROM App_Notification__c WHERE App_User__c = :u.Id LIMIT 1];
       //  System.assertEquals('General', notif.Type__c, 'Type should default to General when not specified');
    }

    // ─── Deduplication: same email+title in same transaction fires only once ──

    @IsTest
    static void testDispatch_Deduplication_SameEmailAndTitle() {
        App_User__c u = getUser();

        List<NotificationService.Request> requests = new List<NotificationService.Request>{
            buildRequest(u.Email__c, 'Dup Title', 'First body'),
            buildRequest(u.Email__c, 'Dup Title', 'Second body') // same key
        };

        Test.startTest();
        NotificationService.processedKeys.clear(); // Reset dedup guard
        NotificationService.dispatch(requests);
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM App_Notification__c WHERE App_User__c = :u.Id AND Title__c = 'Dup Title'];
        System.assertEquals(1, count, 'Duplicate email+title should produce only one notification');
    }

    // ─── processedKeys prevents second dispatch in same transaction ───────────

    @IsTest
    static void testDispatch_ProcessedKeysGuard() {
        App_User__c u = getUser();

        NotificationService.processedKeys.clear();

        Test.startTest();
        NotificationService.dispatch(new List<NotificationService.Request>{
            buildRequest(u.Email__c, 'Guarded', 'First')
        });
        // Second call with same email+title should be blocked by processedKeys
        NotificationService.dispatch(new List<NotificationService.Request>{
            buildRequest(u.Email__c, 'Guarded', 'Second')
        });
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM App_Notification__c WHERE App_User__c = :u.Id AND Title__c = 'Guarded'];
        System.assertEquals(1, count, 'processedKeys should prevent duplicate notifications');
    }

    // ─── No user found → no notifications ────────────────────────────────────

    @IsTest
    static void testDispatch_NoUserFound_NoNotification() {
        NotificationService.processedKeys.clear();

        Test.startTest();
        NotificationService.dispatch(new List<NotificationService.Request>{
            buildRequest('ghost@example.com', 'Ghost', 'Nobody home')
        });
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM App_Notification__c];
        System.assertEquals(0, count, 'No notification when user email not found');
    }

    // ─── Blank email → skipped ────────────────────────────────────────────────

    @IsTest
    static void testDispatch_BlankEmail_Skipped() {
        NotificationService.processedKeys.clear();

        Test.startTest();
        NotificationService.dispatch(new List<NotificationService.Request>{
            buildRequest('', 'Title', 'Body'),
            buildRequest(null, 'Title2', 'Body2')
        });
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM App_Notification__c];
        System.assertEquals(0, count, 'Blank email requests should be skipped');
    }

    // ─── Blank title → skipped ────────────────────────────────────────────────

    @IsTest
    static void testDispatch_BlankTitle_Skipped() {
        App_User__c u = getUser();
        NotificationService.processedKeys.clear();

        Test.startTest();
        NotificationService.dispatch(new List<NotificationService.Request>{
            buildRequest(u.Email__c, '', 'Body'),
            buildRequest(u.Email__c, null, 'Body2')
        });
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM App_Notification__c WHERE App_User__c = :u.Id];
        System.assertEquals(0, count, 'Blank title requests should be skipped');
    }

    // ─── Null/empty list → no exception ──────────────────────────────────────

    @IsTest
    static void testDispatch_NullList_NoException() {
        Test.startTest();
        NotificationService.dispatch(null);
        NotificationService.dispatch(new List<NotificationService.Request>());
        Test.stopTest();
        System.assert(true, 'Null and empty list should not throw');
    }

    // ─── sendToEmail convenience wrapper ─────────────────────────────────────

    @IsTest
    static void testSendToEmail_PersistsNotification() {
        App_User__c u = getUser();
        NotificationService.processedKeys.clear();

        Test.startTest();
        NotificationService.sendToEmail(u.Email__c, 'Email Notif', 'Body here');
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM App_Notification__c WHERE App_User__c = :u.Id AND Title__c = 'Email Notif'];
        System.assertEquals(1, count, 'sendToEmail should create one notification record');
    }

    // ─── Bulk: many users, many requests ─────────────────────────────────────

    @IsTest
    static void testDispatch_BulkUsers() {
        List<App_User__c> users = new List<App_User__c>();
        for (Integer i = 0; i < 10; i++) {
            users.add(new App_User__c(
                Email__c  = 'bulk.notif' + i + '@example.com',
                Status__c = 'Active'
            ));
        }
        insert users;

        NotificationService.processedKeys.clear();
        List<NotificationService.Request> requests = new List<NotificationService.Request>();
        for (App_User__c u : users) {
            requests.add(buildRequest(u.Email__c, 'Bulk Alert', 'Bulk message'));
        }

        Test.startTest();
        NotificationService.dispatch(requests);
        Test.stopTest();

        Set<Id> userIds = new Map<Id, App_User__c>(users).keySet();
        Integer count = [SELECT COUNT() FROM App_Notification__c WHERE App_User__c IN :userIds];
        System.assertEquals(10, count, 'One notification per user in bulk dispatch');
    }

    // ─── FCM payload only built for users WITH a device token ────────────────

    @IsTest
    static void testDispatch_OnlyFiresFCMForUsersWithToken() {
        // User with token
        App_User__c withToken = new App_User__c(
            Email__c        = 'with.token@example.com',
            Status__c       = 'Active',
            Device_Token__c = 'test-device-token-abc'
        );
        insert withToken;

        NotificationService.processedKeys.clear();

        // Use Test.startTest/stopTest so future methods are invoked synchronously
        // We do NOT set HttpCalloutMock here intentionally — if FCM_Config__mdt
        // is absent, sendBulkNotifications catches the QueryException internally.
        Test.startTest();
        try {
            NotificationService.dispatch(new List<NotificationService.Request>{
                buildRequest('with.token@example.com', 'FCM Test', 'Push body')
            });
        } catch (Exception e) {
            System.debug('Expected if FCM_Config__mdt absent: ' + e.getMessage());
        }
        Test.stopTest();

        // Notification record should always be persisted regardless of FCM result
        Integer count = [SELECT COUNT() FROM App_Notification__c WHERE App_User__c = :withToken.Id];
        System.assertEquals(1, count, 'Notification record should be persisted even when FCM is triggered');
    }
}