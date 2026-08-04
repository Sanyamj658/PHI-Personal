/*****************************************************************
* Author: Techila Global Services Pvt Ltd. (Gaurav Agrawal)
* Class Name: PatientInvoiceControllerX
* Created Date: 09-January-2017
* Description: Contoller Extension for download invoice as Excel file
*******************************************************************/

public with sharing class PatientInvoiceControllerX {

    public Contact  objContact{get;set;}
    public Account  objAccount{get;set;}
    public List<Claim__c> ClaimList {get;set;}   
    public Decimal totalCharge {get;set;}
    public Decimal totalPayemnets {get;set;}
    public decimal balanceDue {get;set;}
    public boolean isrender{get;set;}

    public PatientInvoiceControllerX(ApexPages.StandardController controller) {
        init();

        DescribeSObjectResult describeResultContact = Contact.getSObjectType().getDescribe();
        List<String> contactFieldsName = new List<String>(describeResultContact.fields.getMap().keySet());     
        String queryContact = ' SELECT ' + String.join( contactFieldsName, ',' ) + ' FROM ' + describeResultContact.getName();    
        queryContact += ' WHERE Id = \''+ ApexPages.currentPage().getParameters().get('id') +'\' LIMIT 1';
        objContact = Database.query(queryContact);

        if(objContact.AccountId != null){
            DescribeSObjectResult describeResultAccount = Account.getSObjectType().getDescribe();
            List<String> accountFieldsName = new List<String>(describeResultAccount.fields.getMap().keySet());     
            String queryAccount = ' SELECT ' + String.join( accountFieldsName, ',' ) + ' FROM ' + describeResultAccount.getName();    
            queryAccount += ' WHERE Id = \''+ objContact.AccountId +'\' LIMIT 1';
            objAccount = Database.query(queryAccount);              
        }    

        if(objContact.Id !=null){
            DescribeSObjectResult describeResultClaim = Claim__c.getSObjectType().getDescribe();
            List<String> ClaimFieldsName = new List<String>(describeResultClaim.fields.getMap().keySet());     
            String queryClaim = ' SELECT ' + String.join( ClaimFieldsName, ',' ) + ' FROM ' + describeResultClaim.getName();    
            queryClaim += ' WHERE Patient__c = \''+ objContact.Id +'\'';
            ClaimList = Database.query(queryClaim); 
            system.debug('ClaimList'+ClaimList);
        }        
        
        for(Claim__c objC : ClaimList){
            totalCharge += objC.Total_Charge__c;
            totalPayemnets += objC.Sum_of_Payments__c;
        }
                        
        for(Claim__c objC : ClaimList){
             if(objC.Claim_Balance_Due__c != null){
               balanceDue +=  objC.Claim_Balance_Due__c;
             }
        }             
    }

    public void init(){
        objContact = new Contact();
        objAccount = new Account();
        ClaimList = new List<Claim__c>();
        totalCharge = 0.00;
        totalPayemnets = 0.00;
        balanceDue = 0.00;
        isrender = false;
    }
    
    public pageReference downloadExcel(){
        
        isrender = true;
        PageReference ExcelPage = new PageReference('/apex/PatientInvoice?id=' + objContact.id);
        ExcelPage.setRedirect(false);
        return ExcelPage;
    }         
}