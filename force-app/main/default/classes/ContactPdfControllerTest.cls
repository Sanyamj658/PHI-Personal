@isTest
public class ContactPdfControllerTest {
    
    @isTest 
    public static void testInvoiceGenerator(){
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
        
        Attorney__c attObj = new Attorney__c();
        attObj.Name = 'NG';
        attObj.BillingHourRate__c = 100;
        insert attObj;
        
        Task taskObj = new Task();
        taskObj.WhoId = conObj.Id;
        taskObj.Priority = 'Normal';
        taskObj.Status = 'Completed';
        taskObj.ActivityDate = System.today();
        taskObj.Start_Time__c = System.now();
        taskObj.Stop_Time__c = System.now().addMinutes(10);
        taskObj.Attorney__c = attObj.Id;
        taskObj.Subject = 'Call to Medical Provider';
        insert taskObj;
        
        Invoice__c invoice = new Invoice__c(Contact__c = conObj.Id);
        INSERT invoice;
        
        String discDesc = 'Discount';
        Integer discAmt = 10;
        Test.startTest();
        
        PageReference pageRef = Page.InvoicePDFPage;
        pageRef.getParameters().put('id', conObj.Id);
        pageRef.getParameters().put('invoice',invoice.Id);
        pageRef.getParameters().put('discDesc',discDesc);
        pageRef.getParameters().put('discAmt',String.valueOf(discAmt));
        pageRef.getParameters().put('startDate',String.valueOf(System.today()));
        pageRef.getParameters().put('endDate',String.valueOf(System.today()));
        Test.setCurrentPage(pageRef);
        ContactPdfController pdfObj = new contactPdfController(); 
        
        Test.stopTest();
    }
}