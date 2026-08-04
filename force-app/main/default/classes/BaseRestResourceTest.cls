/**
 * BaseRestResourceTest
 * Covers: ApiResponse wrapper, successResponse (with/without message),
 *         successMessage, errorResponse (with/without message),
 *         handleException (with/without savepoint), sendResponse,
 *         validateAuthorizationHeader (valid, missing, malformed, blank token).
 */
@IsTest
private class BaseRestResourceTest {

    // ─── Helper: initialise RestContext ──────────────────────────────────────

    private static void setupRestContext() {
        setupRestContext(null);
    }

    private static void setupRestContext(String authHeader) {
        RestRequest  req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI  = '/services/apexrest/test';
        req.httpMethod  = 'GET';
        if (authHeader != null) {
            req.headers.put('Authorization', authHeader);
        }
        RestContext.request  = req;
        RestContext.response = res;
    }

    // ─── ApiResponse default state ────────────────────────────────────────────

    @IsTest
    static void testApiResponse_Defaults() {
        BaseRestResource.ApiResponse r = new BaseRestResource.ApiResponse();
        System.assertEquals(false, r.success);
        Assert.isNull(r.message,    'message should default to null');
        Assert.isNull(r.errorCode,  'errorCode should default to null');
        Assert.isNull(r.data,       'data should default to null');
    }

    // ─── successResponse(data, message) ──────────────────────────────────────

    @IsTest
    static void testSuccessResponse_WithDataAndMessage() {
        setupRestContext();
        Test.startTest();
        BaseRestResource.ApiResponse resp =
            BaseRestResource.successResponse('myData', 'All good');
        Test.stopTest();

        System.assertEquals(true,       resp.success);
        System.assertEquals('myData',   resp.data);
        System.assertEquals('All good', resp.message);
        System.assertEquals(200, RestContext.response.statusCode);
    }

    // ─── successResponse(data) ────────────────────────────────────────────────

    @IsTest
    static void testSuccessResponse_DataOnly() {
        setupRestContext();
        Test.startTest();
        BaseRestResource.ApiResponse resp = BaseRestResource.successResponse(42);
        Test.stopTest();

        System.assertEquals(true, resp.success);
        System.assertEquals(42,   resp.data);
        Assert.isNull(resp.message, 'message should be null when not provided');
    }

    // ─── successMessage ───────────────────────────────────────────────────────

    @IsTest
    static void testSuccessMessage() {
        setupRestContext();
        Test.startTest();
        BaseRestResource.ApiResponse resp = BaseRestResource.successMessage('Done');
        Test.stopTest();

        System.assertEquals(true,   resp.success);
        System.assertEquals('Done', resp.message);
        Assert.isNull(resp.data, 'data should be null for successMessage');
    }

    // ─── errorResponse(statusCode, errorCode, message) ───────────────────────

    @IsTest
    static void testErrorResponse_Full() {
        setupRestContext();
        Test.startTest();
        BaseRestResource.ApiResponse resp =
            BaseRestResource.errorResponse(400, 'INVALID_INPUT', 'Bad request');
        Test.stopTest();

        System.assertEquals(false,           resp.success);
        System.assertEquals('INVALID_INPUT',  resp.errorCode);
        System.assertEquals('Bad request',    resp.message);
        System.assertEquals(400, RestContext.response.statusCode);
    }

    // ─── errorResponse(statusCode, errorCode) ────────────────────────────────

    @IsTest
    static void testErrorResponse_NoMessage() {
        setupRestContext();
        Test.startTest();
        BaseRestResource.ApiResponse resp = BaseRestResource.errorResponse(404, 'NOT_FOUND');
        Test.stopTest();

        System.assertEquals(false,       resp.success);
        System.assertEquals('NOT_FOUND', resp.errorCode);
        Assert.isNull(resp.message, 'message should be null when not provided');
        System.assertEquals(404, RestContext.response.statusCode);
    }

    // ─── handleException(e) ───────────────────────────────────────────────────

    @IsTest
    static void testHandleException_NoSavepoint() {
        setupRestContext();
        Test.startTest();
        BaseRestResource.ApiResponse resp =
            BaseRestResource.handleException(new IllegalArgumentException('test error'));
        Test.stopTest();

        System.assertEquals(false,            resp.success);
        System.assertEquals('INTERNAL_ERROR',  resp.errorCode);
        System.assert(resp.message.contains('test error'));
        System.assertEquals(500, RestContext.response.statusCode);
    }

    // ─── handleException(e, savepoint) ───────────────────────────────────────

    // ─── handleException with null savepoint ─────────────────────────────────

    @IsTest
    static void testHandleException_NullSavepoint() {
        setupRestContext();
        Test.startTest();
        BaseRestResource.ApiResponse resp =
            BaseRestResource.handleException(new IllegalArgumentException('err'), null);
        Test.stopTest();

        System.assertEquals(false, resp.success);
    }

    // ─── sendResponse ─────────────────────────────────────────────────────────

    @IsTest
    static void testSendResponse_WritesJsonToBody() {
        setupRestContext();
        BaseRestResource.ApiResponse resp = new BaseRestResource.ApiResponse();
        resp.success = true;
        resp.message = 'hello';

        Test.startTest();
        BaseRestResource.sendResponse(resp);
        Test.stopTest();

        String body = RestContext.response.responseBody.toString();
        System.assert(body.contains('true'),  'Body should contain success=true');
        System.assert(body.contains('hello'), 'Body should contain message');
        System.assertEquals('application/json',
            RestContext.response.headers.get('Content-Type'));
    }

    // ─── validateAuthorizationHeader – valid bearer token ─────────────────────

    @IsTest
    static void testValidateAuthorizationHeader_ValidBearer() {
        setupRestContext('Bearer my-secret-token');

        Test.startTest();
        String token = BaseRestResource.validateAuthorizationHeader();
        Test.stopTest();

        System.assertEquals('my-secret-token', token);
    }

    // ─── validateAuthorizationHeader – missing header ─────────────────────────

    @IsTest
    static void testValidateAuthorizationHeader_MissingHeader() {
        setupRestContext();

        Test.startTest();
        String token = BaseRestResource.validateAuthorizationHeader();
        Test.stopTest();

        Assert.isNull(token, 'Should return null when header is absent');
        System.assertEquals(401, RestContext.response.statusCode);
    }

    // ─── validateAuthorizationHeader – not a Bearer scheme ───────────────────

    @IsTest
    static void testValidateAuthorizationHeader_NotBearer() {
        setupRestContext('Basic dXNlcjpwYXNz');

        Test.startTest();
        String token = BaseRestResource.validateAuthorizationHeader();
        Test.stopTest();

        Assert.isNull(token, 'Should return null for non-Bearer auth');
        System.assertEquals(401, RestContext.response.statusCode);
    }

    // ─── validateAuthorizationHeader – blank token after Bearer ──────────────

    @IsTest
    static void testValidateAuthorizationHeader_BlankTokenAfterBearer() {
        setupRestContext('Bearer    ');

        Test.startTest();
        String token = BaseRestResource.validateAuthorizationHeader();
        Test.stopTest();

        Assert.isNull(token, 'Should return null for blank token');
        System.assertEquals(401, RestContext.response.statusCode);
    }

    // ─── validateAuthorizationHeader – null RestRequest ──────────────────────

    @IsTest
    static void testValidateAuthorizationHeader_NullRequest() {
        RestContext.request  = null;
        RestContext.response = new RestResponse();

        Test.startTest();
        String token = BaseRestResource.validateAuthorizationHeader();
        Test.stopTest();

        Assert.isNull(token, 'Should return null when RestContext.request is null');
    }
}