trigger Taskduedate on Task (Before insert, Before update, After Update) {
    
    if( Trigger.isBefore && (Trigger.isInsert || Trigger.isUpdate)){
        TaskTriggerHandler.calculateTimeOfBilling(Trigger.New, Trigger.OldMap);
    }
    if(Trigger.isUpdate && Trigger.isAfter)
    {
        TaskTriggerHandler.afterUpdate(Trigger.NEW, Trigger.oldMap);
        // TaskNotificationHandler.handleAfterUpdate(Trigger.NEW, Trigger.oldMap);
    }
}