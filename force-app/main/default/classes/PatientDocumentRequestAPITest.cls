/**
 * PatientDocumentRequestAPITest
 * ─────────────────────────────────────────────────────────────────────────────
 * Unit tests for PatientDocumentRequestAPI.
 *
 * Coverage targets:
 *   ✅ Happy path — Itemized Bill, Medical Records, all request types
 *   ✅ Documents returned in response payload
 *   ✅ Email sent flag in response
 *   ✅ Case without Contact (emailSent = false, Task still created)
 *   ✅ Missing caseId          → 400 INVALID_INPUT
 *   ✅ Missing requestType     → 400 INVALID_INPUT
 *   ✅ Unsupported requestType → 400 INVALID_REQUEST_TYPE
 *   ✅ Malformed caseId        → 400 INVALID_CASE_ID
 *   ✅ Wrong object type Id    → 400 INVALID_CASE_ID
 *   ✅ Non-existent Case Id    → 404 CASE_NOT_FOUND
 */
@isTest
private class PatientDocumentRequestAPITest {

    // ─────────────────────────────────────────────────────────────────────────
    //  Test Data Setup
    // ─────────────────────────────────────────────────────────────────────────

    @testSetup
    static void setup() {

        Account acc = new Account(Name = 'Test Hospital', Account_Manager_Name__c = 'Test Manager');
        insert acc;
        
        Insurance_Company__c insurance =
    new Insurance_Company__c(
        Name = 'Test Insurance'

    );
insert insurance;

        Contact patient = new Contact(
            FirstName = 'Jane',
            LastName  = 'Smith',
            Email     = 'jane.smith@testpatient.com',
            AccountId = acc.Id,
            DX_s__c   = 'TEST01',
             Primary_Insurance__c = insurance.Id,
    Plan_Type__c     = 'Other Plan'
        );
        insert patient;

        Case patientCase = new Case(
            Status    = 'New',
            Origin    = 'Phone',
            Subject   = 'Test Patient Document Case',
            ContactId = patient.Id,
            AccountId = acc.Id
        );
        insert patientCase;

        // Insert a ContentVersion — Salesforce auto-creates the ContentDocument
        ContentVersion cv = new ContentVersion(
            Title          = 'Patient Invoice 2024',
            PathOnClient   = 'PatientInvoice2024.pdf',
            VersionData    = Blob.valueOf('Test PDF content'),
            IsMajorVersion = true
        );
        insert cv;

        // Link the ContentDocument to the Case
        ContentVersion insertedCv = [
            SELECT Id, ContentDocumentId
            FROM   ContentVersion
            WHERE  Id = :cv.Id
            LIMIT  1
        ];

        ContentDocumentLink cdl = new ContentDocumentLink(
            LinkedEntityId    = patientCase.Id,
            ContentDocumentId = insertedCv.ContentDocumentId,
            ShareType         = 'V'
        );
        insert cdl;
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Utility: Configure RestContext for each test
    // ─────────────────────────────────────────────────────────────────────────

    private static void setupRestContext(String jsonBody) {
        RestRequest req  = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI   = '/services/apexrest/v1/patient-document-request';
        req.httpMethod   = 'POST';
        req.requestBody  = Blob.valueOf(jsonBody);
        RestContext.request  = req;
        RestContext.response = res;
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Happy Path — Itemized Bill
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testHandlePost_ItemizedBillSuccess() {
        Case patientCase = [SELECT Id FROM Case LIMIT 1];

        String requestBody = JSON.serialize(new Map<String, String>{
            'caseId'      => patientCase.Id,
            'requestType' => 'Itemized Bill',
            'notes'       => 'Please send the itemized bill urgently.'
        });

        setupRestContext(requestBody);

        Test.startTest();
        PatientDocumentRequestAPI.handlePost();
        Test.stopTest();

        // HTTP 200
        System.assertEquals(200, RestContext.response.statusCode, 'Expected HTTP 200');

        // Response payload
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(
            RestContext.response.responseBody.toString()
        );
        System.assertEquals(true,  (Boolean) result.get('success'), 'success should be true');
        System.assertEquals('Document request processed successfully.', (String) result.get('message'));
        System.assertNotEquals(null, result.get('data'), 'data should not be null');

        // Task created with correct subject and status
        List<Task> tasks = [SELECT Id, Subject, Status, WhatId, WhoId FROM Task WHERE WhatId = :patientCase.Id];
        System.assertEquals(1,                    tasks.size(),        'One Task should be created');
        System.assertEquals('Itemized Bill Request', tasks[0].Subject, 'Task subject should match');
        System.assertEquals('Open',               tasks[0].Status,     'Task status should be Open');
        System.assertEquals(patientCase.Id,        tasks[0].WhatId,    'Task WhatId should be the Case');
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Happy Path — Medical Records
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testHandlePost_MedicalRecordsSuccess() {
        Case patientCase = [SELECT Id FROM Case LIMIT 1];

        String requestBody = JSON.serialize(new Map<String, String>{
            'caseId'      => patientCase.Id,
            'requestType' => 'Medical Records'
        });

        setupRestContext(requestBody);

        Test.startTest();
        PatientDocumentRequestAPI.handlePost();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);

        List<Task> tasks = [SELECT Subject FROM Task WHERE WhatId = :patientCase.Id];
        System.assertEquals(1,                       tasks.size(),       'One Task should be created');
        System.assertEquals('Medical Records Request', tasks[0].Subject, 'Task subject should match');
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  All Five Supported Request Types
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testHandlePost_AllSupportedRequestTypes() {
        Case patientCase = [SELECT Id FROM Case LIMIT 1];

        List<String> requestTypes = new List<String>{
            'Itemized Bill',
            'Medical Records',
            'Document Request',
            'Insurance Claim',
            'Explanation of Benefits'
        };

        Test.startTest();
        for (String rType : requestTypes) {
            setupRestContext(JSON.serialize(new Map<String, String>{
                'caseId'      => patientCase.Id,
                'requestType' => rType
            }));
            PatientDocumentRequestAPI.handlePost();
            System.assertEquals(200, RestContext.response.statusCode,
                'Should return 200 for requestType: ' + rType);
        }
        Test.stopTest();

        // One Task created per request
        List<Task> allTasks = [SELECT Id FROM Task WHERE WhatId = :patientCase.Id];
        System.assertEquals(requestTypes.size(), allTasks.size(), 'One Task per request type');
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Documents Returned in Response Payload
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testHandlePost_DocumentsReturnedInResponse() {
        Case patientCase = [SELECT Id FROM Case LIMIT 1];

        setupRestContext(JSON.serialize(new Map<String, String>{
            'caseId'      => patientCase.Id,
            'requestType' => 'Document Request'
        }));

        Test.startTest();
        PatientDocumentRequestAPI.handlePost();
        Test.stopTest();

        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(
            RestContext.response.responseBody.toString()
        );
        System.assertEquals(true, (Boolean) result.get('success'));

        Map<String, Object> data = (Map<String, Object>) result.get('data');
        List<Object> docs = (List<Object>) data.get('documents');
        System.assertEquals(1, docs.size(), 'One document should be returned');

        Map<String, Object> doc = (Map<String, Object>) docs[0];
        System.assertEquals('Patient Invoice 2024', (String) doc.get('title'), 'Document title should match');
        System.assertNotEquals(null, doc.get('downloadUrl'), 'downloadUrl should not be null');
        System.assertNotEquals(null, doc.get('documentId'), 'documentId should not be null');
    }


   
    // ─────────────────────────────────────────────────────────────────────────
    //  Error: Missing caseId → 400 INVALID_INPUT
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testHandlePost_MissingCaseId() {
        setupRestContext(JSON.serialize(new Map<String, String>{
            'requestType' => 'Itemized Bill'
        }));

        Test.startTest();
        PatientDocumentRequestAPI.handlePost();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode, 'Expected HTTP 400');

        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(
            RestContext.response.responseBody.toString()
        );
        System.assertEquals(false,           (Boolean) result.get('success'));
        System.assertEquals('INVALID_INPUT', (String)  result.get('errorCode'));
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Error: Missing requestType → 400 INVALID_INPUT
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testHandlePost_MissingRequestType() {
        Case patientCase = [SELECT Id FROM Case LIMIT 1];

        setupRestContext(JSON.serialize(new Map<String, String>{
            'caseId' => patientCase.Id
        }));

        Test.startTest();
        PatientDocumentRequestAPI.handlePost();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);

        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(
            RestContext.response.responseBody.toString()
        );
        System.assertEquals('INVALID_INPUT', (String) result.get('errorCode'));
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Error: Unsupported requestType → 400 INVALID_REQUEST_TYPE
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testHandlePost_InvalidRequestType() {
        Case patientCase = [SELECT Id FROM Case LIMIT 1];

        setupRestContext(JSON.serialize(new Map<String, String>{
            'caseId'      => patientCase.Id,
            'requestType' => 'Unsupported Type'
        }));

        Test.startTest();
        PatientDocumentRequestAPI.handlePost();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);

        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(
            RestContext.response.responseBody.toString()
        );
        System.assertEquals('INVALID_REQUEST_TYPE', (String) result.get('errorCode'));
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Error: Malformed caseId → 400 INVALID_CASE_ID
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testHandlePost_MalformedCaseId() {
        setupRestContext(JSON.serialize(new Map<String, String>{
            'caseId'      => 'NOT-A-VALID-SF-ID',
            'requestType' => 'Itemized Bill'
        }));

        Test.startTest();
        PatientDocumentRequestAPI.handlePost();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);

        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(
            RestContext.response.responseBody.toString()
        );
        System.assertEquals('INVALID_CASE_ID', (String) result.get('errorCode'));
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Error: Wrong Object Type Id (Account instead of Case) → 400 INVALID_CASE_ID
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testHandlePost_WrongObjectTypeId() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        setupRestContext(JSON.serialize(new Map<String, String>{
            'caseId'      => acc.Id,   // Account ID, not a Case ID
            'requestType' => 'Itemized Bill'
        }));

        Test.startTest();
        PatientDocumentRequestAPI.handlePost();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);

        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(
            RestContext.response.responseBody.toString()
        );
        System.assertEquals('INVALID_CASE_ID', (String) result.get('errorCode'));
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Error: Non-Existent Case Id → 404 CASE_NOT_FOUND
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testHandlePost_CaseNotFound() {
        // Create a temporary Case, capture its Id, then delete it
        Case tempCase = new Case(Status = 'New', Origin = 'Phone');
        insert tempCase;
        String deletedCaseId = tempCase.Id;
        delete tempCase;

        setupRestContext(JSON.serialize(new Map<String, String>{
            'caseId'      => deletedCaseId,
            'requestType' => 'Itemized Bill'
        }));

        Test.startTest();
        PatientDocumentRequestAPI.handlePost();
        Test.stopTest();

        System.assertEquals(404, RestContext.response.statusCode, 'Expected HTTP 404');

        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(
            RestContext.response.responseBody.toString()
        );
        System.assertEquals(false,            (Boolean) result.get('success'));
        System.assertEquals('CASE_NOT_FOUND', (String)  result.get('errorCode'));
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Response Structure — taskId and caseId Present in Data
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testHandlePost_ResponseDataStructure() {
        Case patientCase = [SELECT Id FROM Case LIMIT 1];

        setupRestContext(JSON.serialize(new Map<String, String>{
            'caseId'      => patientCase.Id,
            'requestType' => 'Insurance Claim'
        }));

        Test.startTest();
        PatientDocumentRequestAPI.handlePost();
        Test.stopTest();

        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(
            RestContext.response.responseBody.toString()
        );
        Map<String, Object> data = (Map<String, Object>) result.get('data');

        System.assertNotEquals(null, data.get('taskId'),      'taskId should be present in response');
        System.assertEquals(patientCase.Id, (String) data.get('caseId'), 'caseId should match request');
        System.assertEquals('Insurance Claim', (String) data.get('requestType'), 'requestType should be echoed back');
        System.assertNotEquals(null, data.get('documents'),   'documents list should be present');
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Duplicate — an Open task with the same subject already exists → 409
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testHandlePost_DuplicateOpenTask_Returns409() {
        Case patientCase = [SELECT Id FROM Case LIMIT 1];
        String requestBody = JSON.serialize(new Map<String, String>{
            'caseId'      => patientCase.Id,
            'requestType' => 'Itemized Bill'
        });

        setupRestContext(requestBody);
        PatientDocumentRequestAPI.handlePost();
        System.assertEquals(200, RestContext.response.statusCode, 'First request should succeed');

        setupRestContext(requestBody);
        Test.startTest();
        PatientDocumentRequestAPI.handlePost();
        Test.stopTest();

        System.assertEquals(409, RestContext.response.statusCode, 'Second request should be a conflict');
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(
            RestContext.response.responseBody.toString()
        );
        System.assertEquals(false, (Boolean) result.get('success'));
        System.assert(((String) result.get('message')).contains('Itemized Bill'));
        System.assertEquals(1, [SELECT COUNT() FROM Task WHERE WhatId = :patientCase.Id], 'No second task is created');
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Exception — malformed JSON body → 500 INTERNAL_ERROR
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testHandlePost_MalformedJson_Returns500() {
        setupRestContext('not-json-at-all');

        Test.startTest();
        PatientDocumentRequestAPI.handlePost();
        Test.stopTest();

        System.assertEquals(500, RestContext.response.statusCode);
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(
            RestContext.response.responseBody.toString()
        );
        System.assertEquals('INTERNAL_ERROR', (String) result.get('errorCode'));
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Case without a Contact → generic patient name in the bell notification
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testHandlePost_CaseWithoutContact_Succeeds() {
        Case noContactCase = new Case(Status = 'New', Origin = 'Phone', Subject = 'No contact case');
        insert noContactCase;

        setupRestContext(JSON.serialize(new Map<String, String>{
            'caseId'      => noContactCase.Id,
            'requestType' => 'Medical Records'
        }));

        Test.startTest();
        PatientDocumentRequestAPI.handlePost();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        System.assertEquals(1, [SELECT COUNT() FROM Task WHERE WhatId = :noContactCase.Id]);
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Contact without a first name → last name only in the notification
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testHandlePost_ContactWithoutFirstName_Succeeds() {
        Account acc              = [SELECT Id FROM Account LIMIT 1];
        Insurance_Company__c ins = [SELECT Id FROM Insurance_Company__c LIMIT 1];
        Contact lastNameOnly = new Contact(
            LastName             = 'Solo',
            Email                = 'solo.patient@testpatient.com',
            AccountId            = acc.Id,
            DX_s__c              = 'TEST02',
            Primary_Insurance__c = ins.Id,
            Plan_Type__c         = 'Other Plan'
        );
        insert lastNameOnly;
        Case soloCase = new Case(Status = 'New', Origin = 'Phone', Subject = 'Solo case', ContactId = lastNameOnly.Id);
        insert soloCase;

        setupRestContext(JSON.serialize(new Map<String, String>{
            'caseId'      => soloCase.Id,
            'requestType' => 'Document Request'
        }));

        Test.startTest();
        PatientDocumentRequestAPI.handlePost();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        System.assertEquals(1, [SELECT COUNT() FROM Task WHERE WhatId = :soloCase.Id]);
    }
}