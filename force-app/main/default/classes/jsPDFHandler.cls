public with sharing class jsPDFHandler {
    
    @AuraEnabled
    public static Claim__c fetchClaimDetails(String recordId){
        Claim__c claimObj;
        try{
            claimObj = [SELECT Final_Payment_Summary_Num__c,Insurance_Company__c, Name, Medical_Provider__r.Name, Medical_Provider__r.ShippingStreet, Medical_Provider__r.ShippingPostalCode, Medical_Provider__r.ShippingCity, Medical_Provider__r.ShippingState, Medical_Provider__r.ShippingCountry, Medical_Provider__r.invoice_description__c, Patient__r.name, Patient__r.Email, Total_Charge__c, Total_Amount_Paid__c, From_DOS__c, To_DOS__c, Total_Amount_Unpaid__c FROM Claim__c WHERE Id = :recordId LIMIT 1];
        }       
        catch(Exception ex){
            System.debug('Exception Occured: '+ex.getMessage());
        }
        return claimObj;
    }

  /*  @AuraEnabled
    public static void sendEmailWithContentVersionAttachment(String contentVersionId, String recipientEmail, String emailSubject, String emailBody) {

        System.debug('contentVersionId: '+contentVersionId);
        System.debug('recipientEmail: '+recipientEmail);
        System.debug('emailSubject: '+emailSubject);
        System.debug('emailBody: '+emailBody);
        
        // Query the ContentVersion record
        ContentVersion contentVersion = [SELECT Id, Title, VersionData FROM ContentVersion WHERE Id = :contentVersionId LIMIT 1];
        System.debug(contentVersion);
        
        // Create an Email Attachment
        Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
        attachment.setFileName(contentVersion.Title); // Set the attachment filename
        attachment.setBody(contentVersion.VersionData); // AttachmentBody Required Field

        // Create and send the Email Message
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setSubject(emailSubject);
        email.setHtmlBody(emailBody);
        email.setToAddresses(new String[]{recipientEmail});
        email.setFileAttachments(new Messaging.EmailFileAttachment[]{attachment});

        // Send the email
        Messaging.SendEmailResult[] result = Messaging.sendEmail(new Messaging.SingleEmailMessage[]{email});
        System.debug('result: '+result);
        
        // Handle the email sending result if needed
        if (result[0].isSuccess()) {
            System.debug('Email sent successfully!');
        } else {
            System.debug('Email sending failed: ' + result[0].getErrors()[0].getMessage());
        }
    } */
}