// REST API returning a patient's cases, claims, payments, shared documents and claim specialist for the mobile app.
@RestResource(urlMapping='/v1/patient-data')
global with sharing class PatientAppDataService {
    // Response payload returned to the mobile app.
    global class PatientResponse {
        global String contactId;
        global String fullName;
        global String email;
        global Date dateOfBirth;
        global List<CaseSummary> cases;
        global List<DocumentSummary> documents;

         // Claim Specialist Details
        global String claimSpecialistName;
        global String claimSpecialistEmail;
    }

    global class CaseSummary {
        global Id caseId;
        global String caseNumber;
        global String status;
        global Date dischargeDate;
        global String hospitalName;
        global List<ClaimDetail> claims;
    }

    global class ClaimDetail {
        global Id claimId;
        global Id caseId;
        global String claimNumber;
        global String insuranceCompanyName;
        global String medicalProviderName;
        global String pendingStatus;
        global Date fromDOS;
        global Date toDOS;
        global Decimal totalPayments;
        global Decimal TotalCharge;
        global Decimal balanceDue;
        global List<ClaimPaymentSummary> payments;
    }

    global class ClaimPaymentSummary {
        global Id id;
        global Decimal amount;
        global Date paymentDate;
        global String paymentType;
    }

    global class DocumentSummary {
        global Id documentId;
        global String title;
        global String fileType;
        global Integer contentSize;
        global String downloadUrl;
    }

    // Looks up the App User by email and DOB and returns the linked patient's data.
    @HttpGet
    global static void getPatientData() {
        RestRequest req = RestContext.request;
        String email = req.params.get('email');
        Date dob = req.params.get('dob') != null ? Date.valueOf(req.params.get('dob')) : null;

        if (String.isBlank(email)) {
            BaseRestResource.sendResponse(
                BaseRestResource.errorResponse(400, 'INVALID_INPUT', 'Email is required.')
            );
            return;
        }

        String cleanEmail = email.trim().toLowerCase();

        try {
            // Find the App User for this email and DOB.
            List<App_User__c> appUser = [
                SELECT Id,
                    Email__c,
                    Patient__c,
                    Patient__r.Id,
                    Patient__r.FirstName,
                    Patient__r.LastName,
                    Patient__r.Email,
                    Patient__r.Date_of_Birth__c
                FROM App_User__c
                WHERE Email__c = :cleanEmail AND DOB__c = :dob
                LIMIT 1
            ];

            // Reject the request if there is no App User or no linked patient.
            if (appUser.isEmpty() || appUser[0].Patient__c == null) {
                BaseRestResource.sendResponse(
                    BaseRestResource.errorResponse(401, 'UNAUTHORIZED', 'Patient not linked.')
                );
                return;
            }

            Contact patient = appUser[0].Patient__r;

            if (patient == null) {
                BaseRestResource.sendResponse(
                    BaseRestResource.errorResponse(404, 'NOT_FOUND', 'Patient record not found.')
                );
                return;
            }

               // =====================================================
            // FIND CLAIM SPECIALIST FROM LATEST PATIENT CLAIM
            // =====================================================

            String claimSpecialistName;
            String claimSpecialistEmail;


            /*
             * Patient -> Claim__c is a direct relationship.
             *
             * We get the latest claim for this patient based on
             * CreatedDate.
             */

            List<Claim__c> latestPatientClaims = [
                SELECT Id,
                    Name,
                    Patient__c,
                    Collector__c,
                    CreatedDate
                FROM Claim__c
                WHERE Patient__c = :patient.Id
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];

            System.debug(LoggingLevel.INFO, 'Latest Patient Claims: ' + latestPatientClaims);


            if (!latestPatientClaims.isEmpty()) {

                Claim__c latestPatientClaim = latestPatientClaims[0];

                System.debug(LoggingLevel.INFO, 'Latest Patient Claim: ' + latestPatientClaim);


                // =================================================
                // COLLECTOR -> SPECIALIST NAME MAPPING
                // =================================================

                Map<String, String> collectorNameMap =
                    new Map<String, String>{
                        'U Qadir' => 'Uzaifa Qadir',
                        'H Dar' => 'Henry Dar',
                        'M Nissar' => 'Mursaleen Nissar',
                        'M Mir' => 'Jack Mir',
                        'N Shay' => 'Nancy Shay',
                        'M Shannon' => 'Moe Shannon',
                        'I Kennedy' => 'Indhu Kennedy',
                        'B Kumar' => 'Barry Kumar',
                        'S Mohi' => 'Sharif Mohi',
                        'S Shah' => 'Shahid Shah',
                        'M Musaib' => 'Michael Musaib',
                        'R Miles' => 'Richard Miles',
                        'Admin' => 'Administrator',
                        'K Obrien' => 'Kelcie O Brien',
                        'j Sierra' => 'Jorge Sierra'
                    };


                // =================================================
                // COLLECTOR -> EMAIL MAPPING
                // =================================================

                Map<String, String> collectorEmailMap =
                    new Map<String, String>{
                        'U Qadir' => 'uqadir@internationalbillingoffice.com',
                        'H Dar' => 'hdar@internationalbillingoffice.com',
                        'M Nissar' => 'mnissar@internationalbillingoffice.com',
                        'M Mir' => 'jmir@internationalbillingoffice.com',
                        'N Shay' => 'nshay@internationalbillingoffice.com',
                        'M Shannon' => 'MShannon@internationalbillingoffice.com',
                        'I Kennedy' => 'IKennedy@internationalbillingoffice.com',
                        'B Kumar' => 'Barry.Kumar@internationalbillingoffice.com',
                        'S Mohi' => 'sharif@internationalbillingoffice.com',
                        'S Shah' => 'sshah@internationalbillingoffice.com',
                        'M Musaib' => 'michael@internationalbillingoffice.com',
                        'R Miles' => 'Richard.Miles@internationalbillingoffice.com',
                        'Administrator' => 'info@internationalbillingoffice.com',
                        'K Obrien' => 'Kelcie.Obrien@passagehi.com',
                        'j Sierra' => 'Jorge.Sierra@passagehi.com'
                    };


                // =================================================
                // GET COLLECTOR
                // =================================================

                if (!String.isBlank(latestPatientClaim.Collector__c)) {

                    String collector =
                        latestPatientClaim.Collector__c.trim();
                        System.debug(LoggingLevel.INFO, 'Collector: ' + collector);



                    // =============================================
                    // GET SPECIALIST NAME
                    // =============================================

                    if (collectorNameMap.containsKey(collector)) {

                        claimSpecialistName =
                            collectorNameMap.get(collector);
                    }


                    // =============================================
                    // GET SPECIALIST EMAIL
                    // =============================================

                    if (collectorEmailMap.containsKey(collector)) {

                        claimSpecialistEmail =
                            collectorEmailMap.get(collector);
                    }
                }
            }

            // Get all Cases of the patient.
            List<Case> relatedCases = [
                SELECT Id,
                    CaseNumber,
                    Status,
                    Discharge_Date__c,
                    Account.Name,
                    ContactEmail
                FROM Case
                WHERE ContactId = :patient.Id
            ];

            Set<Id> caseIds = new Set<Id>();
            for (Case cs : relatedCases) {
                caseIds.add(cs.Id);
            }

            // Get the claims for those Cases.
            List<Claim__c> relatedClaims = new List<Claim__c>();
            if (!caseIds.isEmpty()) {
                relatedClaims = [
                    SELECT Id,
                        Name,
                        Case__c,
                        Insurance_Company__r.Name,
                        Medical_Provider__r.Name,
                        Pending_Status__c,
                        From_DOS__c,
                        To_DOS__c,
                        Total_Payments__c,
                        Claim_Balance_Due__c,
                        Total_Charge__c
                    FROM Claim__c
                    WHERE Case__c IN :caseIds
                ];
            }

            Set<Id> claimIds = new Set<Id>();
            for (Claim__c cl : relatedClaims) {
                claimIds.add(cl.Id);
            }

            // Group claim payments by claim, newest first.
            Map<Id, List<ClaimPaymentSummary>> paymentsByClaim = new Map<Id, List<ClaimPaymentSummary>>();
            if (!claimIds.isEmpty()) {
                for (Claim_Payment__c cp : [
                    SELECT Id,
                        Amount__c,
                        Payment_Date__c,
                        Payment_Type__c,
                        Claim_Number__c
                    FROM Claim_Payment__c
                    WHERE Claim_Number__c IN :claimIds
                    ORDER BY Payment_Date__c DESC
                ]) {
                    Id claimId = cp.Claim_Number__c;
                    if (!paymentsByClaim.containsKey(claimId)) {
                        paymentsByClaim.put(claimId, new List<ClaimPaymentSummary>());
                    }

                    ClaimPaymentSummary cps = new ClaimPaymentSummary();
                    cps.id = cp.Id;
                    cps.amount = cp.Amount__c;
                    cps.paymentDate = cp.Payment_Date__c;
                    cps.paymentType = cp.Payment_Type__c;
                    paymentsByClaim.get(claimId).add(cps);
                }
            }

            // Get the documents shared with this App User on mobile and build their download links.
            List<DocumentSummary> documentList = new List<DocumentSummary>();
            List<Shared_Document__c> sharedDocs = [
                SELECT Id,
                    Content_Document_Id__c
                FROM Shared_Document__c
                WHERE App_User__c = :appUser[0].Id
                AND Visible_On_Mobile__c = true
            ];

            Set<Id> docIds = new Set<Id>();
            for (Shared_Document__c sd : sharedDocs) {
                if (sd.Content_Document_Id__c != null) {
                    docIds.add((Id) sd.Content_Document_Id__c);
                }
            }

            if (!docIds.isEmpty()) {
                for (ContentDocument cd : [
                    SELECT Id,
                        Title,
                        FileType,
                        ContentSize,
                        LatestPublishedVersionId
                    FROM ContentDocument
                    WHERE Id IN :docIds
                ]) {
                    DocumentSummary ds = new DocumentSummary();
                    ds.documentId = cd.Id;
                    ds.title = cd.Title;
                    ds.fileType = cd.FileType;
                    ds.contentSize = cd.ContentSize;
                    ds.downloadUrl = '/sfc/servlet.shepherd/version/download/' + cd.LatestPublishedVersionId;
                    documentList.add(ds);
                }
            }

            // Group claim details by Case.
            Map<Id, List<ClaimDetail>> claimsByCase = new Map<Id, List<ClaimDetail>>();
            for (Claim__c cl : relatedClaims) {
                ClaimDetail cd = new ClaimDetail();
                cd.claimId = cl.Id;
                cd.caseId = cl.Case__c;
                cd.claimNumber = cl.Name;
                cd.insuranceCompanyName = cl.Insurance_Company__r != null ? cl.Insurance_Company__r.Name : null;
                cd.medicalProviderName = cl.Medical_Provider__r != null ? cl.Medical_Provider__r.Name : null;
                cd.fromDOS = cl.From_DOS__c;
                cd.toDOS = cl.To_DOS__c;
                cd.totalPayments = cl.Total_Payments__c;
                cd.TotalCharge = cl.Total_Charge__c;
                cd.balanceDue = cl.Claim_Balance_Due__c;
                cd.payments = paymentsByClaim.containsKey(cl.Id) ? paymentsByClaim.get(cl.Id) : new List<ClaimPaymentSummary>();

                if (!claimsByCase.containsKey(cl.Case__c)) {
                    claimsByCase.put(cl.Case__c, new List<ClaimDetail>());
                }
                claimsByCase.get(cl.Case__c).add(cd);
            }

            // Build the case summaries with their claims.
            List<CaseSummary> caseSummaries = new List<CaseSummary>();
            for (Case cs : relatedCases) {
                CaseSummary c = new CaseSummary();
                c.caseId = cs.Id;
                c.caseNumber = cs.CaseNumber;
                c.status = cs.Status;
                c.dischargeDate = cs.Discharge_Date__c;
                c.hospitalName = cs.Account != null ? cs.Account.Name : null;
                c.claims = claimsByCase.containsKey(cs.Id) ? claimsByCase.get(cs.Id) : new List<ClaimDetail>();
                caseSummaries.add(c);
            }



            
            // Assemble the final response.
            PatientResponse resp = new PatientResponse();
            resp.contactId = patient.Id;
            resp.fullName = patient.FirstName + ' ' + patient.LastName;
            resp.email = appUser[0].Email__c;
            resp.dateOfBirth = patient.Date_of_Birth__c;
            resp.cases = caseSummaries;
            resp.documents = documentList;
            resp.claimSpecialistName =
                claimSpecialistName;

            resp.claimSpecialistEmail =
                claimSpecialistEmail;
            System.debug(resp.claimSpecialistName   + ' ' + resp.claimSpecialistEmail);
            BaseRestResource.sendResponse(BaseRestResource.successResponse(resp));
        } catch (QueryException qe) {
            BaseRestResource.sendResponse(BaseRestResource.errorResponse(500, 'QUERY_ERROR', qe.getMessage()));
        } catch (Exception e) {
            BaseRestResource.sendResponse(BaseRestResource.handleException(e, null));
        }
    }
}