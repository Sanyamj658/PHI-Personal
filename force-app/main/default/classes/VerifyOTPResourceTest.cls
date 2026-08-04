/**
 * VerifyOTPResourceTest
 * Covers: handlePost – success returns session token + patient data,
 *         missing email (400), missing otpCode (400), user not found (404),
 *         invalid OTP (401), expired OTP (401), OTP cleared after successful verify,
 *         session token stored on user, exception rollback.
 */
@IsTest
private class VerifyOTPResourceTest {

    @TestSetup
    static void setup() {
       Account acc = new Account(
    Name = 'Verify OTP Hospital',
    Account_Manager_Name__c = 'Test Manager'
);
insert acc;

Insurance_Company__c insurance =
    new Insurance_Company__c(
        Name = 'Test Insurance'
    );
insert insurance;

Contact patient = new Contact(
    FirstName        = 'VerifyOTP',
    LastName         = 'Patient',
    Email            = 'verifyotp@example.com',
    DX_s__c          = 'VO01',
    Date_of_Birth__c = Date.newInstance(1988, 5, 20),
    AccountId        = acc.Id,
    Primary_Insurance__c = insurance.Id,
    Plan_Type__c     = 'Other Plan'
);
insert patient;

        App_User__c appUser = new App_User__c(
            Email__c            = 'verifyotp@example.com',
            Status__c           = 'Active',
            Patient__c          = patient.Id,
            OTP__c              = '123456',
            OTP_Expiration__c   = System.now().addMinutes(10)
        );
        insert appUser;
    }

    private static void setupRestContext(String jsonBody) {
        RestRequest  req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI  = '/services/apexrest/v1/verify-otp';
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
        return [SELECT Id, OTP__c, OTP_Expiration__c, Session_Token__c
                FROM App_User__c WHERE Email__c = 'verifyotp@example.com' LIMIT 1];
    }

    // ─── Success ──────────────────────────────────────────────────────────────

    @IsTest
    static void testHandlePost_Success_ReturnsSessionToken() {
        setupRestContext(JSON.serialize(new Map<String, String>{
            'email'   => 'verifyotp@example.com',
            'otpCode' => '123456'
        }));

        Test.startTest();
        VerifyOTPResource.handlePost();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        Map<String, Object> result = parseResponse();
        System.assertEquals(true, result.get('success'));

        Map<String, Object> data = (Map<String, Object>) result.get('data');
        System.assertNotEquals(null, data.get('sessionToken'), 'sessionToken should be returned');
        System.assertNotEquals(null, data.get('fullName'),     'fullName should be returned');
        System.assertEquals('verifyotp@example.com', data.get('email'));
        System.assert(((String) data.get('sessionToken')).length() > 0, 'Session token should not be empty');
    }

    // ─── Success: OTP cleared after use ──────────────────────────────────────

    @IsTest
    static void testHandlePost_Success_OtpClearedAfterVerification() {
        setupRestContext(JSON.serialize(new Map<String, String>{
            'email'   => 'verifyotp@example.com',
            'otpCode' => '123456'
        }));

        Test.startTest();
        VerifyOTPResource.handlePost();
        Test.stopTest();

        App_User__c updated = getAppUser();
        Assert.isNull(updated.OTP__c,            'OTP should be cleared after successful verification');
        Assert.isNull(updated.OTP_Expiration__c, 'OTP expiration should be cleared after use');
    }

    // ─── Success: session token stored on App_User__c ────────────────────────

    @IsTest
    static void testHandlePost_Success_SessionTokenStoredOnUser() {
        setupRestContext(JSON.serialize(new Map<String, String>{
            'email'   => 'verifyotp@example.com',
            'otpCode' => '123456'
        }));

        Test.startTest();
        VerifyOTPResource.handlePost();
        Test.stopTest();

        Map<String, Object> result = parseResponse();
        Map<String, Object> data   = (Map<String, Object>) result.get('data');
        String responseToken = (String) data.get('sessionToken');

        App_User__c updated = getAppUser();
        System.assertEquals(responseToken, updated.Session_Token__c,
            'Session token in response should match what was stored on the user record');
    }

    // ─── Negative: missing email ──────────────────────────────────────────────

    @IsTest
    static void testHandlePost_MissingEmail() {
        setupRestContext(JSON.serialize(new Map<String, String>{ 'otpCode' => '123456' }));

        Test.startTest();
        VerifyOTPResource.handlePost();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        Map<String, Object> result = parseResponse();
        System.assertEquals('INVALID_INPUT', result.get('errorCode'));
    }

    // ─── Negative: missing otpCode ────────────────────────────────────────────

    @IsTest
    static void testHandlePost_MissingOtpCode() {
        setupRestContext(JSON.serialize(new Map<String, String>{ 'email' => 'verifyotp@example.com' }));

        Test.startTest();
        VerifyOTPResource.handlePost();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        Map<String, Object> result = parseResponse();
        System.assertEquals('INVALID_INPUT', result.get('errorCode'));
    }

    // ─── Negative: blank email ────────────────────────────────────────────────

    @IsTest
    static void testHandlePost_BlankEmail() {
        setupRestContext(JSON.serialize(new Map<String, String>{
            'email'   => '',
            'otpCode' => '123456'
        }));

        Test.startTest();
        VerifyOTPResource.handlePost();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
    }

    // ─── Negative: user not found ─────────────────────────────────────────────

    @IsTest
    static void testHandlePost_UserNotFound() {
        setupRestContext(JSON.serialize(new Map<String, String>{
            'email'   => 'nobody@example.com',
            'otpCode' => '999999'
        }));

        Test.startTest();
        VerifyOTPResource.handlePost();
        Test.stopTest();

        System.assertEquals(404, RestContext.response.statusCode);
        Map<String, Object> result = parseResponse();
        System.assertEquals('USER_NOT_FOUND', result.get('errorCode'));
    }

    // ─── Negative: wrong OTP code ─────────────────────────────────────────────

    @IsTest
    static void testHandlePost_WrongOtpCode() {
        setupRestContext(JSON.serialize(new Map<String, String>{
            'email'   => 'verifyotp@example.com',
            'otpCode' => '999999'
        }));

        Test.startTest();
        VerifyOTPResource.handlePost();
        Test.stopTest();

        System.assertEquals(401, RestContext.response.statusCode);
        Map<String, Object> result = parseResponse();
        System.assertEquals('INVALID_OTP', result.get('errorCode'));
    }

    // ─── Negative: expired OTP ────────────────────────────────────────────────

    @IsTest
    static void testHandlePost_ExpiredOtp() {
        App_User__c u = getAppUser();
        u.OTP_Expiration__c = System.now().addMinutes(-5); // already expired
        update u;

        setupRestContext(JSON.serialize(new Map<String, String>{
            'email'   => 'verifyotp@example.com',
            'otpCode' => '123456'
        }));

        Test.startTest();
        VerifyOTPResource.handlePost();
        Test.stopTest();

        System.assertEquals(401, RestContext.response.statusCode);
        Map<String, Object> result = parseResponse();
        System.assertEquals('EXPIRED_OTP', result.get('errorCode'));
    }

    // ─── Negative: null OTP expiration ────────────────────────────────────────

    @IsTest
    static void testHandlePost_NullOtpExpiration() {
        App_User__c u = getAppUser();
        u.OTP_Expiration__c = null;
        update u;

        setupRestContext(JSON.serialize(new Map<String, String>{
            'email'   => 'verifyotp@example.com',
            'otpCode' => '123456'
        }));

        Test.startTest();
        VerifyOTPResource.handlePost();
        Test.stopTest();

        System.assertEquals(401, RestContext.response.statusCode);
        Map<String, Object> result = parseResponse();
        System.assertEquals('EXPIRED_OTP', result.get('errorCode'),
            'Null expiration should be treated as expired');
    }

    // ─── Edge: email case-insensitive match ───────────────────────────────────

    @IsTest
    static void testHandlePost_EmailCaseInsensitive() {
        setupRestContext(JSON.serialize(new Map<String, String>{
            'email'   => 'VERIFYOTP@EXAMPLE.COM',
            'otpCode' => '123456'
        }));

        Test.startTest();
        VerifyOTPResource.handlePost();
        Test.stopTest();

        Map<String, Object> result = parseResponse();
        System.assertEquals(true, result.get('success'), 'Email match should be case-insensitive');
    }

    // ─── Edge: OTP not set on user ────────────────────────────────────────────

    @IsTest
    static void testHandlePost_OtpNotSet_InvalidOtp() {
        App_User__c u = getAppUser();
        u.OTP__c = null;
        update u;

        setupRestContext(JSON.serialize(new Map<String, String>{
            'email'   => 'verifyotp@example.com',
            'otpCode' => '123456'
        }));

        Test.startTest();
        VerifyOTPResource.handlePost();
        Test.stopTest();

        System.assertEquals(401, RestContext.response.statusCode);
        Map<String, Object> result = parseResponse();
        System.assertEquals('INVALID_OTP', result.get('errorCode'),
            'Null OTP on record should result in INVALID_OTP');
    }

    // ─── Exception: malformed JSON ────────────────────────────────────────────

    @IsTest
    static void testHandlePost_MalformedJson_ExceptionHandled() {
        setupRestContext('not-valid-json');

        Test.startTest();
        VerifyOTPResource.handlePost();
        Test.stopTest();

        Map<String, Object> result = parseResponse();
        System.assertEquals(false,           result.get('success'));
        System.assertEquals('INTERNAL_ERROR', result.get('errorCode'));
    }

    // ─── Full name construction from Contact ──────────────────────────────────

    @IsTest
    static void testHandlePost_FullNameBuiltCorrectly() {
        setupRestContext(JSON.serialize(new Map<String, String>{
            'email'   => 'verifyotp@example.com',
            'otpCode' => '123456'
        }));

        Test.startTest();
        VerifyOTPResource.handlePost();
        Test.stopTest();

        Map<String, Object> result = parseResponse();
        Map<String, Object> data   = (Map<String, Object>) result.get('data');
        System.assertEquals('VerifyOTP Patient', data.get('fullName'), 'Full name should be FirstName + LastName');
    }
}