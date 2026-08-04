@RestResource(urlMapping='/v1/patient-lookup')
global with sharing class PatientLookupResource {

    global class PatientLookupRequest {
        global String email;
        global String dateOfBirth; // Expected format: dd/MM/yyyy
    }

    global class PatientData {
        global String contactId;
        global String fullName;
        global String email;
        global Date   dateOfBirth;
        global String hospitalName;
        global List<CaseSummary> cases; 
    }

    global class CaseSummary {
        global String caseId;
        global String contactEmail;
        global Date   dischargeDate;
        global List<ClaimSummary> claims;
    }

    global class ClaimSummary {
        global String  claimId;
        global String  caseId;
        global String  insuranceCompanyName;
        global String  medicalProviderName;
        global String  pendingStatus;
        global Decimal payableToClient;
    }

    @HttpPost
    global static void handlePost() {
        try {
            // 1. Parse request
            PatientLookupRequest req = (PatientLookupRequest) JSON.deserialize(
                RestContext.request.requestBody.toString(),
                PatientLookupRequest.class
            );

            // 2. Validate input
            if (!isValidInput(req)) {
                BaseRestResource.sendResponse(
                    BaseRestResource.errorResponse(400, 'INVALID_INPUT', 'Email and Date of Birth are required and must be valid.')
                );
                return;
            }

            String cleanEmail = req.email.trim().toLowerCase();
            Date   dob;
            
            // --- Date parsing for dd/MM/yyyy ---
            try {
                String rawDate = req.dateOfBirth.trim();
                List<String> dateParts = rawDate.split('/');
                
                if (dateParts.size() == 3) {
                    Integer day = Integer.valueOf(dateParts[0]);
                    Integer month = Integer.valueOf(dateParts[1]);
                    Integer year = Integer.valueOf(dateParts[2]);
                    dob = Date.newInstance(year, month, day);
                } else {
                    throw new IllegalArgumentException('Format must be dd/MM/yyyy');
                }
            } catch (Exception e) {
                BaseRestResource.sendResponse(
                    BaseRestResource.errorResponse(400, 'INVALID_DATE_FORMAT', 'Invalid date provided. Format must be dd/MM/yyyy')
                );
                return;
            }

            // 3. Query App_User__c
            List<App_User__c> appUsers = [
                SELECT Id, Email__c,
                       Patient__c,
                       Patient__r.FirstName,
                       Patient__r.LastName,
                       Patient__r.Account.Name,
                       Patient__r.Date_of_Birth__c
                FROM   App_User__c
                WHERE  Email__c = :cleanEmail
                LIMIT  1
            ];

            // 4. No record found
            if (appUsers.isEmpty()) {
                BaseRestResource.sendResponse(
                    BaseRestResource.errorResponse(404, 'NO_MATCH', 'No matching patient found.')
                );
                return;
            }

            App_User__c appUser = appUsers[0];
            Contact c = appUser.Patient__r;

            // 5. Verify DOB — second factor check
            if (c.Date_of_Birth__c == null || c.Date_of_Birth__c != dob) {
                BaseRestResource.sendResponse(
                    BaseRestResource.errorResponse(404, 'NO_MATCH', 'No matching patient found.')
                );
                return;
            }

            // 6. Fetch related Cases
            List<Case> relatedCases = [
                SELECT Id, ContactEmail, Discharge_Date__c
                FROM   Case
                WHERE  ContactEmail = :cleanEmail
            ];

            Set<Id> caseIds = new Set<Id>();
            for (Case cs : relatedCases) {
                caseIds.add(cs.Id);
            }

            // 7. Fetch related Claims
            List<Claim__c> relatedClaims = new List<Claim__c>();
            if (!caseIds.isEmpty()) {
                relatedClaims = [
                    SELECT Id, Case__c, Insurance_Company__r.Name, Medical_Provider__r.Name, 
                           Pending_Status__c, Payable_to_Client__c
                    FROM   Claim__c
                    WHERE  Case__c IN :caseIds
                ];
            }

            // 8. Build response
            PatientData pd   = new PatientData();
            pd.contactId     = c.Id;
            pd.fullName      = c.FirstName + ' ' + c.LastName;
            pd.email         = appUser.Email__c;
            pd.dateOfBirth   = c.Date_of_Birth__c;
            pd.hospitalName  = c.Account?.Name;
            pd.cases         = buildCaseSummaries(relatedCases, relatedClaims);

            BaseRestResource.sendResponse(
                BaseRestResource.successResponse(pd)
            );

        } catch (Exception e) {
            BaseRestResource.sendResponse(
                BaseRestResource.handleException(e)
            );
        }
    }

    private static Boolean isValidInput(PatientLookupRequest req) {
        if (req == null)                     return false;
        if (String.isBlank(req.email))       return false;
        if (String.isBlank(req.dateOfBirth)) return false;
        Pattern p = Pattern.compile(
            '^[a-zA-Z0-9._%+\\-]+@[a-zA-Z0-9.\\-]+\\.[a-zA-Z]{2,}$'
        );
        return p.matcher(req.email.trim()).matches();
    }

    private static List<CaseSummary> buildCaseSummaries(List<Case> cases, List<Claim__c> claims) {
        Map<Id, List<ClaimSummary>> claimsByCaseId = new Map<Id, List<ClaimSummary>>();
        
        for (Claim__c cl : claims) {
            if (!claimsByCaseId.containsKey(cl.Case__c)) {
                claimsByCaseId.put(cl.Case__c, new List<ClaimSummary>());
            }
            
            ClaimSummary cs = new ClaimSummary();
            cs.claimId              = cl.Id;
            cs.caseId               = cl.Case__c;
            cs.insuranceCompanyName = cl.Insurance_Company__r?.Name;
            cs.medicalProviderName  = cl.Medical_Provider__r?.Name;
            cs.pendingStatus        = cl.Pending_Status__c;
            cs.payableToClient      = cl.Payable_to_Client__c;
            
            claimsByCaseId.get(cl.Case__c).add(cs);
        }

        List<CaseSummary> result = new List<CaseSummary>();
        for (Case cs : cases) {
            CaseSummary caseSum = new CaseSummary();
            caseSum.caseId        = cs.Id;
            caseSum.contactEmail  = cs.ContactEmail;
            caseSum.dischargeDate = cs.Discharge_Date__c;
            caseSum.claims        = claimsByCaseId.containsKey(cs.Id) ? claimsByCaseId.get(cs.Id) : new List<ClaimSummary>();
            result.add(caseSum);
        }
        
        return result;
    }
}