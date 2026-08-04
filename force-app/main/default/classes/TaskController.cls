public class TaskController {
    public Task task { get; set; }
    public String selectedWhatId { get; set; }

    public TaskController(ApexPages.StandardController std) {
        this.task = (Task)std.getRecord();
    }

    public List<SelectOption> getWhatIdOptions() {
        List<SelectOption> options = new List<SelectOption>();
        options.add(new SelectOption('', '-- None --'));

        for (Account acc : [SELECT Id, Name FROM Account LIMIT 50]) {
            options.add(new SelectOption(acc.Id, 'Medical Provider: ' + acc.Name));
        }

        for (Contact con : [SELECT Id, Name FROM Contact LIMIT 50]) {
            options.add(new SelectOption(con.Id, 'Patient: ' + con.Name));
        }

        for (Insurance_Company__c ic : [SELECT Id, Name FROM Insurance_Company__c LIMIT 50]) {
            options.add(new SelectOption(ic.Id, 'Insurance Company: ' + ic.Name));
        }

        return options;
    }

    public PageReference saveTask() {
        if (selectedWhatId != null && selectedWhatId != '') {
            task.WhatId = selectedWhatId;
        }

        try {
            insert task;
            return new PageReference('/' + task.Id);
        } catch (Exception e) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Error saving Task: ' + e.getMessage()));
            return null;
        }
    }

    public PageReference cancel() {
        return new PageReference('/' + task.Id);
    }
}