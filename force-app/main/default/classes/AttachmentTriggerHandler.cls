public class AttachmentTriggerHandler {
	public static void setPrivateStatus(List<Attachment> newAttachmentList)
    {
        Boolean isMatched=false;
        List<Attachment_Exception_Keywords__c> exceptionKeywords = [Select Name from Attachment_Exception_Keywords__c];
        for(Attachment obj : newAttachmentList)
        {
            isMatched=false;
            String id = (String)obj.ParentId;
            if(id.startsWith('003'))
            {
                for(Attachment_Exception_Keywords__c ack : exceptionKeywords)
                {
                    if(obj.Name.containsIgnoreCase(ack.Name))
                    {
                        isMatched=true;
                        break;
                    }
                }
                if(isMatched == true)
                {
                   obj.IsPrivate = true;
                }
            }
        }
    }
}