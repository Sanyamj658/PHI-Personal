/**
 * MobileDocumentsAPITest
 * Covers: getSharedDocuments – success returns documents with download URLs,
 *         no app user id (400), no shared documents (empty list),
 *         documents not visible on mobile excluded, exception path.
 */
@IsTest
private class MobileDocumentsAPITest {

   @TestSetup
static void setup() {

    // Required Account
    Account acc = new Account(
        Name = 'Mobile Docs Hospital',
        Account_Manager_Name__c = 'Test Manager'
    );
    insert acc;

    // Required Insurance
    Insurance_Company__c insurance =
        new Insurance_Company__c(
            Name = 'Test Insurance'
        );
    insert insurance;

    // Patient Contact
    Contact patient = new Contact(
        LastName = 'MobileDocsPatient',
        Email    = 'mobiledocs@example.com',
        DX_s__c  = 'MD01',
        AccountId = acc.Id,
        Primary_Insurance__c = insurance.Id,
        Plan_Type__c = 'Other Plan'
    );
    insert patient;

        App_User__c appUser = new App_User__c(
            Email__c   = 'mobiledocs@example.com',
            Patient__c = patient.Id,
            Status__c  = 'Active'
        );
        insert appUser;

        ContentVersion cv = new ContentVersion(
            Title          = 'Mobile Test Document',
            PathOnClient   = 'MobileTestDoc.pdf',
            VersionData    = Blob.valueOf('PDF data'),
            IsMajorVersion = true
        );
        insert cv;

        ContentVersion inserted = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];

        Shared_Document__c sd = new Shared_Document__c(
            App_User__c            = [SELECT Id FROM App_User__c WHERE Email__c = 'mobiledocs@example.com'].Id,
            Contact__c             = patient.Id,
            Content_Document_Id__c = String.valueOf(inserted.ContentDocumentId),
            Visible_On_Mobile__c   = true
        );
        insert sd;
    }

    private static void setupGetContext(String appUserIdParam) {
        RestRequest  req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI  = '/services/apexrest/mobile/documents/';
        req.httpMethod  = 'GET';
        if (appUserIdParam != null) {
            req.params.put('appUserId', appUserIdParam);
        }
        RestContext.request  = req;
        RestContext.response = res;
    }

    // ─── Success: returns shared documents ───────────────────────────────────

    @IsTest
    static void testGetSharedDocuments_Success() {
        App_User__c appUser = [SELECT Id FROM App_User__c WHERE Email__c = 'mobiledocs@example.com'];
        setupGetContext(appUser.Id);

        Test.startTest();
        MobileDocumentsAPI.getSharedDocuments();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        List<Object> docs = (List<Object>) JSON.deserializeUntyped(
            RestContext.response.responseBody.toString()
        );
        System.assertEquals(1, docs.size(), 'One document should be returned');

        Map<String, Object> doc = (Map<String, Object>) docs[0];
        System.assertNotEquals(null, doc.get('documentId'),  'documentId should be present');
        System.assertNotEquals(null, doc.get('downloadUrl'), 'downloadUrl should be present');
        System.assertEquals('Mobile Test Document', doc.get('title'));
    }

    // ─── Negative: missing appUserId parameter ────────────────────────────────

    @IsTest
    static void testGetSharedDocuments_MissingAppUserId() {
        setupGetContext(null);

        Test.startTest();
        MobileDocumentsAPI.getSharedDocuments();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        System.assert(
            RestContext.response.responseBody.toString().contains('App User Id Required')
        );
    }

    // ─── Negative: blank appUserId parameter ─────────────────────────────────

    @IsTest
    static void testGetSharedDocuments_BlankAppUserId() {
        setupGetContext('');

        Test.startTest();
        MobileDocumentsAPI.getSharedDocuments();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
    }

    // ─── Edge: no shared documents → empty list ───────────────────────────────

    @IsTest
    static void testGetSharedDocuments_NoSharedDocs_EmptyList() {
        // New user with no shared documents
        App_User__c newUser = new App_User__c(Email__c = 'nodocs.mobile@example.com', Status__c = 'Active');
        insert newUser;
        setupGetContext(newUser.Id);

        Test.startTest();
        MobileDocumentsAPI.getSharedDocuments();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        List<Object> docs = (List<Object>) JSON.deserializeUntyped(
            RestContext.response.responseBody.toString()
        );
        System.assertEquals(0, docs.size(), 'No documents should be returned for user with no shares');
    }

    // ─── Edge: shared document with Visible_On_Mobile__c = false excluded ─────

    @IsTest
    static void testGetSharedDocuments_HiddenDocs_NotReturned() {
        App_User__c appUser = [SELECT Id FROM App_User__c WHERE Email__c = 'mobiledocs@example.com'];

        ContentVersion cv2 = new ContentVersion(
            Title          = 'Hidden Doc',
            PathOnClient   = 'HiddenDoc.pdf',
            VersionData    = Blob.valueOf('hidden'),
            IsMajorVersion = true
        );
        insert cv2;
        ContentVersion inserted2 = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv2.Id LIMIT 1];

        insert new Shared_Document__c(
            App_User__c            = appUser.Id,
            Content_Document_Id__c = String.valueOf(inserted2.ContentDocumentId),
            Visible_On_Mobile__c   = false
        );

        setupGetContext(appUser.Id);

        Test.startTest();
        MobileDocumentsAPI.getSharedDocuments();
        Test.stopTest();

        // Only the one visible document should appear
        List<Object> docs = (List<Object>) JSON.deserializeUntyped(
            RestContext.response.responseBody.toString()
        );
        System.assertEquals(1, docs.size(), 'Hidden document should not appear in results');
    }

    // ─── Bulk: multiple shared documents ─────────────────────────────────────

    @IsTest
    static void testGetSharedDocuments_MultipleDocs() {
        App_User__c appUser = [SELECT Id, Patient__c FROM App_User__c WHERE Email__c = 'mobiledocs@example.com'];

        for (Integer i = 0; i < 4; i++) {
            ContentVersion cv = new ContentVersion(
                Title          = 'BulkMobileDoc ' + i,
                PathOnClient   = 'Bulk' + i + '.pdf',
                VersionData    = Blob.valueOf('content' + i),
                IsMajorVersion = true
            );
            insert cv;
            ContentVersion ins = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
            insert new Shared_Document__c(
                App_User__c            = appUser.Id,
                Contact__c             = appUser.Patient__c,
                Content_Document_Id__c = String.valueOf(ins.ContentDocumentId),
                Visible_On_Mobile__c   = true
            );
        }

        setupGetContext(appUser.Id);

        Test.startTest();
        MobileDocumentsAPI.getSharedDocuments();
        Test.stopTest();

        List<Object> docs = (List<Object>) JSON.deserializeUntyped(
            RestContext.response.responseBody.toString()
        );
        System.assertEquals(5, docs.size(), 'All 5 visible documents should be returned');
    }
}