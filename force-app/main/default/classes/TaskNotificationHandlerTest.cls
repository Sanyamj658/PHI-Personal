/**
 * TaskNotificationHandlerTest
 * Covers: handleAfterInsert – notification sent when WhoId is Contact with
 *         App_User__c and description present; skipped when WhoId not a Contact,
 *         blank description, no App_User for contact, WhoId null.
 *         handleAfterUpdate – notification sent when description changes;
 *         skipped when description unchanged, blank new description,
 *         no app user for contact, truncation of long descriptions, bulk.
 */
@IsTest
private class TaskNotificationHandlerTest {

    @TestSetup
    static void setup() {
        Account acc = new Account(Name = 'TaskNotif Hospital', Account_Manager_Name__c = 'Admin');
        insert acc;

        Insurance_Company__c insurance =
    new Insurance_Company__c(
        Name = 'Test Insurance'
    );
insert insurance;

        
        Contact patient = new Contact(
            FirstName = 'TaskNotif',
            LastName  = 'Patient',
            Email     = 'tasknotif@example.com',
            DX_s__c   = 'TN01',
            AccountId = acc.Id,
           
    Primary_Insurance__c = insurance.Id,
    Plan_Type__c = 'Other Plan'
        );
        insert patient;
        
        

        // App_User__c WITHOUT device token to avoid FirebaseService callout
        App_User__c appUser = new App_User__c(
            Email__c   = 'tasknotif@example.com',
            Patient__c = patient.Id,
            Status__c  = 'Active'
        );
        insert appUser;
    }

    private static Contact getPatient() {
        return [SELECT Id FROM Contact WHERE Email = 'tasknotif@example.com' LIMIT 1];
    }

    private static App_User__c getAppUser() {
        return [SELECT Id FROM App_User__c WHERE Email__c = 'tasknotif@example.com' LIMIT 1];
    }

    // ─── handleAfterInsert: success ───────────────────────────────────────────

    @IsTest
    static void testHandleAfterInsert_WithDescription_CreatesNotification() {
        Contact patient = getPatient();
        App_User__c u   = getAppUser();
        NotificationService.processedKeys.clear();

        Task t = new Task(
            Subject     = 'Test Task',
            WhoId       = patient.Id,
            Description = 'Initial task description for patient.',
            Name__c = 'Admin'
        );

        Test.startTest();
        insert t; // triggers Task_trg → TaskTriggerHandler.handleAfter → TaskNotificationHandler.handleAfterInsert
        Test.stopTest();

        List<App_Notification__c> notifs = [
            SELECT Id, Title__c, Body__c, Type__c
            FROM App_Notification__c
            WHERE App_User__c = :u.Id
        ];
        System.assertEquals(1, notifs.size(), 'One notification should be created on task insert');
        System.assertEquals('New Message', notifs[0].Title__c);
        System.assertEquals('General',     notifs[0].Type__c);
        System.assert(notifs[0].Body__c.contains('Initial task description'));
    }

    // ─── handleAfterInsert: no description → skipped ─────────────────────────

    @IsTest
    static void testHandleAfterInsert_NoDescription_NoNotification() {
        Contact patient = getPatient();
        App_User__c u   = getAppUser();
        NotificationService.processedKeys.clear();

        Task t = new Task(Subject = 'No Desc Task', WhoId = patient.Id , Name__c = 'Admin');
        // Description intentionally blank

        Test.startTest();
        insert t;
        Test.stopTest();

        List<App_Notification__c> notifs = [SELECT Id FROM App_Notification__c WHERE App_User__c = :u.Id];
        System.assertEquals(0, notifs.size(), 'No notification when description is blank');
    }

    // ─── handleAfterInsert: WhoId not a Contact (starts with 00Q) → skipped ──

    @IsTest
    static void testHandleAfterInsert_WhoIdNotContact_NoNotification() {
        // Pass directly to handler with a non-Contact WhoId (simulate Lead prefix 00Q)
        // Build a minimal task with WhoId that doesn't start with '003'
        Task fakeTask = new Task();
        // We can't easily set WhoId to a Lead here without creating one; use direct handler call instead
        NotificationService.processedKeys.clear();

        Test.startTest();
        TaskNotificationHandler.handleAfterInsert(new List<Task>{ fakeTask });
        Test.stopTest();

        List<App_Notification__c> notifs = [SELECT Id FROM App_Notification__c];
        System.assertEquals(0, notifs.size(), 'No notification when WhoId is null');
    }

    // ─── handleAfterUpdate: description changed → notification ───────────────

    @IsTest
    static void testHandleAfterUpdate_DescriptionChanged_CreatesNotification() {
        Contact patient = getPatient();
        App_User__c u   = getAppUser();
        NotificationService.processedKeys.clear();

        Task t = new Task(Subject = 'Update Test Task', WhoId = patient.Id, Description = 'Original', Name__c = 'Admin');
        insert t;

        App_Notification__c[] initial = [SELECT Id FROM App_Notification__c WHERE App_User__c = :u.Id];
        // Clear any notification from insert
        delete initial;
        NotificationService.processedKeys.clear();

        Task oldTask = t.clone(true, true, true, true);
        oldTask.Description = 'Original';
        t.Description = 'Updated description for the task.';

        Map<Id, Task> oldMap = new Map<Id, Task>{ t.Id => oldTask };

        Test.startTest();
        TaskNotificationHandler.handleAfterUpdate(new List<Task>{ t }, oldMap);
        Test.stopTest();

        List<App_Notification__c> notifs = [
            SELECT Id, Body__c FROM App_Notification__c WHERE App_User__c = :u.Id
        ];
        System.assertEquals(1, notifs.size(), 'Notification should be sent on description change');
        System.assert(notifs[0].Body__c.contains('Updated description'));
    }

    // ─── handleAfterUpdate: description unchanged → no notification ──────────

    @IsTest
    static void testHandleAfterUpdate_DescriptionUnchanged_NoNotification() {
        Contact patient = getPatient();
        App_User__c u   = getAppUser();
        NotificationService.processedKeys.clear();

        Task t = new Task(Subject = 'Unchanged Desc', WhoId = patient.Id, Description = 'Same text', Name__c = 'Admin');
        insert t;

        // Clear initial notifications
        delete [SELECT Id FROM App_Notification__c WHERE App_User__c = :u.Id];
        NotificationService.processedKeys.clear();

        Task oldTask = t.clone(true, true, true, true);
        // Both old and new have same description → no change

        Map<Id, Task> oldMap = new Map<Id, Task>{ t.Id => oldTask };

        Test.startTest();
        TaskNotificationHandler.handleAfterUpdate(new List<Task>{ t }, oldMap);
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM App_Notification__c WHERE App_User__c = :u.Id];
        System.assertEquals(0, count, 'No notification when description did not change');
    }

    // ─── handleAfterUpdate: description changed to blank → no notification ───

    @IsTest
    static void testHandleAfterUpdate_DescriptionChangedToBlank_NoNotification() {
        Contact patient = getPatient();
        App_User__c u   = getAppUser();
        NotificationService.processedKeys.clear();

        Task t = new Task(Subject = 'Blank Desc Task', WhoId = patient.Id, Description = 'Some text', Name__c = 'Admin');
        insert t;
        delete [SELECT Id FROM App_Notification__c WHERE App_User__c = :u.Id];
        NotificationService.processedKeys.clear();

        Task oldTask = t.clone(true, true, true, true);
        oldTask.Description = 'Some text';
        t.Description = null; // changed to blank

        Map<Id, Task> oldMap = new Map<Id, Task>{ t.Id => oldTask };

        Test.startTest();
        TaskNotificationHandler.handleAfterUpdate(new List<Task>{ t }, oldMap);
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM App_Notification__c WHERE App_User__c = :u.Id];
        System.assertEquals(0, count, 'No notification when new description is blank');
    }

    // ─── handleAfterUpdate: long description is truncated ────────────────────

    @IsTest
    static void testHandleAfterUpdate_LongDescription_Truncated() {
        Contact patient = getPatient();
        App_User__c u   = getAppUser();
        NotificationService.processedKeys.clear();

        Task t = new Task(Subject = 'Long Desc Task', WhoId = patient.Id, Description = 'Short', Name__c = 'Admin');
        insert t;
        delete [SELECT Id FROM App_Notification__c WHERE App_User__c = :u.Id];
        NotificationService.processedKeys.clear();

        // Generate a 300-character description
        String longDesc = '';
        while (longDesc.length() < 300) longDesc += 'A';

        Task oldTask = t.clone(true, true, true, true);
        oldTask.Description = 'Short';
        t.Description = longDesc;

        Map<Id, Task> oldMap = new Map<Id, Task>{ t.Id => oldTask };

        Test.startTest();
        TaskNotificationHandler.handleAfterUpdate(new List<Task>{ t }, oldMap);
        Test.stopTest();

        App_Notification__c notif = [SELECT Body__c FROM App_Notification__c WHERE App_User__c = :u.Id LIMIT 1];
        System.assertNotEquals(null, notif, 'Notification should be created for long description');
        System.assert(notif.Body__c.length() <= 255, 'Body should be truncated to <= 255 chars');
        System.assert(notif.Body__c.endsWith('...'), 'Truncated body should end with ...');
    }

    // ─── handleAfterUpdate: bulk tasks ───────────────────────────────────────

    @IsTest
    static void testHandleAfterUpdate_BulkTasks() {
        List<Contact> contacts = new List<Contact>();
        List<App_User__c> users = new List<App_User__c>();
         Insurance_Company__c insurance =
    new Insurance_Company__c(
        Name = 'Test Insurance'
    );
insert insurance;
        for (Integer i = 0; i < 5; i++) {
            contacts.add(new Contact(LastName = 'BulkTaskNotif' + i, DX_s__c = 'BT' + i,
                                     Email = 'bulktask' + i + '@example.com',   Primary_Insurance__c = insurance.Id,
    Plan_Type__c = 'Other Plan'));
        }
        insert contacts;
        for (Contact c : contacts) {
            users.add(new App_User__c(Email__c = c.Email, Patient__c = c.Id, Status__c = 'Active'));
        }
        insert users;

        // Insert tasks WITHOUT description so the afterInsert handler creates no notifications
        List<Task> tasks = new List<Task>();
        Map<Id, Task> oldMap = new Map<Id, Task>();
        for (Contact c : contacts) {
            Task t = new Task(Subject = 'Bulk Task', WhoId = c.Id, Name__c = 'Admin');
            insert t;
            Task old = t.clone(true, true, true, true);
            old.Description = null;
            t.Description = 'Updated bulk text for ' + c.LastName;
            tasks.add(t);
            oldMap.put(t.Id, old);
        }

        NotificationService.processedKeys.clear();

        Test.startTest();
        TaskNotificationHandler.handleAfterUpdate(tasks, oldMap);
        Test.stopTest();

        Set<Id> userIds = new Map<Id, App_User__c>(users).keySet();
        Integer count = [SELECT COUNT() FROM App_Notification__c WHERE App_User__c IN :userIds];
        System.assertEquals(5, count, 'One notification per contact in bulk update');
    }

    // ─── Empty list guards ────────────────────────────────────────────────────

    @IsTest
    static void testHandlers_EmptyLists_NoException() {
        Test.startTest();
        TaskNotificationHandler.handleAfterInsert(new List<Task>());
        TaskNotificationHandler.handleAfterUpdate(new List<Task>(), new Map<Id, Task>());
        Test.stopTest();
        System.assert(true, 'Empty lists should not throw');
    }

    // ─── Helper: patient Contact that has NO App_User__c ─────────────────────

    private static Contact createContactWithoutAppUser() {
        Account acc              = [SELECT Id FROM Account LIMIT 1];
        Insurance_Company__c ins = [SELECT Id FROM Insurance_Company__c LIMIT 1];
        Contact ct = new Contact(
            FirstName            = 'NoApp',
            LastName             = 'Patient',
            Email                = 'noapp.tasknotif@example.com',
            DX_s__c              = 'TN02',
            AccountId            = acc.Id,
            Primary_Insurance__c = ins.Id,
            Plan_Type__c         = 'Other Plan'
        );
        insert ct;
        return ct;
    }

    // ─── handleAfterInsert: long description is truncated to 255 chars ───────

    @IsTest
    static void testHandleAfterInsert_LongDescription_Truncated() {
        Contact patient = getPatient();
        App_User__c u   = getAppUser();
        NotificationService.processedKeys.clear();

        Task t = new Task(
            Subject     = 'Long Task',
            WhoId       = patient.Id,
            Description = 'A'.repeat(300),
            Name__c     = 'Admin'
        );

        Test.startTest();
        insert t;
        Test.stopTest();

        List<App_Notification__c> notifs = [SELECT Body__c FROM App_Notification__c WHERE App_User__c = :u.Id];
        System.assertEquals(1, notifs.size());
        System.assertEquals(255, notifs[0].Body__c.length(), 'Body is cut to 252 chars + "..."');
        System.assert(notifs[0].Body__c.endsWith('...'));
    }

    // ─── handleAfterInsert: Contact has no App User → nothing to notify ──────

    @IsTest
    static void testHandleAfterInsert_ContactWithoutAppUser_NoNotification() {
        Contact noApp = createContactWithoutAppUser();
        NotificationService.processedKeys.clear();

        Test.startTest();
        insert new Task(Subject = 'Orphan Task', WhoId = noApp.Id, Description = 'Hello', Name__c = 'Admin');
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM App_Notification__c], 'No App User → no notification');
    }

    // ─── handleAfterInsert: Task linked to a Case sets the related record ────

    @IsTest
    static void testHandleAfterInsert_WithWhatId_SetsRelatedRecord() {
        Contact patient = getPatient();
        App_User__c u   = getAppUser();
        Case relatedCase = new Case(Status = 'New', Origin = 'Phone', ContactId = patient.Id);
        insert relatedCase;
        NotificationService.processedKeys.clear();

        Test.startTest();
        insert new Task(
            Subject = 'Case Task', WhoId = patient.Id, WhatId = relatedCase.Id,
            Description = 'Case related message', Name__c = 'Admin'
        );
        Test.stopTest();

        List<App_Notification__c> notifs = [
            SELECT Related_Record_Id__c FROM App_Notification__c WHERE App_User__c = :u.Id
        ];
        System.assertEquals(1, notifs.size());
        System.assertEquals(String.valueOf(relatedCase.Id), notifs[0].Related_Record_Id__c);
    }

    // ─── handleAfterUpdate: Contact has no App User → nothing to notify ──────

    @IsTest
    static void testHandleAfterUpdate_ContactWithoutAppUser_NoNotification() {
        Contact noApp = createContactWithoutAppUser();
        Task t = new Task(Subject = 'Orphan Update', WhoId = noApp.Id, Name__c = 'Admin');
        insert t;
        NotificationService.processedKeys.clear();

        Test.startTest();
        t.Description = 'Changed description';
        update t;
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM App_Notification__c], 'No App User → no notification');
    }

    // ─── handleAfterUpdate: task missing from the old map is skipped ─────────

    @IsTest
    static void testHandleAfterUpdate_TaskMissingFromOldMap_Skipped() {
        Contact patient = getPatient();
        NotificationService.processedKeys.clear();

        Task unsaved = new Task(Subject = 'Unsaved', WhoId = patient.Id, Description = 'New text');

        Test.startTest();
        TaskNotificationHandler.handleAfterUpdate(new List<Task>{ unsaved }, new Map<Id, Task>());
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM App_Notification__c], 'No old record → skipped');
    }

    // ─── Tasks without a WhoId or with a non-Contact WhoId (Lead) are skipped ─

    @IsTest
    static void testHandlers_NoWhoIdOrNonContactWho_Skipped() {
        NotificationService.processedKeys.clear();
        Lead lead = new Lead(LastName = 'Lead', Company = 'Lead Co');
        insert lead;

        Task noWho   = new Task(Subject = 'No Who', Description = 'text');
        Task leadWho = new Task(Subject = 'Lead Who', Description = 'text', WhoId = lead.Id);

        Test.startTest();
        TaskNotificationHandler.handleAfterInsert(new List<Task>{ noWho, leadWho });
        TaskNotificationHandler.handleAfterUpdate(new List<Task>{ noWho, leadWho }, new Map<Id, Task>());
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM App_Notification__c]);
    }
}