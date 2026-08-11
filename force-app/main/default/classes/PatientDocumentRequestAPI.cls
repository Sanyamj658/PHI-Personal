/**
 * PatientDocumentRequestAPI
 * ─────────────────────────────────────────────────────────────────────────────
 * REST endpoint that processes patient document requests from the mobile app.
 *
 * POST /services/apexrest/v1/patient-document-request
 *
 * Flow:
 *   1. Validate the incoming Case Id and request type.
 *   2. Create an Open Task linked to the Case (and its Contact).
 *   3. Send a Salesforce bell notification to the Case owner.
 *   4. Fetch all ContentDocuments attached to the Case.
 *   5. Send an email notification to the patient's Contact (best-effort).
 *   6. Return a structured response with task details and document download URLs.
 *
 * Supported requestType values:
 *   • Itemized Bill
 *   • Medical Records
 *   • Document Request
 *   • Insurance Claim
 *   • Explanation of Benefits
 */
@RestResource(urlMapping='/v1/patient-document-request')
global with sharing class PatientDocumentRequestAPI {

    // ─────────────────────────────────────────────────────────────────────────
    //  Request Wrapper
    // ─────────────────────────────────────────────────────────────────────────

    global class DocumentRequest {
        global String caseId;       // Required — Salesforce Case record Id
        global String requestType;  // Required — one of VALID_REQUEST_TYPES
        global String notes;        // Optional — free-text notes for the Task
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Response Wrappers
    // ─────────────────────────────────────────────────────────────────────────

    global class DocumentRequestData {
        global String            taskId;
        global String            caseId;
        global String            requestType;
        global Boolean           emailSent;
        global List<DocumentInfo> documents;
    }

    global class DocumentInfo {
        global String documentId;
        global String title;
        global String fileType;
        global String downloadUrl;
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Constants
    // ─────────────────────────────────────────────────────────────────────────

    private static final Set<String> VALID_REQUEST_TYPES = new Set<String>{
        'Itemized Bill',
        'Medical Records',
        'Document Request',
        'Insurance Claim',
        'Explanation of Benefits'
    };

    private static final Map<String, String> SUBJECT_MAP = new Map<String, String>{
        'Itemized Bill'            => 'Itemized Bill Request',
        'Medical Records'          => 'Medical Records Request',
        'Document Request'         => 'Document Request',
        'Insurance Claim'          => 'Insurance Claim Request',
        'Explanation of Benefits'  => 'Explanation of Benefits Request'
    };

    // ─────────────────────────────────────────────────────────────────────────
    //  POST Handler
    // ─────────────────────────────────────────────────────────────────────────

    @HttpPost
    global static void handlePost() {

        Savepoint sp = Database.setSavepoint();

        try {

            // 1. Parse Request Body
            // ─────────────────────────────────────────────────────────────────
            DocumentRequest req = (DocumentRequest) JSON.deserialize(
                RestContext.request.requestBody.toString(),
                DocumentRequest.class
            );

            // 2. Validate Required Fields
            // ─────────────────────────────────────────────────────────────────
            if (String.isBlank(req.caseId)) {
                BaseRestResource.sendResponse(
                    BaseRestResource.errorResponse(400, 'INVALID_INPUT', 'caseId is required.')
                );
                return;
            }

            if (String.isBlank(req.requestType)) {
                BaseRestResource.sendResponse(
                    BaseRestResource.errorResponse(400, 'INVALID_INPUT', 'requestType is required.')
                );
                return;
            }

            // 3. Validate Request Type
            // ─────────────────────────────────────────────────────────────────
            String requestType = req.requestType.trim();

            if (!VALID_REQUEST_TYPES.contains(requestType)) {
                BaseRestResource.sendResponse(
                    BaseRestResource.errorResponse(
                        400,
                        'INVALID_REQUEST_TYPE',
                        'requestType must be one of: Itemized Bill, Medical Records, Document Request, Insurance Claim, Explanation of Benefits.'
                    )
                );
                return;
            }

            // 4. Validate Case Id Format and Object Type
            // ─────────────────────────────────────────────────────────────────
            Id caseRecordId;
            try {
                caseRecordId = Id.valueOf(req.caseId.trim());
                if (caseRecordId.getSObjectType() != Case.SObjectType) {
                    BaseRestResource.sendResponse(
                        BaseRestResource.errorResponse(400, 'INVALID_CASE_ID', 'Provided ID does not belong to a Case record.')
                    );
                    return;
                }
            } catch (Exception e) {
                BaseRestResource.sendResponse(
                    BaseRestResource.errorResponse(400, 'INVALID_CASE_ID', 'Provided caseId is not a valid Salesforce ID.')
                );
                return;
            }

            // 5. Fetch Case with Contact and Owner Details
            // ─────────────────────────────────────────────────────────────────
            System.debug('🔍 Looking up Case: ' + caseRecordId);

            List<Case> cases = [
                SELECT Id, CaseNumber, Status,
                       OwnerId,
                       ContactId,
                       Contact.FirstName, Contact.LastName, Contact.Email
                FROM   Case
                WHERE  Id = :caseRecordId
                LIMIT  1
            ];

            if (cases.isEmpty()) {
                BaseRestResource.sendResponse(
                    BaseRestResource.errorResponse(404, 'CASE_NOT_FOUND', 'No Case found with the provided Id.')
                );
                return;
            }

            Case patientCase = cases[0];

            String taskSubject = SUBJECT_MAP.get(requestType);

            List<Task> existingTasks = [
                SELECT Id
                FROM Task
                WHERE WhatId = :patientCase.Id
                AND Status = 'Open'
                AND Subject = :taskSubject
                LIMIT 1
            ];

            if (!existingTasks.isEmpty()) {
                RestContext.response.statusCode = 409;
                Map<String, Object> responseMap = new Map<String, Object>{
                    'success' => false,
                    'message' => 'You have already requested for the ' + requestType
                };
                RestContext.response.responseBody = Blob.valueOf(JSON.serialize(responseMap));
                return;
            }

            Task newTask = new Task(
                Name__c = 'Admin',
                Subject = taskSubject,
                Status = 'Open',
                Priority = 'Normal',
                WhatId = patientCase.Id,
                WhoId = patientCase.ContactId
            );
            insert newTask;

            // 7. Send Salesforce Bell Notification to Case Owner (best-effort)
            // ─────────────────────────────────────────────────────────────────
          
             sendCaseNotification(patientCase, requestType);

            // 8. Fetch Documents Linked to Case
            // ─────────────────────────────────────────────────────────────────
            List<ContentDocumentLink> docLinks = [
                SELECT ContentDocumentId,
                       ContentDocument.Title,
                       ContentDocument.FileType
                FROM   ContentDocumentLink
                WHERE  LinkedEntityId = :patientCase.Id
                ORDER BY ContentDocument.CreatedDate DESC
            ];

            List<DocumentInfo> documentList = buildDocumentInfoList(docLinks);

            System.debug('📄 Documents found: ' + documentList.size());

            // 9. Send Email Notification to Patient (best-effort)
            // ─────────────────────────────────────────────────────────────────
            // Boolean emailSent = false;
            // try {
            //     if (patientCase.ContactId != null && !String.isBlank(patientCase.Contact.Email)) {
            //         // sendPatientEmail(patientCase, requestType, documentList);
            //         emailSent = true;
            //     }
            // } catch (Exception emailEx) {
            //     System.debug(LoggingLevel.WARN, '⚠️ Email notification failed: ' + emailEx.getMessage());
            // }

            // 10. Build and Send Success Response
            // ─────────────────────────────────────────────────────────────────
            DocumentRequestData responseData = new DocumentRequestData();
            responseData.taskId      = newTask.Id;
            responseData.caseId      = patientCase.Id;
            responseData.requestType = requestType;
            // responseData.emailSent   = emailSent;
            responseData.documents   = documentList;

            BaseRestResource.sendResponse(
                BaseRestResource.successResponse(responseData, 'Document request processed successfully.')
            );

        } catch (Exception e) {
            BaseRestResource.sendResponse(
                BaseRestResource.handleException(e, sp)
            );
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Helper: Send Salesforce Bell Notification to Case Owner
    // ─────────────────────────────────────────────────────────────────────────

    private static void sendCaseNotification(Case patientCase, String requestType) {
        try {
            // Requires a Custom Notification Type named "Patient_Document_Request"
            // in Setup → Custom Notifications
            List<CustomNotificationType> notifTypes = [
                SELECT Id
                FROM   CustomNotificationType
                WHERE  DeveloperName = 'Patient_Document_Request'
                LIMIT  1
            ];

            if (notifTypes.isEmpty()) {
                System.debug(LoggingLevel.WARN,
                    '⚠️ CustomNotificationType "Patient_Document_Request" not found. Skipping bell notification.');
                return;
            }

            String patientName = (patientCase.Contact != null && !String.isBlank(patientCase.Contact.FirstName))
                ? patientCase.Contact.FirstName + ' ' + patientCase.Contact.LastName
                : (patientCase.Contact != null ? patientCase.Contact.LastName : 'A patient');

            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            notification.setNotificationTypeId(notifTypes[0].Id);
            notification.setTargetId(patientCase.Id);
            notification.setTitle('New Patient Document Request');
            notification.setBody(patientName + ' has requested: ' + requestType
                                + ' \u2013 Case #' + patientCase.CaseNumber);

            // Notify the Case owner (only Users, not Queues — OwnerId starts with 005)
            Set<String> recipientIds = new Set<String>();
            String ownerId = String.valueOf(patientCase.OwnerId);
            if (ownerId.startsWith('005')) {
                recipientIds.add(ownerId);
            }

            if (!recipientIds.isEmpty()) {
                notification.send(recipientIds);
                System.debug('🔔 Bell notification sent to owner: ' + ownerId);
            }

        } catch (Exception notifEx) {
            System.debug(LoggingLevel.WARN, '⚠️ Bell notification failed: ' + notifEx.getMessage());
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Helper: Build DocumentInfo List from ContentDocumentLinks
    // ─────────────────────────────────────────────────────────────────────────

    private static List<DocumentInfo> buildDocumentInfoList(List<ContentDocumentLink> docLinks) {
        List<DocumentInfo> documentList = new List<DocumentInfo>();
        String baseUrl = URL.getOrgDomainUrl().toExternalForm();

        for (ContentDocumentLink cdl : docLinks) {
            DocumentInfo info = new DocumentInfo();
            info.documentId  = cdl.ContentDocumentId;
            info.title       = cdl.ContentDocument.Title;
            info.fileType    = cdl.ContentDocument.FileType;
            info.downloadUrl = baseUrl + '/sfc/servlet.shepherd/document/download/' + cdl.ContentDocumentId;
            documentList.add(info);
        }

        return documentList;
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Helper: Send Patient Email Notification
    // ─────────────────────────────────────────────────────────────────────────
	/*
    private static void sendPatientEmail(Case patientCase, String requestType, List<DocumentInfo> documents) {
        String patientName = !String.isBlank(patientCase.Contact.FirstName)
            ? patientCase.Contact.FirstName + ' ' + patientCase.Contact.LastName
            : patientCase.Contact.LastName;

        String docLines = '';
        if (!documents.isEmpty()) {
            for (DocumentInfo doc : documents) {
                docLines += '\n  \u2022 ' + doc.title + ' (' + doc.fileType + ')'
                          + '\n    ' + doc.downloadUrl;
            }
        } else {
            docLines = '\n  No documents are currently attached to this case.';
        }

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setTargetObjectId(patientCase.ContactId);
        mail.setSaveAsActivity(false);
        mail.setSubject('Your ' + requestType + ' \u2013 Case #' + patientCase.CaseNumber);
        mail.setPlainTextBody(
            'Dear ' + patientName + ',\n\n'
            + 'We have received your request for: ' + requestType + '.\n'
            + 'Your request has been logged under Case #' + patientCase.CaseNumber + '.\n\n'
            + 'Documents available for your case:' + docLines + '\n\n'
            + 'If you have any questions, please do not hesitate to contact us.\n\n'
            + 'Best regards,\nPassage Hi Team'
        );

        Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ mail });
        System.debug('📧 Email sent to Contact: ' + patientCase.Contact.Email);
    }
*/
}