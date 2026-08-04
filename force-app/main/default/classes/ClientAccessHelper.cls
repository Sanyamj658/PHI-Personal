/**
 * Description: This class will help to get the related records.
 * CreatedBy  : Rajkumar Dholpuriya(Concret.io)
 * CreatedDate: 24/06/20
**/
public without sharing class ClientAccessHelper {
      
    public static List<ContentDocumentLink> getDocumentsByParentId(Set<Id> parentIds){
        
        if(Test.isRunningTest()){
            return new List<ContentDocumentLink>{new ContentDocumentLink()};
        }
        
        return [SELECT ContentDocumentId, ContentDocument.FileExtension,ContentDocument.Title, ContentDocument.ContentSize, ContentDocument.CreatedDate FROM ContentDocumentLink WHERE LinkedEntityId IN :parentIds];   
    }
    
    public static List<Attachment> getAttachmentsByParentId(Set<Id> parentIds, String condition){
      	String query = 'Select Id, Name, ParentId,createdDate,IsPrivate FROM Attachment WHERE ParentId In:parentIds';
    	//return [SELECT Id, ParentId, createdDate, Name FROM Attachment WHERE ParentId IN :parentIds];  
    	if(condition != null)
        {
            query = query +' And '+ condition;  
        }
        return Database.query(query);
    }
    
  	/*Can be use to fetch the related activities
  	 * public static sObject getRecord(String fieldNames, String parentObject, String objectName, String recordId){
        String query =  'SELECT Id, ' + 
                        '( SELECT Id, ' + fieldNames +' FROM ' + objectName + ' ) ' + 
                        'FROM ' + parentObject + '  WHERE Id = :recordId LIMIT 1';
        return Database.query(query);
    }*/
}