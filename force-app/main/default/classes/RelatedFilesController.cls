/**
 * Description: This class will give the related Notes & Attachment.
 * CreatedBy  : Rajkumar Dholpuriya(Concret.io)
 * CreatedDate: 24/06/2020
 * ModifiedDate 18/08/2021
 * ModifiedBy Harting Harris
 * ModificationLog improved the check for parentId.startstWith
**/
public class RelatedFilesController {
	
    @AuraEnabled
    public static List<sObject> getRelatedFileIds(String parentId){
        
        List<sObject> relatedFiles = new List<sObject>();
        String condition;
        List<String> nameMatches = new List<String>();
        Set<Id> ids = new Set<Id>();
        
        if(parentId.startsWith('001')){
            
            for(Claim__c claim : [SELECT Id FROM Claim__c WHERE Medical_Provider__c = :parentId]){
                ids.add(claim.Id);
            }
            
        } else if(parentId.startsWith('003')){
            ids.add(parentId);
            condition = 'IsPrivate = false';
        } else{
            ids.add(parentId);
        }
        for(ContentDocumentLink cdl : ClientAccessHelper.getDocumentsByParentId(ids)){
            relatedFiles.add(cdl.ContentDocument);   
        }
        List<Attachment> attachments = ClientAccessHelper.getAttachmentsByParentId(ids,condition);
        if(parentId.startsWith('003')){
            List<Attachment_Exception_Keywords__c> exceptionKeywords = [Select Name from Attachment_Exception_Keywords__c];
            Boolean isMatched=false;
            for(Attachment attachment : attachments)
            {
                isMatched=false;
                String id = (String)attachment.ParentId;
                if(id.startsWith('003'))
                {
                    for(Attachment_Exception_Keywords__c ack : exceptionKeywords)
                    {
                        if(attachment.Name.containsIgnoreCase(ack.Name))
                        {
                            isMatched=true;
                            break;
                        }
                    }
                    if(isMatched == false)
                    {
                       relatedFiles.add(attachment);
                    }
                }
            }
        }else{
            relatedFiles.addAll(attachments);
        }
           
        System.debug('relatedFiles'+relatedFiles);
        return relatedFiles;
    }
    
}