@isTest
public class ProcessClaimSettlementDaysTest {
    
    @testSetup
    static void setup() {
        
        Insurance_Company__c insuranceObject = new Insurance_Company__c();
        insuranceObject.Name = 'TestInsurance';
        insert insuranceObject;
        
        Account accountRecord = new Account();
        accountRecord.Name = 'Test Account';
        accountRecord.Account_Manager_Name__c = 'Test Manager 1';
        insert accountRecord;
        
        Contact contactRecord = new Contact();
        contactRecord.DX_s__c = 'XXXXX';
        contactRecord.FirstName = 'Test';
        contactRecord.LastName = 'Contact';
        contactRecord.Plan_Type__c = 'Other Plan';
        contactRecord.AccountId = accountRecord.Id;
        contactRecord.Primary_Insurance__c = insuranceObject.Id;        
        insert contactRecord;  
        
		Claim__c claimObject = new Claim__c();
        claimObject.Patient__c=contactRecord.id;
        claimObject.Medical_Provider__c=accountRecord.Id;
        claimObject.Insurance_Company__c = insuranceObject.Id;
        claimObject.Invoice_Number__c = 'Test2312';        
        claimObject.Date_Received__c=system.today();
        claimObject.Date_Sent_to_Ins_Co__c = System.today();
        claimObject.From_DOS__c=system.today();
        claimObject.To_DOS__c=system.today();        
        claimObject.Pending_Status__c='Cash On Hold';
        claimObject.Claim_Rate__c=10;
        claimObject.Biller__c = 'Admin';
        claimObject.collector__c = 'Admin';
        claimObject.Insurance_Policy_Limit__c = 'XXXXX';
        claimObject.Projected_Payment_Date__c = System.today() + 1;
        claimObject.Collectability_Percentage__c = 100;    
        insert claimObject;    
        
        Claim__c claimWithoutPayments = new Claim__c();
        claimWithoutPayments.Patient__c=contactRecord.id;
        claimWithoutPayments.Medical_Provider__c=accountRecord.Id;
        claimWithoutPayments.Insurance_Company__c = insuranceObject.Id;
        claimWithoutPayments.Invoice_Number__c = 'Test23127';        
        claimWithoutPayments.Date_Received__c=system.today();
        claimWithoutPayments.Date_Sent_to_Ins_Co__c = System.today();
        claimWithoutPayments.From_DOS__c=system.today();
        claimWithoutPayments.To_DOS__c=system.today();        
        claimWithoutPayments.Pending_Status__c='Payment Received';
        claimWithoutPayments.Claim_Rate__c=10;
        claimWithoutPayments.Biller__c = 'Admin';
        claimWithoutPayments.collector__c = 'Admin';
        claimWithoutPayments.Insurance_Policy_Limit__c = 'XXXXX';
        claimWithoutPayments.Projected_Payment_Date__c = System.today() + 1;
        claimWithoutPayments.Collectability_Percentage__c = 100;    
        insert claimWithoutPayments;    
        
        Claim__c claimWithInvalidStatus = new Claim__c();
        claimWithInvalidStatus.Patient__c=contactRecord.id;
        claimWithInvalidStatus.Medical_Provider__c=accountRecord.Id;
        claimWithInvalidStatus.Insurance_Company__c = insuranceObject.Id;
        claimWithInvalidStatus.Invoice_Number__c = 'Test23129';        
        claimWithInvalidStatus.Date_Received__c=system.today();
        claimWithInvalidStatus.Date_Sent_to_Ins_Co__c = System.today();
        claimWithInvalidStatus.From_DOS__c=system.today();
        claimWithInvalidStatus.To_DOS__c=system.today();        
        claimWithInvalidStatus.Pending_Status__c='Cash On Hold';
        claimWithInvalidStatus.Claim_Rate__c=10;
        claimWithInvalidStatus.Biller__c = 'Admin';
        claimWithInvalidStatus.collector__c = 'Admin';
        claimWithInvalidStatus.Insurance_Policy_Limit__c = 'XXXXX';
        claimWithInvalidStatus.Projected_Payment_Date__c = System.today() + 1;
        claimWithInvalidStatus.Collectability_Percentage__c = 100;    
        insert claimWithInvalidStatus; 
        
        Claim_Payment__c payment = new Claim_Payment__c();
        payment.Claim_Number__c = claimObject.Id;
      	payment.Client_Customer__c = 'Payments';                 
        payment.Who_received_the_money__c = 'Payment Received';  
        payment.Amount__c = 5358.52;                       
        payment.Payment_Date__c = Date.valueOf(Date.today());   
        payment.Paid_to_client__c = 0.00;                       
        payment.Due_to_Client1__c = 4554.74;                   
        payment.Paid_Earn_Fees__c = 803.78;                  
        payment.Show_in_Report__c = false;                      
        payment.Collector__c = 'Danish Qadir';                  
        payment.Batch_Deposit_Total__c = 26083.06;              
        payment.Facility_Fee_For_Invoice__c = 5358.52; 
        payment.Batch_Deposit_Date__c = System.today();
        payment.Payment_Source__c = 'Not Applicable'; 
        payment.Bank_Account__c = 'Not Applicable';
        
        //clone(Boolean preserveId, Boolean isDeepClone, Boolean preserveReadonlyTimestamps, Boolean preserveAutonumber)
        Claim_Payment__c insurancePayment = payment.clone(false, true, false, false);
        insurancePayment.Payment_Type__c = 'Insurance Payment';

        Claim_Payment__c patientPayment = payment.clone(false, true, false, false);
        patientPayment.Payment_Type__c = 'Patient Payment';
        
        Claim_Payment__c courtesyPayment = payment.clone(false, true, false, false);
        patientPayment.Payment_Type__c = 'Courtesy Payment';
        
        insert patientPayment; 
		insert insurancePayment;
        insert courtesyPayment;
	}
    
    @isTest
    public static void claimSettlementDaysBtchClaimWithoutPaymentTest() {
    	Test.startTest();
        Database.executeBatch(new ProcessClaimSettlementDaysBtch(), 5);
        Test.stopTest();
    }
    
    @isTest
    public static void claimSettlementDaysBtchTest() {
        Id insuranceCompanyId = [SELECT Id FROM Insurance_Company__c WHERE Name = 'TestInsurance' LIMIT 1].Id;
        
        Test.startTest();
        Database.executeBatch(new ProcessClaimSettlementDaysBtch(), 5);
        Database.executeBatch(new ProcessClaimSettlementDaysBtch('Insurance_Company__c =\''+insuranceCompanyId+'\''), 5);
        Test.stopTest();
        
        Claim__c updatedClaim = [SELECT Id, DaysInAR__c, Average_Claim_Payment_Settlement_Days__c FROM Claim__c WHERE Invoice_Number__c = 'Test2312' LIMIT 1];
        Assert.areNotEqual(null, updatedClaim.DaysInAR__c, 'DaysInAR__c should be calculated');
        Assert.areEqual(0, updatedClaim.Average_Claim_Payment_Settlement_Days__c, 'Settlement Days should be 0');
    }
    
    @isTest
    public static void claimSettlementDaysHandlerTest() {
        Claim__c claim = [SELECT Id FROM Claim__c WHERE Invoice_Number__c = 'Test2312' LIMIT 1];
        
        Test.startTest();
        ClaimPaymentDaysHandler.updateClaimPaymentDates(new Set<Id>{claim.Id});
        Test.stoptest();
        
        Claim__c updatedClaim = [SELECT Id, DaysInAR__c, Average_Claim_Payment_Settlement_Days__c FROM Claim__c WHERE Invoice_Number__c = 'Test2312' LIMIT 1];
        Assert.areNotEqual(null, updatedClaim.DaysInAR__c, 'DaysInAR__c should be calculated');
        Assert.areEqual(0, updatedClaim.Average_Claim_Payment_Settlement_Days__c, 'Settlement Days should be 0');
    }
    
    @isTest
    public static void claimDeletionTest() {
        Claim__c claim = [SELECT Id FROM Claim__c WHERE Invoice_Number__c = 'Test2312' LIMIT 1];
        List<Claim_Payment__c> claimPayments = [SELECT Id FROM Claim_Payment__c WHERE Claim_Number__c = :claim.Id];

        Test.startTest();
        try {
            DELETE claimPayments;
            DELETE claim;
        } catch (DmlException e) {
            Assert.isTrue(e.getMessage().contains('You are not authorized to delete the claim.'), 'Expected message not found.');
        }
        Test.stopTest();
    }
}