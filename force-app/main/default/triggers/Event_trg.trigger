trigger Event_trg on Event (before insert) {
    
    //make the Event public for the community user only
    EventTriggerHandler.makeEventPublic(Trigger.New);
}