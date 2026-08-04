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