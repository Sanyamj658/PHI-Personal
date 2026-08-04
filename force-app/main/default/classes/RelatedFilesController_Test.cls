/**
 * Description: This class will test the RelatedFilesController.
 * CreatedBy  : Rajkumar Dholpuriya(Concret.io)
 * CreatedDate: 26/06/20
**/
@isTest
public class RelatedFilesController_Test {
    
    @testSetup
    public static void setup(){
        
        Contact testContact = new Contact(LastName = 'Test 1');
        INSERT testContact;
        
        ContentVersion contentVersion = new ContentVersion(
            Title = 'Penguins',
            PathOnClient = 'Penguins.jpg',
            VersionData = Blob.valueOf('Test Content'),
            IsMajorVersion = true
        );
        
        INSERT contentVersion; 
        
        List<ContentDocument> documents = [SELECT Id FROM ContentDocument];
        
        //create ContentDocumentLink  record 
        ContentDocumentLink cdl = New ContentDocumentLink();
        cdl.LinkedEntityId = testContact.id;
        cdl.ContentDocumentId = documents[0].Id;
        cdl.shareType = 'V';
        
        INSERT cdl; 
        
        Attachment_Exception_Keywords__c keywordRec = new Attachment_Exception_Keywords__c();
        keywordRec.Name='Complaint';
        insert keywordRec;

        Attachment attachment1 = new Attachment();
        String jsonStr = 'TheBlogReaders.com';
        Blob tempBlob = Blob.valueOf(jsonStr);
        attachment1.ParentId= testContact.Id;
        attachment1.Name='Complaint.jpg';
        attachment1.IsPrivate=false;
        attachment1.ContentType='application/pdf';
        attachment1.body=tempBlob ;
        
        Attachment attachment2 = new Attachment();
        attachment2.ParentId= testContact.Id;
        attachment2.Name='Test.jpg';
        attachment2.IsPrivate=false;
        attachment2.ContentType='application/pdf';
        attachment2.body=tempBlob ;
        insert new List<Attachment>{attachment1, attachment2};
    }
    
    @isTest
    public static void getRelatedFileIdsTest(){
        
        Contact cont = [SELECT Id FROM Contact];
        
        System.assertNotEquals(null, cont.Id);
        
        Test.startTest();
        
        List<sObject> relatedFiles = RelatedFilesController.getRelatedFileIds(cont.Id);
        
        Test.stopTest();
        
        System.assertEquals(2, relatedFiles.size(), 'File Not Found');
    }
    
    @isTest
    static void testMedicalProviderList(){
        
        Account medicalProvider = new Account(Name = 'Test Account');
        INSERT medicalProvider;
        
        Contact cont = [SELECT Id FROM Contact];
        
        Insurance_Company__c comp = new Insurance_Company__c(Name = 'Test Insurance');
        INSERT comp;
        
        Claim__c claim = new Claim__c(Patient__c = cont.Id, Medical_Provider__c = medicalProvider.Id,
                                     From_DOS__c = System.today(), To_DOS__c = System.today(),
                                      Insurance_Company__c = comp.Id, Invoice_Number__c = '213456');
        INSERT claim;
        
        ContentVersion contentVersion = new ContentVersion(
            Title = 'Penguins',
            PathOnClient = 'Penguins.jpg',
            VersionData = Blob.valueOf('Test Content'),
            IsMajorVersion = true
        );
        
        INSERT contentVersion; 
        
        List<ContentDocument> documents = [SELECT Id FROM ContentDocument];
        
        //create ContentDocumentLink  record 
        ContentDocumentLink cdl = New ContentDocumentLink();
        cdl.LinkedEntityId = claim.id;
        cdl.ContentDocumentId = documents[0].Id;
        cdl.shareType = 'V';
        
        INSERT cdl;
        
        System.assertNotEquals(null, medicalProvider.Id);
        
        Test.startTest();
        
        List<sObject> relatedFiles = RelatedFilesController.getRelatedFileIds(medicalProvider.Id);
        
        Test.stopTest();
        
        System.assertEquals(1, relatedFiles.size(), 'File Not Found');
    }
}