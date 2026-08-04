public class TaskAndEventUtility{
    
    public static Set<Id> getAccountIdsSharedExternally ()
    {    
        List<AccountShare> accShares = [SELECT Id, AccountId FROM AccountShare 
										WHERE UserOrGroupId IN (SELECT Id FROM User WHERE Profile.Name = 'Client Access User')];
        Set<Id> accountIds = new Set<Id>();
        
        for(AccountShare accShare: accShares)
        {
            accountIds.add(accShare.AccountId);
        }
        
        return accountIds;
    }
    
    public static Map<Id, Contact> getContactsMap(Set<Id> contactIds, Set<Id> accountIds)
    {
        return new Map<Id, Contact>([SELECT Id FROM Contact 
                                     WHERE Id IN :contactIds 
                                      AND AccountId IN :accountIds]);
    }
}