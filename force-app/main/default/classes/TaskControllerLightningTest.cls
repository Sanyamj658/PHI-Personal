@isTest
public class TaskControllerLightningTest {
	
    @isTest
    static void createTaskTest() {
        Task dummyTask = new Task(Subject = 'Test Task', Name__c='Admin');
        insert dummyTask;
        
        DateTime startTime = System.now();
        DateTime stopTime = startTime.addMinutes(15);        
        String startDateTimeStr = startTime.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
        String stopDateTimeStr = stopTime.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
        
        List<String> fieldNames = new List<String>{'Category__c','Subject', 'Description' , 'Claim_Assigned_To__c', 'Status', 
            'Priority', 'IsVisibleInSelfService', 'Name__c', 'WhatId', 'Related_to_Complaints__c', 'Claim_Assigned_To__c'
        };
     	
		Test.startTest();        
        Boolean isTaskCreated = false;
        Boolean isSystemAdmin = false;
        Map<String, Object> taskResultMap = new Map<String,Object>();
        
        isSystemAdmin = TaskControllerLightning.isSystemAdmin();
        Assert.isTrue(isSystemAdmin, 'Expected true because the user is a System Administrator');
        
        isTaskCreated = TaskControllerLightning.createTask(null, null, null);
        Assert.isFalse(isTaskCreated, 'Expected false because invalid jsonData was provided');
        
        isTaskCreated = TaskControllerLightning.createTask(JSON.serialize(dummyTask), startDateTimeStr, stopDateTimeStr);
        Assert.isTrue(isTaskCreated, 'Expected true because valid task data was provided');
        
        taskResultMap = TaskControllerLightning.getTaskByRecordId(null);
        Assert.isNull(taskResultMap, 'Expected taskResultMap to be null');
        
        taskResultMap = TaskControllerLightning.getTaskByRecordId(dummyTask.Id);
        Assert.isNotNull(taskResultMap, 'Expected taskResultMap to be non-null');
        
        Map<String, Map<String, Object>> metadataMap = TaskControllerLightning.getFieldMetadata(fieldNames);
        Assert.isNotNull(metadataMap, 'Expected metadata map to be non-null');
    }
}