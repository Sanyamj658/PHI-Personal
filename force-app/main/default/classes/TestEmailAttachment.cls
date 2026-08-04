@isTest(SeeAllData=true)
public class TestEmailAttachment{
    public static testMethod void EmailAttachmentTester(){
        
        // setup controller object
        emailparsing objconfirm = new emailparsing();
        System.debug('Im starting a method');
        
        //Create an Account for the opportunity to be created
        Account acc = new Account();
        acc.Name = 'M.Choudhury';
        insert acc;
        Contact coc = new Contact();
        coc.lastname='test';
        coc.accountid=acc.id;
        insert coc;
        
        Contact c=[select id from contact where id=:coc.id];
        
        // Create a new email, envelope object and Attachment
        Messaging.InboundEmail email = new Messaging.InboundEmail();
        Messaging.InboundEnvelope envelope = new Messaging.InboundEnvelope();
        objconfirm.handleInboundEmail(email, envelope);
        
        email.subject = c.id;
        email.plainTextBody = 'Hello, this a test email body. for testing purposes only. Bye';
        envelope.fromAddress = 'sirangisunilkumar@gmail.com';
        Messaging.InboundEmail.BinaryAttachment binaryAttachment = new Messaging.InboundEmail.BinaryAttachment();
        binaryAttachment.Filename = 'test.pdf';
        binaryAttachment.body = blob.valueOf('my attachment text');
        email.binaryAttachments = new Messaging.inboundEmail.BinaryAttachment[] { binaryattachment };
        objconfirm.handleInboundEmail(email, envelope);
        Messaging.InboundEmailResult result = objconfirm.handleInboundEmail(email, envelope);
        System.assertEquals( result.success  ,true);
    }
}