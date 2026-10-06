@IsTest
private class ClaimNotificationHandlerTest {

    @TestSetup
    static void setup() {

        Account acc = new Account(
            Name='Test Provider',
            Account_Manager_Name__c='Manager'
        );
        insert acc;

        Insurance_Company__c ins = new Insurance_Company__c(
            Name='Insurance',
            Eligibility_Coverage_Phone__c='111',
            Pre_Cert_Auth_Phone__c='111'
        );
        insert ins;

        Contact con = new Contact(
            LastName='Patient',
            AccountId=acc.Id,
            Primary_Insurance__c=ins.Id,
            Plan_Type__c='Other Plan',
            DX_s__c='DX',
            Email = 'test@gmail.com',
            Account_Status__c='Verification work in process'
        );
        insert con;

        Case cs = new Case(
            Status='New',
            Origin='Phone',
            Subject='Claim Case',
            ContactId=con.Id
        );
        insert cs;
    }

    private static Claim__c createClaim() {

        Account acc = [SELECT Id FROM Account LIMIT 1];
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        Insurance_Company__c ins = [SELECT Id FROM Insurance_Company__c LIMIT 1];
        Case cs = [SELECT Id FROM Case LIMIT 1];

        Claim__c c = new Claim__c(
            Date_Received__c=System.today(),
            From_DOS__c=System.today(),
            To_DOS__c=System.today(),
            Pending_Status__c='Write-Off',
            Claim_Rate__c=10,
            Medical_Provider__c=acc.Id,
            Patient__c=con.Id,
            Facility_Charges__c=100,
            Professional_Charges__c=100,
            Insurance_Company__c=ins.Id,
            Invoice_Number__c='INV-1234',
            Insurance_Policy_Limit__c='N/A',
            Case__c=cs.Id
        );

        return c;
    }

    @IsTest
    static void testHandleAfterInsert() {

        Claim__c claim = createClaim();

        Test.startTest();
        insert claim;
        Test.stopTest();

        System.assertNotEquals(null, claim.Id);
    }

    @IsTest
    static void testClaimWithoutCase() {

        Account acc = [SELECT Id FROM Account LIMIT 1];
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        Insurance_Company__c ins = [SELECT Id FROM Insurance_Company__c LIMIT 1];

        Claim__c claim = new Claim__c(
            Date_Received__c=System.today(),
            From_DOS__c=System.today(),
            To_DOS__c=System.today(),
            Pending_Status__c='Write-Off',
            Claim_Rate__c=10,
            Medical_Provider__c=acc.Id,
            Patient__c=con.Id,
            Facility_Charges__c=100,
            Professional_Charges__c=100,
            Insurance_Company__c=ins.Id,
            Invoice_Number__c='INV-NoCase',
            Insurance_Policy_Limit__c='N/A'
        );

        Test.startTest();
        insert claim;
        Test.stopTest();

        System.assertNotEquals(null, claim.Id);
    }


    // ─── Helpers for direct handler calls (no DML on Claim__c) ───────────────

    private static Id fakeClaimId() {
        return Id.valueOf(Claim__c.SObjectType.getDescribe().getKeyPrefix() + '000000000001');
    }

    private static Claim__c memClaim(Id caseId, String status, Decimal payments, Decimal balance) {
        return new Claim__c(
            Id                   = fakeClaimId(),
            Case__c              = caseId,
            Pending_Status__c    = status,
            Total_Payments__c    = payments,
            Claim_Balance_Due__c = balance
        );
    }

    // The patient's App User: dispatch only persists notifications for known App Users
    private static Id createAppUserForPatient() {
        App_User__c appUser = new App_User__c(Name = 'Claim Patient', Email__c = 'test@gmail.com');
        insert appUser;
        NotificationService.processedKeys.clear();
        return appUser.Id;
    }

    private static String latestNotificationBody(Id appUserId) {
        List<App_Notification__c> notifs = [
            SELECT Body__c FROM App_Notification__c WHERE App_User__c = :appUserId
        ];
        System.assertEquals(1, notifs.size(), 'One notification expected');
        return notifs[0].Body__c;
    }

    private static void runUpdate(Claim__c newClaim, Claim__c oldClaim) {
        Map<Id, Claim__c> oldMap = new Map<Id, Claim__c>();
        if (oldClaim != null) {
            oldMap.put(oldClaim.Id, oldClaim);
        }
        Test.startTest();
        ClaimNotificationHandler.handleAfterUpdate(new List<Claim__c>{ newClaim }, oldMap);
        Test.stopTest();
    }

    // ─── Insert: new claim message ───────────────────────────────────────────

    @IsTest
    static void testHandleAfterInsert_NewClaimMessage() {
        Id appUserId = createAppUserForPatient();
        Case cs = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        ClaimNotificationHandler.handleAfterInsert(new List<Claim__c>{ memClaim(cs.Id, 'Open', 0, 100) });
        Test.stopTest();

        System.assertEquals('A new claim has been added to your account.', latestNotificationBody(appUserId));
    }

    // ─── Update: status change ───────────────────────────────────────────────

    @IsTest
    static void testHandleAfterUpdate_StatusChanged() {
        Id appUserId = createAppUserForPatient();
        Case cs = [SELECT Id FROM Case LIMIT 1];

        runUpdate(memClaim(cs.Id, 'Paid', 10, 50), memClaim(cs.Id, 'Pending', 10, 50));

        System.assertEquals('Your claim status has been updated to Paid.', latestNotificationBody(appUserId));
    }

    // ─── Update: balance change ──────────────────────────────────────────────

    @IsTest
    static void testHandleAfterUpdate_BalanceChanged() {
        Id appUserId = createAppUserForPatient();
        Case cs = [SELECT Id FROM Case LIMIT 1];

        runUpdate(memClaim(cs.Id, 'Open', 10, 50), memClaim(cs.Id, 'Open', 10, 80));

        System.assertEquals('Your claim balance has been updated. Balance due: $50.00.', latestNotificationBody(appUserId));
    }

    // ─── Update: balance cleared to null shows $0.00 ─────────────────────────

    @IsTest
    static void testHandleAfterUpdate_BalanceChangedToNull() {
        Id appUserId = createAppUserForPatient();
        Case cs = [SELECT Id FROM Case LIMIT 1];

        runUpdate(memClaim(cs.Id, 'Open', 10, null), memClaim(cs.Id, 'Open', 10, 80));

        System.assertEquals('Your claim balance has been updated. Balance due: $0.00.', latestNotificationBody(appUserId));
    }

    // ─── Update: payment change ──────────────────────────────────────────────

    @IsTest
    static void testHandleAfterUpdate_PaymentsChanged() {
        Id appUserId = createAppUserForPatient();
        Case cs = [SELECT Id FROM Case LIMIT 1];

        runUpdate(memClaim(cs.Id, 'Open', 20, 50), memClaim(cs.Id, 'Open', 0, 50));

        System.assertEquals('A payment of $20.00 has been applied to your claim.', latestNotificationBody(appUserId));
    }

    // ─── Update: payments cleared to null shows $0.00 ────────────────────────

    @IsTest
    static void testHandleAfterUpdate_PaymentsChangedToNull() {
        Id appUserId = createAppUserForPatient();
        Case cs = [SELECT Id FROM Case LIMIT 1];

        runUpdate(memClaim(cs.Id, 'Open', null, 50), memClaim(cs.Id, 'Open', 20, 50));

        System.assertEquals('A payment of $0.00 has been applied to your claim.', latestNotificationBody(appUserId));
    }

    // ─── Update: status cleared, nothing else changed → generic message ──────

    @IsTest
    static void testHandleAfterUpdate_StatusClearedFallsBackToGenericMessage() {
        Id appUserId = createAppUserForPatient();
        Case cs = [SELECT Id FROM Case LIMIT 1];

        runUpdate(memClaim(cs.Id, null, 10, 50), memClaim(cs.Id, 'Pending', 10, 50));

        System.assertEquals('Your claim information has been updated.', latestNotificationBody(appUserId));
    }

    // ─── Update: claim missing from the old map → generic message ────────────

    @IsTest
    static void testHandleAfterUpdate_ClaimMissingFromOldMap() {
        Id appUserId = createAppUserForPatient();
        Case cs = [SELECT Id FROM Case LIMIT 1];

        runUpdate(memClaim(cs.Id, 'Open', 10, 50), null);

        System.assertEquals('Your claim information has been updated.', latestNotificationBody(appUserId));
    }

    // ─── Update: null old map → treated as a change, "new claim" message ─────

    @IsTest
    static void testHandleAfterUpdate_NullOldMap() {
        Id appUserId = createAppUserForPatient();
        Case cs = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        ClaimNotificationHandler.handleAfterUpdate(new List<Claim__c>{ memClaim(cs.Id, 'Open', 10, 50) }, null);
        Test.stopTest();

        System.assertEquals('A new claim has been added to your account.', latestNotificationBody(appUserId));
    }

    // ─── Update: nothing relevant changed → no notification ──────────────────

    @IsTest
    static void testHandleAfterUpdate_NoRelevantChange_NoNotification() {
        createAppUserForPatient();
        Case cs = [SELECT Id FROM Case LIMIT 1];

        runUpdate(memClaim(cs.Id, 'Open', 10, 50), memClaim(cs.Id, 'Open', 10, 50));

        System.assertEquals(0, [SELECT COUNT() FROM App_Notification__c]);
    }

    // ─── Case whose Contact has no email → skipped ───────────────────────────

    @IsTest
    static void testNotify_CaseWithoutContactEmail_Skipped() {
        createAppUserForPatient();
        Contact noEmail = new Contact(
            LastName             = 'NoEmail',
            AccountId            = [SELECT Id FROM Account LIMIT 1].Id,
            Primary_Insurance__c = [SELECT Id FROM Insurance_Company__c LIMIT 1].Id,
            Plan_Type__c         = 'Other Plan',
            DX_s__c              = 'DX2',
            Account_Status__c    = 'Verification work in process'
        );
        insert noEmail;
        Case noEmailCase = new Case(Status = 'New', Origin = 'Phone', Subject = 'No email', ContactId = noEmail.Id);
        insert noEmailCase;

        Test.startTest();
        ClaimNotificationHandler.handleAfterInsert(new List<Claim__c>{ memClaim(noEmailCase.Id, 'Open', 0, 0) });
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM App_Notification__c]);
    }

    // ─── Exception guards ────────────────────────────────────────────────────

    @IsTest
    static void testHandlers_ExceptionsAreCaught() {
        Test.startTest();
        // null list → NPE in handleAfterUpdate's loop; null element → NPE inside notifyForClaims
        ClaimNotificationHandler.handleAfterUpdate(null, null);
        ClaimNotificationHandler.handleAfterInsert(new List<Claim__c>{ null });
        ClaimNotificationHandler.handleAfterUpdate(new List<Claim__c>{ null }, null);
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM App_Notification__c]);
    }
}