global class emailparsing implements Messaging.InboundEmailHandler  {
  global Messaging.InboundEmailResult handleInboundEmail(Messaging.InboundEmail email, Messaging.InboundEnvelope envelope){
     Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();
    try{
    system.debug('***try1');
    Contact c = [select Id from contact where id = :email.subject];
    List<Attachment> attList = new List<Attachment>();    
    for (Messaging.Inboundemail.BinaryAttachment file : email.binaryAttachments) 
    { 
      Contact c1 = [select Id from contact where id = :email.subject];
      Attachment attachment = new Attachment();
      attachment.Name = file .fileName;
      attachment.Body = file .body;
      attachment.ParentId = c1.id;
      attList .add(attachment);
   }
   if(attList .size()>0)
   {
     insert attList;
   }
       result.success = true;
   }
   catch (QueryException e1){
      system.debug('***catch1');
      result.success = false;
      result.message = 'The patient ID you entered in the subject could not be found';
    }
   catch(NullPointerException e2){
      system.debug('***catch2');
      result.success = false;
      result.message = 'No Attachments found';
   } 
   catch (Exception e) {
      system.debug('***catch3');
      result.success = false;
      String exception1=e.getMessage();
      result.message = exception1;
    }
   
    return result;         
}
}