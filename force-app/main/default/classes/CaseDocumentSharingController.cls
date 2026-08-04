/**
 * Handles Case document sharing with the patient mobile app.
 * Fetches Case files and creates/updates Shared_Document__c records.
 */
public with sharing class CaseDocumentSharingController {

    // ─── Wrappers ─────────────────────────────────────────────────────────────

/** Result wrapper for Case files and sharing status. */
    public class CaseFilesResult {
        @AuraEnabled public Boolean           canShare;
        @AuraEnabled public String            noShareReason;
        @AuraEnabled public List<FileWrapper> files;
    }

    public class FileWrapper {
        @AuraEnabled public String  id;
        @AuraEnabled public String  contentDocumentId;
        @AuraEnabled public String  title;
        @AuraEnabled public String  fileType;
        @AuraEnabled public String  createdDate;
        @AuraEnabled public Long    contentSize;
        @AuraEnabled public String  fileSizeFormatted;
        @AuraEnabled public Boolean isShared;
        @AuraEnabled public String  sharedDocumentId;
    }

    // ─── Cacheable Read ───────────────────────────────────────────────────────

    /** Returns Case files with mobile sharing details. */
    @AuraEnabled(cacheable=true)
    public static CaseFilesResult getCaseFilesData(Id caseId) {
        if (caseId == null) {
            throw new AuraHandledException('Case ID is required.');
        }
        CaseFilesResult resultObj = new CaseFilesResult();
        resultObj.files = new List<FileWrapper>();
        // ── 1. Resolve Case → Contact ─────────────────────────────────────────
        List<Case> cases = [
            SELECT Id, ContactId
            FROM   Case
            WHERE  Id = :caseId
            LIMIT  1
        ];

        if (cases.isEmpty()) {
            throw new AuraHandledException('Case not found.');
        }

        Id contactId = cases[0].ContactId;

        if (contactId == null) {
            resultObj.canShare      = false;
            resultObj.noShareReason = 'No patient contact is linked to this case. Documents cannot be shared to mobile.';
        }

        // ── 2. Resolve Contact → App_User__c ──────────────────────────────────
        Id appUserId = null;
        if (contactId != null) {
            List<App_User__c> users = [
                SELECT Id
                FROM   App_User__c
                WHERE  Patient__c = :contactId
                LIMIT  1
            ];

            if (!users.isEmpty()) {
                appUserId          = users[0].Id;
                resultObj.canShare = true;
            } else {
                resultObj.canShare      = false;
                resultObj.noShareReason = 'This patient does not have a mobile app account. Files are visible here but cannot be shared.';
            }
        }

        // If we don't have an app user, we can still show the files but sharing actions will be disabled.
        if(appUserId == null){
            resultObj.canShare      = false;
            resultObj.noShareReason = 'No mobile app user found for the patient linked to this case. Files are visible here but cannot be shared.';
            return resultObj;
        }

        // ── 3. Fetch ContentDocumentLinks for the Case ────────────────────────
        List<ContentDocumentLink> ContentDocumentLinks = [
            SELECT ContentDocumentId,
                   ContentDocument.Title,
                   ContentDocument.FileType,
                   ContentDocument.CreatedDate,
                   ContentDocument.ContentSize
            FROM   ContentDocumentLink
            WHERE  LinkedEntityId = :caseId
            ORDER  BY ContentDocument.CreatedDate DESC
        ];

        if (ContentDocumentLinks.isEmpty()) {
            return resultObj;
        }

        // ── 4. Collect doc IDs for sharing look-up ────────────────────────────
        Set<String> docIdSet = new Set<String>();
        for (ContentDocumentLink cdl : ContentDocumentLinks) {
            docIdSet.add(String.valueOf(cdl.ContentDocumentId));
        }

        // ── 5. Batch-query existing Shared_Document__c records ────────────────
        Map<String, Shared_Document__c> sharedMap = new Map<String, Shared_Document__c>();
        if (appUserId != null) {
            for (Shared_Document__c sd : [
                SELECT Id, Content_Document_Id__c, Visible_On_Mobile__c
                FROM   Shared_Document__c
                WHERE  App_User__c            = :appUserId
                AND    Content_Document_Id__c IN :docIdSet
            ]) {
                sharedMap.put(sd.Content_Document_Id__c, sd);
            }
        }

        // ── 6. Build FileWrapper list ─────────────────────────────────────────
        for (ContentDocumentLink cdl : ContentDocumentLinks) {
            String  docId  = String.valueOf(cdl.ContentDocumentId);
            Boolean shared = sharedMap.containsKey(docId)
                             && sharedMap.get(docId).Visible_On_Mobile__c;

            FileWrapper fw       = new FileWrapper();
            fw.id                = docId;
            fw.contentDocumentId = docId;
            fw.title             = cdl.ContentDocument.Title;
            fw.fileType          = cdl.ContentDocument.FileType != null
                                     ? cdl.ContentDocument.FileType.toUpperCase()
                                     : 'UNKNOWN';
            fw.createdDate       = cdl.ContentDocument.CreatedDate != null
                                     ? String.valueOf(cdl.ContentDocument.CreatedDate)
                                     : '';
            fw.contentSize       = cdl.ContentDocument.ContentSize;
            fw.fileSizeFormatted = formatFileSize(cdl.ContentDocument.ContentSize);
            fw.isShared          = shared;
            fw.sharedDocumentId  = shared ? sharedMap.get(docId).Id : null;
            resultObj.files.add(fw);
        }

        return resultObj;
    }

    // ─── DML Write ────────────────────────────────────────────────────────────

   /** Shares selected Case documents with the patient mobile app. */
    @AuraEnabled
    public static Integer shareDocuments(Id caseId, List<String> contentDocumentIds) {
        if (caseId == null || contentDocumentIds == null || contentDocumentIds.isEmpty()) {
            throw new AuraHandledException(
                'Invalid parameters: Case ID and at least one document ID are required.'
            );
        }

        // ── 1. Resolve Case → Contact ─────────────────────────────────────────
        List<Case> cases = [
            SELECT Id, ContactId
            FROM   Case
            WHERE  Id = :caseId
            LIMIT  1
        ];

        if (cases.isEmpty()) {
            throw new AuraHandledException('Case not found.');
        }

        if (cases[0].ContactId == null) {
            throw new AuraHandledException(
                'This Case has no linked Contact. Documents cannot be shared to the mobile app.'
            );
        }

        Id contactId = cases[0].ContactId;

        // ── 2. Resolve Contact → App_User__c ──────────────────────────────────
        List<App_User__c> users = [
            SELECT Id
            FROM   App_User__c
            WHERE  Patient__c = :contactId
            LIMIT  1
        ];

        if (users.isEmpty()) {
            throw new AuraHandledException(
                'No mobile app account found for this patient. Documents cannot be shared.'
            );
        }

        Id appUserId = users[0].Id;

        // ── 3. Load existing records to prevent duplicates ────────────────────
        Map<String, Shared_Document__c> existingMap = new Map<String, Shared_Document__c>();
        for (Shared_Document__c sd : [
            SELECT Id, Content_Document_Id__c, Visible_On_Mobile__c
            FROM   Shared_Document__c
            WHERE  App_User__c            = :appUserId
            AND    Content_Document_Id__c IN :contentDocumentIds
        ]) {
            existingMap.put(sd.Content_Document_Id__c, sd);
        }

        // ── 4. Build upsert list ──────────────────────────────────────────────
        List<Shared_Document__c> toUpsert = new List<Shared_Document__c>();

        for (String docId : contentDocumentIds) {
            if (existingMap.containsKey(docId)) {
                // Only update if the visibility flag needs changing
                Shared_Document__c existing = existingMap.get(docId);
                if (!existing.Visible_On_Mobile__c) {
                    existing.Visible_On_Mobile__c = true;
                    toUpsert.add(existing);
                }
            } else {
                toUpsert.add(new Shared_Document__c(
                    App_User__c            = appUserId,
                    Contact__c             = contactId,
                    Content_Document_Id__c = docId,
                    Visible_On_Mobile__c   = true
                ));
            }
        }

        // ── 5. Bulk upsert (governor-limit safe) ──────────────────────────────
        if (!toUpsert.isEmpty()) {
            upsert toUpsert;
        }

        if (!toUpsert.isEmpty()) {

    List<App_User__c> appUser = [
        SELECT Email__c
        FROM App_User__c
        WHERE Id = :appUserId
        LIMIT 1
    ];

    if (String.isNotBlank(appUser[0].Email__c)) {

        NotificationService.Request req =
            new NotificationService.Request(
                appUser[0].Email__c,
                'New Document Shared',
                'A new document has been shared with your account.'
            );

        req.type = 'Document_Shared';

        NotificationService.dispatch(
            new List<NotificationService.Request>{ req }
        );
    }
}

        // ── 6. Mark related open document-request Tasks as Completed ──────────
         closeRelatedDocumentTasks(caseId);

        // ── 7. Notify patient by email ────────────────────────────────────────
        if (!toUpsert.isEmpty()) {
            List<Contact> patient = [SELECT FirstName, Email FROM Contact WHERE Id = :contactId LIMIT 1];

        if (String.isNotBlank(patient[0].Email)) {
            sendShareNotificationEmail(patient[0].Email, patient[0].FirstName, toUpsert.size());
        }
}

        return toUpsert.size();
    }

    // ─── Private Helper: Close Tasks ─────────────────────────────────────────

    /**
     * Finds all open document-request Tasks on the Case and sets their
     * Status to 'Completed'.  Called automatically after a successful share
     * so the fulfilment loop is closed without manual agent effort.
     *
     * Uses IsClosed = false so that any custom "closed" picklist values
     * configured in the org are also respected.
     */
    private static void closeRelatedDocumentTasks(Id caseId) {
        List<Task> openTasks = [
            SELECT Id
            FROM   Task
            WHERE  WhatId   = :caseId
            AND    Subject  IN (
                'Itemized Bill Request',
                'Document Request',
                'Insurance Claim Request',
                'Explanation of Benefits Request'
            )
        ];

        if (openTasks.isEmpty()) { return; }

        for (Task t : openTasks) {
            t.Status = 'Completed';
        }
        update openTasks;

    }

    // ─── Private Helper: Format File Size ────────────────────────────────────

    /** Converts a byte count into a human-readable string. */
    @TestVisible
    private static String formatFileSize(Long bytes) {
        if (bytes == null || bytes == 0) { return '0 B'; }
        if (bytes < 1024L)               { return bytes + ' B'; }
        if (bytes < 1048576L)            { return (bytes / 1024) + ' KB'; }
        if (bytes < 1073741824L) {
            return (bytes / 1048576.0).setScale(1) + ' MB';
        }
        return (bytes / 1073741824.0).setScale(1) + ' GB';
    }


    private static void sendShareNotificationEmail(String toEmail,String toName,Integer docCount) {

    String greeting = String.isNotBlank(toName) ? 'Hi ' + toName + ',' : 'Hello,';
    String docLabel = docCount == 1 ? '1 document has' : docCount + ' documents have';

    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
    mail.setToAddresses(new List<String>{ toEmail });
    mail.setSubject('New Document Available in Your PHI Patient Portal ');
    mail.setPlainTextBody(
        greeting + '\n\n' +
       'A new document has been shared with you in your Passage Health International Patient Portal. Please log in to view it.' + 
       'If you have questions about this document, please contact us at support@passagehi.com.' + '\n \n' + 
       'Thank you,'+ '\n' + 
       'Passage Health International Team' + '\n \n' +
       'This message was sent by Passage Health International' + '\n' +
       '[INSERT PHI PHYSICAL MAILING ADDRESS]' + '\n' + 'support@passagehi.com  |  [INSERT PHI SUPPORT PHONE]' + '\n' +
        'You are receiving this message because you are a registered user of the Passage Health International Patient Portal App.'
        + '\n' + 'To manage your communication preferences: [App Settings Link]' + '\n' +
        'To unsubscribe from marketing communications: [Unsubscribe Link]' + '\n' +
        'Privacy Policy: [URL]  |  Terms of Use: [URL]'
    );

    mail.setSaveAsActivity(false); // prevent unwanted Task records

    try {
        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
    } catch (Exception e) {
        // Log but don't rethrow — a failed email should not roll back a
        // successful document share.
        System.debug(LoggingLevel.ERROR,
            'CaseDocumentSharingController: email send failed — ' + e.getMessage());
    }
}
}