Public class BatchReportMail implements Database.Batchable<sObject>,Database.AllowsCallouts {
    
    String batchQuery = '';
    String batchQueryCriteria = '';
    
    public BatchReportMail(){ }
    
    public BatchReportMail(String reportId){
        batchQueryCriteria = ' WHERE Id =\'' + reportId + '\'';
    }
    
    
    Public Database.querylocator start(Database.BatchableContext BC) {
        
        batchQuery = 'Select id, Select_Report__c, Report_Format__c, Email__c,Email1__c,Email2__c,Email3__c,Email4__c,Email5__c '
            +',Formulae_email__c,Subject__c '
            +' From Schedule_Report__c ';
        System.debug(Database.getQueryLocator(batchQuery + batchQueryCriteria));
        return Database.getQueryLocator(batchQuery + batchQueryCriteria);    
    }
    
    Public void execute(Database.BatchableContext BC, List<Schedule_Report__c> Scope) {
        for(Schedule_Report__c sc : Scope){
            if (hasNoRows(sc.Select_Report__c) && !Test.isRunningTest()) {
                System.debug('Skipping report email for Schedule_Report__c record as there are no rows: ' + sc.Id);
                continue;
            }
            Messaging.SingleEmailMessage semail = new Messaging.SingleEmailMessage(); 
            Messaging.EmailFileAttachment attach = new Messaging.EmailFileAttachment();
            PageReference pref;
            Blob b ;
            String reportName;
            // work normal if condition not match 
            if (sc.Report_Format__c == '.xlsx') {
                reportName = 'Weekly Report.xlsx';
                String requestUrl = URL.getSalesforceBaseUrl().toExternalForm().replace('http:', 'https:');
                requestUrl += '/servlet/PrintableViewDownloadServlet?isdtp=p1&reportId=';
                requestUrl += String.valueOf(sc.Select_Report__c);
                requestUrl += '&enc=UTF-8';
                pref = new ApexPages.PageReference(requestUrl);
            } else {
                reportName = 'Weekly Report' + (sc.Report_Format__c == NULL ? '.csv' : sc.Report_Format__c);
                pref = page.SamplePage; 
                pref.getParameters().put('id',(String)sc.id); 
                pref.setRedirect(true);  		
            }
            
            
            //For Test class preventing the error for getting Content
            if(Test.isRunningTest()){
                b = Blob.ValueOf('Name,Email\nTest,Test@test.com');
            }else{
                b= pref.getContent(); 
            }
            
            attach.setFileName(reportName);         
            attach.setBody(b); 
            semail.setSubject(sc.Subject__c); 
            
            String[] sendTo = new String[]{sc.email__c,sc.Formulae_email__c};  
                
                if(!String.isEmpty(sc.Email1__c))
                sendTo.add(sc.Email1__c); 
            if(!String.isEmpty(sc.Email2__c))
                sendTo.add(sc.Email2__c); 
            if(!String.isEmpty(sc.Email3__c))
                sendTo.add(sc.Email3__c); 
            if(!String.isEmpty(sc.Email4__c))
                sendTo.add(sc.Email4__c); 
            if(!String.isEmpty(sc.Email5__c))
                sendTo.add(sc.Email5__c);                                    
            semail.setToAddresses(sendTo); 
            
            String str = 'Dear Sir or Madam,';
            str = str + '\n\n\n';
            str = str + 'please find attached the report(s) you have requested...'+'\n\n\n';
            str = str + 'Kind regards,'+'\n';
            str = str + 'Passage Health International';
            
            semail.setPlainTextBody(str); 
            semail.setFileAttachments(new Messaging.EmailFileAttachment[]{attach}); 
            Messaging.sendEmail(new Messaging.SingleEmailMessage[]{semail}); 
        }
    }
    // Method to check if the report has rows or not
    private Boolean hasNoRows(String reportId) {
        try {
            Reports.ReportResults reportResults = Reports.ReportManager.runReport(reportId, true);
            
            if (reportResults.getHasDetailRows()) {
                Map<String, Reports.ReportFact> factMap = reportResults.getFactMap();
                
                for (String key : factMap.keySet()) {
                    Reports.ReportFact fact = factMap.get(key);
                    
                    // Check if there is any row in aggregates
                    Integer recordsCount = 0;
                    for (Reports.SummaryValue summaryValue : fact.getAggregates()) {
                        recordsCount = Integer.valueOf(summaryValue.getValue());
                    }
                    System.debug(recordsCount);
                    return recordsCount < 1 ? true : false;
                }
            }
        } catch (Exception e) {
            System.debug('Error running report: ' + e.getMessage());
        }
        
        return false;  // Returns false if no rows or if an exception occurred
    }
    
    Public void finish(Database.BatchableContext BC) {       
    }  
}