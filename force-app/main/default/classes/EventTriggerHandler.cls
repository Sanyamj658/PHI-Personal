/**
 * Description: This class will make event public
 * CreatedBy  : Rajkumar Dholpuriya(Concret.io)
 * CreatedDate: 08/07/20
**/
public class EventTriggerHandler
{
    public static void makeEventPublic(List<Event> newRecords)
    {
        //get all shared account ids
        Set<Id> accountIds = TaskAndEventUtility.getAccountIdsSharedExternally();
        
        Set<Id> contactIds = new Set<Id>();
        
        for(Event evt : newRecords)
        {
            if(evt.WhoId != null && String.valueOf(evt.WhoId).contains('003'))
            {
                contactIds.add(evt.WhoId);
            }
        }
        
        //get related contacts
        Map<Id, Contact> contactMap = TaskAndEventUtility.getContactsMap(contactIds, accountIds);
        
        for(Event evt : newRecords)
        {
            if(contactMap.containsKey(evt.WhoId) 
               && !String.isBlank(evt.Subject) 
               && evt.Subject.trim().subString(0, 1) != '7')
            {
                evt.IsVisibleInSelfService = true;
            }
    	}
    }
}