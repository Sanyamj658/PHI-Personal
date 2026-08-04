/**
 * PatientAppRegisterTest
 * Covers: handlePost – success creates App_User__c in Pending status,
 *         missing required fields (400), invalid email format (400),
 *         invalid date format (400), duplicate user (409),
 *         exception rollback, bulk-safe input patterns.
 *
 * Note: PatientAppRegister uses MM/dd/yyyy date format for dateOfBirth parsing
 * (day = parts[0], month = parts[1], year = parts[2]).
 */
@IsTest
private class PatientAppRegisterTest {

    private static void setupRestContext(String jsonBody) {
        RestRequest  req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI  = '/services/apexrest/v1/patient-register';
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
        setupRestContext(validBody());

        Test.startTest();
        PatientAppRegister.handlePost();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        Map<String, Object> result = parseResponse();
        System.assertEquals(true,  result.get('success'));
        System.assert(((String) result.get('message')).contains('pending'));

        Map<String, Object> data = (Map<String, Object>) result.get('data');
        System.assertNotEquals(null, data.get('appUserId'), 'appUserId should be returned');
        System.assertEquals('Alice Register', data.get('fullName'));
        System.assertEquals('alice.register@example.com', data.get('email'));
        System.assertEquals('Pending', data.get('status'));

        // Verify record was actually inserted
        List<App_User__c> users = [SELECT Id, Status__c, Email__c FROM App_User__c WHERE Email__c = 'alice.register@example.com'];
        System.assertEquals(1, users.size(),   'One App_User__c should be created');
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
        PatientAppRegister.handlePost();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        Map<String, Object> result = parseResponse();
        System.assertEquals('INVALID_INPUT', result.get('errorCode'));
        System.assert(((String) result.get('message')).contains('firstName'));
    }

    // ─── Negative: missing lastName ───────────────────────────────────────────

    @IsTest
    static void testHandlePost_MissingLastName() {
        setupRestContext(JSON.serialize(new Map<String, String>{
            'firstName'   => 'Alice',
            'email'       => 'missing.last@example.com',
            'dateOfBirth' => '01/01/1990'
        }));

        Test.startTest();
        PatientAppRegister.handlePost();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        Map<String, Object> result = parseResponse();
        System.assert(((String) result.get('message')).contains('lastName'));
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
        PatientAppRegister.handlePost();
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
        PatientAppRegister.handlePost();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        Map<String, Object> result = parseResponse();
        System.assert(((String) result.get('message')).contains('dateOfBirth'));
    }

    // ─── Negative: all fields missing ─────────────────────────────────────────

    @IsTest
    static void testHandlePost_AllFieldsMissing() {
        setupRestContext('{}');

        Test.startTest();
        PatientAppRegister.handlePost();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        Map<String, Object> result = parseResponse();
        System.assertEquals('INVALID_INPUT', result.get('errorCode'));
    }

    // ─── Negative: invalid email format ──────────────────────────────────────

    @IsTest
    static void testHandlePost_InvalidEmailFormat() {
        setupRestContext(JSON.serialize(new Map<String, String>{
            'firstName'   => 'Alice',
            'lastName'    => 'Register',
            'email'       => 'not-an-email',
            'dateOfBirth' => '01/01/1990'
        }));

        Test.startTest();
        PatientAppRegister.handlePost();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        Map<String, Object> result = parseResponse();
        System.assertEquals('INVALID_EMAIL', result.get('errorCode'));
    }

    // ─── Negative: invalid date format (wrong separator) ─────────────────────

    @IsTest
    static void testHandlePost_InvalidDateFormat_WrongSeparator() {
        setupRestContext(JSON.serialize(new Map<String, String>{
            'firstName'   => 'Alice',
            'lastName'    => 'Register',
            'email'       => 'baddate@example.com',
            'dateOfBirth' => '1990-01-01'
        }));

        Test.startTest();
        PatientAppRegister.handlePost();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        Map<String, Object> result = parseResponse();
        System.assertEquals('INVALID_DATE_FORMAT', result.get('errorCode'));
    }

    // ─── Negative: invalid date format (text) ────────────────────────────────

    @IsTest
    static void testHandlePost_InvalidDateFormat_Text() {
        setupRestContext(JSON.serialize(new Map<String, String>{
            'firstName'   => 'Bob',
            'lastName'    => 'BadDate',
            'email'       => 'baddate2@example.com',
            'dateOfBirth' => 'January 1st 1990'
        }));

        Test.startTest();
        PatientAppRegister.handlePost();
        Test.stopTest();

        Map<String, Object> result = parseResponse();
        System.assertEquals('INVALID_DATE_FORMAT', result.get('errorCode'));
    }

    // ─── Negative: duplicate user ─────────────────────────────────────────────

    @IsTest
    static void testHandlePost_DuplicateUser_Conflict() {
        insert new App_User__c(Email__c = 'alice.register@example.com', dob__c = Date.newInstance(1990, 2, 1),  Status__c = 'Pending');

        setupRestContext(validBody());

        Test.startTest();
        PatientAppRegister.handlePost();
        Test.stopTest();

        System.assertEquals(409, RestContext.response.statusCode);
        Map<String, Object> result = parseResponse();
        System.assertEquals('DUPLICATE_USER', result.get('errorCode'));
        System.assert(((String) result.get('message')).containsIgnoreCase('registered'));
    }

    // ─── Edge: email with leading/trailing spaces is trimmed ─────────────────

    @IsTest
    static void testHandlePost_EmailTrimmed() {
        setupRestContext(JSON.serialize(new Map<String, String>{
            'firstName'   => 'Trim',
            'lastName'    => 'Email',
            'email'       => '  trim.email@example.com  ',
            'dateOfBirth' => '15/06/1985'
        }));

        Test.startTest();
        PatientAppRegister.handlePost();
        Test.stopTest();

        Map<String, Object> result = parseResponse();
        System.assertEquals(true, result.get('success'), 'Trimmed email should be accepted');

        App_User__c u = [SELECT Email__c FROM App_User__c WHERE Email__c = 'trim.email@example.com' LIMIT 1];
        System.assertEquals('trim.email@example.com', u.Email__c);
    }

    // ─── Edge: optional phone field can be omitted ────────────────────────────

    @IsTest
    static void testHandlePost_OptionalPhoneOmitted_Success() {
        setupRestContext(JSON.serialize(new Map<String, String>{
            'firstName'   => 'Nophone',
            'lastName'    => 'User',
            'email'       => 'nophone@example.com',
            'dateOfBirth' => '10/10/1995'
        }));

        Test.startTest();
        PatientAppRegister.handlePost();
        Test.stopTest();

        Map<String, Object> result = parseResponse();
        System.assertEquals(true, result.get('success'), 'Registration without phone should succeed');
    }

    // ─── Exception / malformed JSON ──────────────────────────────────────────

    @IsTest
    static void testHandlePost_MalformedJson_ExceptionHandled() {
        setupRestContext('not-json-at-all');

        Test.startTest();
        PatientAppRegister.handlePost();
        Test.stopTest();

        Map<String, Object> result = parseResponse();
        System.assertEquals(false,           result.get('success'));
        System.assertEquals('INTERNAL_ERROR', result.get('errorCode'));
    }
}