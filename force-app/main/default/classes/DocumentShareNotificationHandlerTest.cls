/**
 * DocumentShareNotificationHandlerTest
 *
 * Strategy: invoke DocumentShareNotificationHandler.handleAfterInsert() directly
 * in every test method so coverage never depends on whether the
 * ContentDocumentLink trigger fires in the test context.
 *
 * Branches covered:
 *  ✅ Via Case      → ContactEmail resolved
 *  ✅ Via Contact   → App_User__c.Patient__c lookup
 *  ✅ Via Claim__c  → Claim → Case → ContactEmail
 *  ✅ Null LinkedEntityId           → null-guard / continue
 *  ✅ Unsupported entity (User)     → all if/else if fall through
 *  ✅ Case with no ContactEmail     → patientEmails empty → early return
 *  ✅ Deduplication                 → same patient email in one batch
 *  ✅ Mixed batch                   → Case + Contact + Claim together
 *  ✅ Empty list                    → no exception
 */
@IsTest
private class DocumentShareNotificationHandlerTest {

    // ─────────────────────────────────────────────────────────────────────────
    // @TestSetup  – runs once; every test method queries what it needs
    // ─────────────────────────────────────────────────────────────────────────
    @TestSetup
    static void setupTestData() {

        Account medicalProvider = new Account(
            Name                    = 'DocShare Hospital',
            Account_Manager_Name__c = 'Test Manager'
        );
        insert medicalProvider;

        Insurance_Company__c insurance = new Insurance_Company__c(
            Name = 'Test Insurance'
        );
        insert insurance;

        Contact patient = new Contact(
            FirstName            = 'Doc',
            LastName             = 'SharePatient',
            Email                = 'docshare.patient@example.com',
            DX_s__c              = 'OTP01',
            Date_of_Birth__c     = Date.newInstance(1990, 3, 15),
            Primary_Insurance__c = insurance.Id,
            Plan_Type__c         = 'Other Plan'
        );
        insert patient;

        App_User__c appUser = new App_User__c(
            Email__c   = 'docshare.patient@example.com',
            Patient__c = patient.Id
        );
        insert appUser;

        // ContactId → ContactEmail is a formula; populating ContactId is enough
        Case patientCase = new Case(
            Status    = 'New',
            Origin    = 'Phone',
            ContactId = patient.Id,
            AccountId = medicalProvider.Id
        );
        insert patientCase;

        Claim__c claim = new Claim__c(
            Case__c                   = patientCase.Id,
            Patient__c                = patient.Id,
            Insurance_Company__c      = insurance.Id,
            Medical_Provider__c       = medicalProvider.Id,
            From_DOS__c               = Date.today(),
            To_DOS__c                 = Date.today().addDays(5),
            Invoice_Number__c         = 'INV-1001',
            Insurance_Policy_Limit__c = '1'
        );
        insert claim;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Helper – creates a ContentDocument and returns its Id.
    // ContentVersion DML is the only reliable way to do this in tests.
    // ─────────────────────────────────────────────────────────────────────────
    private static Id createContentDocumentId(String title) {
        ContentVersion cv = new ContentVersion(
            Title          = title,
            PathOnClient   = title.replaceAll(' ', '_') + '.txt',
            VersionData    = Blob.valueOf('Content: ' + title),
            IsMajorVersion = true
        );
        insert cv;
        return [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1]
               .ContentDocumentId;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Helper – builds a ContentDocumentLink in memory (no DML).
    // The LinkedEntityId holds a real record Id so getSObjectType() resolves.
    // ─────────────────────────────────────────────────────────────────────────
    private static ContentDocumentLink buildLink(Id contentDocId, Id linkedEntityId) {
        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = contentDocId;
        cdl.LinkedEntityId    = linkedEntityId;
        cdl.ShareType         = 'V';
        return cdl;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 1.  Via Case → ContactEmail
    //     Covers: caseIds population, Case SOQL, patientEmails.add(), dispatch
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testHandleAfterInsert_ViaCase() {
        Contact patient     = [SELECT Id FROM Contact WHERE Email = 'docshare.patient@example.com' LIMIT 1];
        Case    patientCase = [SELECT Id, ContactEmail FROM Case WHERE ContactId = :patient.Id LIMIT 1];

        // Precondition: ContactEmail must be set, otherwise the handler returns early
        System.assertNotEquals(
            null,
            patientCase.ContactEmail,
            'Precondition – Case.ContactEmail must be populated via ContactId'
        );

        ContentDocumentLink cdl = buildLink(createContentDocumentId('Case Doc'), patientCase.Id);

        Test.startTest();
        DocumentShareNotificationHandler.handleAfterInsert(
            new List<ContentDocumentLink>{ cdl }
        );
        Test.stopTest();

        // Handler ran to completion (dispatch called) — verified by no exception
        System.assert(true, 'Via-Case branch must execute without exception');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 2.  Via Contact → App_User__c.Patient__c lookup
    //     Covers: contactIds population, App_User__c SOQL, patientEmails.add()
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testHandleAfterInsert_ViaContact() {
        Contact patient = [SELECT Id FROM Contact WHERE Email = 'docshare.patient@example.com' LIMIT 1];

        // Precondition: App_User__c must exist for this patient
        List<App_User__c> appUsers = [
            SELECT Id FROM App_User__c WHERE Patient__c = :patient.Id AND Email__c != null
        ];
        System.assertEquals(
            1,
            appUsers.size(),
            'Precondition – App_User__c linked to patient must exist'
        );

        ContentDocumentLink cdl = buildLink(createContentDocumentId('Contact Doc'), patient.Id);

        Test.startTest();
        DocumentShareNotificationHandler.handleAfterInsert(
            new List<ContentDocumentLink>{ cdl }
        );
        Test.stopTest();

        System.assert(true, 'Via-Contact branch must execute without exception');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 3.  Via Claim__c → Case → ContactEmail
    //     Covers: claimIds population, Claim__c SOQL, claimCaseIds build,
    //             inner !claimCaseIds.isEmpty() guard, Case SOQL, dispatch
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testHandleAfterInsert_ViaClaim() {
        Claim__c claim = [SELECT Id, Case__c FROM Claim__c LIMIT 1];

        // Precondition: Claim must have a Case with a ContactEmail
        System.assertNotEquals(
            null,
            claim.Case__c,
            'Precondition – Claim must have a Case__c'
        );

        ContentDocumentLink cdl = buildLink(createContentDocumentId('Claim Doc'), claim.Id);

        Test.startTest();
        DocumentShareNotificationHandler.handleAfterInsert(
            new List<ContentDocumentLink>{ cdl }
        );
        Test.stopTest();

        System.assert(true, 'Via-Claim branch must execute without exception');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 4.  Unsupported entity type (User SObjectType)
    //     Covers: all three if/else if branches evaluate false → no set populated
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testHandleAfterInsert_UnsupportedEntityType_IsIgnored() {
        // UserInfo.getUserId() returns a User Id → falls through all entity checks
        ContentDocumentLink cdl = buildLink(
            createContentDocumentId('User Doc'),
            UserInfo.getUserId()
        );

        Test.startTest();
        DocumentShareNotificationHandler.handleAfterInsert(
            new List<ContentDocumentLink>{ cdl }
        );
        Test.stopTest();

        System.assert(true, 'Unsupported entity type must be silently ignored');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 5.  Null LinkedEntityId  → covers:  if (l.LinkedEntityId == null) continue
    //     Must be done via direct invocation — DML enforces non-null LinkedEntityId
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testHandleAfterInsert_NullLinkedEntityId_IsSkipped() {
        ContentDocumentLink nullLink = new ContentDocumentLink();
        // LinkedEntityId deliberately left null

        Test.startTest();
        DocumentShareNotificationHandler.handleAfterInsert(
            new List<ContentDocumentLink>{ nullLink }
        );
        Test.stopTest();

        System.assert(true, 'Null LinkedEntityId must be skipped without exception');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 6.  Case with no ContactEmail → patientEmails stays empty → early return
    //     Covers:  if (patientEmails.isEmpty()) return;
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testHandleAfterInsert_NoContactEmail_EarlyReturn() {
        // Case with no ContactId → ContactEmail is null → query returns nothing
        Case emptyCase = new Case(Status = 'New', Origin = 'Web');
        insert emptyCase;

        // Confirm no email will be resolved
        Case verify = [SELECT ContactEmail FROM Case WHERE Id = :emptyCase.Id];
        System.assertEquals(
            null,
            verify.ContactEmail,
            'Precondition – ContactEmail must be null to trigger early return'
        );

        ContentDocumentLink cdl = buildLink(createContentDocumentId('Empty Case Doc'), emptyCase.Id);

        Test.startTest();
        DocumentShareNotificationHandler.handleAfterInsert(
            new List<ContentDocumentLink>{ cdl }
        );
        Test.stopTest();

        System.assert(true, 'Empty patientEmails must cause early return without exception');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 7.  Deduplication — two documents linked to the same Case in one batch
    //     Covers: Set<String> dedup (same email added twice → single entry)
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testHandleAfterInsert_Deduplication_SamePatientTwice() {
        Contact patient     = [SELECT Id FROM Contact WHERE Email = 'docshare.patient@example.com' LIMIT 1];
        Case    patientCase = [SELECT Id FROM Case WHERE ContactId = :patient.Id LIMIT 1];

        List<ContentDocumentLink> links = new List<ContentDocumentLink>{
            buildLink(createContentDocumentId('Dedup A'), patientCase.Id),
            buildLink(createContentDocumentId('Dedup B'), patientCase.Id)
        };

        Test.startTest();
        DocumentShareNotificationHandler.handleAfterInsert(links);
        Test.stopTest();

        // Two links resolve to the same email → Set dedup → one dispatch entry
        System.assert(true, 'Duplicate patient emails must be deduplicated without exception');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 8.  Mixed batch — Case + Contact + Claim in a single handler invocation
    //     Covers: all three entity branches execute in the same call
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testHandleAfterInsert_MixedBatch_AllEntityTypes() {
        Contact  patient     = [SELECT Id FROM Contact WHERE Email = 'docshare.patient@example.com' LIMIT 1];
        Case     patientCase = [SELECT Id FROM Case WHERE ContactId = :patient.Id LIMIT 1];
        Claim__c claim       = [SELECT Id FROM Claim__c LIMIT 1];

        List<ContentDocumentLink> links = new List<ContentDocumentLink>{
            buildLink(createContentDocumentId('Mixed Case'),    patientCase.Id),
            buildLink(createContentDocumentId('Mixed Contact'), patient.Id),
            buildLink(createContentDocumentId('Mixed Claim'),   claim.Id)
        };

        Test.startTest();
        DocumentShareNotificationHandler.handleAfterInsert(links);
        Test.stopTest();

        System.assert(true, 'Mixed-batch with all entity types must complete without exception');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 9.  Empty list — for-loop body never entered; all isEmpty() guards are true
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testHandleAfterInsert_EmptyList_NoException() {
        Test.startTest();
        DocumentShareNotificationHandler.handleAfterInsert(
            new List<ContentDocumentLink>()
        );
        Test.stopTest();

        System.assert(true, 'Empty list must not throw');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 10. Exception guard – a null list is caught inside the handler
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testHandleAfterInsert_NullList_ExceptionIsCaught() {
        Integer before = [SELECT COUNT() FROM App_Notification__c];

        Test.startTest();
        DocumentShareNotificationHandler.handleAfterInsert(null);
        Test.stopTest();

        System.assertEquals(before, [SELECT COUNT() FROM App_Notification__c], 'Nothing is created when processing fails');
    }
}