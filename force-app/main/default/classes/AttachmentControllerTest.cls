@isTest
public class AttachmentControllerTest {
    @testSetup
    static void setup() {
        Account medicalProvider = new Account(Name = 'Test Medical Provider', Account_Manager_Name__c = 'PHI Manager');
        insert medicalProvider;    
        
        Attachment attachmentRecord = new Attachment();
        attachmentRecord.isPrivate = false;
        attachmentRecord.Name = 'examplefile.txt';        
        attachmentRecord.ContentType = 'text/plain';
        attachmentRecord.ParentId = medicalProvider.Id;
        attachmentRecord.Description = 'Test Description';
        attachmentRecord.Body = Blob.valueOf('This is the content of the file.');        
        insert attachmentRecord;        
    }    
    
    @isTest
    static void getAttachmentsTest() {  
        Id accountId = [SELECT Id FROM Account WHERE Name = 'Test Medical Provider' LIMIT 1].Id;
        
        Test.startTest();
        List<AttachmentController.AttachmentWrapper> attachments = AttachmentController.getAttachments(accountId);
        Test.stopTest();
        
        Assert.areEqual(1, attachments.size(), 'There should be exactly one attachment.');
        Assert.areEqual('examplefile.txt', attachments[0].name, 'Attachment name should match.');
        Assert.isFalse(attachments[0].isPrivate, 'Attachment should not be private.');
    }
    
    @isTest
    static void deleteAttachmentTest() {
        Id attachmentId = [SELECT Id FROM Attachment WHERE Name = 'examplefile.txt' LIMIT 1].Id;
        
        Test.startTest();
        AttachmentController.deleteAttachment(attachmentId);
        Test.stopTest();
        
        // SOQL the Attachment records including deleted records (All Rows)
        Attachment deletedAttachment = [SELECT Id, IsDeleted FROM Attachment WHERE Id = :attachmentId LIMIT 1 ALL ROWS];
        Assert.isTrue(deletedAttachment.IsDeleted, 'Attachment should be marked as deleted.');
    }
    
    @isTest
    static void updateAttachmentTest() {
        String updatedName = 'updateExampleFile.txt';
        Boolean updatedIsPrivate = false;
        String updatedDescription = 'Test Updated Description';
        Id attachmentId = [SELECT Id FROM Attachment WHERE Name = 'examplefile.txt' LIMIT 1].Id;
        
        Test.startTest();
        AttachmentController.updateAttachment(attachmentId, updatedName, updatedIsPrivate, updatedDescription);
        Test.stopTest();
        
        Attachment updatedAttachment = [SELECT Id, Name, IsPrivate, Description FROM Attachment WHERE Id = :attachmentId LIMIT 1];
        Assert.areEqual(updatedName, updatedAttachment.Name, 'Attachment name should be updated.');
        Assert.areEqual(updatedIsPrivate, updatedAttachment.IsPrivate, 'Attachment privacy should be updated.');
        Assert.areEqual(updatedDescription, updatedAttachment.Description, 'Attachment description should be updated.');
    }    
    
    @isTest
    static void deleteContentDocument() {
        Test.startTest();
        Profile standardProf = [select id from profile where name='Collectors']; 
        User su = new User(alias = 'standt', email='standarduser@testorg.com', 
            emailencodingkey='UTF-8', lastname='Testing1', languagelocalekey='en_US', 
            localesidkey='en_US', profileid = standardProf.Id, 
            timezonesidkey='America/Los_Angeles', username='standarduser56h7@testorg.com'
        );    
        System.runAs(su) {  
            ContentVersion cv = new ContentVersion(Title='Test File', PathOnClient = 'file.txt', VersionData = Blob.valueOf('Test File Content.'));
            insert cv;            
            Id contentDocumentId = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1].ContentDocumentId;
            ContentDocument doc = [SELECT Id, Title FROM ContentDocument WHERE Id = :contentDocumentId LIMIT 1];
            Assert.areNotEqual(null, doc, 'ContentDocument should exist before deletion.');
        
            Boolean errorThrown = false; 
            try {
                delete doc;
            } catch (Exception e) {
                System.debug(e);
                if (e.getMessage().contains('Only System Administrator can delete this record')) {
                    errorThrown = true;
                }
            }
            Assert.isTrue(errorThrown, 'Error should be thrown.');
        }
        Test.stopTest();
    }
}