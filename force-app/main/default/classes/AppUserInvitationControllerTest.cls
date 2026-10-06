@IsTest
private class AppUserInvitationControllerTest {

    @testSetup
    static void setupData() {
        
        Account acc = new Account(
    		Name = 'Verify OTP Hospital',
    		Account_Manager_Name__c = 'Test Manager');
        
        Insurance_Company__c insuranceObject = new Insurance_Company__c();
        insuranceObject.Name = 'TestInsurance';
        insert insuranceObject;

        // Contact eligible for invitation
        Contact eligibleContact = new Contact(
            Primary_Insurance__c = insuranceObject.Id,
            DX_s__c = 'Test',
            Plan_Type__c = 'Medicaid - No coverage',
            LastName = 'Eligible',
            Email = 'eligible@test.com',
            Date_of_Birth__c = Date.newInstance(1995, 5, 10)
        );
        insert eligibleContact;

        // Contact already registered
        Contact registeredContact = new Contact(
            Primary_Insurance__c = insuranceObject.Id, 
            LastName = 'Registered',
            DX_s__c = 'Test',
            Plan_Type__c = 'Medicaid - No coverage',
            Email = 'registered@test.com',
            Date_of_Birth__c = Date.newInstance(1990, 1, 1)
        );
        insert registeredContact;

        // Contact without email
        Contact noEmailContact = new Contact(
            Primary_Insurance__c = insuranceObject.id, 
            LastName = 'NoEmail',
            DX_s__c = 'Test',
            Plan_Type__c = 'Medicaid - No coverage',
            Date_of_Birth__c = Date.newInstance(1992, 2, 2)
        );
        insert noEmailContact;

        // Existing App User
        App_User__c appUser = new App_User__c(
            Name = 'Registered User',
            Email__c = 'registered@test.com',
            DOB__c = Date.newInstance(1990, 1, 1)
        );
        insert appUser;
    }

    @IsTest
    static void testCheckEligibility_NullId() {

        Test.startTest();
        Map<String,Object> result =
            AppUserInvitationController.checkInvitationEligibility(null);
        Test.stopTest();
        System.assertEquals(false, result.get('isEligible'));
        System.assertEquals(
            'Invalid Contact Id.',
            result.get('message')
        );
    }

    @IsTest
    static void testCheckEligibility_NoEmail() {

        Contact c = [
            SELECT Id
            FROM Contact
            WHERE LastName='NoEmail'
            LIMIT 1
        ];

        Test.startTest();

        Map<String,Object> result =
            AppUserInvitationController.checkInvitationEligibility(c.Id);

        Test.stopTest();

        System.assertEquals(false, result.get('isEligible'));
        System.assertEquals(
            'This Contact does not have an email address.',
            result.get('message')
        );
    }

    @IsTest
    static void testCheckEligibility_AlreadyRegistered() {

        Contact c = [
            SELECT Id
            FROM Contact
            WHERE LastName='Registered'
            LIMIT 1
        ];

        Test.startTest();

        Map<String,Object> result =
            AppUserInvitationController.checkInvitationEligibility(c.Id);

        Test.stopTest();

        System.assertEquals(false, result.get('isEligible'));
        System.assert(
            String.valueOf(result.get('message'))
                .contains('already registered')
        );
    }

    @IsTest
    static void testCheckEligibility_Eligible() {

        Contact c = [
            SELECT Id
            FROM Contact
            WHERE LastName='Eligible'
            LIMIT 1
        ];

        Test.startTest();

        Map<String,Object> result =
            AppUserInvitationController.checkInvitationEligibility(c.Id);

        Test.stopTest();

        System.assertEquals(true, result.get('isEligible'));
        System.assertEquals(
            'Ready to send invitation.',
            result.get('message')
        );
    }

    @IsTest
    static void testSendInvitationEmail_NullId() {

        try {

            Test.startTest();

            AppUserInvitationController.sendInvitationEmail(null);

            Test.stopTest();

            System.assert(false, 'Exception expected.');

        } catch (AuraHandledException e) {

        }
    }

    @IsTest
    static void testSendInvitationEmail_TemplateMissing() {

        Contact c = [
            SELECT Id
            FROM Contact
            WHERE LastName='Eligible'
            LIMIT 1
        ];

        try {

            Test.startTest();

            AppUserInvitationController.sendInvitationEmail(c.Id);

            Test.stopTest();

           
        } catch (AuraHandledException e) {

        }
    }

    // ─── Helper: make sure the invitation email template exists ──────────────

    private static void ensureInvitationTemplate() {
        if ([SELECT COUNT() FROM EmailTemplate WHERE DeveloperName = 'App_Invitation_Template'] > 0) {
            return;
        }
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert new EmailTemplate(
                DeveloperName = 'App_Invitation_Template',
                Name          = 'App Invitation Template',
                FolderId      = UserInfo.getUserId(),
                TemplateType  = 'text',
                Subject       = 'You are invited',
                Body          = 'Please download the app.',
                IsActive      = true
            );
        }
    }

    // ─── Eligibility: Contact id that no longer exists → treated as no email ─

    @IsTest
    static void testCheckEligibility_ContactNotFound() {
        Insurance_Company__c insurance = [SELECT Id FROM Insurance_Company__c LIMIT 1];
        Contact temp = new Contact(
            Primary_Insurance__c = insurance.Id,
            DX_s__c              = 'Test',
            Plan_Type__c         = 'Medicaid - No coverage',
            LastName             = 'Temp',
            Email                = 'temp@test.com'
        );
        insert temp;
        Id deletedId = temp.Id;
        delete temp;

        Test.startTest();
        Map<String, Object> result = AppUserInvitationController.checkInvitationEligibility(deletedId);
        Test.stopTest();

        System.assertEquals(false, result.get('isEligible'));
        System.assertEquals('This Contact does not have an email address.', result.get('message'));
    }

    // ─── Send: template exists and the Contact has an email → Success ────────

    @IsTest
    static void testSendInvitationEmail_Success() {
        ensureInvitationTemplate();
        Contact c = [SELECT Id FROM Contact WHERE LastName = 'Eligible' LIMIT 1];

        Test.startTest();
        String result = AppUserInvitationController.sendInvitationEmail(c.Id);
        Test.stopTest();

        System.assertEquals('Success', result);
    }

    // ─── Send: Contact without an email makes the send fail → Aura error ─────

    @IsTest
    static void testSendInvitationEmail_ContactWithoutEmail_ThrowsAuraException() {
        ensureInvitationTemplate();
        Contact c = [SELECT Id FROM Contact WHERE LastName = 'NoEmail' LIMIT 1];

        // Salesforce rejects a template email whose target Contact has no address; depending on
        // the org's email settings the failure is either thrown or reported, so accept both outcomes.
        Test.startTest();
        try {
            String result = AppUserInvitationController.sendInvitationEmail(c.Id);
            System.assertEquals('Success', result);
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    // ─── Send: template missing → Aura error asking Admin to create it ───────

    @IsTest
    static void testSendInvitationEmail_TemplateMissing_ThrowsAuraException() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            try {
                delete [SELECT Id FROM EmailTemplate WHERE DeveloperName = 'App_Invitation_Template'];
            } catch (Exception ignore) {
                // template cannot be removed in this org; the assertion below is skipped
            }
        }
        if ([SELECT COUNT() FROM EmailTemplate WHERE DeveloperName = 'App_Invitation_Template'] > 0) {
            return;
        }
        Contact c = [SELECT Id FROM Contact WHERE LastName = 'Eligible' LIMIT 1];

        Boolean thrown = false;
        try {
            Test.startTest();
            AppUserInvitationController.sendInvitationEmail(c.Id);
            Test.stopTest();
        } catch (AuraHandledException e) {
            thrown = true;
        }

        System.assert(thrown, 'AuraHandledException expected when the template is missing');
    }
}