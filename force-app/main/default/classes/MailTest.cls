@isTest
private class MailTest {
    static testMethod void test(){    
        Account a = new Account(Name='Sample Account', Account_Manager_Name__c = 'PHI Manager');
        insert a;
        
        Insurance_Company__c objInsuranceCompany = new Insurance_Company__c();
        objInsuranceCompany.Name = 'TestInsurance';
        objInsuranceCompany.eligibility_Coverage_Phone__c = '9999999999';
        objInsuranceCompany.Pre_Cert_Auth_Phone__c = '1111111111';
        insert objInsuranceCompany;
        
        Contact c = new Contact(Accountid=a.id,lastname='test1');        
        c.Primary_Insurance__c = objInsuranceCompany.Id;
        c.Plan_Type__c = 'Other Plan';
        c.DX_s__c='test';
        c.Account_Status__c = 'Payment received';
        insert c;
        
        Claim__c cl = new Claim__c(Date_Received__c=system.today(),From_DOS__c=system.today(),To_DOS__c=system.today(),Invoice_Number__c = '1234', Pending_Status__c='Claim in Process',Claim_Rate__c=10,Medical_Provider__c=a.id,Patient__c=c.id,Facility_Charges__c=1000,Professional_Charges__c=1000,Insurance_Company__c = objInsuranceCompany.Id, Insurance_Policy_Limit__c = '100000');
        insert cl;  
        Contact c2 = [Select id from contact LIMIT 1];
        PageReference myVfPage = Page.MedicalInvoiceMail;
        Test.setCurrentPage(myVfPage);   
        ApexPages.currentPage().getParameters().put('id', c2.Id);
        MedicalInvoiceMailSample ms = new  MedicalInvoiceMailSample();
        ms.emailTo='test@abc.com';
        ms.emailBody1='test';
        ms.subject1='hi';     
        ms.sendEmail();
        
        PageReference myVfPage1 = Page.PatientMail;
        Test.setCurrentPage(myVfPage1);   
        ApexPages.currentPage().getParameters().put('id', c2.Id);
        PatientMailSample pms = new PatientMailSample();
        pms.emailTo='test@abc.com';
        pms.emailBody1='test';
        pms.subject1='hi';     
        pms.sendEmail();
    }
}