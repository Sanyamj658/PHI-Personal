@RestResource(urlMapping='/v1/request-otp')
global with sharing class RequestOTPResource {

    global class OTPRequest {
        global String email;
        global String dateOfBirth; // Expected format: dd/mm/yyyy
    }

    @HttpPost
    global static void handlePost() {

        Savepoint sp = Database.setSavepoint();

        try {
            // 1. Parse Request
            OTPRequest req = (OTPRequest) JSON.deserialize(
                RestContext.request.requestBody.toString(),
                OTPRequest.class
            );

            if (String.isBlank(req.email) || String.isBlank(req.dateOfBirth)) {
                BaseRestResource.sendResponse(
                    BaseRestResource.errorResponse(400, 'INVALID_INPUT', 'Email and Date of Birth are required.')
                );
                return;
            }

            String cleanEmail = req.email.trim().toLowerCase();
            Date dob;

            // 2. Parse Date
            try {
                String rawDate = req.dateOfBirth.trim();
                List<String> dateParts = rawDate.split('/');

                if (dateParts.size() == 3) {
                    Integer day = Integer.valueOf(dateParts[0]);
                    Integer month = Integer.valueOf(dateParts[1]);
                    Integer year = Integer.valueOf(dateParts[2]);
                    dob = Date.newInstance(year, month, day);
                } else {
                    BaseRestResource.sendResponse(
                        BaseRestResource.errorResponse(400, 'INVALID_DATE_FORMAT', 'Format must be dd/mm/yyyy')
                    );
                    return;
                }

            } catch (Exception e) {
                BaseRestResource.sendResponse(
                    BaseRestResource.errorResponse(400, 'INVALID_DATE_FORMAT', 'Invalid date provided.')
                );
                return;
            }

            // 3. Fetch User
            System.debug('🔍 Looking up user with email: ' + cleanEmail + ' and DOB: ' + dob);
            List<App_User__c> existingappUsers = [
                SELECT Id, Status__c, Patient__c , Name 
                FROM App_User__c
                WHERE Email__c = :cleanEmail AND dob__c = :dob
                LIMIT 1
            ];

            if (existingappUsers.isEmpty()) {
                BaseRestResource.sendResponse(
                    BaseRestResource.errorResponse(404, 'USER_NOT_FOUND', 'No account found with this Email and Date of Birth.')
                );
                return;
            }

            // ✅ Correct assignment
            App_User__c appUser = existingappUsers[0];

            System.debug('🔍 Found user with email:  Status: ' + appUser.Status__c + '  appUser ' + appUser.patient__c);
            // 4. Check Status
            // if (appUser.Status__c != 'Active' ||  appUser.Patient__c == null) {
            //     BaseRestResource.sendResponse(
            //         BaseRestResource.errorResponse(
            //             403,
            //             'ACCOUNT_NOT_APPROVED',
            //             'Your account is under review!\nPlease wait for approval. You will receive an email shortly.'
            //         )
            //     );
            //     return;
            // }

             System.debug('🔍 87 User status is valid for OTP request.');
            if (appUser.Status__c == 'Pending' &&  appUser.Patient__c == null) {
                 System.debug('🔍 89 User status is valid for OTP request.');
                BaseRestResource.sendResponse(
                    BaseRestResource.errorResponse(
                        403,
                        'ACCOUNT_NOT_APPROVED',
                        'Your account is under review!\nPlease wait for approval. You will receive an email shortly.'
                    )
                );
                return;
            }
            System.debug('🔍 197 User status is valid for OTP request.');
            if (appUser.Status__c == 'Inactive' &&  appUser.Patient__c == null) {
                 System.debug('🔍 99  User status is valid for OTP request.');
                BaseRestResource.sendResponse(
                    BaseRestResource.errorResponse(
                        403,
                        'ACCOUNT_INACTIVE',
                        'Your account has been deactivated.\nPlease contact support for more information.'
                    )
                );
                return;
            }

            // 5. Generate OTP
            String otpCode = String.valueOf(Math.abs(Crypto.getRandomInteger()));
            otpCode = otpCode.leftPad(6, '0').substring(0, 6);

            // 6. Update User
            appUser.OTP__c = otpCode;
            appUser.OTP_Expiration__c = System.now().addMinutes(10);
            update appUser;

        //     //  7. Send OTP Email 
        //    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        //    mail.setToAddresses(new String[] { cleanEmail });
        //    mail.setSubject('Your OTP Code');

        //     mail.setPlainTextBody(
        //         'Hello,\n\nYour OTP is: ' + otpCode + 
        //         '\nIt will expire in 10 minutes.\n\nThanks'
        //     );

        //     Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });

        // Send OTP Email
Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
mail.setToAddresses(new String[] { cleanEmail });
mail.setSubject('Your OTP Code');

mail.setPlainTextBody(
    'Dear ' + appUser.Name + ',\n\n' +
    'Your One-Time Password (OTP) for login verification is:\n' +
    otpCode + '\n\n' +
    'This OTP is valid for 10 minutes. Please do not share it with anyone for security reasons.\n\n' +
    'If you did not request this OTP, please contact our support team immediately.\n\n' +
    'Thank you,\n' +
    'Passage HI Team'
);

Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });

            // 8. Success Response
            BaseRestResource.sendResponse(
                BaseRestResource.successMessage('OTP sent successfully. Expires in 10 minutes.')
            );

        } catch (Exception e) {
            BaseRestResource.sendResponse(
                BaseRestResource.handleException(e, sp)
            );
        }
    }
}