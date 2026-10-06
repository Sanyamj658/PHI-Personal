// REST API to clear the device token when a mobile user logs out.
@RestResource(urlMapping='/removeDeviceToken')
global with sharing class MobileLogoutAPI {
    // Finds the active App User by email and DOB and clears Device_Token__c.
    @HttpPost
    global static void removeToken() {
        try {
            RestRequest req = RestContext.request;
            String body = req.requestBody != null ? req.requestBody.toString() : '{}';

            Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(body);
            String email = (String) data.get('email');
            String dobStr = (String) data.get('dob');

            // Email and DOB are required to identify the user.
            if (String.isBlank(email) || String.isBlank(dobStr)) {
                BaseRestResource.sendResponse(
                    BaseRestResource.errorResponse(400, 'INVALID_INPUT', 'Email and DOB is required')
                );
                return;
            }

            // Find the active App User matching email and DOB.
            List<App_User__c> users = [
                SELECT Id, Device_Token__c
                FROM App_User__c
                WHERE Email__c = :email AND dob__c = :Date.valueOf(dobStr) AND Status__c = 'Active'
                LIMIT 1
            ];

            if (users.isEmpty()) {
                BaseRestResource.sendResponse(
                    BaseRestResource.errorResponse(404, 'NOT_FOUND', 'User not found')
                );
                return;
            }

            // Clear the stored device token so push notifications stop.
            App_User__c usr = users[0];
            usr.Device_Token__c = null;
            update usr;

            BaseRestResource.sendResponse(
                BaseRestResource.successMessage('Device token removed successfully.')
            );
        } catch (Exception e) {
            BaseRestResource.sendResponse(BaseRestResource.handleException(e));
        }
    }
}