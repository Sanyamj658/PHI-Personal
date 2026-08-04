@isTest
public class CaseTriggerHandlerTest {
	
    @testsetup
    public static void setup() {        
        Insurance_Company__c insuranceObject = new Insurance_Company__c();
        insuranceObject.Name = 'TestInsurance';
        insert insuranceObject;
        
        Account accountRecord = new Account();
        accountRecord.Name = 'Test Account';
        accountRecord.Account_Manager_Name__c = 'Test Manager 1';
        insert accountRecord;
        
        Account accountObject = new Account();
        accountObject.name = 'Test Account 2';
        accountObject.Account_Manager_Name__c = 'Test Manager 2';
        insert accountObject;
        
        Contact contactRecord = new Contact();
        contactRecord.DX_s__c = 'XXXXX';
        contactRecord.FirstName = 'Test';
        contactRecord.LastName = 'Contact';
        contactRecord.Plan_Type__c = 'Other Plan';
        contactRecord.AccountId = accountRecord.Id;
        contactRecord.Primary_Insurance__c = insuranceObject.Id;        
        insert contactRecord;  
        
        Contact contactObject = new Contact();
        contactObject.DX_s__c = 'XXXXX';
        contactObject.FirstName = 'Test';
        contactObject.LastName = 'Contact 2';
        contactObject.Plan_Type__c = 'Other Plan';
        contactObject.AccountId = accountObject.Id;       
        contactObject.Primary_Insurance__c = insuranceObject.Id;        
        insert contactObject;
        
        Case caseRecord = new Case();
        caseRecord.Status = 'New';
        caseRecord.origin = 'Phone';
        caseRecord.accountId = accountRecord.Id;
        caseRecord.contactId = contactRecord.Id;        
        insert caseRecord;
        
        Claim__c claimObject = new Claim__c();
        claimObject.Patient__c=contactRecord.id;
        claimObject.Medical_Provider__c=accountRecord.Id;
        claimObject.Insurance_Company__c = insuranceObject.Id;
        claimObject.Invoice_Number__c = 'Test2312';        
        claimObject.Date_Received__c=system.today();
        claimObject.From_DOS__c=system.today();
        claimObject.To_DOS__c=system.today();        
        claimObject.Pending_Status__c='Cash On Hold';
        claimObject.Claim_Rate__c=10;
        claimObject.Biller__c = 'Admin';
        claimObject.collector__c = 'Admin';
        claimObject.Insurance_Policy_Limit__c = 'XXXXX';
        claimObject.Projected_Payment_Date__c = System.today() + 1;
        claimObject.Collectability_Percentage__c = 100;    
        claimObject.case__c = caseRecord.Id;
        insert claimObject; 
    }
    
    @isTest
    public static void testUpdateCaseAccount() { 
        Boolean isUpdateFailed = false;
        List<Account> accountRecord = [SELECT Id FROM Account WHERE Name = 'Test Account 2' LIMIT 1];
        List<Case> caseRecord = [SELECT accountId FROM Case WHERE Status = 'New' AND origin = 'Phone' LIMIT 1];
        
        caseRecord[0].AccountId = accountRecord[0].Id;
        Test.startTest();
        try {
            update caseRecord;
        }
        catch(Exception ex) {
            isUpdateFailed = true;
            Assert.isTrue(ex.getMessage().contains('Related Medical Provider or Patient cannot be updated because this case has associated claims.'));
        }        
        Test.stopTest();
        Assert.isTrue(isUpdateFailed);
    }
    
    @isTest
    public static void testUpdateCaseContact() {
        Boolean isUpdateFailed = false;
    	List<Contact> contactRecord = [SELECT Id FROM Contact WHERE Name = 'Test Contact 2' LIMIT 1];
        List<Case> caseRecord = [SELECT contactId FROM Case WHERE Status = 'New' AND origin = 'Phone' LIMIT 1];
        
        caseRecord[0].contactId = contactRecord[0].Id;
        Test.startTest();
        try {
            update caseRecord;
        }
        catch(Exception ex) {
            isUpdateFailed = true;
            Assert.isTrue(ex.getMessage().contains('Related Medical Provider or Patient cannot be updated because this case has associated claims.'));
        }        
        Test.stopTest();
        Assert.isTrue(isUpdateFailed);
    }
    
    @isTest
    public static void testDeleteCaseWithExistingClaim() {
        Boolean isDeleteFailed = false;
        Test.startTest();
        try {
        	DELETE [SELECT Id FROM Case WHERE Status = 'New' AND origin = 'Phone' LIMIT 1];   
        }
        catch(Exception ex) {
            isDeleteFailed = true;
            Assert.isTrue(ex.getMessage().contains('The case cannot be deleted because it has associated claims.'));
        }        
        Test.stopTest();
        Assert.isTrue(isDeleteFailed);
    }  
    
    @isTest
    public static void testClaimDelete() {
        List<Claim__c> claims = [SELECT Id FROM Claim__c];
        Test.startTest();
        try {
        	DELETE claims;
        }
        catch(Exception ex) {
            Assert.isTrue(ex.getMessage().contains('You are not authorized to delete the claim.'));
        }     
        Test.stopTest();
    }
}