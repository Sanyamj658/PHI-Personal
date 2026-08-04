@RestResource(urlMapping='/saveDeviceToken')
global with sharing class MobileTokenAPI {

    @HttpPost
    global static void saveToken() {
        try {
            RestRequest req = RestContext.request;
            String body = req.requestBody.toString();

            Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(body);

            String email = (String) data.get('email');
            String token = (String) data.get('token');
            String dobStr = (String) data.get('dob');

            System.debug('Received data: ' + data);
            System.debug('Email: ' + email + ', Token: ' + token + ', DOB: ' + dobStr);


            if (String.isBlank(email) || String.isBlank(token) || String.isBlank(dobStr)) {
                BaseRestResource.sendResponse(
                    BaseRestResource.errorResponse(400, 'INVALID_INPUT', 'Missing email, DOB or token')
                );
                return;
            }


            Date dob = Date.valueOf(dobStr);
            // MM/DD/YYYY format
            // List<String> dobParts = dobStr.split('-');
            // Date dob = Date.newInstance(
            //     Integer.valueOf(dobParts[2]), // Year
            //     Integer.valueOf(dobParts[0]), // Month
            //     Integer.valueOf(dobParts[1])  // Day
            // );

            System.debug('Parsed DOB: ' + dob);

            List<App_User__c> existing = [
                SELECT Id FROM App_User__c WHERE Email__c = :email AND dob__c = :dob LIMIT 1
            ];

            System.debug('Existing users found: ' + existing.size());

            /*if (existing.isEmpty()) {
                App_User__c md = new App_User__c();
                md.Email__c = email;
                md.Device_Token__c = token;
                insert md;
            } else {
                */
                existing[0].Device_Token__c = token;
                update existing[0];
            // }

            BaseRestResource.sendResponse(
                BaseRestResource.successMessage('Token saved successfully.')
            );

        } catch (Exception e) {
            System.debug('IN CATCH: ' + e.getMessage());    
            BaseRestResource.sendResponse(
                BaseRestResource.handleException(e)
            );
        }
    }
}