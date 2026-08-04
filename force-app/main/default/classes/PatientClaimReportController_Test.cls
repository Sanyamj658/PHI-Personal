/***********************************************************************************

Author          |Date       | Comments
Atul Dobhal     |08/06/2018 | Controller to dispaly patient and claim report

************************************************************************************/

@istest
public class PatientClaimReportController_Test{
    
    public static testMethod void  executePatientClaimReportControllerNoParameter(){
    
        Account objAccount = new Account();
        objAccount.Name = 'TestAccount';
        insert objAccount;
        
        Contact objContact = New Contact();
        objContact.LastName = 'TestContact';
        objContact.AccountId = objAccount.Id;
        insert objContact;
        
        Collector__c objCollector = new Collector__c();
        objCollector.Patient__c = objContact.id;
        insert objCollector;
        
        Task objTask = new Task();
        objTask.OwnerId = UserInfo.getUserId();
        objTask.ActivityDate = date.today()+7;
        objTask.Subject='Test';
        objTask.Status='Open';
        objTask.Priority='Normal';
        objTask.WhoId = objContact.Id;
        insert objTask;    
        
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
        
        Task objTaskClaim = new Task();
        objTaskClaim.OwnerId = UserInfo.getUserId();
        objTaskClaim.ActivityDate = date.today()+7;
        objTaskClaim.Subject='Test 23';
        objTaskClaim.Status='Open';
        objTaskClaim.Priority='Normal';
        objTaskClaim.WhatId= objClaim.Id;
        insert objTaskClaim ;
        
        PageReference pageRef = Page.PatientClaimReport;
		Test.setCurrentPage(pageRef);
        
		PatientClaimReportController objPatientClaimReportController = New PatientClaimReportController();
    }
    
    public static testMethod void  executePatientClaimReportControllerNoProColl(){
    
        Account objAccount = new Account();
        objAccount.Name = 'TestAccount';
        insert objAccount;
        
        Contact objContact = New Contact();
        objContact.LastName = 'TestContact';
        objContact.AccountId = objAccount.Id;
        insert objContact;
        
        Collector__c objCollector = new Collector__c();
        objCollector.Patient__c = objContact.id;
        insert objCollector;
        
        Task objTask = new Task();
        objTask.OwnerId = UserInfo.getUserId();
        objTask.ActivityDate = date.today()+7;
        objTask.Subject='Test';
        objTask.Status='Open';
        objTask.Priority='Normal';
        objTask.WhoId = objContact.Id;
        insert objTask;    
        
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
        
        Task objTaskClaim = new Task();
        objTaskClaim.OwnerId = UserInfo.getUserId();
        objTaskClaim.ActivityDate = date.today()+7;
        objTaskClaim.Subject='Test 23';
        objTaskClaim.Status='Open';
        objTaskClaim.Priority='Normal';
        objTaskClaim.WhatId= objClaim.Id;
        insert objTaskClaim ;
        
        PageReference pageRef = Page.PatientClaimReport;
		Test.setCurrentPage(pageRef);
        ApexPages.currentPage().getParameters().put('fromDate', String.valueOf(system.today()));
        ApexPages.currentPage().getParameters().put('toDate', String.valueOf(system.today()+10));
		
        
        PatientClaimReportController objPatientClaimReportController = New PatientClaimReportController();
    }
    
    public static testMethod void  executePatientClaimReportControllerNoPro(){
    
        Account objAccount = new Account();
        objAccount.Name = 'TestAccount';
        insert objAccount;
        
        Contact objContact = New Contact();
        objContact.LastName = 'TestContact';
        objContact.AccountId = objAccount.Id;
        insert objContact;
        
        Collector__c objCollector = new Collector__c();
        objCollector.Patient__c = objContact.id;
        insert objCollector;
        
        Task objTask = new Task();
        objTask.OwnerId = UserInfo.getUserId();
        objTask.ActivityDate = date.today()+7;
        objTask.Subject='Test';
        objTask.Status='Open';
        objTask.Priority='Normal';
        objTask.WhoId = objContact.Id;
        insert objTask;    
        
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
        
        Task objTaskClaim = new Task();
        objTaskClaim.OwnerId = UserInfo.getUserId();
        objTaskClaim.ActivityDate = date.today()+7;
        objTaskClaim.Subject='Test 23';
        objTaskClaim.Status='Open';
        objTaskClaim.Priority='Normal';
        objTaskClaim.WhatId= objClaim.Id;
        insert objTaskClaim ;
        
        PageReference pageRef = Page.PatientClaimReport;
		Test.setCurrentPage(pageRef);
        ApexPages.currentPage().getParameters().put('fromDate', String.valueOf(system.today()));
        ApexPages.currentPage().getParameters().put('toDate', String.valueOf(system.today()+10));
		ApexPages.currentPage().getParameters().put('collector', 'Admin');
        
        PatientClaimReportController objPatientClaimReportController = New PatientClaimReportController();
    }
    
    public static testMethod void  executePatientClaimReportControllerBothPres(){
    
        Account objAccount = new Account();
        objAccount.Name = 'TestAccount';
        insert objAccount;
        
        Contact objContact = New Contact();
        objContact.LastName = 'TestContact';
        objContact.AccountId = objAccount.Id;
        insert objContact;
        
        Collector__c objCollector = new Collector__c();
        objCollector.Patient__c = objContact.id;
        insert objCollector;
        
        Task objTask = new Task();
        objTask.OwnerId = UserInfo.getUserId();
        objTask.ActivityDate = date.today()+7;
        objTask.Subject='Test';
        objTask.Status='Open';
        objTask.Priority='Normal';
        objTask.WhoId = objContact.Id;
        insert objTask; 
        
        Event objEvent = new Event();
        objEvent.WhoId=objContact.id;
        objEvent.StartDateTime=system.today();
        objEvent.EndDateTime=system.today()+5;
        insert objEvent;
        
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
        
        Task objTaskClaim = new Task();
        objTaskClaim.OwnerId = UserInfo.getUserId();
        objTaskClaim.ActivityDate = date.today()+7;
        objTaskClaim.Subject='Test 23';
        objTaskClaim.Status='Open';
        objTaskClaim.Priority='Normal';
        objTaskClaim.WhatId= objClaim.Id;
        insert objTaskClaim ;
        
        Event objEventClaim = new Event();
        objEventClaim.WhatId=objClaim.id;
        objEventClaim.StartDateTime=system.today();
        objEventClaim.EndDateTime=system.today()+5;
        insert objEventClaim;
        
        PageReference pageRef = Page.PatientClaimReport;
		Test.setCurrentPage(pageRef);
        ApexPages.currentPage().getParameters().put('fromDate', String.valueOf(system.today()));
        ApexPages.currentPage().getParameters().put('toDate', String.valueOf(system.today()+10));
		ApexPages.currentPage().getParameters().put('collector', 'Admin');
        ApexPages.currentPage().getParameters().put('provider', objAccount.id);
        
        PatientClaimReportController objPatientClaimReportController = New PatientClaimReportController();
    }
}