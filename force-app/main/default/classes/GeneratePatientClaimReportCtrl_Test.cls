/***********************************************************************************

Author          |Date       | Comments
Atul Dobhal     |08/06/2018 | Controller to dispaly patient and claim report

************************************************************************************/

@istest
public class GeneratePatientClaimReportCtrl_Test{
    public static testMethod void  executePatientClaimReportController(){
        
        Account objAccount = new Account();
        objAccount.Name = 'TestAccount';
        insert objAccount;
        
        Contact objContact = New Contact();
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
        objClaim.collector__c = 'Admin';
        objClaim.Invoice_Number__c = 'Test2312';
        objClaim.Professional_Charges__c=1000;
        objClaim.Insurance_Company__c = objInsuranceCompany.Id;
        insert objClaim; 
        
        GeneratePatientClaimReportController objGeneratePatientClaimReportController = New GeneratePatientClaimReportController();
        objGeneratePatientClaimReportController.showReport();
        objGeneratePatientClaimReportController.afterExportReport();
    }
    
    public static testMethod void  executePatientClaimReportController2(){
        
        Account objAccount = new Account();
        objAccount.Name = 'TestAccount';
        insert objAccount;
        
        Contact objContact = New Contact();
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
        objClaim.collector__c = 'Admin';
        objClaim.Invoice_Number__c = 'Test2312';
        objClaim.Professional_Charges__c=1000;
        objClaim.Insurance_Company__c = objInsuranceCompany.Id;
        insert objClaim; 
        
        GeneratePatientClaimReportController objGeneratePatientClaimReportController = New GeneratePatientClaimReportController();
        objGeneratePatientClaimReportController.fromdate = system.today();
        objGeneratePatientClaimReportController.hasError = False;
        objGeneratePatientClaimReportController.showReport();
        objGeneratePatientClaimReportController.afterExportReport();
    }
    
    public static testMethod void  executePatientClaimReportController3(){
        
        Account objAccount = new Account();
        objAccount.Name = 'TestAccount';
        insert objAccount;
        
        Contact objContact = New Contact();
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
        objClaim.collector__c = 'Admin';
        objClaim.Invoice_Number__c = 'Test2312';
        objClaim.Professional_Charges__c=1000;
        objClaim.Insurance_Company__c = objInsuranceCompany.Id;
        insert objClaim; 
        
        GeneratePatientClaimReportController objGeneratePatientClaimReportController = New GeneratePatientClaimReportController();
        objGeneratePatientClaimReportController.fromdate = system.today();
        objGeneratePatientClaimReportController.todate = system.today()+10;
        objGeneratePatientClaimReportController.Collector = 'External Collection';
        objGeneratePatientClaimReportController.getCollectors();     
        objGeneratePatientClaimReportController.getMetdicalProvider();  
        objGeneratePatientClaimReportController.showReport();
        objGeneratePatientClaimReportController.afterExportReport();
    }
}