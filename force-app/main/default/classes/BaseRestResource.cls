public class BaseRestResource {
    public class ApiResponse {
        public Boolean success;
        public String message;
        public String errorCode;
        public Object data;

        public ApiResponse() {
            this.success = false;
            this.message = null;
            this.errorCode = null;
            this.data = null;
        }
    }

    public static void sendResponse(ApiResponse resp) {
        RestContext.response.addHeader('Content-Type', 'application/json');
        RestContext.response.responseBody = Blob.valueOf(JSON.serialize(resp));
    }

    public static ApiResponse successResponse(Object data, String message) {
        RestContext.response.statusCode = 200;
        ApiResponse resp = new ApiResponse();
        resp.success = true;
        resp.data = data;
        resp.message = message;
        return resp;
    }

    public static ApiResponse successResponse(Object data) {
        return successResponse(data, null);
    }

    public static ApiResponse successMessage(String message) {
        return successResponse(null, message);
    }

    public static ApiResponse errorResponse(Integer statusCode, String errorCode, String message) {
        RestContext.response.statusCode = statusCode;
        ApiResponse resp = new ApiResponse();
        resp.success = false;
        resp.errorCode = errorCode;
        resp.message = message;
        return resp;
    }

    public static ApiResponse errorResponse(Integer statusCode, String errorCode) {
        return errorResponse(statusCode, errorCode, null);
    }

    public static ApiResponse handleException(Exception e) {
        System.debug(LoggingLevel.ERROR, 'REST API Error: ' + e.getMessage() + ' | ' + e.getStackTraceString());
        return errorResponse(500, 'INTERNAL_ERROR', e.getMessage());
    }

    public static ApiResponse handleException(Exception e, Savepoint sp) {
        if (sp != null) {
            Database.rollback(sp);
        }
        return handleException(e);
    }

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