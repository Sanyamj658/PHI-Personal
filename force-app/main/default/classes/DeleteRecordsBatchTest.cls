@isTest
public class DeleteRecordsBatchTest {
    @testSetup
    static void setup() {
        // Create test data
        List<Attachment> attachments = new List<Attachment>();
        Account acc = new Account(Name='test');
        INSERT acc;
        attachments.add(new Attachment(Name = 'delete', Body = Blob.valueOf('Test Attachment 1'), ParentId = acc.Id));
        attachments.add(new Attachment(Name = 'deleted', Body = Blob.valueOf('Test Attachment 2'), ParentId = acc.Id));
        attachments.add(new Attachment(Name = 'deleted.pdf', Body = Blob.valueOf('Test Attachment 3'), ParentId = acc.Id));
        attachments.add(new Attachment(Name = 'keep', Body = Blob.valueOf('Test Attachment 4'), ParentId = acc.Id));
        insert attachments;
    }

    @isTest
    static void testBatchExecution() {
        Test.startTest();
        
        // Schedule the batch job
        DeleteRecordsBatch.scheduleBatch(
            'Delete Attachments Job Test', 
            'Attachment', 
            'Name = \'delete\' OR Name = \'deleted\' OR Name = \'deleted.pdf\'', 
            false, 
            'test@example.com', 
            'Monthly'
        );
        
        // Execute the batch job immediately
        Database.executeBatch(new DeleteRecordsBatch(
            'Attachment', 
            'Name = \'delete\' OR Name = \'deleted\' OR Name = \'deleted.pdf\'', 
            false, 
            'test@example.com'
        ));
        
        Test.stopTest();
        
        // Verify that the correct records were deleted
        List<Attachment> remainingAttachments = [SELECT Id, Name FROM Attachment];
        System.assertEquals(1, remainingAttachments.size(), 'Expected one remaining attachment');
        System.assertEquals('keep', remainingAttachments[0].Name, 'Expected remaining attachment to have name "keep"');
    }

    @isTest
    static void testEmailNotification() {
        Test.startTest();
        
        // Schedule the batch job
        DeleteRecordsBatch.scheduleBatch(
            'Delete Attachments Job Test', 
            'Attachment', 
            'Name = \'delete\' OR Name = \'deleted\' OR Name = \'deleted.pdf\'', 
            false, 
            'test@example.com', 
            'Monthly'
        );
        
        // Execute the batch job immediately
        Database.executeBatch(new DeleteRecordsBatch(
            'Attachment', 
            'Name = \'delete\' OR Name = \'deleted\' OR Name = \'deleted.pdf\'', 
            false, 
            'test@example.com'
        ));
        
        Test.stopTest();
        
      
    }
}