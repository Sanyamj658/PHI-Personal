/**
 * ─────────────────────────────────────────────────────────────────────────────────────────────────┐
 * This class is the controller class of TaskEditPage Visualforce Page.
 * ──────────────────────────────────────────────────────────────────────────────────────────────────
 * @author      : concret.io
 * @createdOn   : 12-May-2025    
 * ──────────────────────────────────────────────────────────────────────────────────────────────────
 */
public class TaskEditPageCtrl {
    public Task task { get; set; }
    public String taskSubject {get; set;}
    public String objectAPIName { get; set; }
    public String parentRecordIdValue {get; set;}
    public String parentRecordNameValue {get; set;}

    public TaskEditPageCtrl(ApexPages.StandardController std) {}

    public PageReference init() {
        taskSubject = 'New Task';
        objectAPIName = '';
        parentRecordIdValue = '';
        parentRecordNameValue = '';
        String taskId = ApexPages.currentPage().getParameters().get('id');
        System.debug('taskId----------->'+taskId);
        if (String.isNotBlank(taskId)) {
            task = [SELECT Id, WhatId, WhoId, Claim_Assigned_To__c, Related_to_Complaints__c, IsVisibleInSelfService, Category__c,
                Subject, Status, Priority, ActivityDate, Description, OwnerId, Name__c, Attorney__c, Start_Time__c, Stop_Time__c
                FROM Task 
                WHERE Id = :taskId 
                LIMIT 1
            ];
            if (task != null) {
                taskSubject = task.Subject;
                if (task.WhatId != null) {
                    parentRecordIdValue = task.WhatId;
                    objectAPIName = getEntityTypeFromWhatId(task.WhatId);
                } 
            }
        } else {
            task = new Task();
            task.OwnerId = UserInfo.getUserId();
            task.Status = 'Open';
            task.Priority = 'Normal';
            task.Claim_Assigned_To__c = 'ADMINISTRATOR';

            String whatId = ApexPages.currentPage().getParameters().get('what_id');
            String whoId = ApexPages.currentPage().getParameters().get('who_id');
            if (String.isNotBlank(whatId)) {
                parentRecordIdValue = whatId;
                objectAPIName = getEntityTypeFromWhatId(whatId);
            }        
            if (String.isNotBlank(whoId)) {
                task.WhoId = whoId;
            } 
        }
        if (String.isNotBlank(objectAPIName) && String.isNotBlank(parentRecordIdValue)) {            
            String query = 'SELECT Name FROM ' + objectApiName + ' WHERE Id = :parentRecordIdValue LIMIT 1';
            List<SObject> results = Database.query(query);
            if (!results.isEmpty()) {
                parentRecordNameValue = String.valueOf(results[0].get('Name'));
            }
        }
        return null;
    }
    
    public PageReference save() {
        try {
            if (String.isNotBlank(parentRecordIdValue)) {
                task.WhatId = parentRecordIdValue;
            }     
            String operation = String.isNotBlank(task.Id) ? 'updated' : 'created';       
            upsert task;
            ApexPages.addMessage(new ApexPages.message(ApexPages.Severity.CONFIRM, 'Task '+operation+' successfully'));
            String retUrl = ApexPages.currentPage().getParameters().get('retURL');
            if (retUrl != null) {
                return new PageReference(retUrl).setRedirect(true);
            }
            return new PageReference('/' + task.Id).setRedirect(true);
        } 
        catch (Exception e) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, e.getMessage()));
            return null;
        }
    }

    public PageReference cancel() {
        String retUrl = ApexPages.currentPage().getParameters().get('retURL');
        if (String.isNotBlank(retUrl)) {
            return new PageReference(retUrl).setRedirect(true);
        }
        return new PageReference('/' + (task != null ? task.Id : '')).setRedirect(true);
    }

    private String getEntityTypeFromWhatId(String entityId) {
        if (entityId.startsWith('001')) {
            return 'Account';
        } 
        if (entityId.startsWith('a02')) {
            return 'Insurance_Company__c';
        }     
        return '';
    }

    public List<SelectOption> objectList {
		get {
			objectList = new List<SelectOption>();
            objectList.add(new SelectOption('Account', 'Medical Provider'));
            objectList.add(new SelectOption('Insurance_Company__c', 'Insurance Company'));
			return objectList;
		}
		set;
	}
}