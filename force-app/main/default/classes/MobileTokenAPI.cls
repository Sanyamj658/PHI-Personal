// REST API to save the device token used for push notifications.
@RestResource(urlMapping='/saveDeviceToken')
global with sharing class MobileTokenAPI {
    // Saves the device token for the active App User matching email and DOB.
    @HttpPost
    global static void saveToken() {
        try {
            RestRequest req = RestContext.request;
            String body = req.requestBody != null ? req.requestBody.toString() : '{}';

            Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(body);
            String email = (String) data.get('email');
            String token = (String) data.get('token');
            String dobStr = (String) data.get('dob');

            // Email, DOB and token are all required.
            if (String.isBlank(email) || String.isBlank(token) || String.isBlank(dobStr)) {
                BaseRestResource.sendResponse(
                    BaseRestResource.errorResponse(400, 'INVALID_INPUT', 'Missing email, DOB or token')
                );
                return;
            }

            Date dob = Date.valueOf(dobStr);
            // Find the active App User matching email and DOB.
            List<App_User__c> existing = [
                SELECT Id
                FROM App_User__c
                WHERE Email__c = :email AND dob__c = :dob AND Status__c = 'Active'
                LIMIT 1
            ];

            if (existing.isEmpty()) {
                BaseRestResource.sendResponse(
                    BaseRestResource.errorResponse(404, 'NOT_FOUND', 'User not found')
                );
                return;
            }

            // Store the device token on the App User.
            existing[0].Device_Token__c = token;
            update existing[0];

            BaseRestResource.sendResponse(
                BaseRestResource.successMessage('Token saved successfully.')
            );
        } catch (Exception e) {
            BaseRestResource.sendResponse(BaseRestResource.handleException(e));
        }
    }
}