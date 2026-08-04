trigger Task_trg on Task (before insert, after insert, after update) {
    
    //make the task public for the community user only
    if(trigger.isBefore){
     TaskTriggerHandler.makeTaskPublic(Trigger.New);
    }
    
    if(trigger.isAfter){
     	TaskTriggerHandler.handleAfter(Trigger.new, Trigger.oldMap, Trigger.isInsert, Trigger.isUpdate);
    }

}