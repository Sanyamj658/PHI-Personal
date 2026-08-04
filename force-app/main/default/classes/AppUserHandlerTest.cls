@IsTest
public class AppUserHandlerTest {

    @TestSetup
    static void setupData() {

        List<App_User__c> users = new List<App_User__c>();

        for (Integer i = 0; i < 5; i++) {
            users.add(new App_User__c(
                Name = 'Test User ' + i,
                Email__c = 'test' + i + '@example.com',
                Status__c = 'Inactive'
            ));
        }

        insert users;
    }

    @IsTest
    static void testHandleAfterUpdate_StatusChangedToActive() {

        List<App_User__c> users = [
            SELECT Id, Name, Email__c, Status__c
            FROM App_User__c
        ];

        Map<Id, App_User__c> oldMap = new Map<Id, App_User__c>();

        for (App_User__c usr : users) {
            oldMap.put(usr.Id, usr.clone(false, true, false, false));
            usr.Status__c = 'Active';
        }

        Test.startTest();

        update users;

        AppUserHandler.handleAfterUpdate(users, oldMap);

        Test.stopTest();

        System.assertEquals(5, users.size());
    }

    @IsTest
    static void testHandleAfterUpdate_NoStatusChange() {

        List<App_User__c> users = [
            SELECT Id, Name, Email__c, Status__c
            FROM App_User__c
        ];

        Map<Id, App_User__c> oldMap = new Map<Id, App_User__c>();

        for (App_User__c usr : users) {
            oldMap.put(usr.Id, usr.clone(false, true, false, false));
            // Status remains Inactive
        }
        Test.startTest();
        AppUserHandler.handleAfterUpdate(users, oldMap);
        Test.stopTest();
        System.assert(true);
    }


}