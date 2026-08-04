@RestResource(urlMapping='/v1/verify-otp')
global with sharing class VerifyOTPResource {

    global class VerifyRequest {
        global String email;
        global String otpCode;
        global Date dateOfBirth;
    }

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

    @HttpPost
    global static void handlePost() {
        System.debug('🔍 Received OTP verification request: ' + RestContext.request.requestBody.toString());
        Savepoint sp = Database.setSavepoint();

        try {
            // 1. Parse Request
            VerifyRequest req = (VerifyRequest) JSON.deserialize(
                RestContext.request.requestBody.toString(), VerifyRequest.class
            );

            if (String.isBlank(req.email) || String.isBlank(req.otpCode)) {
                BaseRestResource.sendResponse(
                    BaseRestResource.errorResponse(400, 'INVALID_INPUT', 'Email and OTP code are required.')
                );
                return;
            }

            String cleanEmail = req.email.trim().toLowerCase();
            Date dob = req.dateOfBirth;
            System.debug('🔍 Verifying OTP for email: ' + cleanEmail + ', DOB: ' + dob + ', OTP: ' + req.otpCode);
            // 2. Query App_User__c for OTP Verification
            List<App_User__c> appUsers = [
                SELECT Id, OTP__c, OTP_Expiration__c, Email__c,
                       Patient__c, Patient__r.FirstName, Patient__r.LastName, 
                       Patient__r.Date_of_Birth__c, Patient__r.Account.Name
                FROM App_User__c
                WHERE Email__c = :cleanEmail AND DOB__C = :req.dateOfBirth
                LIMIT 1
            ];
            System.debug('🔍 App_User__c query returned ' + appUsers.size() + ' records.');

            if (appUsers.isEmpty()) {
                BaseRestResource.sendResponse(
                    BaseRestResource.errorResponse(404, 'USER_NOT_FOUND', 'No user found with the provided email.')
                );
                return;
            }

            App_User__c appUser = appUsers[0];

            // 3. Verify OTP and Expiration
            if (appUser.OTP__c != req.otpCode) {
                BaseRestResource.sendResponse(
                    BaseRestResource.errorResponse(401, 'INVALID_OTP', 'The OTP code is incorrect.')
                );
                return;
            }
            if (appUser.OTP_Expiration__c == null || System.now() > appUser.OTP_Expiration__c) {
                BaseRestResource.sendResponse(
                    BaseRestResource.errorResponse(401, 'EXPIRED_OTP', 'The OTP code has expired. Please request a new one.')
                );
                return;
            }

            // 4. OTP is Valid: Clear it to prevent reuse and generate session token
            appUser.OTP__c = null;
            appUser.OTP_Expiration__c = null;
            
            // Generate cryptographically-secure session token
            String sessionToken = EncodingUtil.convertToHex(
                Crypto.generateAesKey(256)
            );
            appUser.Session_Token__c = sessionToken;
            update appUser;

            // 5. Fetch Cases & Claims related to the patient
            Contact c = appUser.Patient__r;
            List<Case> relatedCases = [
                SELECT Id, ContactEmail, Discharge_Date__c, CaseNumber, Status, Account.Name, ContactId
                FROM Case WHERE ContactId = :c.Id
            ];

            /* Set<Id> caseIds = new Set<Id>();
            for (Case cs : relatedCases) {
                caseIds.add(cs.Id);
            }

            List<Claim__c> relatedClaims = new List<Claim__c>();
            if (!caseIds.isEmpty()) {
                relatedClaims = [
                    SELECT Id, Case__c, Insurance_Company__r.Name, Medical_Provider__r.Name, From_DOS__c, To_DOS__c,
                           Total_Payments__c, Claim_Balance_Due__c, Pending_Status__c, Payable_to_Client__c
                    FROM Claim__c WHERE Case__c IN :caseIds
                ];
            }

            */

            // 6. Build response payload
            PatientData pd = new PatientData();
            pd.sessionToken = sessionToken;
            pd.fullName = c.FirstName + ' ' + c.LastName;
            pd.email = appUser.Email__c;
            pd.dateOfBirth = c.Date_of_Birth__c;
            // pd.cases = buildCaseSummaries(relatedCases, relatedClaims);

            BaseRestResource.sendResponse(
                BaseRestResource.successResponse(pd)
            );
            
        } catch (Exception e) {
            BaseRestResource.sendResponse(
                BaseRestResource.handleException(e, sp)
            );
        }
    }

   /* private static List<CaseSummary> buildCaseSummaries(List<Case> cases, List<Claim__c> claims) {
        Map<Id, List<ClaimSummary>> claimsByCaseId = new Map<Id, List<ClaimSummary>>();
        
        for (Claim__c cl : claims) {
            if (!claimsByCaseId.containsKey(cl.Case__c)) {
                claimsByCaseId.put(cl.Case__c, new List<ClaimSummary>());
            }
            
            ClaimSummary cs = new ClaimSummary();
            cs.claimId = cl.Id;
            cs.caseId = cl.Case__c;
            cs.admittedDate = cl.From_DOS__c;
			cs.dischargedDate = cl.To_DOS__c;         
            cs.insuranceCompanyName = cl.Insurance_Company__r?.Name;
            cs.medicalProviderName = cl.Medical_Provider__r?.Name;
            cs.pendingStatus = cl.Pending_Status__c;
            cs.totalAmount = cl.Total_Payments__c;
            cs.totalDue = cl.Claim_Balance_Due__c;
            
            claimsByCaseId.get(cl.Case__c).add(cs);
        }

        List<CaseSummary> result = new List<CaseSummary>();
        for (Case cs : cases) {
            CaseSummary caseSum = new CaseSummary();
            caseSum.caseId = cs.Id;
            caseSum.Status = cs.Status;
            caseSum.CaseNumber = cs.CaseNumber;
            caseSum.dischargeDate = cs.Discharge_Date__c;
            caseSum.hospitalName = cs.Account.Name;
            caseSum.claims = claimsByCaseId.containsKey(cs.Id) ? claimsByCaseId.get(cs.Id) : new List<ClaimSummary>();
            result.add(caseSum);
        }
        
        return result;
    } */
}