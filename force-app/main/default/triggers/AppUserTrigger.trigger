trigger AppUserTrigger on App_User__c (before insert) {
    if (Trigger.isBefore && Trigger.isInsert) {
      AppUserNotificationHandler.matchAppUserToPatients(Trigger.new);
    }

}