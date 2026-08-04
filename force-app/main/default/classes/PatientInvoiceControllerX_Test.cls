@isTest
public class PatientInvoiceControllerX_Test {
    
    public static testmethod void ValidateInvoice(){
        
        Account objAccount = new Account();
        objAccount.Name = 'TestAccount';
        insert objAccount;
        
        Contact objContact = new Contact();
        objContact.LastName = 'TestContact';
        objContact.AccountId = objAccount.Id;
        insert objContact;
        
        Insurance_Company__c objInsuranceCompany = new Insurance_Company__c();
        objInsuranceCompany.Name = 'TestInsurance';
        insert objInsuranceCompany;
        
        Claim__c objClaim = new Claim__c();
        objClaim.Date_Received__c=system.today();
        objClaim.From_DOS__c=system.today();
        objClaim.To_DOS__c=system.today();
        objClaim.Pending_Status__c='New Invoice From Client';
        objClaim.Claim_Rate__c=10;
        objClaim.Medical_Provider__c=objAccount.id;
        objClaim.Patient__c=objContact.id;
        objClaim.Facility_Charges__c=1000;
        objClaim.Professional_Charges__c=1000;
        objClaim.Insurance_Company__c = objInsuranceCompany.Id;
        insert objClaim; 
        
        ApexPages.CurrentPage().getParameters().put('Id',objContact.Id);
        
        ApexPages.StandardController SC = new ApexPages.StandardController(objContact);
        PatientInvoiceControllerX objPatientInvoiceControllerX = new PatientInvoiceControllerX(SC);
        objPatientInvoiceControllerX.downloadExcel();           
    }
}