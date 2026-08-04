@isTest
public class InvoiceGeneratorTest {
    
    public static testMethod void testSelectedContact() 
    {
        Account accObj = new Account();
        accObj.Name = 'CMC';
        accObj.billingstreet = 'parkstreet';
        accObj.billingstate = 'Illinois';
        accObj.billingcity = 'er';
        insert accObj;
        
        Contact conObj = new Contact();
        conObj.AccountId = accObj.Id;
        conObj.Account_Status__c = 'Verification work in process';
        conObj.LastName ='testcontact';
        conObj.Phone = '1234567890';
        insert conObj;
        
        Test.startTest();
        
        PageReference pageRef = Page.InvoiceGenerator; // Add your VF page Name here
        pageRef.getParameters().put('id', String.valueOf(conObj.Id));
        Test.setCurrentPage(pageRef);
        InvoiceGeneratorController controller = new InvoiceGeneratorController();
        
        Test.stopTest();
        
        System.assertEquals(conObj.Id, controller.selectedContactId);	
        
    }
    
    public static testMethod void testSelectedContactNegative() 
    {
        
        Test.startTest();
        
        PageReference pageRef = Page.InvoiceGenerator; // Add your VF page Name here
        Test.setCurrentPage(pageRef);
        InvoiceGeneratorController controller = new InvoiceGeneratorController();
        
        Test.stopTest();
        
        System.assertEquals(null, controller.selectedContactId);	
    }
    
    public static testMethod void testGeneratePdF() 
    {
        Account accObj = new Account();
        accObj.Name = 'CMC';
        accObj.billingstreet = 'parkstreet';
        accObj.billingstate = 'Illinois';
        accObj.billingcity = 'er';
        insert accObj;
        
        Contact conObj = new Contact();
        conObj.AccountId = accObj.Id;
        conObj.Account_Status__c = 'Verification work in process';
        conObj.LastName ='testcontact';
        conObj.Phone = '1234567890';
        insert conObj;
        
        Task tsk = new Task(Status = 'Completed', Subject = 'Manage', WhoId = conObj.Id, Start_Time__c = System.now(), Stop_Time__c = System.now().addMinutes(20));
        INSERT tsk;
        
        Test.startTest();
        
        PageReference pageRef = Page.InvoiceGenerator; // Add your VF page Name here
        pageRef.getParameters().put('id', String.valueOf(conObj.Id));
        Test.setCurrentPage(pageRef);
        Map<String, String> result = InvoiceGeneratorController.generatePdF(conObj.Id, null, null, null, null, null);
        Test.stopTest();
        
        List<Invoice__c> invoices = [SELECT ID FROM Invoice__c];
        
        System.assertEquals(1, invoices.size());
    }
    
    
    public static testMethod void testGeneratePdFNegative() 
    {
        Account accObj = new Account();
        accObj.Name = 'CMC';
        accObj.billingstreet = 'parkstreet';
        accObj.billingstate = 'Illinois';
        accObj.billingcity = 'er';
        insert accObj;
        
        Contact conObj = new Contact();
        conObj.AccountId = accObj.Id;
        conObj.Account_Status__c = 'Verification work in process';
        conObj.LastName ='testcontact';
        conObj.Phone = '1234567890';
        insert conObj;
        
        Task tsk = new Task(Status = 'Open', Subject = 'Manage', WhoId = conObj.Id, Start_Time__c = System.now(), Stop_Time__c = System.now().addMinutes(20));
        INSERT tsk;
        
        Test.startTest();
        
        PageReference pageRef = Page.InvoiceGenerator; // Add your VF page Name here
        pageRef.getParameters().put('id', String.valueOf(conObj.Id));
        Test.setCurrentPage(pageRef);
        Map<String, String> result = InvoiceGeneratorController.generatePdF(conObj.Id, null, null, null, null, null);
        Test.stopTest();
        
        List<Invoice__c> invoices = [SELECT ID FROM Invoice__c];
        
        System.assertEquals(0, invoices.size());
    }
}