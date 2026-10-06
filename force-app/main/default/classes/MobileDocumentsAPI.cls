// REST API returning documents shared with a mobile App User.
@RestResource(urlMapping='/mobile/documents/*')
global with sharing class MobileDocumentsAPI {
    // Returns mobile-visible shared documents (title, type, download URL) for the given appUserId.
    @HttpGet
    global static void getSharedDocuments() {
        RestResponse res = RestContext.response;

        try {
            String appUserId = RestContext.request.params.get('appUserId');

            if (String.isBlank(appUserId)) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf('App User Id Required');
                return;
            }

            // Get shared documents flagged visible on mobile for this App User.
            List<Shared_Document__c> sharedDocs = [
                SELECT Id, Content_Document_Id__c
                FROM Shared_Document__c
                WHERE App_User__c = :appUserId
                AND Visible_On_Mobile__c = true
            ];

            Set<Id> docIds = new Set<Id>();

            for (Shared_Document__c sd : sharedDocs) {
                if (sd.Content_Document_Id__c != null) {
                    docIds.add((Id) sd.Content_Document_Id__c);
                }
            }

            // Fetch ContentDocument details for the shared document Ids.
            Map<Id, ContentDocument> docMap = new Map<Id, ContentDocument>([
                SELECT Id, Title, FileType
                FROM ContentDocument
                WHERE Id IN :docIds
            ]);

            List<Map<String, Object>> responseList = new List<Map<String, Object>>();

            for (Id docId : docMap.keySet()) {
                ContentDocument cd = docMap.get(docId);
                // Build the file download link for the document.
                String downloadUrl = URL.getOrgDomainUrl().toExternalForm() + '/sfc/servlet.shepherd/document/download/' + docId;

                responseList.add(new Map<String, Object>{
                    'documentId' => docId,
                    'title' => cd.Title,
                    'fileType' => cd.FileType,
                    'downloadUrl' => downloadUrl
                });
            }

            res.statusCode = 200;
            res.responseBody = Blob.valueOf(JSON.serialize(responseList));
        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(e.getMessage());
        }
    }
}