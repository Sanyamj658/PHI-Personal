trigger ContentDocumentLinkTrigger on ContentDocumentLink (after insert) {
    if (Trigger.isAfter && Trigger.isInsert) {
        // DocumentShareNotificationHandler.handleAfterInsert(Trigger.new);
    }
}