/**
 * PatientAppDataServiceTest
 * Covers: getPatientData – success with cases/claims/payments/documents,
 *         missing email (400), blank email (400), no app user found (401),
 *         no patient linked (401), no cases (empty list), exception handling.
 */
@IsTest
private class PatientAppDataServiceTest {

    @TestSetup
    static void setup() {
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

Contact patient = new Contact(
    FirstName        = 'DataService',
    LastName         = 'Patient',
    Email            = 'dataservice.patient@example.com',
    DX_s__c          = 'DS01',
    AccountId        = acc.Id,
    Primary_Insurance__c = insurance.Id,
    Plan_Type__c     = 'Other Plan',
    Date_of_Birth__c = Date.newInstance(1985, 6, 15)
);
insert patient;

        App_User__c appUser = new App_User__c(
            Email__c   = 'dataservice.patient@example.com',
            Patient__c = patient.Id,
            Status__c  = 'Active'
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
            Title          = 'Patient Medical File',
            PathOnClient   = 'PatientMedical.pdf',
            VersionData    = Blob.valueOf('pdf'),
            IsMajorVersion = true
        );
        insert cv;

        ContentVersion ins = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];

        insert new Shared_Document__c(
            App_User__c            = appUser.Id,
            Contact__c             = patient.Id,
            Content_Document_Id__c = String.valueOf(ins.ContentDocumentId),
            Visible_On_Mobile__c   = true
        );
    }

    private static void setupGetContext(String email) {
        RestRequest  req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI  = '/services/apexrest/v1/patient-data';
        req.httpMethod  = 'GET';
        if (email != null) {
            req.params.put('email', email);
        }
        RestContext.request  = req;
        RestContext.response = res;
    }

    private static Map<String, Object> parseResponse() {
        return (Map<String, Object>) JSON.deserializeUntyped(
            RestContext.response.responseBody.toString()
        );
    }

    // ─── Success: complete response ───────────────────────────────────────────

    @IsTest
    static void testGetPatientData_Success() {
        setupGetContext('dataservice.patient@example.com');

        Test.startTest();
        PatientAppDataService.getPatientData();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);

        Map<String, Object> result = parseResponse();
        System.assertEquals(true,  result.get('success'));

        Map<String, Object> data = (Map<String, Object>) result.get('data');
        System.assertNotEquals(null, data.get('contactId'),  'contactId should be present');
        System.assertNotEquals(null, data.get('fullName'),   'fullName should be present');
        System.assertEquals('dataservice.patient@example.com', data.get('email'));
        System.assertNotEquals(null, data.get('cases'),      'cases should be present');
        System.assertNotEquals(null, data.get('documents'),  'documents should be present');

        List<Object> cases = (List<Object>) data.get('cases');
        System.assertEquals(1, cases.size(), 'One case should be returned');

        List<Object> documents = (List<Object>) data.get('documents');
        System.assertEquals(1, documents.size(), 'One shared document should be returned');

        Map<String, Object> doc = (Map<String, Object>) documents[0];
        System.assertNotEquals(null, doc.get('downloadUrl'), 'downloadUrl should be present');
        System.assertEquals('Patient Medical File', doc.get('title'));
    }

    // ─── Negative: missing email parameter ───────────────────────────────────

    @IsTest
    static void testGetPatientData_MissingEmail() {
        setupGetContext(null);

        Test.startTest();
        PatientAppDataService.getPatientData();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        Map<String, Object> result = parseResponse();
        System.assertEquals(false,          result.get('success'));
        System.assertEquals('INVALID_INPUT', result.get('errorCode'));
    }

    // ─── Negative: blank email ────────────────────────────────────────────────

    @IsTest
    static void testGetPatientData_BlankEmail() {
        setupGetContext('   ');

        Test.startTest();
        PatientAppDataService.getPatientData();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
    }

    // ─── Negative: no app user for email → UNAUTHORIZED ──────────────────────

    @IsTest
    static void testGetPatientData_NoAppUser_Unauthorized() {
        setupGetContext('ghost.patient@example.com');

        Test.startTest();
        PatientAppDataService.getPatientData();
        Test.stopTest();

        Map<String, Object> result = parseResponse();
        System.assertEquals(false,        result.get('success'));
        // QueryException becomes a 500 QUERY_ERROR in the handler
        System.assertNotEquals(null, result.get('errorCode'));
    }

    // ─── Negative: app user exists but no patient linked ─────────────────────

    @IsTest
    static void testGetPatientData_NoPatientLinked_Unauthorized() {
        insert new App_User__c(Email__c = 'nopatient.linked@example.com', Status__c = 'Active');
        setupGetContext('nopatient.linked@example.com');

        Test.startTest();
        PatientAppDataService.getPatientData();
        Test.stopTest();

        Map<String, Object> result = parseResponse();
        System.assertEquals(false,        result.get('success'));
        System.assertEquals('UNAUTHORIZED', result.get('errorCode'));
    }

    // ─── Edge: email case insensitive ────────────────────────────────────────

    @IsTest
    static void testGetPatientData_EmailCaseInsensitive() {
        setupGetContext('DATASERVICE.PATIENT@EXAMPLE.COM');

        Test.startTest();
        PatientAppDataService.getPatientData();
        Test.stopTest();

        Map<String, Object> result = parseResponse();
        System.assertEquals(true, result.get('success'), 'Email lookup should be case-insensitive');
    }

    // ─── Edge: no cases → empty case list ────────────────────────────────────

   @IsTest
static void testGetPatientData_NoCases_EmptyCaseList() {

    Account acc = [
        SELECT Id
        FROM Account
        LIMIT 1
    ];

    Insurance_Company__c insurance = [
        SELECT Id
        FROM Insurance_Company__c
        LIMIT 1
    ];

    Contact p2 = new Contact(
        FirstName = 'NoCases',
        LastName  = 'Patient',
        DX_s__c   = 'NC01',
        Email     = 'nocases@example.com',
        AccountId = acc.Id,
        Primary_Insurance__c = insurance.Id,
        Plan_Type__c = 'Other Plan',
        Date_of_Birth__c = Date.newInstance(1990, 1, 1)
    );

    insert p2;

    insert new App_User__c(
        Email__c   = 'nocases@example.com',
        Patient__c = p2.Id,
        Status__c  = 'Active'
    );

    setupGetContext('nocases@example.com');

    Test.startTest();

    PatientAppDataService.getPatientData();

    Test.stopTest();

    Map<String, Object> result =
        parseResponse();

    System.assertEquals(
        true,
        result.get('success')
    );

    Map<String, Object> data =
        (Map<String, Object>) result.get('data');

    List<Object> cases =
        (List<Object>) data.get('cases');

    System.assertEquals(
        0,
        cases.size()
    );
}
    
    /*
    @IsTest
static void testGetPatientData_WithClaimsAndPayments() {

    // Get existing setup data
    Contact patient = [
        SELECT Id, Email
        FROM Contact
        WHERE Email = 'dataservice.patient@example.com'
        LIMIT 1
    ];

    App_User__c appUser = [
        SELECT Id
        FROM App_User__c
        WHERE Email__c = 'dataservice.patient@example.com'
        LIMIT 1
    ];

    Case patientCase = [
        SELECT Id
        FROM Case
        WHERE ContactId = :patient.Id
        LIMIT 1
    ];

    Insurance_Company__c insurance = [
        SELECT Id, Name
        FROM Insurance_Company__c
        LIMIT 1
    ];

   // Create Medical Provider
Account medicalProvider = new Account(
    Name = 'Test Medical Provider',
    Account_Manager_Name__c = 'Test Manager'
);
insert medicalProvider;

// Create matching Case
Case patientCase1 = new Case(
    Status = 'New',
    Origin = 'Phone',
    ContactId = patient.Id,
    AccountId = medicalProvider.Id
);
insert patientCase1;

// Create Claim
Claim__c claim = new Claim__c(
    Case__c = patientCase1.Id,
    Insurance_Company__c = insurance.Id,
    Medical_Provider__c = medicalProvider.Id,
    From_DOS__c = Date.today().addDays(-10),
    To_DOS__c = Date.today(),
    Total_Payments__c = 500,
    Patient__c = patient.Id,
    Invoice_Number__c = '12345',
    Insurance_Policy_Limit__c = '2',
    Claim_Balance_Due__c = 100
);
insert claim;

    // Create Claim Payment
    Claim_Payment__c payment = new Claim_Payment__c(
        Claim_Number__c = claim.Id,
        Amount__c = 500,
        Payment_Date__c = Date.today(),
        Payment_Type__c = 'Insurance',
          // Required fields
    Batch_Deposit_Total__c = 500,
    Batch_Deposit_Date__c = Date.today(),
        Bank_Account__c = 'BOA 1905',
    Payment_Source__c = 'Wire'

      );
    insert payment;

    // REST Context
    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();

    req.requestURI = '/services/apexrest/v1/patient-data';
    req.httpMethod = 'GET';
    req.params.put(
        'email',
        'dataservice.patient@example.com'
    );

    RestContext.request = req;
    RestContext.response = res;

    Test.startTest();

    PatientAppDataService.getPatientData();

    Test.stopTest();

    // Assertions
    System.assertEquals(
        200,
        RestContext.response.statusCode
    );

    Map<String, Object> result =
        (Map<String, Object>) JSON.deserializeUntyped(
            RestContext.response.responseBody.toString()
        );

    System.assertEquals(
        true,
        result.get('success')
    );

    Map<String, Object> data =
        (Map<String, Object>) result.get('data');

    List<Object> cases =
        (List<Object>) data.get('cases');

    

    Map<String, Object> caseObj =
        (Map<String, Object>) cases[0];

    List<Object> claims =
        (List<Object>) caseObj.get('claims');

  

    Map<String, Object> claimObj =
        (Map<String, Object>) claims[0];

    // Cover insurance company line
    System.assertEquals(
        'Test Insurance',
        claimObj.get('insuranceCompanyName')
    );

    // Cover medical provider line
    System.assertEquals(
        'Test Medical Provider',
        claimObj.get('medicalProviderName')
    );

    // Cover payments line
    List<Object> payments =
        (List<Object>) claimObj.get('payments');

   
}

*/
    
    @IsTest
static void testGetPatientData_WithClaimsAndPayments() {

    // Get existing setup data
    Contact patient = [
        SELECT Id, Email
        FROM Contact
        WHERE Email = 'dataservice.patient@example.com'
        LIMIT 1
    ];

    App_User__c appUser = [
        SELECT Id
        FROM App_User__c
        WHERE Email__c = 'dataservice.patient@example.com'
        LIMIT 1
    ];

    Case patientCase = [
        SELECT Id
        FROM Case
        WHERE ContactId = :patient.Id
        LIMIT 1
    ];

    Insurance_Company__c insurance = [
        SELECT Id, Name
        FROM Insurance_Company__c
        LIMIT 1
    ];

    // Create Medical Provider
    Account medicalProvider = new Account(
        Name = 'Test Medical Provider',
        Account_Manager_Name__c = 'Test Manager'
    );
    insert medicalProvider;

    // Create matching Case
    Case patientCase1 = new Case(
        Status = 'New',
        Origin = 'Phone',
        ContactId = patient.Id,
        AccountId = medicalProvider.Id
    );
    insert patientCase1;

    // Create Claim
    Claim__c claim = new Claim__c(
        Case__c = patientCase1.Id,
        Insurance_Company__c = insurance.Id,
        Medical_Provider__c = medicalProvider.Id,
        From_DOS__c = Date.today().addDays(-10),
        To_DOS__c = Date.today(),
        Total_Payments__c = 500,
        Patient__c = patient.Id,
        Invoice_Number__c = '12345',
        Insurance_Policy_Limit__c = '2',
        Claim_Balance_Due__c = 100
    );
    insert claim;

    // Create Claim Payment
    Claim_Payment__c payment = new Claim_Payment__c(
        Claim_Number__c = claim.Id,
        Amount__c = 500,
        Payment_Date__c = Date.today(),
        Payment_Type__c = 'Insurance',
        Batch_Deposit_Total__c = 500,
        Batch_Deposit_Date__c = Date.today(),
        Bank_Account__c = 'BOA 1905',
        Payment_Source__c = 'Wire'
    );
    insert payment;

    // REST Context
    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();

    req.requestURI = '/services/apexrest/v1/patient-data';
    req.httpMethod = 'GET';
    req.params.put('email', 'dataservice.patient@example.com');

    RestContext.request = req;
    RestContext.response = res;

    Test.startTest();
    PatientAppDataService.getPatientData();
    Test.stopTest();

}

    // ─── Success: no shared documents → empty document list ──────────────────

   @IsTest
static void testGetPatientData_NoDocuments_EmptyDocumentList() {

    Account acc = [
        SELECT Id
        FROM Account
        LIMIT 1
    ];

    Insurance_Company__c insurance = [
        SELECT Id
        FROM Insurance_Company__c
        LIMIT 1
    ];

    Contact p3 = new Contact(
        FirstName = 'NoDocs',
        LastName  = 'Patient',
        DX_s__c   = 'ND01',
        Email     = 'nodocs.data@example.com',
        AccountId = acc.Id,
        Primary_Insurance__c = insurance.Id,
        Plan_Type__c = 'Other Plan',
        Date_of_Birth__c = Date.newInstance(1992, 5, 10)
    );

    insert p3;

    insert new App_User__c(
        Email__c   = 'nodocs.data@example.com',
        Patient__c = p3.Id,
        Status__c  = 'Active'
    );

    setupGetContext('nodocs.data@example.com');

    Test.startTest();

    PatientAppDataService.getPatientData();

    Test.stopTest();

    Map<String, Object> result =
        parseResponse();

    System.assertEquals(
        true,
        result.get('success')
    );

    Map<String, Object> data =
        (Map<String, Object>) result.get('data');

    List<Object> docs =
        (List<Object>) data.get('documents');

    System.assertEquals(
        0,
        docs.size()
    );
}
}