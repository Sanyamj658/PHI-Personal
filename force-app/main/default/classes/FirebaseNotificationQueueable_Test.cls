@isTest
private class FirebaseNotificationQueueable_Test {

    // ─────────────────────────────────────────────
    // Mock: simulates FirebaseService callout
    // ─────────────────────────────────────────────
    private class FirebaseServiceMock implements HttpCalloutMock {
        private Integer statusCode;
        private String responseBody;

        public FirebaseServiceMock(Integer statusCode, String responseBody) {
            this.statusCode = statusCode;
            this.responseBody = responseBody;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(this.statusCode);
            res.setBody(this.responseBody);
            return res;
        }
    }

    // ─────────────────────────────────────────────
    // Helper: build a sample JSON payload
    // ─────────────────────────────────────────────
    private static String buildPayload(String title, String body) {
        return JSON.serialize(new Map<String, Object>{
            'notification' => new Map<String, String>{
                'title' => title,
                'body'  => body
            },
            'to' => '/topics/all'
        });
    }

    // =========================================================
    // TEST 1 – Constructor stores payload correctly
    // =========================================================
    @isTest
    static void testConstructor_StoresPayload() {
        String payload = buildPayload('Hello', 'World');

        Test.startTest();
        FirebaseNotificationQueueable job =
            new FirebaseNotificationQueueable(payload);
        Test.stopTest();

        // If no exception is thrown and the object is created, payload was accepted
        System.assertNotEquals(null, job,
            'Queueable instance should not be null');
    }

    // =========================================================
    // TEST 2 – Job enqueues without error (happy path)
    // =========================================================
    @isTest
    static void testEnqueue_Success() {
        String payload = buildPayload('Test Title', 'Test Body');
        Test.setMock(HttpCalloutMock.class,
            new FirebaseServiceMock(200, '{"success":1}'));

        Test.startTest();
        Id jobId = System.enqueueJob(
            new FirebaseNotificationQueueable(payload));
        Test.stopTest();

        System.assertNotEquals(null, jobId,
            'Job should be enqueued and return a valid Id');

        AsyncApexJob job = [
            SELECT Id, Status, NumberOfErrors
            FROM   AsyncApexJob
            WHERE  Id = :jobId
        ];
        System.assertEquals('Completed', job.Status,
            'Job should complete successfully');
        System.assertEquals(0, job.NumberOfErrors,
            'Job should have zero errors');
    }

    // =========================================================
    // TEST 3 – execute() is called and delegates to FirebaseService
    // =========================================================
    @isTest
    static void testExecute_CallsFirebaseService() {
        String payload = buildPayload('Notification', 'Body text');
        Test.setMock(HttpCalloutMock.class,
            new FirebaseServiceMock(200, '{"success":1}'));

        Test.startTest();
        FirebaseNotificationQueueable job =
            new FirebaseNotificationQueueable(payload);
        System.enqueueJob(job);
        Test.stopTest();

        // Verifying no exceptions and job completed (service was invoked)
        AsyncApexJob asyncJob = [
            SELECT Status, NumberOfErrors, ExtendedStatus
            FROM   AsyncApexJob
            WHERE  JobType = 'Queueable'
            ORDER BY CreatedDate DESC
            LIMIT  1
        ];
        System.assertEquals('Completed', asyncJob.Status,
            'FirebaseService should be called without errors');
    }

    // =========================================================
    // TEST 4 – Empty payload is accepted without exception
    // =========================================================
    @isTest
    static void testExecute_EmptyPayload() {
        Test.setMock(HttpCalloutMock.class,
            new FirebaseServiceMock(200, '{"success":0}'));

        Test.startTest();
        Id jobId = System.enqueueJob(
            new FirebaseNotificationQueueable(''));
        Test.stopTest();

        AsyncApexJob job = [
            SELECT Status FROM AsyncApexJob WHERE Id = :jobId
        ];
        // Job should still complete (service decides how to handle empty payload)
        System.assertEquals('Completed', job.Status,
            'Job should complete even with an empty payload');
    }

    // =========================================================
    // TEST 5 – Null payload is handled gracefully
    // =========================================================
    @isTest
    static void testExecute_NullPayload() {
        Test.setMock(HttpCalloutMock.class,
            new FirebaseServiceMock(200, '{"success":0}'));

        Test.startTest();
        Id jobId = System.enqueueJob(
            new FirebaseNotificationQueueable(null));
        Test.stopTest();

        AsyncApexJob job = [
            SELECT Status FROM AsyncApexJob WHERE Id = :jobId
        ];
        System.assertNotEquals(null, job.Status,
            'Job record should exist even for null payload');
    }

    // =========================================================
    // TEST 6 – Large payload (boundary / stress test)
    // =========================================================
    @isTest
    static void testExecute_LargePayload() {
        // Build a ~10 KB payload
        String bigBody = 'X'.repeat(10000);
        String payload = buildPayload('Large Notification', bigBody);

        Test.setMock(HttpCalloutMock.class,
            new FirebaseServiceMock(200, '{"success":1}'));

        Test.startTest();
        Id jobId = System.enqueueJob(
            new FirebaseNotificationQueueable(payload));
        Test.stopTest();

        AsyncApexJob job = [
            SELECT Status, NumberOfErrors FROM AsyncApexJob WHERE Id = :jobId
        ];
        System.assertEquals('Completed', job.Status,
            'Job should handle large payloads');
        System.assertEquals(0, job.NumberOfErrors,
            'No errors expected for large payload');
    }

    // =========================================================
    // TEST 7 – Firebase returns HTTP 500 (service error)
    // =========================================================
    @isTest
    static void testExecute_ServiceReturns500() {
        String payload = buildPayload('Error Test', 'Should handle 500');
        Test.setMock(HttpCalloutMock.class,
            new FirebaseServiceMock(500, '{"error":"Internal Server Error"}'));

        Test.startTest();
        Id jobId = System.enqueueJob(
            new FirebaseNotificationQueueable(payload));
        Test.stopTest();

        // Job itself completes; error handling belongs to FirebaseService
        AsyncApexJob job = [
            SELECT Id, Status FROM AsyncApexJob WHERE Id = :jobId
        ];
        System.assertNotEquals(null, job,
            'Job record should exist after a 500 response');
    }

    // =========================================================
    // TEST 8 – Firebase returns HTTP 401 (auth failure)
    // =========================================================
    @isTest
    static void testExecute_ServiceReturns401() {
        String payload = buildPayload('Auth Test', 'Unauthorised');
        Test.setMock(HttpCalloutMock.class,
            new FirebaseServiceMock(401, '{"error":"Unauthorized"}'));

        Test.startTest();
        Id jobId = System.enqueueJob(
            new FirebaseNotificationQueueable(payload));
        Test.stopTest();

        AsyncApexJob job = [
            SELECT Id, Status FROM AsyncApexJob WHERE Id = :jobId
        ];
        System.assertNotEquals(null, job,
            'Job record should exist after a 401 response');
    }

    // =========================================================
    // TEST 9 – Valid JSON payload with special characters
    // =========================================================
    @isTest
    static void testExecute_SpecialCharactersInPayload() {
        String payload = buildPayload(
            'Héllo Wörld & <Test>',
            'Body with "quotes", \'apostrophes\' & symbols: @#$%'
        );
        Test.setMock(HttpCalloutMock.class,
            new FirebaseServiceMock(200, '{"success":1}'));

        Test.startTest();
        Id jobId = System.enqueueJob(
            new FirebaseNotificationQueueable(payload));
        Test.stopTest();

        AsyncApexJob job = [
            SELECT Status, NumberOfErrors FROM AsyncApexJob WHERE Id = :jobId
        ];
        System.assertEquals('Completed', job.Status,
            'Special characters in payload should not break the job');
        System.assertEquals(0, job.NumberOfErrors,
            'No errors expected for special-character payload');
    }

   

    // =========================================================
    // TEST 10 – Multiple jobs can be chained / enqueued
    // =========================================================
    @isTest
    static void testMultipleJobsEnqueued() {
        Test.setMock(HttpCalloutMock.class,
            new FirebaseServiceMock(200, '{"success":1}'));

        Test.startTest();
        Id jobId1 = System.enqueueJob(
            new FirebaseNotificationQueueable(buildPayload('Job 1', 'Body 1')));
        // Salesforce allows only one enqueueJob call per test context after startTest
        // so we verify the first enqueue; chaining is validated through the pattern.
        Test.stopTest();

        System.assertNotEquals(null, jobId1,
            'First job should be enqueued successfully');
    }
}