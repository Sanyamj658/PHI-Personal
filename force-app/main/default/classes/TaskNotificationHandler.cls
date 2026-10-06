/**
 * TaskNotificationHandler
 * Fires a notification to the patient when an agent updates the Description
 * (Activity Progress / Next Step) on a Task linked to a patient Contact.
 *
 * Trigger: Task after update
 * Condition: Description changed AND is not blank AND WhoId is a Contact
 *            that has an active App_User__c record.
 *
 * Resolution chain: Task.WhoId (Contact) → App_User__c.Patient__c → Email__c
 */
public class TaskNotificationHandler {

    // Notifies the patient when a new Task with a description is created for their Contact.
    public static void handleAfterInsert(List<Task> newTasks) {

        // Collect Tasks linked to a Contact (WhoId prefix 003) that have a description.
        Map<Id, Task> contactIdToTask = new Map<Id, Task>();

        for (Task t : newTasks) {
            if (t.WhoId == null) continue;
            if (!String.valueOf(t.WhoId).startsWith('003')) continue;
            if (String.isBlank(t.Description)) continue;
            contactIdToTask.put(t.WhoId, t);
        }

        if (contactIdToTask.isEmpty()) return;

        // Find App Users linked to these Contacts.
        List<App_User__c> appUsers = [
            SELECT Id, Email__c, Patient__c
            FROM   App_User__c
            WHERE  Patient__c IN :contactIdToTask.keySet()
            AND    Email__c   != null
        ];

        if (appUsers.isEmpty()) return;

        // Create one notification per App User using the task description as the message.
        List<NotificationService.Request> requests = new List<NotificationService.Request>();

        for (App_User__c u : appUsers) {
            Task t = contactIdToTask.get(u.Patient__c);
            if (t == null) continue;

            // Truncate long descriptions to keep the body within 255 characters.
            String body = t.Description.length() > 255
                ? t.Description.substring(0, 252) + '...'
                : t.Description;

            NotificationService.Request r = new NotificationService.Request(
                u.Email__c,
                'New Message',
                body
            );
            r.type              = 'General';
            r.relatedRecordId   = t.WhatId != null ? String.valueOf(t.WhatId) : null;
            r.relatedRecordType = t.WhatId != null ? 'Case' : null;
            requests.add(r);
        }

        if (!requests.isEmpty()) {
            NotificationService.dispatch(requests);
        }
    }

    // Notifies the patient when the description of a Task changes.
    public static void handleAfterUpdate(List<Task> newTasks, Map<Id, Task> oldMap) {

        // Collect tasks where Description actually changed
        // WhoId prefix '003' = Contact
        Map<Id, Task> contactIdToTask = new Map<Id, Task>();

        for (Task t : newTasks) {
            if (t.WhoId == null) continue;
            if (!String.valueOf(t.WhoId).startsWith('003')) continue;

            Task old = oldMap.get(t.Id);
            if (old == null) continue;

            Boolean descriptionChanged = (t.Description != old.Description)
                                         && String.isNotBlank(t.Description);
            if (!descriptionChanged) continue;

            // Last change for the same contact wins (rare but safe)
            contactIdToTask.put(t.WhoId, t);
        }

        if (contactIdToTask.isEmpty()) return;

        // Single SOQL: find App_User__c for these contacts
        List<App_User__c> appUsers = [
            SELECT Id, Email__c, Patient__c
            FROM   App_User__c
            WHERE  Patient__c IN :contactIdToTask.keySet()
            AND    Email__c   != null
        ];

        if (appUsers.isEmpty()) return;

        List<NotificationService.Request> requests = new List<NotificationService.Request>();

        for (App_User__c u : appUsers) {
            Task t = contactIdToTask.get(u.Patient__c);
            if (t == null) continue;

            // Truncate long descriptions to keep the notification body readable
            String body = t.Description.length() > 255
                ? t.Description.substring(0, 252) + '...'
                : t.Description;

            NotificationService.Request r = new NotificationService.Request(
                u.Email__c,
                'New Message',
                body
            );
            r.type              = 'General';
            r.relatedRecordId   = t.WhatId != null ? String.valueOf(t.WhatId) : null;
            r.relatedRecordType = t.WhatId != null ? 'Case' : null;
            requests.add(r);
        }

        if (!requests.isEmpty()) {
            NotificationService.dispatch(requests);
        }
    }
}