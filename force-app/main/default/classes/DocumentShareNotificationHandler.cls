/**
 * DocumentShareNotificationHandler
 * Trigger handler for push notifications when a document is shared with a patient.
 *
 * Trigger: Document Shared
 *   - Fires when a ContentDocumentLink is inserted (file linked to a record)
 *   - Relevant LinkedEntityId types: Case, Contact (patient), Claim__c
 *   - Resolves the patient email from the linked record
 *   - Notification title : "New Document Shared"
 *   - Notification body  : "A new document has been shared with your account."
 *
 * Deduplication: if multiple files are linked in one batch to the same patient,
 * NotificationService.processedKeys ensures only one notification is sent.
 */
public class DocumentShareNotificationHandler {

    public static void handleAfterInsert(List<ContentDocumentLink> newLinks) {
        // Separate linked entity IDs by SObject type
        Set<Id> caseIds    = new Set<Id>();
        Set<Id> contactIds = new Set<Id>();
        Set<Id> claimIds   = new Set<Id>();

        for (ContentDocumentLink l : newLinks) {
            if (l.LinkedEntityId == null) continue;

            Schema.SObjectType objType = l.LinkedEntityId.getSObjectType();

            if (objType == Case.SObjectType) {
                caseIds.add(l.LinkedEntityId);
            } else if (objType == Contact.SObjectType) {
                contactIds.add(l.LinkedEntityId);
            } else if (objType == Claim__c.SObjectType) {
                claimIds.add(l.LinkedEntityId);
            }
            // All other entity types (User, Task, etc.) are ignored
        }

        // Collect unique patient emails from all three entity types
        Set<String> patientEmails = new Set<String>();

        // Via Case → ContactEmail
        if (!caseIds.isEmpty()) {
            for (Case cs : [SELECT ContactEmail FROM Case WHERE Id IN :caseIds AND ContactEmail != null]) {
                patientEmails.add(cs.ContactEmail.toLowerCase());
            }
        }

        // Via Contact → App_User__c.Patient__c lookup
        if (!contactIds.isEmpty()) {
            for (App_User__c u : [
                SELECT Email__c
                FROM App_User__c
                WHERE Patient__c IN :contactIds
                  AND Email__c != null
            ]) {
                patientEmails.add(u.Email__c.toLowerCase());
            }
        }

        // Via Claim__c → Case → ContactEmail
        if (!claimIds.isEmpty()) {
            Set<Id> claimCaseIds = new Set<Id>();
            for (Claim__c cl : [SELECT Case__c FROM Claim__c WHERE Id IN :claimIds AND Case__c != null]) {
                claimCaseIds.add(cl.Case__c);
            }
            if (!claimCaseIds.isEmpty()) {
                for (Case cs : [SELECT ContactEmail FROM Case WHERE Id IN :claimCaseIds AND ContactEmail != null]) {
                    patientEmails.add(cs.ContactEmail.toLowerCase());
                }
            }
        }

        if (patientEmails.isEmpty()) return;

        // Build one request per unique email (NotificationService will dedup further)
        List<NotificationService.Request> requests = new List<NotificationService.Request>();
        for (String email : patientEmails) {
            NotificationService.Request r = new NotificationService.Request(
                email,
                'New Document Shared',
                'A new document has been shared with your account.'
            );
            r.type = 'Document_Shared';
            requests.add(r);
        }

        NotificationService.dispatch(requests);
    }
}