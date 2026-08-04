public class BatchReportMail implements Database.Batchable<sObject>, Database.Stateful {
    
    String batchQuery = '';
    // Stores all exceptions across execute() calls
    private List<String> exceptionList = new List<String>();
    
    String batchQueryCriteria = '';
    
    public BatchReportMail(){ }
    
    // Constructor used to run the batch for a specific Schedule_Report__c record
    public BatchReportMail(String reportId){
        batchQueryCriteria = ' WHERE Id =\'' + reportId + '\'';
    }
    
    public Database.querylocator start(Database.BatchableContext BC) {
        batchQuery = 'Select id, Select_Report__c, Report_Format__c, Email__c, Email1__c, Email2__c, Email3__c, Email4__c, Email5__c, Formulae_email__c, Subject__c '
            + 'From Schedule_Report__c ';
        System.debug(Database.getQueryLocator(batchQuery + batchQueryCriteria));
        return Database.getQueryLocator(batchQuery + batchQueryCriteria);
    }
    
    public void execute(Database.BatchableContext BC, List<Schedule_Report__c> Scope) {
        for (Schedule_Report__c sc : Scope) {
            try{
                // Run the selected Salesforce report
                // Implemented these changes from the previous HTTP callout as salesforce verify the identity on exported reports as on 27-July-2026 mail
                Reports.ReportResults reportResults;
                reportResults = Reports.ReportManager.runReport(sc.Select_Report__c, true);
                
                // Skip sending emails when the report contains no rows (except during tests)
                if (!Test.isRunningTest() && hasNoRows(reportResults)) {
                    System.debug('Skipping report email for Schedule_Report__c record as there are no rows: ' + sc.Id);
                    continue;
                }
                
                // Determine requested output format (CSV or Excel)
                String format = sc.Report_Format__c != null ? sc.Report_Format__c.toLowerCase() : 'csv';
                String reportName = 'Weekly Report';
                Blob fileBody;
                
                if (format.contains('xls') || format.contains('xlsx')) {
                    fileBody = generateExcelBlob(reportResults);
                    reportName += '.xls'; // Must use .xls for XML Spreadsheets to open correctly
                }
                else {
                    fileBody = generateReportBlob(reportResults);
                    reportName += '.csv';
                }
                
                // Prepare email and attachment
                Messaging.SingleEmailMessage semail = new Messaging.SingleEmailMessage();
                Messaging.EmailFileAttachment attach = new Messaging.EmailFileAttachment();
                
                attach.setFileName(reportName);
                attach.setBody(fileBody);
                semail.setSubject(sc.Subject__c);
                
                // Safely build the recipient list to avoid null pointer exceptions
                List<String> sendTo = new List<String>();
                if (String.isNotBlank(sc.Email__c)) sendTo.add(sc.Email__c);
                if (String.isNotBlank(sc.Formulae_email__c)) sendTo.add(sc.Formulae_email__c);
                if (String.isNotBlank(sc.Email1__c)) sendTo.add(sc.Email1__c);
                if (String.isNotBlank(sc.Email2__c)) sendTo.add(sc.Email2__c);
                if (String.isNotBlank(sc.Email3__c)) sendTo.add(sc.Email3__c);
                if (String.isNotBlank(sc.Email4__c)) sendTo.add(sc.Email4__c);
                if (String.isNotBlank(sc.Email5__c)) sendTo.add(sc.Email5__c);
                
                semail.setToAddresses(sendTo);
                
                // Build the email body
                String str = 'Dear Sir or Madam,\n\n\n';
                str += 'Please find attached the report(s) you have requested...\n\n\n';
                str += 'Kind regards,\n';
                str += 'Passage Health International';
                
                semail.setPlainTextBody(str);
                semail.setFileAttachments(new Messaging.EmailFileAttachment[]{attach});
                
                // Send email only if recipients exist
                if (!sendTo.isEmpty()) {
                    Messaging.sendEmail(new Messaging.SingleEmailMessage[]{semail});
                }
            }
            catch (Exception e) {
                System.debug('Error running report for Schedule_Report__c ' + sc.Id + ': ' + e.getMessage());
                exceptionList.add(
                    'Record: ' + sc.Id +
                    ' | Message: ' + e.getMessage() +
                    ' | Line: ' + e.getLineNumber() + '\n\n'
                    );
            }
        }
    }
    
    // Generates an Excel-compatible XML file from report results
    private Blob generateExcelBlob(Reports.ReportResults reportResults) {
        String xml = '<?xml version="1.0"?><?mso-application progid="Excel.Sheet"?>';
        xml += '<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet" ';
        xml += 'xmlns:o="urn:schemas-microsoft-com:office:office" ';
        xml += 'xmlns:x="urn:schemas-microsoft-com:office:excel" ';
        xml += 'xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet" ';
        xml += 'xmlns:html="http://www.w3.org/TR/REC-html40">';
        xml += '<Worksheet ss:Name="Report Data"><Table>';
        
        // Retrieve report metadata for column labels
        Reports.ReportExtendedMetadata extMetadata = reportResults.getReportExtendedMetadata();
        Map<String, Reports.DetailColumn> detailColumnInfo = extMetadata.getDetailColumnInfo();
        List<String> detailColumns = reportResults.getReportMetadata().getDetailColumns();
        
        // Build Headers
        xml += '<Row>';
        for (String col : detailColumns) {
            Reports.DetailColumn dc = detailColumnInfo.get(col);
            String label = (dc != null && dc.getLabel() != null) ? dc.getLabel() : col;
            xml += '<Cell><Data ss:Type="String">' + label.escapeXml() + '</Data></Cell>';
        }
        xml += '</Row>';
        
        // Build Rows
        Reports.ReportFactWithDetails factDetails = getFactWithDetails(reportResults);
        if (factDetails != null) {
            for (Reports.ReportDetailRow row : factDetails.getRows()) {
                xml += '<Row>';
                for (Reports.ReportDataCell cell : row.getDataCells()) {
                    String cellVal = cell.getLabel() != null ? cell.getLabel() : '';
                    xml += '<Cell><Data ss:Type="String">' + cellVal.escapeXml() + '</Data></Cell>';
                }
                xml += '</Row>';
            }
        }
        
        xml += '</Table></Worksheet></Workbook>';
        return Blob.valueOf(xml);
    }
    
    // Builds a CSV blob directly from Standard Report class results
    private Blob generateReportBlob(Reports.ReportResults reportResults) {
        
        // Retrieve report metadata for column labels
        Reports.ReportExtendedMetadata extMetadata = reportResults.getReportExtendedMetadata();
        Map<String, Reports.DetailColumn> detailColumnInfo = extMetadata.getDetailColumnInfo();
        List<String> detailColumns = reportResults.getReportMetadata().getDetailColumns();
        
        // Build CSV header row
        List<String> headers = new List<String>();
        for (String col : detailColumns) {
            Reports.DetailColumn dc = detailColumnInfo.get(col);
            headers.add(csvEscape(dc != null ? dc.getLabel() : col));
        }
        
        String csv = String.join(headers, ',') + '\n';
        
        // Append report detail rows
        Reports.ReportFactWithDetails factDetails = getFactWithDetails(reportResults);
        if (factDetails != null) {
            for (Reports.ReportDetailRow row : factDetails.getRows()) {
                List<String> rowValues = new List<String>();
                for (Reports.ReportDataCell cell : row.getDataCells()) {
                    rowValues.add(csvEscape(cell.getLabel()));
                }
                csv += String.join(rowValues, ',') + '\n';
            }
        }
        
        return Blob.valueOf(csv);
    }
    
    // Escapes CSV values containing commas, quotes or new lines
    private String csvEscape(String val) {
        if (val == null) {
            return '';
        }
        if (val.contains(',') || val.contains('"') || val.contains('\n')) {
            val = '"' + val.replace('"', '""') + '"';
        }
        return val;
    }
    
    // Retrieves the report fact that contains detailed rows
    private Reports.ReportFactWithDetails getFactWithDetails(Reports.ReportResults reportResults) {
        Map<String, Reports.ReportFact> factMap = reportResults.getFactMap();
        if (factMap != null) {
            for (String key : factMap.keySet()) {
                Reports.ReportFact fact = factMap.get(key);
                if (fact instanceof Reports.ReportFactWithDetails) {
                    return (Reports.ReportFactWithDetails) fact;
                }
            }
        }
        return null;
    }
    
    // Determines whether the report returned any rows
    private Boolean hasNoRows(Reports.ReportResults reportResults) {
        try {
            if (reportResults.getHasDetailRows()) {
                Map<String, Reports.ReportFact> factMap = reportResults.getFactMap();
                for (String key : factMap.keySet()) {
                    Reports.ReportFact fact = factMap.get(key);
                    Integer recordsCount = 0;
                    for (Reports.SummaryValue summaryValue : fact.getAggregates()) {
                        recordsCount = Integer.valueOf(summaryValue.getValue());
                    }
                    return recordsCount < 1;
                }
            }
        } catch (Exception e) {
            System.debug('Error checking report rows: ' + e.getMessage());
        }
        return false;
    }
    
    // Batch finish method
    public void finish(Database.BatchableContext BC) {
        
        if (!exceptionList.isEmpty()) {
            
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            
            email.setToAddresses(new List<String>{
                'passagehi@concret.io'
            });
            
            email.setSubject(
                'Schedule report completed with ' +
                exceptionList.size() +
                ' Exception(s)'
                );
            
            String body =
                'Batch Job Id: ' + bc.getJobId() + '\n\n' +
                'The following exceptions occurred:\n\n' +
                String.join(exceptionList, '\n\n');
            
            email.setPlainTextBody(body);
            
            Messaging.sendEmail(
            new List<Messaging.SingleEmailMessage>{ email }
            );
        }
    }
}