/**
 * PatientAppDeleteAccountTest
 * Covers: handlePost – success deletes the matching App_User__c record,
 *         missing required fields (400), invalid date format (400),
 *         no matching account (404), exception rollback.
 *
 * Note: dateOfBirth accepts either ISO format (yyyy-MM-dd, sent by the
 * mobile app's delete-account screen) or the dd/MM/yyyy slash format used
 * elsewhere in this app (day = parts[0], month = parts[1], year = parts[2]).
 * Either way the parsed Date is compared against the stored dob__c.
 */
@IsTest
private class PatientAppDeleteAccountTest {

    private static void setupRestContext(String jsonBody) {
        RestRequest  req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI  = '/services/apexrest/v1/app-user-delete';
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

    private static String validBody() {
        return JSON.serialize(new Map<String, String>{
            'firstName'   => 'Alice',
            'lastName'    => 'Register',
            'email'       => 'alice.register@example.com',
            'dateOfBirth' => '01/02/1990'  // day=01, month=02, year=1990
        });
    }

    // ─── Success ──────────────────────────────────────────────────────────────

    @IsTest
    static void testHandlePost_Success() {
        insert new App_User__c(
            Name = 'Alice Register',
            Email__c = 'alice.register@example.com',
            dob__c = Date.newInstance(1990, 2, 1),
            Status__c = 'Approved'
        );

        setupRestContext(validBody());

        Test.startTest();
        PatientAppDeleteAccount.handlePost();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        Map<String, Object> result = parseResponse();
        System.assertEquals(true, result.get('success'));
        System.assert(((String) result.get('message')).contains('deleted'));

        Map<String, Object> data = (Map<String, Object>) result.get('data');
        System.assertEquals('Alice Register', data.get('fullName'));
        System.assertEquals('alice.register@example.com', data.get('email'));

        List<App_User__c> remaining = [SELECT Id FROM App_User__c WHERE Email__c = 'alice.register@example.com'];
        System.assertEquals(0, remaining.size(), 'App_User__c should be deleted');
    }

    // ─── Negative: missing firstName ──────────────────────────────────────────

    @IsTest
    static void testHandlePost_MissingFirstName() {
        setupRestContext(JSON.serialize(new Map<String, String>{
            'lastName'    => 'Register',
            'email'       => 'missing.first@example.com',
            'dateOfBirth' => '01/01/1990'
        }));

        Test.startTest();
        PatientAppDeleteAccount.handlePost();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        Map<String, Object> result = parseResponse();
        System.assertEquals('INVALID_INPUT', result.get('errorCode'));
        System.assert(((String) result.get('message')).contains('firstName'));
    }

    // ─── Negative: missing email ──────────────────────────────────────────────

    @IsTest
    static void testHandlePost_MissingEmail() {
        setupRestContext(JSON.serialize(new Map<String, String>{
            'firstName'   => 'Alice',
            'lastName'    => 'Register',
            'dateOfBirth' => '01/01/1990'
        }));

        Test.startTest();
        PatientAppDeleteAccount.handlePost();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        Map<String, Object> result = parseResponse();
        System.assert(((String) result.get('message')).contains('email'));
    }

    // ─── Negative: missing dateOfBirth ────────────────────────────────────────

    @IsTest
    static void testHandlePost_MissingDateOfBirth() {
        setupRestContext(JSON.serialize(new Map<String, String>{
            'firstName' => 'Alice',
            'lastName'  => 'Register',
            'email'     => 'missingdob@example.com'
        }));

        Test.startTest();
        PatientAppDeleteAccount.handlePost();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        Map<String, Object> result = parseResponse();
        System.assert(((String) result.get('message')).contains('dateOfBirth'));
    }

    // ─── Negative: invalid date format ────────────────────────────────────────

    @IsTest
    static void testHandlePost_InvalidDateFormat() {
        setupRestContext(JSON.serialize(new Map<String, String>{
            'firstName'   => 'Alice',
            'lastName'    => 'Register',
            'email'       => 'baddate@example.com',
            'dateOfBirth' => 'January 1st 1990'
        }));

        Test.startTest();
        PatientAppDeleteAccount.handlePost();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        Map<String, Object> result = parseResponse();
        System.assertEquals('INVALID_DATE_FORMAT', result.get('errorCode'));
    }

    // ─── Success: mobile app sends ISO date format (yyyy-MM-dd) ───────────────
    // Regression test: the mobile app's delete-account screen sends dateOfBirth
    // as "2026-07-05" (ISO), not the dd/MM/yyyy format used by other screens.

    @IsTest
    static void testHandlePost_Success_IsoDateFormat() {
        insert new App_User__c(
            Name = 'Avi Jain',
            Email__c = 'jai.sanyam@concret.io',
            dob__c = Date.newInstance(2026, 7, 5),
            Status__c = 'Approved'
        );

        setupRestContext(JSON.serialize(new Map<String, String>{
            'firstName'   => 'Avi',
            'lastName'    => 'Jain',
            'email'       => 'jai.sanyam@concret.io',
            'dateOfBirth' => '2026-07-05'
        }));

        Test.startTest();
        PatientAppDeleteAccount.handlePost();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        Map<String, Object> result = parseResponse();
        System.assertEquals(true, result.get('success'));

        List<App_User__c> remaining = [SELECT Id FROM App_User__c WHERE Email__c = 'jai.sanyam@concret.io'];
        System.assertEquals(0, remaining.size(), 'App_User__c should be deleted when dateOfBirth is sent in ISO format');
    }

    // ─── Negative: no matching account (wrong name) ───────────────────────────

    @IsTest
    static void testHandlePost_NoMatch_NameMismatch() {
        insert new App_User__c(
            Name = 'Someone Else',
            Email__c = 'alice.register@example.com',
            dob__c = Date.newInstance(1990, 2, 1),
            Status__c = 'Approved'
        );

        setupRestContext(validBody());

        Test.startTest();
        PatientAppDeleteAccount.handlePost();
        Test.stopTest();

        System.assertEquals(404, RestContext.response.statusCode);
        Map<String, Object> result = parseResponse();
        System.assertEquals('NOT_FOUND', result.get('errorCode'));

        List<App_User__c> remaining = [SELECT Id FROM App_User__c WHERE Email__c = 'alice.register@example.com'];
        System.assertEquals(1, remaining.size(), 'Non-matching App_User__c should not be deleted');
    }

    // ─── Negative: no matching account (nothing exists) ───────────────────────

    @IsTest
    static void testHandlePost_NoMatch_NoRecord() {
        setupRestContext(validBody());

        Test.startTest();
        PatientAppDeleteAccount.handlePost();
        Test.stopTest();

        System.assertEquals(404, RestContext.response.statusCode);
        Map<String, Object> result = parseResponse();
        System.assertEquals('NOT_FOUND', result.get('errorCode'));
    }

    // ─── Exception / malformed JSON ──────────────────────────────────────────

    @IsTest
    static void testHandlePost_MalformedJson_ExceptionHandled() {
        setupRestContext('not-json-at-all');

        Test.startTest();
        PatientAppDeleteAccount.handlePost();
        Test.stopTest();

        Map<String, Object> result = parseResponse();
        System.assertEquals(false, result.get('success'));
        System.assertEquals('INTERNAL_ERROR', result.get('errorCode'));
    }
}
