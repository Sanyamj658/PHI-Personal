public class TaskDetailController {
    public Task taskRecord { get; set; }

    public TaskDetailController() {
        Id taskId = ApexPages.currentPage().getParameters().get('id');
        if (taskId != null) {
            taskRecord = [SELECT Id, Subject, Status, Priority, Description, WhatId, WhoId FROM Task WHERE Id = :taskId LIMIT 1];
        }
    }
}