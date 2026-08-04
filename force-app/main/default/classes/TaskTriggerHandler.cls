/**
 * Description: This class will process the task data and check the custom validation
 * CreatedBy  : Rajkumar Dholpuriya(Concret.io)
 * CreatedDate: 05/07/20
**/
public class TaskTriggerHandler
{
    //this method will check the if the case is open then one task should be open
    public static void afterUpdate(List<Task> newRecords, Map<Id, Task> oldTask)
    {
        List<Id> contactIds = new List<Id>();
        
        //get all completed task contact ids
        for(Task tsk : newRecords)
        {
            if(tsk.Status == 'Completed' && oldTask.get(tsk.Id).Status != 'Completed')
            {
                contactIds.add(tsk.WhoId);
            }
        }
        
        List<Case> caseOpenList = [SELECT Id, ContactId FROM Case 
                                   WHERE ContactId IN :contactIds 
                                    AND Status NOT IN ('Closed', 'CaseClosed_WithClaim', 'CaseClosed_NoClaim')];
        
        if(caseOpenList.isEmpty())
        {
            return;
        }
        
        List<Id> caseOpenContactIds = new List<Id>();
        
        for( Case cse : caseOpenList)
        {
            caseOpenContactIds.add(cse.ContactId);
        }
        
        Map<Id, List<Task>> mapOfOpenTask = new Map<Id, List<Task>>();
        
        for(Task tsk : [SELECT Id, WhoId FROM Task WHERE WhoId IN :caseOpenContactIds AND Status = 'Open'])
        {
            if(mapOfOpenTask.containsKey(tsk.WhoId))
            {
                mapOfOpenTask.get(tsk.WhoId).add(tsk);
            }
            else
            {
                mapOfOpenTask.put(tsk.WhoId, new List<Task>{tsk});
            }
        }
        
        System.debug('Number of open tasks:' + mapOfOpenTask);
        
        Set<String> documentRequestSubjects = new Set<String>{
            'Itemized Bill Request', 'Medical Records Request', 'Document Request',
            'Insurance Claim Request', 'Explanation of Benefits Request'
        };

        for(Task tsk : newRecords)
        {
            if(tsk.Status != 'Completed' || oldTask.get(tsk.Id).Status == 'Completed')
            {
                continue;
            }

            // Document-request tasks are completed programmatically by CaseDocumentSharingController
            // and do not require a follow-up task, so skip the open-task validation for them.
            if(documentRequestSubjects.contains(tsk.Subject))
            {
                continue;
            }

            if(!mapOfOpenTask.containsKey(tsk.WhoId))
            {
                tsk.adderror('Please create follow up task as Case is still open');
            }
        }
    }
    
    public static void makeTaskPublic(List<Task> newRecords)
    {
        //get all shared account ids
        Set<Id> accountIds = TaskAndEventUtility.getAccountIdsSharedExternally();
        
        Set<Id> contactIds = new Set<Id>();
        
        for(Task tsk : newRecords)
        {
            if(tsk.WhoId != null && String.valueOf(tsk.WhoId).contains('003'))
            {
                contactIds.add(tsk.WhoId);
            }
        }
        
        //get related contacts
        Map<Id, Contact> contactMap = TaskAndEventUtility.getContactsMap(contactIds, accountIds);
        
        for(Task tsk : newRecords)
        {
            if(contactMap.containsKey(tsk.WhoId) 
               && !String.isBlank(tsk.Subject) 
               && tsk.Subject.trim().subString(0, 1) != '7')
            {
                tsk.IsVisibleInSelfService = true;
            }
    	}
    }
    
    public static void handleAfter(List<Task> newList, Map<Id, Task> oldMap, Boolean isInsert, Boolean isUpdate) {
        if (isInsert) {
            TaskNotificationHandler.handleAfterInsert(newList);
        }
        if (isUpdate) {
        TaskNotificationHandler.handleAfterUpdate(newList, oldMap);
        }
    }

    //Before Insert and Before Update
    public static void calculateTimeOfBilling(List<Task> taskRecords, Map<Id, Task> oldTaskMap)
    {
        for( Task tsk : taskRecords ){
            if( oldTaskMap == null || (oldTaskMap != null && oldTaskMap.containsKey(tsk.Id) && (tsk.Start_Time__c != oldTaskMap.get(tsk.Id).Start_Time__c  || tsk.Stop_Time__c != oldTaskMap.get(tsk.Id).Stop_Time__c))){
                if( tsk.Start_Time__c != null && tsk.Stop_Time__c != null){
                    tsk.Total_Time_Of_Completing_Task__c = ContactPdfController.calculateTimeAmount(tsk.Start_Time__c, tsk.Stop_Time__c); 
                }
                else{
                    tsk.Total_Time_Of_Completing_Task__c = 0;
                }
            } 
        }
        
    }
}