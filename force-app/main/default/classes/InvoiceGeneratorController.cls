public class InvoiceGeneratorController {
    public String selectedContactId{get;set;} 
    
    public InvoiceGeneratorController(){
        selectedContactId = ApexPages.currentPage().getParameters().get('id');
    }
    
    @AuraEnabled
    public static Map<String, String> generatePdF(Id contactId, Date startDate, Date endDate, String discAmt, String discDesc, Id attorneyId){
        Map<String, String> result = new Map<String, String>{'Status'=>'SUCCESS'};    
        try{
            if(contactId != null){
                List<Task> taskList = ContactPdfController.prepareTasks(contactId, startDate, endDate, attorneyId);
                if( !taskList.isEmpty() ){
                    Invoice__c invoice = new Invoice__c(Contact__c = contactId);
                    INSERT invoice;
                    
                    PageReference pdf = Page.InvoicePDFPage;
                    pdf.getParameters().put('id',contactId);
                    pdf.getParameters().put('invoice',invoice.Name);
                    pdf.getParameters().put('startDate',String.valueOf(startDate));
                    pdf.getParameters().put('endDate',String.valueOf(endDate));
                    pdf.getParameters().put('discDesc',discDesc);
                    pdf.getParameters().put('discAmt',String.valueOf(discAmt));
                    pdf.getParameters().put('attorneyId',attorneyId);
                    
                    //Insert ContentVersion
                    ContentVersion cVersion = new ContentVersion();
                    cVersion.ContentLocation = 'S';
                    cVersion.PathOnClient = 'Invoice Generator'+'.pdf';
                    cVersion.Origin = 'H';
                    cVersion.Title = 'Invoice Generator';
                    if(Test.isRunningTest()){
                        cVersion.VersionData = Blob.valueof('Test');
                    }
                    else{
                        cVersion.VersionData = pdf.getContent();
                    }
                    Insert cVersion;
                    
                    //After saved the Content Verison, get the ContentDocumentId
                    Id conDocument = [SELECT ContentDocumentId FROM ContentVersion WHERE Id =:cVersion.Id].ContentDocumentId;
                    
                    //Insert ContentDocumentLink
                    List<ContentDocumentLink> contentDocumentLinkList = new List<ContentDocumentLink>{new ContentDocumentLink(
                        ContentDocumentId = conDocument,
                        LinkedEntityId = contactId,
                        ShareType = 'I',
                        Visibility = 'InternalUsers'),
                        new ContentDocumentLink(
                            ContentDocumentId = conDocument,
                            LinkedEntityId = invoice.Id,
                            ShareType = 'I',
                            Visibility = 'InternalUsers')
                        };
                            
                            Insert contentDocumentLinkList;
                }
            }
        }catch(Exception ex){
            result.put('Status ', 'ERROR');
            result.put('Message', ex.getMessage());
        }
        return result;
    }
    
}