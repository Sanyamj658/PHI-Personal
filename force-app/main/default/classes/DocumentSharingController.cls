public with sharing class DocumentSharingController {
    public class FileWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String contentDocumentId;
        @AuraEnabled public String title;
        @AuraEnabled public String fileType;
        @AuraEnabled public String createdDate;
        @AuraEnabled public Long contentSize;
        @AuraEnabled public String fileSizeFormatted;
        @AuraEnabled public Boolean isShared;
        @AuraEnabled public String sharedDocumentId;
    }

    @AuraEnabled(cacheable=true)
    public static List<FileWrapper> getContactFiles(Id appUserId) {
        try {
            if (appUserId == null) {
                throw new AuraHandledException('App User ID is required.');
            }

            List<App_User__c> users = [
                SELECT Id, Patient__c
                FROM App_User__c
                WHERE Id = :appUserId
                LIMIT 1
            ];

            if (users.isEmpty() || users[0].Patient__c == null) {
                return new List<FileWrapper>();
            }

            Id contactId = users[0].Patient__c;

            List<ContentDocumentLink> links = [
                SELECT ContentDocumentId,
                    ContentDocument.Title,
                    ContentDocument.FileType,
                    ContentDocument.CreatedDate,
                    ContentDocument.ContentSize
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :contactId
                ORDER BY ContentDocument.CreatedDate DESC
            ];

            if (links.isEmpty()) {
                return new List<FileWrapper>();
            }

            Set<String> docIdSet = new Set<String>();
            for (ContentDocumentLink cdl : links) {
                docIdSet.add(String.valueOf(cdl.ContentDocumentId));
            }

            Map<String, Shared_Document__c> sharedMap = new Map<String, Shared_Document__c>();
            for (Shared_Document__c sd : [
                SELECT Id, Content_Document_Id__c, Visible_On_Mobile__c
                FROM Shared_Document__c
                WHERE App_User__c = :appUserId
                AND Content_Document_Id__c IN :docIdSet
            ]) {
                sharedMap.put(sd.Content_Document_Id__c, sd);
            }

            List<FileWrapper> result = new List<FileWrapper>();
            for (ContentDocumentLink cdl : links) {
                String docId = String.valueOf(cdl.ContentDocumentId);
                Boolean shared = sharedMap.containsKey(docId) && sharedMap.get(docId).Visible_On_Mobile__c;

                FileWrapper fw = new FileWrapper();
                fw.id = docId;
                fw.contentDocumentId = docId;
                fw.title = cdl.ContentDocument.Title;
                fw.fileType = cdl.ContentDocument.FileType != null ? cdl.ContentDocument.FileType.toUpperCase() : 'UNKNOWN';
                fw.createdDate = cdl.ContentDocument.CreatedDate != null ? String.valueOf(cdl.ContentDocument.CreatedDate) : '';
                fw.contentSize = cdl.ContentDocument.ContentSize;
                fw.fileSizeFormatted = formatFileSize(cdl.ContentDocument.ContentSize);
                fw.isShared = shared;
                fw.sharedDocumentId = shared ? sharedMap.get(docId).Id : null;
                result.add(fw);
            }

            return result;
        } catch (Exception ex) {
            throw new AuraHandledException('Error loading contact files: ' + ex.getMessage());
        }
    }

    @AuraEnabled
    public static Integer shareDocuments(Id appUserId, List<String> contentDocumentIds) {
        try {
            if (appUserId == null || contentDocumentIds == null || contentDocumentIds.isEmpty()) {
                throw new AuraHandledException('Invalid parameters: App User ID and at least one document ID are required.');
            }

            List<App_User__c> users = [
                SELECT Id, Patient__c
                FROM App_User__c
                WHERE Id = :appUserId
                LIMIT 1
            ];

            if (users.isEmpty() || users[0].Patient__c == null) {
                throw new AuraHandledException('No linked Contact found for this App User.');
            }

            Id contactId = users[0].Patient__c;

            Map<String, Shared_Document__c> existingMap = new Map<String, Shared_Document__c>();
            for (Shared_Document__c sd : [
                SELECT Id, Content_Document_Id__c, Visible_On_Mobile__c
                FROM Shared_Document__c
                WHERE App_User__c = :appUserId
                AND Content_Document_Id__c IN :contentDocumentIds
            ]) {
                existingMap.put(sd.Content_Document_Id__c, sd);
            }

            List<Shared_Document__c> toUpsert = new List<Shared_Document__c>();

            for (String docId : contentDocumentIds) {
                if (existingMap.containsKey(docId)) {
                    Shared_Document__c existing = existingMap.get(docId);
                    if (!existing.Visible_On_Mobile__c) {
                        existing.Visible_On_Mobile__c = true;
                        toUpsert.add(existing);
                    }
                } else {
                    toUpsert.add(new Shared_Document__c(
                        App_User__c = appUserId,
                        Contact__c = contactId,
                        Content_Document_Id__c = docId,
                        Visible_On_Mobile__c = true
                    ));
                }
            }

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
                    NotificationService.Request req = new NotificationService.Request(
                        appUser[0].Email__c,
                        'New Document Shared',
                        'A new document has been shared with your account.'
                    );
                    req.type = 'Document_Shared';
                    NotificationService.dispatch(new List<NotificationService.Request>{ req });
                }
            }

            return toUpsert.size();
        } catch (Exception ex) {
            throw new AuraHandledException('Error sharing documents: ' + ex.getMessage());
        }
    }

    @TestVisible
    private static String formatFileSize(Long bytes) {
        if (bytes == null || bytes == 0) {
            return '0 B';
        }
        if (bytes < 1024L) {
            return bytes + ' B';
        }
        if (bytes < 1048576L) {
            return (bytes / 1024) + ' KB';
        }
        if (bytes < 1073741824L) {
            return (bytes / 1048576.0).setScale(1) + ' MB';
        }
        return (bytes / 1073741824.0).setScale(1) + ' GB';
    }
}