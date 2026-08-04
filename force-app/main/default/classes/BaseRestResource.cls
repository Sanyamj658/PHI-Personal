/**
 * Centralised utility class for all @RestResource endpoints.
 */
public class BaseRestResource {

    // ───────────────────────────────────────────────
    //  Standard API Response Wrapper
    // ───────────────────────────────────────────────
    public class ApiResponse {
        public Boolean success;
        public String  message;
        public String  errorCode;
        public Object  data;

        public ApiResponse() {
            this.success   = false;
            this.message   = null;
            this.errorCode = null;
            this.data      = null;
        }
    }

    // ───────────────────────────────────────────────
    //  Send Response  (writes JSON to RestContext)
    // ───────────────────────────────────────────────

    /**
     * Serializes the ApiResponse to JSON and writes it to
     * RestContext.response.responseBody.  Call this as the
     * last statement in every @HttpPost / @HttpGet method.
     */
    public static void sendResponse(ApiResponse resp) {
        RestContext.response.addHeader('Content-Type', 'application/json');
        RestContext.response.responseBody = Blob.valueOf(JSON.serialize(resp));
    }

    // ───────────────────────────────────────────────
    //  Success Responses
    // ───────────────────────────────────────────────

    /** Return a 200 success response with data and a custom message. */
    public static ApiResponse successResponse(Object data, String message) {
        RestContext.response.statusCode = 200;
        ApiResponse resp = new ApiResponse();
        resp.success = true;
        resp.data    = data;
        resp.message = message;
        System.debug('Success Response: ' + JSON.serialize(resp));
        return resp;
    }

    /** Return a 200 success response with data (no message). */
    public static ApiResponse successResponse(Object data) {
        return successResponse(data, null);
    }

    /** Return a 200 success response with only a message (no data). */
    public static ApiResponse successMessage(String message) {
        return successResponse(null, message);
    }

    // ───────────────────────────────────────────────
    //  Error Responses
    // ───────────────────────────────────────────────

    /** Return an error response with HTTP status code, error code, and message. */
    public static ApiResponse errorResponse(Integer statusCode, String errorCode, String message) {
        RestContext.response.statusCode = statusCode;
        ApiResponse resp = new ApiResponse();
        resp.success   = false;
        resp.errorCode = errorCode;
        resp.message   = message;
        return resp;
    }

    /** Return an error response with HTTP status code and error code (no message). */
    public static ApiResponse errorResponse(Integer statusCode, String errorCode) {
        return errorResponse(statusCode, errorCode, null);
    }

    // ───────────────────────────────────────────────
    //  Centralised Exception Handling
    // ───────────────────────────────────────────────

    /**
     * Log the exception and return a generic 500 INTERNAL_ERROR response.
     */
    public static ApiResponse handleException(Exception e) {
        System.debug(LoggingLevel.ERROR,
            'REST API Error: ' + e.getMessage() + ' | ' + e.getStackTraceString()
        );
        return errorResponse(500, 'INTERNAL_ERROR', e.getMessage());
    }

    /**
     * Rollback to the given Savepoint, log the exception, and return a 500 response.
     */
    public static ApiResponse handleException(Exception e, Savepoint sp) {
        if (sp != null) {
            Database.rollback(sp);
        }
        return handleException(e);
    }

    // ───────────────────────────────────────────────
    //  Authorization Header Validation
    // ───────────────────────────────────────────────

    /**
     * Reads the Authorization header from the current REST request.
     * Expects the format:  "Bearer <token>"
     *
     * @return  The extracted token string, or null if the header is
     *          missing / malformed (also sets a 401 status code).
     */
    public static String validateAuthorizationHeader() {
        RestRequest req = RestContext.request;

        if (req == null || req.headers == null) {
            return null;
        }

        String authHeader = req.headers.get('Authorization');

        if (String.isBlank(authHeader) || !authHeader.startsWithIgnoreCase('Bearer ')) {
            RestContext.response.statusCode = 401;
            return null;
        }

        String token = authHeader.substring(7).trim();

        if (String.isBlank(token)) {
            RestContext.response.statusCode = 401;
            return null;
        }

        return token;
    }
}