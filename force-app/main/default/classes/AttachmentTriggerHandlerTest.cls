@isTest
public class AttachmentTriggerHandlerTest {
    
    @testSetup
    public static void setup()
    {
        Attachment_Exception_Keywords__c obj = new Attachment_Exception_Keywords__c();
        obj.Name='Complaint';
        insert obj;
        
        Account acc = new Account();
        acc.Name='TrialAcc';
        insert acc;
        
        Contact p = new Contact();
        p.AccountId=acc.Id;
        p.LastName='Trial';
        p.Account_Status__c='Verification work in process';
        insert p;
    }
    @isTest
    public static void setPrivateStatusTest()
    {
        
        List<Contact> contacts = [SELECT Id FROM Contact];
        Test.startTest();
        Attachment pass = new Attachment();
        String jsonStr = 'TheBlogReaders.com';
        Blob tempBlob = Blob.valueOf(jsonStr);
        pass.ParentId= contacts[0].Id;
        pass.Name='Complaint.jpg';
        pass.IsPrivate=false;
        pass.ContentType='application/pdf';
        pass.body=tempBlob ;
        insert pass;
        Test.stopTest();
        
        Attachment attachmentRec = [Select Id,ParentId,Name,IsPrivate from Attachment where Name='Complaint.jpg' Limit 1];
        System.assertEquals(false, attachmentRec.IsPrivate);
    }
}