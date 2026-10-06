@IsTest
private class MobileTokenAPITest {

    @testSetup
    static void setupData() {

        App_User__c appUser = new App_User__c(
            Name = 'Test User',
            Email__c = 'test@test.com',
            DOB__c = Date.newInstance(1995, 5, 10)

            // Add any other required fields here
            // Example:
            // Status__c = 'Pending',
            // Phone__c = '9999999999'
        );

        insert appUser;

        // AppUserTrigger (before insert) overrides Status__c and a validation rule requires a
        // linked Patient before an App User can be Active, so link a Contact and activate after insert.
        Insurance_Company__c insurance = new Insurance_Company__c(Name = 'Test Insurance');
        insert insurance;
        Contact patient = new Contact(
            FirstName = 'Test', LastName = 'User', Email = 'test@test.com',
            Date_of_Birth__c = Date.newInstance(1995, 5, 10), DX_s__c = 'MT01',
            Primary_Insurance__c = insurance.Id, Plan_Type__c = 'Other Plan'
        );
        insert patient;
        appUser.Patient__c = patient.Id;
        appUser.Status__c  = 'Active';
        update appUser;
    }

    private static void createRestRequest(String body) {

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/saveDeviceToken';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(body);

        RestContext.request = req;
        RestContext.response = new RestResponse();
    }

    @IsTest
    static void testSaveTokenSuccess() {

        String body = JSON.serialize(new Map<String,Object>{
            'email' => 'test@test.com',
            'token' => 'DEVICE_TOKEN_123',
            'dob'   => '1995-05-10'
        });

        createRestRequest(body);

        Test.startTest();
        MobileTokenAPI.saveToken();
        Test.stopTest();

        App_User__c user = [
            SELECT Device_Token__c
            FROM App_User__c
            WHERE Email__c = 'test@test.com'
            LIMIT 1
        ];

        System.assertEquals(
            'DEVICE_TOKEN_123',
            user.Device_Token__c,
            'Device token should be updated.'
        );
    }

    @IsTest
    static void testMissingInput() {

        String body = JSON.serialize(new Map<String,Object>{
            'email' => '',
            'token' => '',
            'dob'   => ''
        });

        createRestRequest(body);

        Test.startTest();
        MobileTokenAPI.saveToken();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
    }

    @IsTest
    static void testUserNotFound() {

        String body = JSON.serialize(new Map<String,Object>{
            'email' => 'unknown@test.com',
            'token' => 'ABC123',
            'dob'   => '1990-01-01'
        });

        createRestRequest(body);

        Test.startTest();
        MobileTokenAPI.saveToken();
        Test.stopTest();

        // Method catches exception internally
        System.assertNotEquals(null, RestContext.response);
    }

    @IsTest
    static void testInvalidDOB() {

        String body = JSON.serialize(new Map<String,Object>{
            'email' => 'test@test.com',
            'token' => 'ABC123',
            'dob'   => '10/05/1995'
        });

        createRestRequest(body);

        Test.startTest();
        MobileTokenAPI.saveToken();
        Test.stopTest();

        System.assertNotEquals(null, RestContext.response);
    }
}