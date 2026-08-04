public class ContactPdfController {
    public Contact contact{get;set;}
    public List<TaskWrapper> wrapTaskList{get;set;}
    public String invoiceNo{get;set;}
    public Decimal totalamount{get;set;}
    public Decimal totaltime{get;set;}
    public String discDesc {get;set;}
    public Integer discAmt {get;set;}
    public Decimal netAmt {get;set;}
    public Date startDate{get;set;}
    public Date endDate{get;set;}
    public static Integer totalHours;
    public static Integer partOfHour;
    
    public ContactPdfController() {
        String contactId = ApexPages.currentPage().getParameters().get('id');
        invoiceNo = ApexPages.currentPage().getParameters().get('invoice');
        discDesc = ApexPages.currentPage().getParameters().get('discDesc');
        String startDateString = ApexPages.currentPage().getParameters().get('startDate');
        String endDateString = ApexPages.currentPage().getParameters().get('endDate');
        String attorneyId = ApexPages.currentPage().getParameters().get('attorneyId');
        totalamount =0;
        totaltime = 0;
        wrapTaskList = new List<TaskWrapper>();
        
        if( startDateString != null){
            startDate = Date.valueOf(startDateString);
        }
        if( endDateString != null ){
            endDate = Date.valueOf(endDateString);
        }
        
        String discAmtStr = ApexPages.currentPage().getParameters().get('discAmt');
        if( discDesc != null ){
            discAmt = 0;
        }
        if( discAmtStr != null ){
            discAmt = Integer.valueOf(discAmtStr);
        }
        
        if( contactId != null ){
            contact = [Select Id, Name, Phone, MobilePhone, Email, Fax,Primary_Claim_No__c
                       ,Account.Name,Account.billingstatecode,Account.billingstreet,Account.billingcountrycode,
                       Account.billingstate,Account.billingcity FROM Contact
                       where Id = :contactId];
            
            List<Task> tasks = prepareTasks(contactId, startDate, endDate, attorneyId); 
            
            for(Task task : tasks)
            {
               TaskWrapper wrapObj = new TaskWrapper(task);
               try
               {
                    if(wrapObj.TaskObj.Start_Time__c != null && wrapObj.TaskObj.Stop_Time__c != null)
                    {
                        wrapObj.totalHours = calculateTimeAmount(wrapObj.TaskObj.Start_Time__c, wrapObj.TaskObj.Stop_Time__c );
                        Decimal billingHourRate = 0;
                        if( wrapObj.TaskObj.Attorney__c != null && wrapObj.TaskObj.Attorney__r.BillingHourRate__c != null){
                            billingHourRate = wrapObj.TaskObj.Attorney__r.BillingHourRate__c;
                        }
                        Decimal amt = totalHours * billingHourRate; 

                        if( partOfHour > 0){
                            Decimal perPartRate = billingHourRate/6;
                            amt = amt + (perPartRate * partOfHour);
                        }
                        wrapObj.amount = amt;
                        totalamount += wrapObj.amount;
                        totaltime += wrapObj.totalHours;
                    }
                    else
                    {
                        continue;
                    }
                   wrapTaskList.add(wrapObj);
                }
                catch(Exception ex)
                {
                    System.debug('ex'+ex);
                }
            }
            if( discAmt > 0){
                netAmt = totalAmount - discAmt;
            }
            else{
                netAmt = totalAmount;
            }
        } 
    }
    
    
    public class TaskWrapper
    {
        public Task TaskObj {get;set;}
        public Long startTime{get;set;}
        public Long stopTime{get;set;}
        public Decimal totalHours{get;set;}
        public Decimal amount{get;set;}
        
        public TaskWrapper(Task task) {
            TaskObj = task; 
        }
    }
    
    public Static List<Task> prepareTasks(Id contactId, Date startDate, Date endDate, Id attorneyId){
        
        String query = 'Select whoid,subject,status,LastModifiedDate,start_time__c,stop_time__c,description,'+
            + 'Attorney__r.Name,Attorney__r.BillingHourRate__c FROM Task where whoid =:contactId AND IsClosed = true' 
            +' AND Start_Time__c != null AND Stop_Time__c != null';
        if( startDate != null ){
            query += ' AND ActivityDate >= :startDate';
        }  
        if( endDate != null ){
            query += ' AND ActivityDate <= :endDate';
        }
        if( attorneyId != null){
            query += ' AND Attorney__c =: attorneyId';
        }
        query += ' ALL ROWS';
        return Database.query(query);
    }
    
    public static Decimal calculateTimeAmount(DateTime taskStartTime, DateTime taskStopTime){
        if( taskStartTime < taskStopTime){
            Long dt1Long = taskStartTime.getTime();
            Long dt2Long = taskStopTime.getTime();
            
            Long milliseconds = dt2Long - dt1Long;
            Decimal hours = milliseconds / (1000.0*60.0*60.0);
            totalHours = Integer.valueOf(math.floor(hours));
            Decimal remainingMins = math.round((Hours - totalHours)*60);
            System.debug('remainingMins'+remainingMins);
            
            partOfHour = 0;
            if( remainingMins >= 1 && remainingMins <= 10 ){
                partOfHour = 1;
            }
            else if( remainingMins >= 11 && remainingMins <= 20 ){
                partOfHour = 2;
            }
            else if( remainingMins >= 21 && remainingMins <= 30 ){
                partOfHour = 3;
            }
            else if( remainingMins >= 31 && remainingMins <= 40 ){
                partOfHour = 4;
            }
            else if( remainingMins >= 41 && remainingMins <= 50 ){
                partOfHour = 5;
            }
            else if( remainingMins >= 51 && remainingMins <= 60 ){
                partOfHour = 6;
            }
            
            return (totalHours+(Decimal.valueOf(partOfHour)/10)).setScale(2,RoundingMode.FLOOR);
        }
        return 0;
    }
}