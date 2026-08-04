@isTest
private class ClaimCollectorInfoControllerTest {

    @isTest
    static void testGetCollectorAndARdays_withMockedHistory() {
        // Required data
        Account acc = new Account(Name = 'Test Account', Account_Manager_Name__c = 'Test Manager');
        insert acc;

        Insurance_Company__c insurance = new Insurance_Company__c(Name = 'Test Insurance');
        insert insurance;

        Contact con = new Contact(
            LastName = 'Test Contact',
            AccountId = acc.Id,
            DX_s__c = 'Test DX',
            Plan_Type__c = 'Other Plan',
            Primary_Insurance__c = insurance.Id
        );
        insert con;

        // valid claim with all required fields
        Claim__c claim = new Claim__c(
            Insurance_Policy_Limit__c = 'none',
            Date_Received__c = Date.today(),
            From_DOS__c = Date.today(),
            To_DOS__c = Date.today(),
            Pending_Status__c = 'Claim in Process',
            Claim_Rate__c = 10,
            Medical_Provider__c = acc.Id,
            Patient__c = con.Id,
            Facility_Charges__c = 1000,
            collector__c = 'A Greenblatt',
            Invoice_Number__c = 'INV001',
            Professional_Charges__c = 500,
            Insurance_Company__c = insurance.Id
        );
        insert claim;
        
        // valid claim with Collector as Admin 
        Claim__c claimWithAdminCollector = new Claim__c(
            Insurance_Policy_Limit__c = 'none',
            Date_Received__c = Date.today(),
            From_DOS__c = Date.today(),
            To_DOS__c = Date.today(),
            Pending_Status__c = 'Claim in Process',
            Claim_Rate__c = 10,
            Medical_Provider__c = acc.Id,
            Patient__c = con.Id,
            Facility_Charges__c = 1000,
            collector__c = 'Admin',
            Invoice_Number__c = 'INV002',
            Professional_Charges__c = 500,
            Insurance_Company__c = insurance.Id
        );
        insert claimWithAdminCollector;

        // Mock history list
        List<Claim__History> mockHistory = new List<Claim__History>();

        Claim__History collectorChange = (Claim__History) JSON.deserialize(
            '{"attributes":{"type":"Claim__History"}, "Field": "Collector__c", "CreatedDate": "' +
            DateTime.now().addDays(-2).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'') + '"}', Claim__History.class);

        Claim__History paymentReceived = (Claim__History) JSON.deserialize(
            '{"attributes":{"type":"Claim__History"}, "Field": "Pending_Status__c", "CreatedDate": "' +
            DateTime.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'') + '"}', Claim__History.class);

        mockHistory.add(paymentReceived);
        mockHistory.add(collectorChange);

        // Inject the mock history into the controller
        ClaimCollectorInfoController.mockHistoryList = mockHistory;

        // Execute and validate
        Test.startTest();
        Map<String, Object> claimWithNonAdminCollectorResult = ClaimCollectorInfoController.getCollectorAndARdays(claim.Id);
        Map<String, Object> claimWithAdminCollectorResult = ClaimCollectorInfoController.getCollectorAndARdays(claimWithAdminCollector.Id);
        Test.stopTest();

       	Assert.isNotNull(claimWithNonAdminCollectorResult);
        Assert.isNull(claimWithAdminCollectorResult.get('daysTaken'));
        Assert.isNull(claimWithAdminCollectorResult.get('latestCollector'));
    }
}