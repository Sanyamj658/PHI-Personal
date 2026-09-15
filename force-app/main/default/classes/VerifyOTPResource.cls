
@RestResource(urlMapping='/v1/verify-otp')
global with sharing class VerifyOTPResource {

    // User can enter 3 incorrect OTPs.
    // The account will be locked on the 4th incorrect attempt.
    private static final Integer MAX_FAILED_ATTEMPTS = 2;

    // Account lock duration
    private static final Integer LOCKOUT_MINUTES = 5;


    // ============================================================
    // REQUEST CLASS
    // ============================================================

    global class VerifyRequest {
        global String email;
        global String otpCode;
        global Date dateOfBirth;
    }


    // ============================================================
    // RESPONSE CLASSES
    // ============================================================

    global class PatientData {
        global String sessionToken;
        global String contactId;
        global String fullName;
        global String email;
        global Date dateOfBirth;
        global List<CaseSummary> cases;
    }


    global class CaseSummary {
        global String caseId;
        global String CaseNumber;
        global String Status;
        global Date dischargeDate;
        global String hospitalName;
        global List<ClaimSummary> claims;
    }


    global class ClaimSummary {
        global String claimId;
        global String caseId;
        global String insuranceCompanyName;
        global String medicalProviderName;
        global String pendingStatus;
        global Date admittedDate;
        global Date dischargedDate;
        global Decimal totalAmount;
        global Decimal totalDue;
    }


    // ============================================================
    // POST
    // ============================================================

    @HttpPost
    global static void handlePost() {

        Savepoint sp = Database.setSavepoint();

        try {

            // ====================================================
            // 1. Parse Request
            // ====================================================

            VerifyRequest req = (VerifyRequest) JSON.deserialize(
                RestContext.request.requestBody.toString(),
                VerifyRequest.class
            );


            if (String.isBlank(req.email) || String.isBlank(req.otpCode)) {

                BaseRestResource.sendResponse(
                    BaseRestResource.errorResponse(
                        400,
                        'INVALID_INPUT',
                        'Email and OTP code are required.'
                    )
                );

                return;
            }


            String cleanEmail = req.email.trim().toLowerCase();
            Date dob = req.dateOfBirth;


            System.debug(
                '🔍 Verifying OTP for email: ' +
                cleanEmail +
                ', DOB: ' +
                dob +
                ', OTP: ' +
                req.otpCode
            );


            // ====================================================
            // 2. Query App_User__c
            // ====================================================

            List<App_User__c> appUsers = [
                SELECT
                    Id,
                    OTP__c,
                    OTP_Expiration__c,
                    Email__c,
                    Failed_OTP_Attempts__c,
                    OTP_Locked_Until__c,
                    Patient__c,
                    Patient__r.FirstName,
                    Patient__r.LastName,
                    Patient__r.Date_of_Birth__c,
                    Patient__r.Account.Name
                FROM App_User__c
                WHERE Email__c = :cleanEmail
                AND DOB__C = :req.dateOfBirth
                LIMIT 1
            ];


            System.debug(
                '🔍 App_User__c query returned ' +
                appUsers.size() +
                ' records.'
            );


            if (appUsers.isEmpty()) {

                BaseRestResource.sendResponse(
                    BaseRestResource.errorResponse(
                        404,
                        'USER_NOT_FOUND',
                        'No user found with the provided email.'
                    )
                );

                return;
            }


            App_User__c appUser = appUsers[0];


            // ====================================================
            // 3. Check Existing Lock
            // ====================================================

            if (
                appUser.OTP_Locked_Until__c != null &&
                System.now() < appUser.OTP_Locked_Until__c
            ) {

                Integer minutesLeft =
                    minutesRemaining(appUser.OTP_Locked_Until__c);


                BaseRestResource.sendResponse(
                    BaseRestResource.errorResponse(
                        403,
                        'ACCOUNT_LOCKED',
                        'Login is temporarily blocked due to too many invalid OTP attempts. Please try again after ' +
                        minutesLeft +
                        (
                            minutesLeft == 1
                            ? ' minute.'
                            : ' minutes.'
                        )
                    )
                );

                return;
            }


            // ====================================================
            // 4. Verify OTP
            // ====================================================

            if (appUser.OTP__c != req.otpCode) {

                Integer attempts =
                    appUser.Failed_OTP_Attempts__c == null
                    ? 0
                    : appUser.Failed_OTP_Attempts__c.intValue();


                // ------------------------------------------------
                // If the user already has 3 failed attempts,
                // this is the 4th wrong attempt.
                // Lock the account.
                // ------------------------------------------------

                if (attempts >= MAX_FAILED_ATTEMPTS) {

                    appUser.Failed_OTP_Attempts__c = 0;

                    appUser.OTP_Locked_Until__c =
                        System.now().addMinutes(LOCKOUT_MINUTES);

                    update appUser;


                    BaseRestResource.sendResponse(
                        BaseRestResource.errorResponse(
                            403,
                            'ACCOUNT_LOCKED',
                            'Login is temporarily blocked due to too many invalid OTP attempts. Please try again after ' +
                            LOCKOUT_MINUTES +
                            ' minutes .'
                        )
                    );

                    return;
                }


                // ------------------------------------------------
                // Count current incorrect attempt
                // ------------------------------------------------

                attempts++;

                appUser.Failed_OTP_Attempts__c = attempts;

                update appUser;


                // ------------------------------------------------
                // First 3 incorrect attempts
                // ------------------------------------------------

                BaseRestResource.sendResponse(
                    BaseRestResource.errorResponse(
                        401,
                        'INVALID_OTP',
                        'The code you entered is incorrect. Please try again.'
                    )
                );

                return;
            }


            // ====================================================
            // 5. Check OTP Expiration
            // ====================================================

            if (
                appUser.OTP_Expiration__c == null ||
                System.now() > appUser.OTP_Expiration__c
            ) {

                BaseRestResource.sendResponse(
                    BaseRestResource.errorResponse(
                        401,
                        'EXPIRED_OTP',
                        'The OTP code has expired. Please request a new one.'
                    )
                );

                return;
            }


            // ====================================================
            // 6. OTP Successfully Verified
            // ====================================================

            // Clear OTP so it cannot be reused.
            appUser.OTP__c = null;

            appUser.OTP_Expiration__c = null;

            // Reset failed attempts.
            appUser.Failed_OTP_Attempts__c = 0;

            // Remove any lock.
            appUser.OTP_Locked_Until__c = null;


            // ====================================================
            // 7. Generate Session Token
            // ====================================================

            String sessionToken = EncodingUtil.convertToHex(
                Crypto.generateAesKey(256)
            );


            appUser.Session_Token__c = sessionToken;

            update appUser;


            // ====================================================
            // 8. Fetch Patient Cases
            // ====================================================

            Contact c = appUser.Patient__r;


            List<Case> relatedCases = [
                SELECT
                    Id,
                    ContactEmail,
                    Discharge_Date__c,
                    CaseNumber,
                    Status,
                    Account.Name,
                    ContactId
                FROM Case
                WHERE ContactId = :c.Id
            ];


            // ====================================================
            // 9. Build Response
            // ====================================================

            PatientData pd = new PatientData();

            pd.sessionToken = sessionToken;

            pd.contactId = c.Id;

            pd.fullName =
                c.FirstName +
                ' ' +
                c.LastName;

            pd.email = appUser.Email__c;

            pd.dateOfBirth = c.Date_of_Birth__c;

            // Cases can be enabled later if required.
            // pd.cases = buildCaseSummaries(
            //     relatedCases,
            //     relatedClaims
            // );


            // ====================================================
            // 10. Success Response
            // ====================================================

            BaseRestResource.sendResponse(
                BaseRestResource.successResponse(pd)
            );


        } catch (Exception e) {

            BaseRestResource.sendResponse(
                BaseRestResource.handleException(e, sp)
            );
        }
    }


    // ============================================================
    // HELPER METHOD
    // ============================================================

    /**
     * Returns remaining lock time in minutes.
     * Rounded up so the user never sees 0 minutes
     * while the account is still locked.
     */
    private static Integer minutesRemaining(DateTime lockedUntil) {

        Long millisLeft =
            lockedUntil.getTime() -
            System.now().getTime();


        return (Integer) Math.max(
            1,
            Math.ceil(millisLeft / 60000.0)
        );
    }
}
