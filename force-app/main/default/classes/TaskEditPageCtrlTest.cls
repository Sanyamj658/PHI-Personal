@isTest
public class TaskEditPageCtrlTest {
    
    @testsetup
    static void setup() {        
        Account medicalProvider = new Account(Name = 'Test Medical Provider', Account_Manager_Name__c = 'Test Manager');
        insert medicalProvider;
        
        Insurance_Company__c insuranceObject = new Insurance_Company__c();
        insuranceObject.Name = 'TestInsurance';
        insert insuranceObject;
        
        Contact patient = new Contact(accountId = medicalProvider.Id, LastName= 'Test Patient', Primary_Insurance__c = insuranceObject.Id, DX_s__c = 'XXXXX', Plan_Type__c='Other Plan');
        insert patient;
        
        Task dummyTask = new Task(Subject = 'Test Task', Name__c='Admin', WhatId = medicalProvider.Id, WhoId = patient.Id);
        insert dummyTask;
    }
    
    @isTest
    static void testInit_createTask() {
        Task dummyTask = [SELECT Id FROM Task WHERE Subject = 'Test Task' LIMIT 1];
        
        Test.setCurrentPageReference(new PageReference('/apex/TaskEditPage'));
        ApexPages.currentPage().getParameters().put('id', dummyTask.Id);                
		ApexPages.StandardController stdController = new ApexPages.StandardController(dummyTask);
        
        TaskEditPageCtrl page = new TaskEditPageCtrl(stdController);
        page.init();
        Assert.areEqual('Test Task', page.taskSubject, 'Task subject should match the inserted task');
        Assert.areEqual('Account', page.objectAPIName, 'objectAPIName should be set to Account');
        
        List<SelectOption> objectList = page.objectList;
        Assert.areEqual(2, objectList.size(), 'Object list should contain 2 entries');
        
        PageReference saveResult = page.save();
        Assert.isNotNull(saveResult, 'Should return a redirect PageReference');
        
        PageReference cancelResult = page.cancel();
        Assert.isNotNull(cancelResult, 'Should return a PageReference');
    }
    
    @isTest
    static void testInit_editTaskWithMedicalProvider() {        
        Task dummyTask = [SELECT Id FROM Task WHERE Subject = 'Test Task' LIMIT 1];
        Contact patient = [SELECT Id FROM Contact WHERE LastName= 'Test Patient' LIMIT 1];
        Account medicalProvider = [SELECT Id FROM Account WHERE Name = 'Test Medical Provider' LIMIT 1];
        
        Test.setCurrentPageReference(new PageReference('/apex/TaskEditPage'));
        ApexPages.currentPage().getParameters().put('what_id', medicalProvider.Id);        
        ApexPages.currentPage().getParameters().put('who_id', patient.Id);        
        
		ApexPages.StandardController stdController = new ApexPages.StandardController(dummyTask);
        
        TaskEditPageCtrl page = new TaskEditPageCtrl(stdController);
        page.init();
        Assert.areEqual('Account', page.objectAPIName, 'objectAPIName should be Account');
    }
    
    @isTest
    static void testInit_editTaskWithInsuranceCompany() {
        Task dummyTask = [SELECT Id FROM Task WHERE Subject = 'Test Task' LIMIT 1];
        Contact patient = [SELECT Id FROM Contact WHERE LastName= 'Test Patient' LIMIT 1];
        Insurance_Company__c insuranceObject = [SELECT Id FROM Insurance_Company__c WHERE Name = 'TestInsurance' LIMIT 1];
        
        Test.setCurrentPageReference(new PageReference('/apex/TaskEditPage'));
        ApexPages.currentPage().getParameters().put('what_id', insuranceObject.Id);        
        ApexPages.currentPage().getParameters().put('who_id', patient.Id);        
        
		ApexPages.StandardController stdController = new ApexPages.StandardController(dummyTask);
        
        TaskEditPageCtrl page = new TaskEditPageCtrl(stdController);
        page.init();
        Assert.areEqual('Insurance_Company__c', page.objectAPIName, 'objectAPIName should be Insurance_Company__c');
    }  
}