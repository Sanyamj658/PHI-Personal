@IsTest
private class PatientNotificationsAPITest {

    @TestSetup
    static void setupData() {

        App_User__c user = new App_User__c(
            Name = 'Test User',
            Email__c = 'test@test.com',
            DOB__c = Date.newInstance(1995,1,1)
        );
        insert user;

        List<App_Notification__c> notifications = new List<App_Notification__c>();

        for(Integer i=0;i<3;i++){
            notifications.add(new App_Notification__c(
                App_User__c = user.Id,
                Title__c = 'Title ' + i,
                Body__c = 'Body ' + i,
                Type__c = 'General',
                Is_Read__c = (i==2)
            ));
        }

        insert notifications;
    }

    private static void initializeRestContext() {
        RestContext.request = new RestRequest();
        RestContext.response = new RestResponse();
    }

    @IsTest
    static void testGetNotifications() {

        initializeRestContext();

        RestContext.request.httpMethod = 'GET';
        RestContext.request.requestURI = '/services/apexrest/v1/patient-notifications';

        RestContext.request.addParameter('email','test@test.com');
        RestContext.request.addParameter('dob','1995-01-01');

        Test.startTest();
        PatientNotificationsAPI.getNotifications();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
    }

    @IsTest
    static void testGetUnreadNotifications() {

        initializeRestContext();

        RestContext.request.httpMethod = 'GET';
        RestContext.request.requestURI = '/services/apexrest/v1/patient-notifications';

        RestContext.request.addParameter('email','test@test.com');
        RestContext.request.addParameter('dob','1995-01-01');
        RestContext.request.addParameter('unread_only','true');

        Test.startTest();
        PatientNotificationsAPI.getNotifications();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
    }

    @IsTest
    static void testGetNotificationsMissingParams() {

        initializeRestContext();

        RestContext.request.httpMethod='GET';
        RestContext.request.requestURI='/services/apexrest/v1/patient-notifications';

        Test.startTest();
        PatientNotificationsAPI.getNotifications();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
    }

    @IsTest
    static void testGetUserNotFound() {

        initializeRestContext();

        RestContext.request.httpMethod='GET';
        RestContext.request.requestURI='/services/apexrest/v1/patient-notifications';

        RestContext.request.addParameter('email','nouser@test.com');
        RestContext.request.addParameter('dob','1995-01-01');

        Test.startTest();
        PatientNotificationsAPI.getNotifications();
        Test.stopTest();

        System.assertEquals(404, RestContext.response.statusCode);
    }

    @IsTest
    static void testMarkSelectedNotificationsRead() {

        initializeRestContext();

        List<App_Notification__c> notifications = [
            SELECT Id, Is_Read__c
            FROM App_Notification__c
            WHERE Is_Read__c = false
            LIMIT 2
        ];

        List<String> ids = new List<String>();

        for(App_Notification__c n : notifications){
            ids.add(String.valueOf(n.Id));
        }

        Map<String,Object> body = new Map<String,Object>{
            'ids' => ids
        };

        RestContext.request.httpMethod='POST';
        RestContext.request.requestBody =
            Blob.valueOf(JSON.serialize(body));

        Test.startTest();
        PatientNotificationsAPI.markRead();
        Test.stopTest();

        List<App_Notification__c> updated = [
            SELECT Is_Read__c
            FROM App_Notification__c
            WHERE Id IN :notifications
        ];

        for(App_Notification__c n : updated){
            System.assertEquals(true,n.Is_Read__c);
        }

        System.assertEquals(200, RestContext.response.statusCode);
    }

    @IsTest
    static void testMarkAllNotificationsRead() {

        initializeRestContext();

        Map<String,Object> body = new Map<String,Object>{
            'markAllRead' => true,
            'email' => 'test@test.com',
            'dob' => '1995-01-01'
        };

        RestContext.request.httpMethod='POST';
        RestContext.request.requestBody =
            Blob.valueOf(JSON.serialize(body));

        Test.startTest();
        PatientNotificationsAPI.markRead();
        Test.stopTest();

        Integer unread = [
            SELECT Count()
            FROM App_Notification__c
            WHERE Is_Read__c = false
        ];

        System.assertEquals(0, unread);
        System.assertEquals(200, RestContext.response.statusCode);
    }

    @IsTest
    static void testMarkReadEmptyBody() {

        initializeRestContext();

        RestContext.request.httpMethod='POST';
        RestContext.request.requestBody = Blob.valueOf('{}');

        Test.startTest();
        PatientNotificationsAPI.markRead();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
    }
}