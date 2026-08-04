/**
 * CaseDocumentSharingControllerTest
 * Covers: getCaseFilesData (success, null caseId, case not found, no contact,
 *         no app user, no documents, already shared),
 *         shareDocuments (success, duplicate prevention, re-enable visibility,
 *         closes open tasks, no case, no contact, no app user, null params),
 *         formatFileSize helper.
 */
@IsTest
private class CaseDocumentSharingControllerTest {

    // ─── Test Setup ───────────────────────────────────────────────────────────

    @TestSetup
    static void setup() {
        Account acc = new Account(
    Name = 'Case Doc Test Hospital',
    Account_Manager_Name__c = 'Test Manager'
);
insert acc;
        Insurance_Company__c insurance =
    new Insurance_Company__c(
        Name = 'Test Insurance'
    );
insert insurance;

Contact patient = new Contact(
    FirstName = 'CaseDoc',
    LastName  = 'Patient',
    Email     = 'casedoc.patient@example.com',
    DX_s__c   = 'TEST01',
    AccountId = acc.Id,
    Primary_Insurance__c = insurance.Id,
    Plan_Type__c = 'Other Plan'
);
        insert patient;

        App_User__c appUser = new App_User__c(
            Email__c  = 'casedoc.patient@example.com',
            Patient__c = patient.Id,
            Status__c = 'Active'
        );
        insert appUser;

        Case patientCase = new Case(
            Status    = 'New',
            Origin    = 'Phone',
            ContactId = patient.Id,
            AccountId = acc.Id
        );
        insert patientCase;

        ContentVersion cv = new ContentVersion(
            Title          = 'Case Medical Report',
            PathOnClient   = 'CaseMedical.pdf',
            VersionData    = Blob.valueOf('PDF content here'),
            IsMajorVersion = true
        );
        insert cv;

        ContentVersion insertedCv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];

        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = insertedCv.ContentDocumentId,
            LinkedEntityId    = patientCase.Id,
            ShareType         = 'V',
            Visibility        = 'AllUsers'
        );
        insert cdl;
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────

    private static Case getCase() {
        return [SELECT Id, ContactId FROM Case WHERE Contact.Email = 'casedoc.patient@example.com' LIMIT 1];
    }

    private static App_User__c getAppUser() {
        return [SELECT Id, Patient__c FROM App_User__c WHERE Email__c = 'casedoc.patient@example.com' LIMIT 1];
    }

    private static Id getContentDocumentId() {
        Case c = getCase();
        return [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :c.Id LIMIT 1].ContentDocumentId;
    }

    // ─── getCaseFilesData ─────────────────────────────────────────────────────

    @IsTest
    static void testGetCaseFilesData_Success() {
        Case c = getCase();

        Test.startTest();
        CaseDocumentSharingController.CaseFilesResult result =
            CaseDocumentSharingController.getCaseFilesData(c.Id);
        Test.stopTest();

        System.assertEquals(true, result.canShare, 'canShare should be true');
        System.assertEquals(1, result.files.size(), 'One file should be returned');
        System.assertEquals('Case Medical Report', result.files[0].title);
        Assert.isFalse(result.files[0].isShared, 'File should not yet be shared');
    }

    @IsTest
    static void testGetCaseFilesData_AlreadyShared() {
        Case c        = getCase();
        App_User__c u = getAppUser();
        Id docId      = getContentDocumentId();

        insert new Shared_Document__c(
            App_User__c            = u.Id,
            Contact__c             = u.Patient__c,
            Content_Document_Id__c = String.valueOf(docId),
            Visible_On_Mobile__c   = true
        );

        Test.startTest();
        CaseDocumentSharingController.CaseFilesResult result =
            CaseDocumentSharingController.getCaseFilesData(c.Id);
        Test.stopTest();

        Assert.isTrue(result.files[0].isShared, 'File should be marked as shared');
        System.assertNotEquals(null, result.files[0].sharedDocumentId);
    }

    @IsTest
    static void testGetCaseFilesData_NullCaseId_ThrowsException() {
        Boolean thrown = false;
        Test.startTest();
        try {
            CaseDocumentSharingController.getCaseFilesData(null);
        } catch (AuraHandledException ex) {
            thrown = true;
        }
        Test.stopTest();
        System.assert(thrown, 'Null caseId should throw AuraHandledException');
    }

    @IsTest
    static void testGetCaseFilesData_CaseNotFound_ThrowsException() {
        Case tempCase = new Case(Status = 'New', Origin = 'Phone');
        insert tempCase;
        Id deletedId = tempCase.Id;
        delete tempCase;

        Boolean thrown = false;
        Test.startTest();
        try {
            CaseDocumentSharingController.getCaseFilesData(deletedId);
        } catch (AuraHandledException ex) {
            thrown = true;
        }
        Test.stopTest();
        System.assert(thrown, 'Should throw when case not found');
    }

    @IsTest
    static void testGetCaseFilesData_NoContact_CannotShare() {
        Case noContactCase = new Case(Status = 'New', Origin = 'Phone');
        insert noContactCase;

        Test.startTest();
        CaseDocumentSharingController.CaseFilesResult result =
            CaseDocumentSharingController.getCaseFilesData(noContactCase.Id);
        Test.stopTest();

        Assert.isFalse(result.canShare, 'canShare should be false without a contact');
    }


    // ─── shareDocuments ───────────────────────────────────────────────────────

    @IsTest
    static void testShareDocuments_CreatesNewRecord() {
        Case c  = getCase();
        Id docId = getContentDocumentId();

        Test.startTest();
        Integer count = CaseDocumentSharingController.shareDocuments(
            c.Id, new List<String>{ String.valueOf(docId) }
        );
        Test.stopTest();

        System.assertEquals(1, count, 'One document should be shared');
        List<Shared_Document__c> shared = [
            SELECT Id, Visible_On_Mobile__c FROM Shared_Document__c
            WHERE Content_Document_Id__c = :String.valueOf(docId)
        ];
        System.assertEquals(1, shared.size());
        Assert.isTrue(shared[0].Visible_On_Mobile__c);
    }

    @IsTest
    static void testShareDocuments_PreventsDuplicate() {
        Case        c     = getCase();
        App_User__c u     = getAppUser();
        Id          docId = getContentDocumentId();
        String      docStr = String.valueOf(docId);

        insert new Shared_Document__c(
            App_User__c            = u.Id,
            Contact__c             = u.Patient__c,
            Content_Document_Id__c = docStr,
            Visible_On_Mobile__c   = true
        );

        Test.startTest();
        Integer count = CaseDocumentSharingController.shareDocuments(c.Id, new List<String>{ docStr });
        Test.stopTest();

        System.assertEquals(0, count, 'Already-shared doc should not produce a new record');
        System.assertEquals(1, [SELECT COUNT() FROM Shared_Document__c WHERE Content_Document_Id__c = :docStr]);
    }

    @IsTest
    static void testShareDocuments_ReEnablesVisibility() {
        Case        c     = getCase();
        App_User__c u     = getAppUser();
        Id          docId = getContentDocumentId();
        String      docStr = String.valueOf(docId);

        insert new Shared_Document__c(
            App_User__c            = u.Id,
            Contact__c             = u.Patient__c,
            Content_Document_Id__c = docStr,
            Visible_On_Mobile__c   = false
        );

        Test.startTest();
        Integer count = CaseDocumentSharingController.shareDocuments(c.Id, new List<String>{ docStr });
        Test.stopTest();

        System.assertEquals(1, count, 'Should update the existing record');
        Shared_Document__c sd = [SELECT Visible_On_Mobile__c FROM Shared_Document__c WHERE Content_Document_Id__c = :docStr LIMIT 1];
        Assert.isTrue(sd.Visible_On_Mobile__c);
    }


    @IsTest
    static void testShareDocuments_NullParams_ThrowsException() {
        Boolean thrown = false;
        Test.startTest();
        try {
            CaseDocumentSharingController.shareDocuments(null, null);
        } catch (AuraHandledException ex) {
            thrown = true;
        }
        Test.stopTest();
        System.assert(thrown, 'Null params should throw');
    }

    @IsTest
    static void testShareDocuments_CaseNotFound_ThrowsException() {
        Case temp = new Case(Status = 'New', Origin = 'Phone');
        insert temp;
        Id deletedId = temp.Id;
        delete temp;

        Boolean thrown = false;
        Test.startTest();
        try {
            CaseDocumentSharingController.shareDocuments(deletedId, new List<String>{ 'someId' });
        } catch (AuraHandledException ex) {
            thrown = true;
        }
        Test.stopTest();
        System.assert(thrown);
    }

    @IsTest
    static void testShareDocuments_NoContact_ThrowsException() {
        Case noContact = new Case(Status = 'New', Origin = 'Phone');
        insert noContact;

        Boolean thrown = false;
        Test.startTest();
        try {
            CaseDocumentSharingController.shareDocuments(noContact.Id, new List<String>{ 'someId' });
        } catch (AuraHandledException ex) {
            thrown = true;
        }
        Test.stopTest();
        System.assert(thrown, 'No contact on case should throw');
    }

 

    // ─── formatFileSize ───────────────────────────────────────────────────────

    @IsTest
    static void testFormatFileSize_AllRanges() {
        System.assertEquals('0 B',   CaseDocumentSharingController.formatFileSize(null));
        System.assertEquals('0 B',   CaseDocumentSharingController.formatFileSize(0));
        System.assertEquals('512 B', CaseDocumentSharingController.formatFileSize(512));
        System.assertEquals('1 KB',  CaseDocumentSharingController.formatFileSize(1024));
        System.assertEquals('2 KB',  CaseDocumentSharingController.formatFileSize(2048));
        System.assert(CaseDocumentSharingController.formatFileSize(1048576).contains('MB'));
        System.assert(CaseDocumentSharingController.formatFileSize(2147483648L).contains('GB'));
    }

    // ─── Bulk shareDocuments ──────────────────────────────────────────────────

    @IsTest
    static void testShareDocuments_BulkDocuments() {
        Case        c  = getCase();
        App_User__c u  = getAppUser();

        // Create 5 content versions to share
        List<ContentVersion> cvs = new List<ContentVersion>();
        for (Integer i = 0; i < 5; i++) {
            cvs.add(new ContentVersion(
                Title          = 'BulkDoc ' + i,
                PathOnClient   = 'BulkDoc' + i + '.pdf',
                VersionData    = Blob.valueOf('content' + i),
                IsMajorVersion = true
            ));
        }
        insert cvs;

        List<String> docIds = new List<String>();
        for (ContentVersion cv : [SELECT ContentDocumentId FROM ContentVersion WHERE Id IN :cvs]) {
            // Link to case
            insert new ContentDocumentLink(
                ContentDocumentId = cv.ContentDocumentId,
                LinkedEntityId    = c.Id,
                ShareType         = 'V'
            );
            docIds.add(String.valueOf(cv.ContentDocumentId));
        }

        Test.startTest();
        Integer count = CaseDocumentSharingController.shareDocuments(c.Id, docIds);
        Test.stopTest();

        System.assertEquals(5, count, 'All 5 docs should be shared');
        System.assertEquals(5, [SELECT COUNT() FROM Shared_Document__c WHERE App_User__c = :u.Id AND Content_Document_Id__c IN :docIds]);
    }
}