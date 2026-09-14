@RestResource(urlMapping='/v1/app-user-delete')
global with sharing class PatientAppDeleteAccount {
    global class DeleteAccountRequest {
        global String firstName;
        global String lastName;
        global String email;
        global String dateOfBirth;
    }

    global class DeleteAccountData {
        global String appUserId;
        global String fullName;
        global String email;
    }

    @HttpPost
    global static void handlePost() {
        Savepoint sp = Database.setSavepoint();

        try {
            DeleteAccountRequest req = (DeleteAccountRequest) JSON.deserialize(
                RestContext.request.requestBody.toString(),
                DeleteAccountRequest.class
            );

            System.debug('Received request: ' + JSON.serialize(req));
            List<String> missingFields = new List<String>();
            if (String.isBlank(req.firstName)) missingFields.add('firstName');
            if (String.isBlank(req.lastName)) missingFields.add('lastName');
            if (String.isBlank(req.email)) missingFields.add('email');
            if (String.isBlank(req.dateOfBirth)) missingFields.add('dateOfBirth');

            if (!missingFields.isEmpty()) {
                BaseRestResource.sendResponse(
                    BaseRestResource.errorResponse(400, 'INVALID_INPUT', 'Missing required fields: ' + String.join(missingFields, ', '))
                );
                return;
            }

            String cleanEmail = req.email.trim().toLowerCase();
            String fullName = req.firstName.trim() + ' ' + req.lastName.trim();

            Date dob;
            try {
                String rawDate = req.dateOfBirth.trim();

                if (Pattern.matches('^\\d{4}-\\d{2}-\\d{2}$', rawDate)) {
                    // ISO format, e.g. 2026-07-05 (yyyy-MM-dd)
                    dob = Date.valueOf(rawDate);
                } else {
                    // Slash format used elsewhere in this app, e.g. 05/07/2026 (dd/MM/yyyy)
                    List<String> dateParts = rawDate.split('/');

                    if (dateParts.size() == 3) {
                        Integer day = Integer.valueOf(dateParts[0]);
                        Integer month = Integer.valueOf(dateParts[1]);
                        Integer year = Integer.valueOf(dateParts[2]);
                        dob = Date.newInstance(year, month, day);
                    } else {
                        throw new IllegalArgumentException('Unrecognized date format');
                    }
                }
            } catch (Exception e) {
                BaseRestResource.sendResponse(
                    BaseRestResource.errorResponse(400, 'INVALID_DATE_FORMAT', 'Invalid date of birth. Expected format: yyyy-MM-dd or dd/MM/yyyy')
                );
                return;
            }

            List<App_User__c> matchedUsers = [
                SELECT Id, Name, Email__c
                FROM App_User__c
                WHERE Email__c = :cleanEmail
                AND dob__c = :dob
                AND Name = :fullName
                LIMIT 1
            ];

            if (matchedUsers.isEmpty()) {
                BaseRestResource.sendResponse(
                    BaseRestResource.errorResponse(404, 'NOT_FOUND', 'No account was found matching the provided name, email and date of birth.')
                );
                return;
            }

            App_User__c userToDelete = matchedUsers[0];

            DeleteAccountData data = new DeleteAccountData();
            data.appUserId = userToDelete.Id;
            data.fullName = userToDelete.Name;
            data.email = userToDelete.Email__c;

            delete userToDelete;

            BaseRestResource.sendResponse(
                BaseRestResource.successResponse(data, 'Account deleted successfully.')
            );
        } catch (Exception e) {
            BaseRestResource.sendResponse(BaseRestResource.handleException(e, sp));
        }
    }
}
