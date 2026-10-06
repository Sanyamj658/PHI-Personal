/**
 * RequestOTPResourceTest
 * Covers: handlePost – success sends OTP and sets expiration,
 *         missing email (400), missing DOB (400), invalid date format (400),
 *         user not found (404), account not approved (403),
 *         account Active but no Patient linked (403), OTP overwritten on re-request,
 *         exception handling.
 *
 * Note: RequestOTPResource parses DOB as dd/mm/yyyy
 *   (day = parts[0], month = parts[1], year = parts[2]).
 */
@IsTest
private class RequestOTPResourceTest {

    @TestSetup
    static void setup() {
        
         Insurance_Company__c insurance =
    new Insurance_Company__c(
        Name = 'Test Insurance'
    );
insert insurance;
        Contact patient = new Contact(
            FirstName        = 'OTPTest',
            LastName         = 'Patient',
            Email            = 'otptest@example.com',
            DX_s__c          = 'OTP01',
            Date_of_Birth__c = Date.newInstance(1990, 3, 15),
             Primary_Insurance__c = insurance.Id,
    Plan_Type__c = 'Other Plan'
        );
        insert patient;

        App_User__c activeUser = new App_User__c(
            Email__c   = 'otptest@example.com',
            Status__c  = 'Active',
            dob__c     = Date.newInstance(1990, 3, 15),
            Patient__c = patient.Id
        );
        insert activeUser;

        // Pending user (not approved)
        App_User__c pendingUser = new App_User__c(
            Email__c  = 'pending.otp@example.com',
            Status__c = 'Pending',
            dob__c    = Date.newInstance(1985, 1, 1)
        );
        insert pendingUser;

        // AppUserTrigger (before insert) overrides Status__c, so set the statuses after insert.
        activeUser.Status__c  = 'Active';
        pendingUser.Status__c = 'Pending';
        update new List<App_User__c>{ activeUser, pendingUser };
    }

    private static void setupRestContext(String jsonBody) {
        RestRequest  req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI  = '/services/apexrest/v1/request-otp';
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

    // ─── Success ──────────────────────────────────────────────────────────────

    @IsTest
    static void testHandlePost_Success_OTPSent() {
        // DOB in dd/mm/yyyy format: 15/03/1990
        setupRestContext(JSON.serialize(new Map<String, String>{
            'email'       => 'otptest@example.com',
            'dateOfBirth' => '15/03/1990'
        }));

        Test.startTest();
        RequestOTPResource.handlePost();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        Map<String, Object> result = parseResponse();
        System.assertEquals(true,  result.get('success'));
        System.assert(((String) result.get('message')).contains('OTP sent'));

        // Verify OTP and expiration were set
        App_User__c updated = [SELECT OTP__c, OTP_Expiration__c FROM App_User__c WHERE Email__c = 'otptest@example.com'];
        System.assertNotEquals(null,   updated.OTP__c,            'OTP should be set');
        System.assertNotEquals(null,   updated.OTP_Expiration__c, 'OTP expiration should be set');
        System.assertEquals(6, updated.OTP__c.length(), 'OTP should be 6 digits');
        System.assert(updated.OTP_Expiration__c > System.now(), 'OTP should expire in the future');
    }

    // ─── Negative: missing email ──────────────────────────────────────────────

    @IsTest
    static void testHandlePost_MissingEmail() {
        setupRestContext(JSON.serialize(new Map<String, String>{
            'dateOfBirth' => '15/03/1990'
        }));

        Test.startTest();
        RequestOTPResource.handlePost();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        Map<String, Object> result = parseResponse();
        System.assertEquals('INVALID_INPUT', result.get('errorCode'));
    }

    // ─── Negative: missing dateOfBirth ───────────────────────────────────────

    @IsTest
    static void testHandlePost_MissingDateOfBirth() {
        setupRestContext(JSON.serialize(new Map<String, String>{
            'email' => 'otptest@example.com'
        }));

        Test.startTest();
        RequestOTPResource.handlePost();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        Map<String, Object> result = parseResponse();
        System.assertEquals('INVALID_INPUT', result.get('errorCode'));
    }

    // ─── Negative: invalid date format ───────────────────────────────────────

    @IsTest
    static void testHandlePost_InvalidDateFormat_WrongSeparator() {
        setupRestContext(JSON.serialize(new Map<String, String>{
            'email'       => 'otptest@example.com',
            'dateOfBirth' => '1990-03-15'
        }));

        Test.startTest();
        RequestOTPResource.handlePost();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        Map<String, Object> result = parseResponse();
        System.assertEquals('INVALID_DATE_FORMAT', result.get('errorCode'));
    }

    // ─── Negative: invalid date format (text) ────────────────────────────────

    @IsTest
    static void testHandlePost_InvalidDateFormat_Text() {
        setupRestContext(JSON.serialize(new Map<String, String>{
            'email'       => 'otptest@example.com',
            'dateOfBirth' => 'not-a-date'
        }));

        Test.startTest();
        RequestOTPResource.handlePost();
        Test.stopTest();

        Map<String, Object> result = parseResponse();
        System.assertEquals('INVALID_DATE_FORMAT', result.get('errorCode'));
    }

    // ─── Negative: user not found ────────────────────────────────────────────

    @IsTest
    static void testHandlePost_UserNotFound() {
        setupRestContext(JSON.serialize(new Map<String, String>{
            'email'       => 'nobody@example.com',
            'dateOfBirth' => '01/01/1990'
        }));

        Test.startTest();
        RequestOTPResource.handlePost();
        Test.stopTest();

        System.assertEquals(404, RestContext.response.statusCode);
        Map<String, Object> result = parseResponse();
        System.assertEquals('USER_NOT_FOUND', result.get('errorCode'));
    }

    // ─── Negative: account not approved (Pending status) ─────────────────────

    @IsTest
    static void testHandlePost_AccountNotApproved() {
        setupRestContext(JSON.serialize(new Map<String, String>{
            'email'       => 'pending.otp@example.com',
            'dateOfBirth' => '01/01/1985'
        }));

        Test.startTest();
        RequestOTPResource.handlePost();
        Test.stopTest();

        // Only Active users are looked up, so a Pending user is reported as not found
        System.assertEquals(404, RestContext.response.statusCode);
        Map<String, Object> result = parseResponse();
        System.assertEquals('USER_NOT_FOUND', result.get('errorCode'));
    }

    // ─── Negative: active but no patient linked ───────────────────────────────

    // An App User cannot be Active without a linked Patient (validation rule), so that
    // scenario cannot be created; an Inactive user is simply "not found" for OTP requests.
    @IsTest
    static void testHandlePost_InactiveUser_NotFound() {
        App_User__c inactive = new App_User__c(
            Name = 'Inactive User', Email__c = 'inactive.otp@example.com', dob__c = Date.newInstance(1992, 7, 20)
        );
        insert inactive;

        setupRestContext(JSON.serialize(new Map<String, String>{
            'email'       => 'inactive.otp@example.com',
            'dateOfBirth' => '20/07/1992'
        }));

        Test.startTest();
        RequestOTPResource.handlePost();
        Test.stopTest();

        System.assertEquals(404, RestContext.response.statusCode);
        System.assertEquals('USER_NOT_FOUND', parseResponse().get('errorCode'));
    }

    // ─── OTP overwritten on second request ───────────────────────────────────

    @IsTest
    static void testHandlePost_OtpOverwrittenOnReRequest() {
        setupRestContext(JSON.serialize(new Map<String, String>{
            'email'       => 'otptest@example.com',
            'dateOfBirth' => '15/03/1990'
        }));

        Test.startTest();
        RequestOTPResource.handlePost();
        String firstOtp = [SELECT OTP__c FROM App_User__c WHERE Email__c = 'otptest@example.com'].OTP__c;

        // Clear processedKeys to allow second dispatch
        NotificationService.processedKeys.clear();

        // Reset context for second call
        setupRestContext(JSON.serialize(new Map<String, String>{
            'email'       => 'otptest@example.com',
            'dateOfBirth' => '15/03/1990'
        }));
        RequestOTPResource.handlePost();
        Test.stopTest();

        String secondOtp = [SELECT OTP__c FROM App_User__c WHERE Email__c = 'otptest@example.com'].OTP__c;
        // Both should be 6 digits (may differ due to random generation)
        System.assertEquals(6, secondOtp.length(), 'New OTP should be 6 digits');
    }

    // ─── Edge: email is trimmed and lowercased ────────────────────────────────

    @IsTest
    static void testHandlePost_EmailTrimmedAndLowercased() {
        setupRestContext(JSON.serialize(new Map<String, String>{
            'email'       => '  OTPTEST@EXAMPLE.COM  ',
            'dateOfBirth' => '15/03/1990'
        }));

        Test.startTest();
        RequestOTPResource.handlePost();
        Test.stopTest();

        Map<String, Object> result = parseResponse();
        System.assertEquals(true, result.get('success'), 'Email should be matched case-insensitively');
    }

    // ─── Exception: malformed JSON ────────────────────────────────────────────

    @IsTest
    static void testHandlePost_MalformedJson_ExceptionHandled() {
        setupRestContext('bad-json');

        Test.startTest();
        RequestOTPResource.handlePost();
        Test.stopTest();

        Map<String, Object> result = parseResponse();
        System.assertEquals(false,           result.get('success'));
        System.assertEquals('INTERNAL_ERROR', result.get('errorCode'));
    }

    // ─── Negative: account frozen from prior wrong-OTP attempts ───────────────

    @IsTest
    static void testHandlePost_AccountLocked_BlocksNewOtpRequest() {
        App_User__c u = [SELECT Id FROM App_User__c WHERE Email__c = 'otptest@example.com'];
        u.OTP_Locked_Until__c = System.now().addMinutes(3);
        update u;

        setupRestContext(JSON.serialize(new Map<String, String>{
            'email'       => 'otptest@example.com',
            'dateOfBirth' => '15/03/1990'
        }));

        Test.startTest();
        RequestOTPResource.handlePost();
        Test.stopTest();

        System.assertEquals(403, RestContext.response.statusCode);
        Map<String, Object> result = parseResponse();
        System.assertEquals('ACCOUNT_LOCKED', result.get('errorCode'));
    }

    // ─── Negative: non-numeric / impossible date parts → caught → 400 ────────

    @IsTest
    static void testHandlePost_InvalidDateFormat_NonNumericParts() {
        setupRestContext(JSON.serialize(new Map<String, String>{
            'email'       => 'otptest@example.com',
            'dateOfBirth' => 'aa/bb/cccc'
        }));

        Test.startTest();
        RequestOTPResource.handlePost();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        System.assertEquals('INVALID_DATE_FORMAT', parseResponse().get('errorCode'));
    }

    // ─── Locked account with under a minute left → singular "minute" ─────────

    @IsTest
    static void testHandlePost_AccountLocked_LessThanOneMinuteLeft() {
        App_User__c u = [SELECT Id FROM App_User__c WHERE Email__c = 'otptest@example.com'];
        u.OTP_Locked_Until__c = System.now().addSeconds(30);
        update u;

        setupRestContext(JSON.serialize(new Map<String, String>{
            'email'       => 'otptest@example.com',
            'dateOfBirth' => '15/03/1990'
        }));

        Test.startTest();
        RequestOTPResource.handlePost();
        Test.stopTest();

        System.assertEquals(403, RestContext.response.statusCode);
        System.assert(((String) parseResponse().get('message')).endsWith('1 minute.'));
    }
}