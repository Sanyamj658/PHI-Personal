/**
 * @description  Apex controller for the DocumentSharing LWC.
 *               Retrieves ContentDocument files linked to the Contact on an
 *               App_User__c record and allows bulk sharing to the mobile app
 *               by creating / updating Shared_Document__c records.
 *
 * @author       PassageHi
 * @apiVersion   66.0
 */
public with sharing class DocumentSharingController {

    // ─── Inner Wrapper ────────────────────────────────────────────────────────

    /**
     * @description Lightweight DTO sent to the LWC for each ContentDocument.
     */
    public class FileWrapper {
        /** Row key used by the LWC (equals contentDocumentId). */
        @AuraEnabled public String  id;
        @AuraEnabled public String  contentDocumentId;
        @AuraEnabled public String  title;
        @AuraEnabled public String  fileType;
        /** ISO-8601 date string – formatted in JS for locale awareness. */
        @AuraEnabled public String  createdDate;
        @AuraEnabled public Long    contentSize;
        /** Pre-formatted size string (e.g. "2.4 MB"). */
        @AuraEnabled public String  fileSizeFormatted;
        /** True when a Shared_Document__c with Visible_On_Mobile__c = true exists. */
        @AuraEnabled public Boolean isShared;
        /** Id of the existing Shared_Document__c record (null if not yet shared). */
        @AuraEnabled public String  sharedDocumentId;
    }

    // ─── Cacheable Read ───────────────────────────────────────────────────────

    /**
     * @description Returns all ContentDocuments linked to the Contact on the
     *              given App_User__c, annotating each with its current sharing state.
     *
     * @param  appUserId  Id of the current App_User__c record.
     * @return            List of FileWrapper DTOs (empty when no Contact or no files).
     */
    @AuraEnabled(cacheable=true)
    public static List<FileWrapper> getContactFiles(Id appUserId) {
        if (appUserId == null) {
            throw new AuraHandledException('App User ID is required.');
        }

        // ── 1. Resolve the linked Contact ────────────────────────────────────
        List<App_User__c> users = [
            SELECT Id, Patient__c
            FROM   App_User__c
            WHERE  Id = :appUserId
            LIMIT  1
        ];

        if (users.isEmpty() || users[0].Patient__c == null) {
            return new List<FileWrapper>();
        }

        Id contactId = users[0].Patient__c;

        // ── 2. Fetch all ContentDocumentLinks for the Contact ─────────────────
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId,
                   ContentDocument.Title,
                   ContentDocument.FileType,
                   ContentDocument.CreatedDate,
                   ContentDocument.ContentSize
            FROM   ContentDocumentLink
            WHERE  LinkedEntityId = :contactId
            ORDER  BY ContentDocument.CreatedDate DESC
        ];

        if (links.isEmpty()) {
            return new List<FileWrapper>();
        }

        // ── 3. Collect document IDs (String) for the sharing look-up ──────────
        Set<String> docIdSet = new Set<String>();
        for (ContentDocumentLink cdl : links) {
            docIdSet.add(String.valueOf(cdl.ContentDocumentId));
        }

        // ── 4. Batch-query existing Shared_Document__c records ────────────────
        Map<String, Shared_Document__c> sharedMap = new Map<String, Shared_Document__c>();
        for (Shared_Document__c sd : [
            SELECT Id, Content_Document_Id__c, Visible_On_Mobile__c
            FROM   Shared_Document__c
            WHERE  App_User__c          = :appUserId
            AND    Content_Document_Id__c IN :docIdSet
        ]) {
            sharedMap.put(sd.Content_Document_Id__c, sd);
        }

        // ── 5. Build wrapper list ─────────────────────────────────────────────
        List<FileWrapper> result = new List<FileWrapper>();
        for (ContentDocumentLink cdl : links) {
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
            result.add(fw);
        }

        return result;
    }

    // ─── DML Write ────────────────────────────────────────────────────────────

    /**
     * @description Creates or updates Shared_Document__c records for each
     *              supplied ContentDocumentId, setting Visible_On_Mobile__c = true.
     *              Duplicate-safe: existing records are updated, not re-inserted.
     *
     * @param  appUserId            Id of the App_User__c record.
     * @param  contentDocumentIds   List of ContentDocument Id strings to share.
     * @return                      Count of records actually upserted.
     */
    @AuraEnabled
    public static Integer shareDocuments(Id appUserId, List<String> contentDocumentIds) {
        // ── Validation ────────────────────────────────────────────────────────
        if (appUserId == null || contentDocumentIds == null || contentDocumentIds.isEmpty()) {
            throw new AuraHandledException(
                'Invalid parameters: App User ID and at least one document ID are required.'
            );
        }

        // ── 1. Resolve App User + Contact ────────────────────────────────────
        List<App_User__c> users = [
            SELECT Id, Patient__c
            FROM   App_User__c
            WHERE  Id = :appUserId
            LIMIT  1
        ];

        if (users.isEmpty() || users[0].Patient__c == null) {
            throw new AuraHandledException('No linked Contact found for this App User.');
        }

        Id contactId = users[0].Patient__c;

        // ── 2. Load existing Shared_Document__c records to prevent duplicates ─
        Map<String, Shared_Document__c> existingMap = new Map<String, Shared_Document__c>();
        for (Shared_Document__c sd : [
            SELECT Id, Content_Document_Id__c, Visible_On_Mobile__c
            FROM   Shared_Document__c
            WHERE  App_User__c            = :appUserId
            AND    Content_Document_Id__c IN :contentDocumentIds
        ]) {
            existingMap.put(sd.Content_Document_Id__c, sd);
        }

        // ── 3. Build upsert list ──────────────────────────────────────────────
        List<Shared_Document__c> toUpsert = new List<Shared_Document__c>();

        for (String docId : contentDocumentIds) {
            if (existingMap.containsKey(docId)) {
                // Only update if the flag needs changing
                Shared_Document__c existing = existingMap.get(docId);
                if (!existing.Visible_On_Mobile__c) {
                    existing.Visible_On_Mobile__c = true;
                    toUpsert.add(existing);
                }
            } else {
                // New sharing record
                toUpsert.add(new Shared_Document__c(
                    App_User__c            = appUserId,
                    Contact__c             = contactId,
                    Content_Document_Id__c = docId,
                    Visible_On_Mobile__c   = true
                ));
            }
        }

        // ── 4. Bulk upsert (governor-limit safe) ──────────────────────────────
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

        return toUpsert.size();
    }

    // ─── Private Helpers ──────────────────────────────────────────────────────

    /**
     * @description Converts a byte count into a human-readable string.
     *
     * @param  bytes  Raw file size in bytes.
     * @return        Formatted string such as "2.4 MB".
     */
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
}