public class ScheduleReportController {
    public String subject{ get; set;}
    public String SelectedContact { get; set; }
    public String selectedReport { get; set; }
    public String selectedReportFormat {get; set;}
    public PageReference Save(){
        system.debug('****subject:'+subject);
        system.debug('****contacts:'+SelectedContact);
        system.debug('****report:'+selectedReport);
        String contacts='';
        if(subject<>''&& selectedReport<>'--None--'){
            
            system.debug('****contacts:'+ contacts);
            Schedule_Report__c src = new Schedule_Report__c();
            src.Select_Contacts__c=SelectedContact;
            src.Email__c=[select Email__c From Account WHERE name=:SelectedContact].Email__c;
            src.Email1__c=[select Contact_1_Email__c From Account WHERE name=:SelectedContact].Contact_1_Email__c;
            src.Email2__c=[select Contact_2_Email__c From Account WHERE name=:SelectedContact].Contact_2_Email__c;
            src.Email3__c=[select Contact_3_Email__c From Account WHERE name=:SelectedContact].Contact_3_Email__c;
            src.Email4__c=[select Contact_4_Email__c From Account WHERE name=:SelectedContact].Contact_4_Email__c;
            src.Email5__c=[select Contact_5_Email__c From Account WHERE name=:SelectedContact].Contact_5_Email__c;
            src.Subject__c=subject;
            src.Report_Name__c=selectedReport;
            String tmp = [Select id from Report Where Name=:selectedReport].id;
            src.Select_Report__c=tmp.substring(0,15);
            src.Report_Format__c = selectedReportFormat;
            insert src;
            return page.success;
        }
        else{
            ApexPages.addMessage(new ApexPages.Message(ApexPages.severity.Error,'Please select Report OR Please Enter Subject'));
        }
        
        return null;
    }
    public PageReference Cancel(){
        return null;
    }
    
    public List<SelectOption> getReportList() {
        List<SelectOption> options = new List<SelectOption>();
        options.add(new SelectOption('--None--','--None--'));
        for(Report r :[SELECT id,Name FROM Report ]){
            options.add(new SelectOption(String.valueOf(r.Name),String.valueOf(r.Name)));
        }
        system.debug('***'+options.size());
        
        return options;
    }
    public List<SelectOption> getContactList() {
        List<SelectOption> options = new List<SelectOption>();
        options.add(new SelectOption('--None--','--None--'));
        for(Account a :[SELECT Name FROM Account where Email__c<>null ]){
            options.add(new SelectOption(a.name,a.name));
        }
        system.debug('***'+options.size());
        return options;
    }
    public List<SelectOption> getReportFormats(){
        List<SelectOption> options = new List<SelectOption>();
        Schema.DescribeFieldResult fieldResult = Schedule_Report__c.Report_Format__c.getDescribe();
        for( Schema.PicklistEntry pickListVal : fieldResult.getPicklistValues()){
            options.add(new SelectOption(pickListVal.getValue(),pickListVal.getLabel()));
        }
        return options;
    }
}