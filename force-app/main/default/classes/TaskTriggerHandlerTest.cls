/**
 * TaskTriggerHandlerTest
 * Covers: afterUpdate – adderror on completing task when case is still open
 *         and no follow-up task exists; no error when follow-up exists;
 *         document-request subjects bypass validation; no open cases → no error.
 *         calculateTimeOfBilling – time calculated when start/stop set,
 *         zero when times are null, only recalculated when times change.
 *         handleAfter – delegates insert to TaskNotificationHandler.
 *         makeTaskPublic – runs without exception.
 */
@IsTest
private class TaskTriggerHandlerTest {

    @TestSetup
    static void setup() {
        Account acc = new Account(
    Name = 'TaskTrigger Hospital',
    Account_Manager_Name__c = 'Admin'
);
insert acc;

Insurance_Company__c insurance =
    new Insurance_Company__c(
        Name = 'Test Insurance'
    );
insert insurance;

Contact patient = new Contact(
    FirstName = 'TaskTrigger',
    LastName  = 'Patient',
    Email     = 'tasktrigger@example.com',
    DX_s__c   = 'TT01',
    AccountId = acc.Id,
    Primary_Insurance__c = insurance.Id,
    Plan_Type__c = 'Other Plan'
);
insert patient;

        Case openCase = new Case(
            Status    = 'New',
            Origin    = 'Phone',
            ContactId = patient.Id,
            AccountId = acc.Id
        );
        insert openCase;
    }

    private static Contact getPatient() {
        return [SELECT Id FROM Contact WHERE Email = 'tasktrigger@example.com' LIMIT 1];
    }

    private static Case getOpenCase() {
        return [SELECT Id, ContactId FROM Case WHERE Contact.Email = 'tasktrigger@example.com' LIMIT 1];
    }

   
    // ─── afterUpdate: no error when a follow-up task exists ──────────────────

    @IsTest
    static void testAfterUpdate_FollowUpExists_NoError() {
        Contact patient = getPatient();
        Case c          = getOpenCase();

        Task mainTask = new Task(
            Subject = 'Regular Task',
            WhoId   = patient.Id,
            WhatId  = c.Id,
            Name__c = 'Admin',
            Status  = 'Open'
        );
        insert mainTask;

        // Insert a follow-up open task for same contact
        insert new Task(Subject = 'Follow Up', WhoId = patient.Id, Status = 'Open', Name__c = 'Admin');

        Task old = mainTask.clone(true, true, true, true);
        old.Status = 'Open';
        mainTask.Status = 'Completed';

        Map<Id, Task> oldMap = new Map<Id, Task>{ mainTask.Id => old };

        Test.startTest();
        TaskTriggerHandler.afterUpdate(new List<Task>{ mainTask }, oldMap);
        Test.stopTest();

        System.assertEquals(0, mainTask.getErrors().size(), 'No error when follow-up task exists');
    }

    // ─── afterUpdate: document-request subject bypasses validation ───────────

    @IsTest
    static void testAfterUpdate_DocumentRequestSubject_BypassesValidation() {
        Contact patient = getPatient();
        Case c          = getOpenCase();

        List<String> docSubjects = new List<String>{
            'Itemized Bill Request',
            'Medical Records Request',
            'Document Request',
            'Insurance Claim Request',
            'Explanation of Benefits Request'
        };

        List<Task> tasksToCheck = new List<Task>();
        List<Map<Id, Task>> oldMaps = new List<Map<Id, Task>>();

        for (String subject : docSubjects) {
            Task docTask = new Task(
                Subject = subject,
                WhoId   = patient.Id,
                WhatId  = c.Id,
                Name__c = 'Admin',
                Status  = 'Open'
            );
            insert docTask;

            Task old = docTask.clone(true, true, true, true);
            old.Status = 'Open';
            docTask.Status = 'Completed';
            tasksToCheck.add(docTask);
            oldMaps.add(new Map<Id, Task>{ docTask.Id => old });
        }

        Test.startTest();
        for (Integer i = 0; i < tasksToCheck.size(); i++) {
            TaskTriggerHandler.afterUpdate(new List<Task>{ tasksToCheck[i] }, oldMaps[i]);
        }
        Test.stopTest();

        for (Task docTask : tasksToCheck) {
            System.assertEquals(0, docTask.getErrors().size(),
                'Document-request subject "' + docTask.Subject + '" should bypass validation');
        }
    }

    // ─── afterUpdate: no open cases → no error even without follow-up ────────

    @IsTest
    static void testAfterUpdate_NoOpenCase_NoError() {
     Account acc = [SELECT Id FROM Account LIMIT 1];

Insurance_Company__c insurance = [
    SELECT Id
    FROM Insurance_Company__c
    LIMIT 1
];

Contact orphan = new Contact(
    LastName = 'NoCase',
    DX_s__c = 'NC01',
    AccountId = acc.Id,
    Primary_Insurance__c = insurance.Id,
    Plan_Type__c = 'Other Plan'
);
insert orphan;

        Task t = new Task(Subject = 'No Case Task', WhoId = orphan.Id, Status = 'Open', Name__c = 'Admin');
        insert t;

        Task old = t.clone(true, true, true, true);
        old.Status = 'Open';
        t.Status   = 'Completed';

        Map<Id, Task> oldMap = new Map<Id, Task>{ t.Id => old };

        Test.startTest();
        TaskTriggerHandler.afterUpdate(new List<Task>{ t }, oldMap);
        Test.stopTest();

        System.assertEquals(0, t.getErrors().size(), 'No error when contact has no open cases');
    }

    // ─── afterUpdate: already completed task stays completed (no re-trigger) ─

    @IsTest
    static void testAfterUpdate_AlreadyCompleted_Skipped() {
        Contact patient = getPatient();

        Task t = new Task(Subject = 'Already Done', WhoId = patient.Id, Status = 'Completed', Name__c = 'Admin');
        insert t;

        // Old map also says Completed → condition (oldTask.Status == 'Completed') skips
        Task old = t.clone(true, true, true, true);
        Map<Id, Task> oldMap = new Map<Id, Task>{ t.Id => old };

        Test.startTest();
        TaskTriggerHandler.afterUpdate(new List<Task>{ t }, oldMap);
        Test.stopTest();

        System.assertEquals(0, t.getErrors().size(), 'Already-completed task should not trigger validation');
    }

    // ─── calculateTimeOfBilling: both times set ───────────────────────────────

    @IsTest
    static void testCalculateTimeOfBilling_BothTimesSet_Calculates() {
        Task t = new Task(
            Subject      = 'Billing Task',
            Start_Time__c = Datetime.newInstance(2024, 1, 1, 9, 0, 0),
            Stop_Time__c  = Datetime.newInstance(2024, 1, 1, 10, 30, 0)
        );

        Test.startTest();
        TaskTriggerHandler.calculateTimeOfBilling(new List<Task>{ t }, null);
        Test.stopTest();

        // Total_Time_Of_Completing_Task__c should be set (calculation via ContactPdfController)
        // Just verify no exception thrown and field is updated
        System.assertNotEquals(null, t.Total_Time_Of_Completing_Task__c,
            'Time should be calculated when both Start and Stop are provided');
    }

    // ─── calculateTimeOfBilling: missing start → zero ────────────────────────

    @IsTest
    static void testCalculateTimeOfBilling_MissingStart_Zero() {
        Task t = new Task(Subject = 'No Start', Stop_Time__c = Datetime.newInstance(2024, 1, 1, 10, 0, 0));

        Test.startTest();
        TaskTriggerHandler.calculateTimeOfBilling(new List<Task>{ t }, null);
        Test.stopTest();

        System.assertEquals(0, t.Total_Time_Of_Completing_Task__c,
            'Time should be zero when Start_Time__c is missing');
    }

    // ─── calculateTimeOfBilling: missing stop → zero ─────────────────────────

    @IsTest
    static void testCalculateTimeOfBilling_MissingStop_Zero() {
        Task t = new Task(Subject = 'No Stop', Start_Time__c = Datetime.newInstance(2024, 1, 1, 9, 0, 0));

        Test.startTest();
        TaskTriggerHandler.calculateTimeOfBilling(new List<Task>{ t }, null);
        Test.stopTest();

        System.assertEquals(0, t.Total_Time_Of_Completing_Task__c,
            'Time should be zero when Stop_Time__c is missing');
    }

    // ─── calculateTimeOfBilling: unchanged times on update → skip ────────────

    @IsTest
    static void testCalculateTimeOfBilling_TimesUnchanged_Skipped() {
        Task t = new Task(
            Subject       = 'Stable Task',
            Start_Time__c = Datetime.newInstance(2024, 1, 1, 8, 0, 0),
            Stop_Time__c  = Datetime.newInstance(2024, 1, 1, 9, 0, 0),
            Name__c = 'Admin',
            Total_Time_Of_Completing_Task__c = 99 // pre-existing value
        );
        insert t;

        Task old = t.clone(true, true, true, true);
        // Times not changed
        Map<Id, Task> oldMap = new Map<Id, Task>{ t.Id => old };

        Test.startTest();
        TaskTriggerHandler.calculateTimeOfBilling(new List<Task>{ t }, oldMap);
        Test.stopTest();

        System.assertEquals(99, t.Total_Time_Of_Completing_Task__c,
            'Time should NOT be recalculated when Start/Stop unchanged');
    }

    // ─── handleAfter: insert delegates to TaskNotificationHandler ────────────

    @IsTest
    static void testHandleAfter_Insert_DelegatesToNotificationHandler() {
        Contact patient = getPatient();
        List<App_User__c> existingUsers = [SELECT Id FROM App_User__c WHERE Email__c = 'tasktrigger@example.com' LIMIT 1];
        App_User__c u;
        if (existingUsers.isEmpty()) {
            u = new App_User__c(Email__c = 'tasktrigger@example.com', Patient__c = patient.Id, Status__c = 'Active');
            insert u;
        } else {
            u = existingUsers[0];
        }
        NotificationService.processedKeys.clear();

        Task t = new Task(Subject = 'Handle After Task', WhoId = patient.Id, Description = 'Task body text');

        Test.startTest();
        TaskTriggerHandler.handleAfter(new List<Task>{ t }, null, true, false);
        Test.stopTest();

        // NotificationService creates App_Notification__c for insert with description
        Integer count = [SELECT COUNT() FROM App_Notification__c WHERE App_User__c = :u.Id];
        System.assertEquals(1, count, 'handleAfter insert should delegate to TaskNotificationHandler');
    }

    // ─── makeTaskPublic: runs without exception ───────────────────────────────

    @IsTest
    static void testMakeTaskPublic_NoException() {
        Contact patient = getPatient();

        Task t = new Task(
            Subject = 'Public Task',
            WhoId   = patient.Id,
            Status  = 'Open'
        );

        Test.startTest();
        TaskTriggerHandler.makeTaskPublic(new List<Task>{ t });
        Test.stopTest();

        System.assert(true, 'makeTaskPublic should complete without throwing');
    }

    // ─── afterUpdate: empty list → no exception ───────────────────────────────

    @IsTest
    static void testAfterUpdate_EmptyList_NoException() {
        Test.startTest();
        TaskTriggerHandler.afterUpdate(new List<Task>(), new Map<Id, Task>());
        Test.stopTest();
        System.assert(true, 'Empty list should not throw');
    }

    // ─── afterUpdate: completing the only open task on an open Case → error ──

    @IsTest
    static void testAfterUpdate_NoFollowUpTask_AddsError() {
        Contact patient = getPatient();
        Case c          = getOpenCase();

        // Persisted as Completed, so the contact has no Open task left
        Task mainTask = new Task(
            Subject = 'Regular Task',
            WhoId   = patient.Id,
            WhatId  = c.Id,
            Name__c = 'Admin',
            Status  = 'Completed'
        );
        insert mainTask;

        Task old = mainTask.clone(true, true, true, true);
        old.Status = 'Open';

        Test.startTest();
        TaskTriggerHandler.afterUpdate(new List<Task>{ mainTask }, new Map<Id, Task>{ mainTask.Id => old });
        Test.stopTest();

        System.assertEquals(1, mainTask.getErrors().size(), 'Follow-up validation error expected');
        System.assert(mainTask.getErrors()[0].getMessage().contains('follow up task'));
    }

    // ─── handleAfter: update branch delegates to TaskNotificationHandler ─────

    @IsTest
    static void testHandleAfter_Update_DelegatesToNotificationHandler() {
        Contact patient = getPatient();
        NotificationService.processedKeys.clear();
        Task t = new Task(Subject = 'Update Task', WhoId = patient.Id, Description = 'Changed');

        Test.startTest();
        TaskTriggerHandler.handleAfter(new List<Task>{ t }, new Map<Id, Task>(), false, true);
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM App_Notification__c], 'Task missing from old map is skipped');
    }

    // ─── makeTaskPublic: Contact on an externally shared Account ─────────────
    // Best effort: needs a "Client Access User" profile and the ability to share the
    // Account with that user; the check is skipped when the org does not allow it.

    @IsTest
    static void testMakeTaskPublic_ExternallySharedAccount_SetsVisibleInSelfService() {
        List<Profile> profiles = [SELECT Id FROM Profile WHERE Name = 'Client Access User' LIMIT 1];
        if (profiles.isEmpty()) {
            return;
        }
        Contact patient = [SELECT Id, AccountId FROM Contact WHERE Email = 'tasktrigger@example.com' LIMIT 1];

        User externalUser = new User(
            Alias = 'extusr', Email = 'ext.tasktrigger@example.com', Username = 'ext.tasktrigger@example.com.test',
            LastName = 'External', ProfileId = profiles[0].Id, ContactId = patient.Id,
            TimeZoneSidKey = 'America/New_York', LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US'
        );
        try {
            System.runAs(new User(Id = UserInfo.getUserId())) {
                insert externalUser;
                insert new AccountShare(
                    AccountId = patient.AccountId, UserOrGroupId = externalUser.Id,
                    AccountAccessLevel = 'Read', OpportunityAccessLevel = 'None', CaseAccessLevel = 'None'
                );
            }
        } catch (Exception e) {
            return; // the org does not allow creating this external share in a test
        }

        Task visible = new Task(Subject = 'Public Task', WhoId = patient.Id, Status = 'Open');
        Task hidden  = new Task(Subject = '7 Hidden Task', WhoId = patient.Id, Status = 'Open');

        Test.startTest();
        TaskTriggerHandler.makeTaskPublic(new List<Task>{ visible, hidden });
        Test.stopTest();

        System.assertEquals(true,  visible.IsVisibleInSelfService, 'Regular subject is made visible');
        System.assertEquals(false, hidden.IsVisibleInSelfService,  'Subjects starting with 7 stay private');
    }

    // ─── afterUpdate: a task that was not completed is skipped in a mixed batch ─

    @IsTest
    static void testAfterUpdate_MixedBatch_NonCompletedTaskSkipped() {
        Contact patient = getPatient();
        Case c          = getOpenCase();

        Task done    = new Task(Subject = 'Done Task', WhoId = patient.Id, WhatId = c.Id, Name__c = 'Admin', Status = 'Open');
        Task pending = new Task(Subject = 'Still Open', WhoId = patient.Id, Name__c = 'Admin', Status = 'Open');
        insert new List<Task>{ done, pending };

        Task oldDone    = done.clone(true, true, true, true);
        Task oldPending = pending.clone(true, true, true, true);
        done.Status     = 'Completed';

        Test.startTest();
        TaskTriggerHandler.afterUpdate(
            new List<Task>{ done, pending },
            new Map<Id, Task>{ done.Id => oldDone, pending.Id => oldPending }
        );
        Test.stopTest();

        System.assertEquals(0, done.getErrors().size(), 'Another open task remains, so no error');
        System.assertEquals(0, pending.getErrors().size(), 'Non-completed task is skipped');
    }
}