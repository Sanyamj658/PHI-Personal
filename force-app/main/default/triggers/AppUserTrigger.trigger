trigger AppUserTrigger on App_User__c (after update, after insert) {
    if (Trigger.isAfter && Trigger.isUpdate) {
         AppUserNotificationHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
    }

    if (Trigger.isAfter && Trigger.isInsert) {
       //  AppUserNotificationHandler.handleAfterInsert(Trigger.new);
        Boolean shouldRunBatch = false;
         for (App_User__c appUser : Trigger.new) {
        if (appUser.Status__c == 'Pending') {
            shouldRunBatch = true;
            break;
        }
    }
    if (shouldRunBatch) {
        // Optional: Prevent multiple batch executions
        if (!System.isBatch()) {
            Database.executeBatch(
                new PatientAppMatchingBatch(),
                200
            );
        }
    }
    }

}