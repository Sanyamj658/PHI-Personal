public with sharing class CaseDocumentSharingController {
    public class CaseFilesResult {
        @AuraEnabled public Boolean canShare;
        @AuraEnabled public String noShareReason;
        @AuraEnabled public List<FileWrapper> files;
    }

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
    public static CaseFilesResult getCaseFilesData(Id caseId) {
        try {
            if (caseId == null) {
                throw new AuraHandledException('Case ID is required.');
            }

            CaseFilesResult resultObj = new CaseFilesResult();
            resultObj.files = new List<FileWrapper>();

            List<Case> cases = [
                SELECT Id, ContactId
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];

            if (cases.isEmpty()) {
                throw new AuraHandledException('Case not found.');
            }

            Id contactId = cases[0].ContactId;

            if (contactId == null) {
                resultObj.canShare = false;
                resultObj.noShareReason = 'No patient contact is linked to this case. Documents cannot be shared to mobile.';
            }

            Id appUserId = null;
            if (contactId != null) {
                List<App_User__c> users = [
                    SELECT Id
                    FROM App_User__c
                    WHERE Patient__c = :contactId
                    LIMIT 1
                ];

                if (!users.isEmpty()) {
                    appUserId = users[0].Id;
                    resultObj.canShare = true;
                } else {
                    resultObj.canShare = false;
                    resultObj.noShareReason = 'This patient does not have a mobile app account. Files are visible here but cannot be shared.';
                }
            }

            if (appUserId == null) {
                resultObj.canShare = false;
                resultObj.noShareReason = 'No mobile app user found for the patient linked to this case. Files are visible here but cannot be shared.';
                return resultObj;
            }

            List<ContentDocumentLink> contentDocumentLinks = [
                SELECT ContentDocumentId,
                    ContentDocument.Title,
                    ContentDocument.FileType,
                    ContentDocument.CreatedDate,
                    ContentDocument.ContentSize
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :caseId
                ORDER BY ContentDocument.CreatedDate DESC
            ];

            if (contentDocumentLinks.isEmpty()) {
                return resultObj;
            }

            Set<String> docIdSet = new Set<String>();
            for (ContentDocumentLink cdl : contentDocumentLinks) {
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

            for (ContentDocumentLink cdl : contentDocumentLinks) {
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
                resultObj.files.add(fw);
            }

            return resultObj;
        } catch (Exception ex) {
            throw new AuraHandledException('Error loading case files: ' + ex.getMessage());
        }
    }

    @AuraEnabled
    public static Integer shareDocuments(Id caseId, List<String> contentDocumentIds) {
        try {
            if (caseId == null || contentDocumentIds == null || contentDocumentIds.isEmpty()) {
                throw new AuraHandledException('Invalid parameters: Case ID and at least one document ID are required.');
            }

            List<Case> cases = [
                SELECT Id, ContactId
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];

            if (cases.isEmpty()) {
                throw new AuraHandledException('Case not found.');
            }

            if (cases[0].ContactId == null) {
                throw new AuraHandledException('This Case has no linked Contact. Documents cannot be shared to the mobile app.');
            }

            Id contactId = cases[0].ContactId;

            List<App_User__c> users = [
                SELECT Id
                FROM App_User__c
                WHERE Patient__c = :contactId
                LIMIT 1
            ];

            if (users.isEmpty()) {
                throw new AuraHandledException('No mobile app account found for this patient. Documents cannot be shared.');
            }

            Id appUserId = users[0].Id;

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

            closeRelatedDocumentTasks(caseId);

            if (!toUpsert.isEmpty()) {
                List<Contact> patient = [
                    SELECT FirstName, Email
                    FROM Contact
                    WHERE Id = :contactId
                    LIMIT 1
                ];

                if (String.isNotBlank(patient[0].Email)) {
                    sendShareNotificationEmail(patient[0].Email, patient[0].FirstName, toUpsert.size());
                }
            }

            return toUpsert.size();
        } catch (Exception ex) {
            throw new AuraHandledException('Error sharing documents: ' + ex.getMessage());
        }
    }

    private static void closeRelatedDocumentTasks(Id caseId) {
        try {
            List<Task> openTasks = [
                SELECT Id
                FROM Task
                WHERE WhatId = :caseId
                AND Subject IN (
                    'Itemized Bill Request',
                    'Document Request',
                    'Insurance Claim Request',
                    'Explanation of Benefits Request'
                )
            ];

            if (openTasks.isEmpty()) {
                return;
            }

            for (Task t : openTasks) {
                t.Status = 'Completed';
            }
            update openTasks;
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'CaseDocumentSharingController.closeRelatedDocumentTasks failed: ' + ex.getMessage());
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

    private static void sendShareNotificationEmail(String toEmail, String toName, Integer docCount) {
        try {
            String greeting = String.isNotBlank(toName) ? 'Hi ' + toName + ',' : 'Hello,';
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{ toEmail });
            mail.setSubject('New Document Available in Your PHI Patient Portal');
            mail.setPlainTextBody(
                greeting + '\n\n' +
                'A new document has been shared with you in your Passage Health International Patient Portal. Please log in to view it.' +
                'If you have questions about this document, please contact us at support@passagehi.com.' + '\n\n' +
                'Thank you,\n' +
                'Passage Health International Team\n\n' +
                'This message was sent by Passage Health International\n' +
                '[INSERT PHI PHYSICAL MAILING ADDRESS]\n' + 'support@passagehi.com  |  [INSERT PHI SUPPORT PHONE]\n' +
                'You are receiving this message because you are a registered user of the Passage Health International Patient Portal App.' +
                '\n' + 'To manage your communication preferences: [App Settings Link]' + '\n' +
                'To unsubscribe from marketing communications: [Unsubscribe Link]' + '\n' +
                'Privacy Policy: [URL]  |  Terms of Use: [URL]'
            );
            mail.setSaveAsActivity(false);
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'CaseDocumentSharingController: email send failed — ' + e.getMessage());
        }
    }
}