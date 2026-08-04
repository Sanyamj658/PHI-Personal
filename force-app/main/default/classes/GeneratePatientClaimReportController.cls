/***********************************************************************************

Author          |Date       | Comments

Vinod           |22/06/2018 | Controller to generate report for patient and claim

************************************************************************************/

public class GeneratePatientClaimReportController{
    public Date fromdate{get;set;}
    public Date todate{get;set;}
    public String collector{get;set;}
	public String medProvider{get;set;}
    public Claim__c objClaim{get;set;}
    public boolean hasError{get;set;}
    
    public GeneratePatientClaimReportController(){
        fromdate = null;
        todate = null;
        objClaim = new Claim__c();
        hasError = false;
        collector = '';
		medProvider = '';
    }
    
    public List<SelectOption> getCollectors() {

        // do a field describe of the picklist field
        Schema.DescribeFieldResult describeResult = Claim__c.Collector__c.getDescribe();
        // get the picklist values from this describe result
        List<Schema.PicklistEntry> entries = describeResult.getPicklistValues();
        // list of options to be returned to the VF page
        List<SelectOption> optionsToReturn = new List<SelectOption>();
        optionsToReturn.add(new SelectOption('', '--None--'));
        for (Schema.PicklistEntry pEntry : entries) {
            if (pEntry.isActive()) {
                optionsToReturn.add(new SelectOption(pEntry.getValue(), pEntry.getLabel()));
            }
        }
        return optionsToReturn;
    }
	
	public List<SelectOption> getMetdicalProvider() {
	
        // do a field describe of the picklist field
        List<Account> medicalProviderList = New List<Account>();
        // get the picklist values from this describe result
        medicalProviderList = [SELECT Id,Name FROM Account];
        // list of options to be returned to the VF page
        List<SelectOption> optionsToReturn = new List<SelectOption>();
        optionsToReturn.add(new SelectOption('null', '--None--'));
        for (Account objAccount : medicalProviderList) {
            optionsToReturn.add(new SelectOption(objAccount.Id, objAccount.Name));
        }
        return optionsToReturn;
    }
    
    public PageReference showReport(){
        //showtable = true;
        System.debug('fromdate-->'+fromdate);
        System.debug('todate-->'+todate);
        System.debug('collector-->'+collector);
        System.debug('objClaim.Medical_Provider__c-->'+medProvider);
        
        if(fromdate == null && todate == null && (collector == null || collector =='') && (medProvider == null  && medProvider=='')){
            hasError = true;
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Please select atleast one filters. '));
            return null;
        }
        if((fromdate == null && todate != null)||(fromdate != null && todate == null)){
            hasError = true;
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Please fill from and to date filter. '));
            return null;
        }
    
        if(fromdate > todate ){
            hasError = true;
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, '\'To Date\' should be Greater or equal to \'From Date\'. '));
            return null;
        }
        System.debug('collector-->'+collector);
        System.debug('medProvider-->'+medProvider);
        hasError = false;
        PageReference pg = new Pagereference('/apex/PatientClaimReport?fromDate='+fromdate+'&todate='+todate+'&collector='+collector+'&provider='+medProvider);
        pg.setRedirect(true);
        return pg;
    }
    
    public void afterExportReport(){
        System.debug('Inside error');
        fromdate = null;
        todate = null;
        objClaim = new Claim__c();
    }
}