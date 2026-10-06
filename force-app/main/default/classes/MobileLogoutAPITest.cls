@IsTest
private class MobileLogoutAPITest {

    @testSetup
    static void setupData() {
        App_User__c user = new App_User__c(
            Email__c = 'test@example.com',
            DOB__c = Date.newInstance(1995, 5, 15),
            Device_Token__c = 'SampleDeviceToken'
        );
        insert user;

        // AppUserTrigger (before insert) overrides Status__c and a validation rule requires a
        // linked Patient before an App User can be Active, so link a Contact and activate after insert.
        Insurance_Company__c insurance = new Insurance_Company__c(Name = 'Test Insurance');
        insert insurance;
        Contact patient = new Contact(
            FirstName = 'Test', LastName = 'Logout', Email = 'test@example.com',
            Date_of_Birth__c = Date.newInstance(1995, 5, 15), DX_s__c = 'ML01',
            Primary_Insurance__c = insurance.Id, Plan_Type__c = 'Other Plan'
        );
        insert patient;
        user.Patient__c = patient.Id;
        user.Status__c  = 'Active';
        update user;
    }

    @IsTest
    static void testRemoveTokenSuccess() {

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestUri = '/services/apexrest/removeDeviceToken';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(
            '{"email":"test@example.com","dob":"1995-05-15"}'
        );

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        MobileLogoutAPI.removeToken();
        Test.stopTest();

        App_User__c usr = [
            SELECT Device_Token__c
            FROM App_User__c
            WHERE Email__c = 'test@example.com'
            LIMIT 1
        ];

        System.assertEquals(null, usr.Device_Token__c);
    }

    @IsTest
    static void testRemoveTokenMissingInput() {

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestUri = '/services/apexrest/removeDeviceToken';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(
            '{"email":"","dob":""}'
        );

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        MobileLogoutAPI.removeToken();
        Test.stopTest();

        // Method should complete without exception
        System.assert(true);
    }

    @IsTest
    static void testRemoveTokenUserNotFound() {

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestUri = '/services/apexrest/removeDeviceToken';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(
            '{"email":"nouser@example.com","dob":"1995-05-15"}'
        );

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        MobileLogoutAPI.removeToken();
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void testRemoveTokenException() {

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestUri = '/services/apexrest/removeDeviceToken';
        req.httpMethod = 'POST';

        // Invalid date format forces Date.valueOf() to throw exception
        req.requestBody = Blob.valueOf(
            '{"email":"test@example.com","dob":"invalid-date"}'
        );

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        MobileLogoutAPI.removeToken();
        Test.stopTest();

        System.assert(true);
    }
}