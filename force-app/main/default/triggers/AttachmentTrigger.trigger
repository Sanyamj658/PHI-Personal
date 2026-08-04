trigger AttachmentTrigger on Attachment (before insert) {
    If((Trigger.isBefore) && (Trigger.isInsert ))
    {
        System.debug('in trigger');
        AttachmentTriggerHandler.setPrivateStatus(Trigger.new);
    }
}