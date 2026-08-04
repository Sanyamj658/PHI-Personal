/**
 * @description  Test class for DocumentSharingController.
 *               Covers: file retrieval, sharing (new + duplicate prevention),
 *               edge cases (no contact, null params), and the formatFileSize helper.
 *
 * @author       PassageHi
 * @apiVersion   66.0
 */
@IsTest
private class DocumentSharingControllerTest {

    // ─── Test Setup ───────────────────────────────────────────────────────────

    @TestSetup
    static void setup() {
        // 1. Contact (represents the patient)
         Account acc = new Account(
    Name = 'PatientDataService Hospital',
    Account_Manager_Name__c = 'Test Manager'
);
insert acc;
        Insurance_Company__c insurance =
    new Insurance_Company__c(
        Name = 'Test Insurance'
    );
insert insurance;
        Contact con = new Contact(LastName = 'DocShareTestPatient', Email            = 'dataservice.patient@example.com',
    DX_s__c          = 'DS01',
    AccountId        = acc.Id,
    Primary_Insurance__c = insurance.Id,
    Plan_Type__c     = 'Other Plan',
    Date_of_Birth__c = Date.newInstance(1985, 6, 15));
        insert con;

        // 2. App User linked to the Contact
        App_User__c appUser = new App_User__c(
            Patient__c = con.Id,
            Email__c   = 'docsharetest@example.com'
        );
        insert appUser;

        // 3. ContentVersion → auto-creates ContentDocument
        ContentVersion cv = new ContentVersion(
            Title          = 'Medical Report',
            PathOnClient   = 'MedicalReport.pdf',
            VersionData    = Blob.valueOf('PDF binary content'),
            IsMajorVersion = true
        );
        insert cv;

        // Re-query to get the auto-generated ContentDocumentId
        ContentVersion insertedCV = [
            SELECT Id, ContentDocumentId
            FROM   ContentVersion
            WHERE  Id = :cv.Id
            LIMIT  1
        ];

        // 4. Link the ContentDocument to the Contact
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = insertedCV.ContentDocumentId,
            LinkedEntityId    = con.Id,
            ShareType         = 'V',
            Visibility        = 'AllUsers'
        );
        insert cdl;
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────

    private static App_User__c getAppUser() {
        return [SELECT Id, Patient__c FROM App_User__c WHERE Email__c = 'docsharetest@example.com' LIMIT 1];
    }

    private static Id getContentDocumentId() {

    Contact con = [
        SELECT Id
        FROM Contact
        WHERE LastName = 'DocShareTestPatient'
        LIMIT 1
    ];

    return [
        SELECT ContentDocumentId
        FROM ContentDocumentLink
        WHERE LinkedEntityId = :con.Id
        LIMIT 1
    ].ContentDocumentId;
}

    // ─── getContactFiles ──────────────────────────────────────────────────────

    @IsTest
    static void getContactFiles_returnsFilesWithCorrectData() {
        App_User__c appUser = getAppUser();

        Test.startTest();
        List<DocumentSharingController.FileWrapper> files =
            DocumentSharingController.getContactFiles(appUser.Id);
        Test.stopTest();

        Assert.areEqual(1, files.size(),  'Should return exactly one file.');
        Assert.areEqual('Medical Report', files[0].title, 'Title should match.');
        Assert.isFalse(files[0].isShared, 'File should not yet be marked as shared.');
        Assert.isNull(files[0].sharedDocumentId, 'No sharing record should exist yet.');
        Assert.isTrue(
            files[0].fileSizeFormatted != null && files[0].fileSizeFormatted.length() > 0,
            'File size should be formatted.'
        );
    }

    @IsTest
    static void getContactFiles_marksAlreadySharedFiles() {
        App_User__c appUser      = getAppUser();
        Id          contentDocId = getContentDocumentId();

        // Pre-create a sharing record
        insert new Shared_Document__c(
            App_User__c            = appUser.Id,
            Contact__c             = appUser.Patient__c,
            Content_Document_Id__c = String.valueOf(contentDocId),
            Visible_On_Mobile__c   = true
        );

        Test.startTest();
        List<DocumentSharingController.FileWrapper> files =
            DocumentSharingController.getContactFiles(appUser.Id);
        Test.stopTest();

        Assert.areEqual(1, files.size(), 'Should return one file.');
        Assert.isTrue(files[0].isShared, 'File should be marked as shared.');
        Assert.isNotNull(files[0].sharedDocumentId, 'Shared document ID should be populated.');
    }

   
    @IsTest
    static void getContactFiles_throwsOnNullId() {
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            DocumentSharingController.getContactFiles(null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        Assert.isTrue(exceptionThrown, 'Should throw AuraHandledException for null appUserId.');
    }

    // ─── shareDocuments ───────────────────────────────────────────────────────

    @IsTest
    static void shareDocuments_createsNewSharingRecord() {
        App_User__c appUser      = getAppUser();
        Id          contentDocId = getContentDocumentId();
        List<String> docIds      = new List<String>{ String.valueOf(contentDocId) };

        Test.startTest();
        Integer count = DocumentSharingController.shareDocuments(appUser.Id, docIds);
        Test.stopTest();

        Assert.areEqual(1, count, 'One new record should have been created.');
        List<Shared_Document__c> created = [
            SELECT Id, Visible_On_Mobile__c, Contact__c
            FROM   Shared_Document__c
            WHERE  App_User__c = :appUser.Id
        ];
        Assert.areEqual(1, created.size(), 'One Shared_Document__c should exist.');
        Assert.isTrue(created[0].Visible_On_Mobile__c, 'Visible_On_Mobile__c should be true.');
        Assert.areEqual(appUser.Patient__c, created[0].Contact__c, 'Contact should be set correctly.');
    }

    @IsTest
    static void shareDocuments_preventsCreatingDuplicateRecords() {
        App_User__c appUser      = getAppUser();
        Id          contentDocId = getContentDocumentId();
        String      docIdStr     = String.valueOf(contentDocId);

        // First share
        insert new Shared_Document__c(
            App_User__c            = appUser.Id,
            Contact__c             = appUser.Patient__c,
            Content_Document_Id__c = docIdStr,
            Visible_On_Mobile__c   = true
        );

        Test.startTest();
        // Re-sharing the same document should not create a new record
        Integer count = DocumentSharingController.shareDocuments(
            appUser.Id,
            new List<String>{ docIdStr }
        );
        Test.stopTest();

        Assert.areEqual(0, count, 'No new records should be inserted when already shared.');
        Integer total = [
            SELECT COUNT() FROM Shared_Document__c WHERE App_User__c = :appUser.Id
        ];
        Assert.areEqual(1, total, 'There should still be exactly one Shared_Document__c record.');
    }

    @IsTest
    static void shareDocuments_reEnablesVisibilityWhenFlagWasFalse() {
        App_User__c appUser      = getAppUser();
        Id          contentDocId = getContentDocumentId();
        String      docIdStr     = String.valueOf(contentDocId);

        // Existing record with visibility turned off
        insert new Shared_Document__c(
            App_User__c            = appUser.Id,
            Contact__c             = appUser.Patient__c,
            Content_Document_Id__c = docIdStr,
            Visible_On_Mobile__c   = false
        );

        Test.startTest();
        Integer count = DocumentSharingController.shareDocuments(
            appUser.Id,
            new List<String>{ docIdStr }
        );
        Test.stopTest();

        Assert.areEqual(1, count, 'One record should be updated.');
        Shared_Document__c updated = [
            SELECT Visible_On_Mobile__c FROM Shared_Document__c WHERE App_User__c = :appUser.Id LIMIT 1
        ];
        Assert.isTrue(updated.Visible_On_Mobile__c, 'Visible_On_Mobile__c should now be true.');
    }

    @IsTest
    static void shareDocuments_throwsWhenNoContactLinked() {
        App_User__c noContact = new App_User__c(Email__c = 'noc2@example.com');
        insert noContact;

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            DocumentSharingController.shareDocuments(
                noContact.Id,
                new List<String>{ 'someDocId' }
            );
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        Assert.isTrue(exceptionThrown, 'Should throw when no Contact is linked.');
    }

    @IsTest
    static void shareDocuments_throwsOnNullParams() {
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            DocumentSharingController.shareDocuments(null, null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        Assert.isTrue(exceptionThrown, 'Should throw on null parameters.');
    }

    // ─── formatFileSize (private helper via @TestVisible) ────────────────────

    @IsTest
    static void formatFileSize_handlesAllRanges() {
        Assert.areEqual('0 B',   DocumentSharingController.formatFileSize(0),          'Zero bytes');
        Assert.areEqual('500 B', DocumentSharingController.formatFileSize(500),        'Bytes range');
        Assert.areEqual('1 KB',  DocumentSharingController.formatFileSize(1024),       '1 KB exactly');
        Assert.areEqual('2 KB',  DocumentSharingController.formatFileSize(2048),       '2 KB');
        Assert.isTrue(
            DocumentSharingController.formatFileSize(2097152).contains('MB'),          '2 MB range'
        );
        Assert.isTrue(
            DocumentSharingController.formatFileSize(2147483648L).contains('GB'),      '2 GB range'
        );
        Assert.areEqual('0 B',   DocumentSharingController.formatFileSize(null),       'Null input');
    }
}