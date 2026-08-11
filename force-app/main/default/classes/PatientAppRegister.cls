@RestResource(urlMapping='/v1/patient-register')
global with sharing class PatientAppRegister {
    global class RegistrationRequest {
        global String firstName;
        global String lastName;
        global String email;
        global String dateOfBirth;
        global String Zipcode;
        global String street;
        global String city;
        global String state;
        global String country;
    }

    global class RegistrationData {
        global String appUserId;
        global String fullName;
        global String email;
        global String status;
    }

    private static final String STATUS_PENDING = 'Pending';
    private static final Pattern EMAIL_PATTERN = Pattern.compile('^[a-zA-Z0-9._%+\\-]+@[a-zA-Z0-9.\\-]+\\.[a-zA-Z]{2,}$');

    @HttpPost
    global static void handlePost() {
        Savepoint sp = Database.setSavepoint();

        try {
            RegistrationRequest req = (RegistrationRequest) JSON.deserialize(
                RestContext.request.requestBody.toString(),
                RegistrationRequest.class
            );

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
            if (!EMAIL_PATTERN.matcher(cleanEmail).matches()) {
                BaseRestResource.sendResponse(
                    BaseRestResource.errorResponse(400, 'INVALID_EMAIL', 'The email address format is invalid.')
                );
                return;
            }

            Date dob;
            try {
                String rawDate = req.dateOfBirth.trim();
                List<String> dateParts = rawDate.split('/');

                if (dateParts.size() == 3) {
                    Integer day = Integer.valueOf(dateParts[0]);
                    Integer month = Integer.valueOf(dateParts[1]);
                    Integer year = Integer.valueOf(dateParts[2]);
                    dob = Date.newInstance(year, month, day);
                } else {
                    throw new IllegalArgumentException('Expected 3 parts');
                }
            } catch (Exception e) {
                BaseRestResource.sendResponse(
                    BaseRestResource.errorResponse(400, 'INVALID_DATE_FORMAT', 'Invalid date of birth. Expected format: MM/dd/yyyy')
                );
                return;
            }

            List<App_User__c> existingUsers = [
                SELECT Id
                FROM App_User__c
                WHERE Email__c = :cleanEmail AND dob__c = :dob
                LIMIT 1
            ];

            if (!existingUsers.isEmpty()) {
                BaseRestResource.sendResponse(
                    BaseRestResource.errorResponse(409, 'DUPLICATE_USER', 'Account Already Exists!\nA User with this email address and Date of Birth is already registered.')
                );
                return;
            }

            App_User__c newUser = new App_User__c();
            newUser.Name = req.firstName.trim() + ' ' + req.lastName.trim();
            newUser.Email__c = cleanEmail;
            newUser.Status__c = STATUS_PENDING;
            newUser.Street__c = req.street;
            newUser.City__c = req.city;
            newUser.State__c = req.state;
            newUser.Zip_Code__c = req.Zipcode;
            newUser.dob__c = dob;
            newUser.Country__c = req.country;
            insert newUser;

            RegistrationData data = new RegistrationData();
            data.appUserId = newUser.Id;
            data.fullName = newUser.Name;
            data.email = newUser.Email__c;
            data.status = newUser.Status__c;

            BaseRestResource.sendResponse(
                BaseRestResource.successResponse(data, 'Registration successful. Your account is pending for approval.')
            );
        } catch (Exception e) {
            BaseRestResource.sendResponse(BaseRestResource.handleException(e, sp));
        }
    }
}