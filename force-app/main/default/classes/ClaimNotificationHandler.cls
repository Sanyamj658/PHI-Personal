/**
 * ClaimNotificationHandler
 * Trigger handler for push notifications related to Claim__c changes.
 *
 * Notification is sent when any of these fields change on an existing claim,
 * or when a new claim is created:
 *   - Pending_Status__c
 *   - Total_Payments__c
 *   - Claim_Balance_Due__c
 *
 * Device token is resolved via:
 *   Claim__c.Case__c → Case.ContactEmail → App_User__c.Device_Token__c
 */
public class ClaimNotificationHandler {

    // ─── Trigger entry points ────────────────────────────────────────────────

    public static void handleAfterInsert(List<Claim__c> newClaims) {
        notifyForClaims(newClaims, null);
    }

    public static void handleAfterUpdate(List<Claim__c> newClaims, Map<Id, Claim__c> oldMap) {
        List<Claim__c> changed = new List<Claim__c>();
        for (Claim__c c : newClaims) {
            if (hasRelevantChange(c, oldMap.get(c.Id))) {
                changed.add(c);
            }
        }
        if (!changed.isEmpty()) {
            notifyForClaims(changed, oldMap);
        }
    }

    // ─── Private helpers ─────────────────────────────────────────────────────

    private static Boolean hasRelevantChange(Claim__c newClaim, Claim__c oldClaim) {
        if (oldClaim == null) return true;
        return (newClaim.Pending_Status__c   != oldClaim.Pending_Status__c)
            || (newClaim.Total_Payments__c   != oldClaim.Total_Payments__c)
            || (newClaim.Claim_Balance_Due__c != oldClaim.Claim_Balance_Due__c);
    }

    private static void notifyForClaims(List<Claim__c> claims, Map<Id, Claim__c> oldMap) {
        // Collect the case IDs linked to these claims
        Set<Id> caseIds = new Set<Id>();
        for (Claim__c c : claims) {
            if (c.Case__c != null) caseIds.add(c.Case__c);
        }
        if (caseIds.isEmpty()) return;

        // Single SOQL: get ContactEmail from Cases
        Map<Id, String> caseEmailMap = new Map<Id, String>();
        for (Case cs : [SELECT Id, ContactEmail FROM Case WHERE Id IN :caseIds AND ContactEmail != null]) {
            caseEmailMap.put(cs.Id, cs.ContactEmail);
        }

        // Build notification requests (one per claim, dedup happens in NotificationService)
        List<NotificationService.Request> requests = new List<NotificationService.Request>();
        for (Claim__c c : claims) {
            String email = caseEmailMap.get(c.Case__c);
            if (String.isBlank(email)) continue;

            String title = 'Claim Update';
            String body  = buildBody(c, oldMap);

            NotificationService.Request r = new NotificationService.Request(email, title, body);
            r.type              = 'Claim_Update';
            r.relatedRecordId   = String.valueOf(c.Id);
            r.relatedRecordType = 'Claim';
            requests.add(r);
        }

        if (!requests.isEmpty()) {
            NotificationService.dispatch(requests);
        }
    }

    private static String buildBody(Claim__c c, Map<Id, Claim__c> oldMap) {
        if (oldMap == null) {
            // New claim created
            return 'A new claim has been added to your account.';
        }

        Claim__c old = oldMap.get(c.Id);
        if (old == null) return 'Your claim information has been updated.';

        // Prioritise status change message
        if (c.Pending_Status__c != old.Pending_Status__c && String.isNotBlank(c.Pending_Status__c)) {
            return 'Your claim status has been updated to ' + c.Pending_Status__c + '.';
        }

        if (c.Claim_Balance_Due__c != old.Claim_Balance_Due__c) {
            String amt = c.Claim_Balance_Due__c != null
                ? '$' + c.Claim_Balance_Due__c.setScale(2).toPlainString()
                : '$0.00';
            return 'Your claim balance has been updated. Balance due: ' + amt + '.';
        }

        if (c.Total_Payments__c != old.Total_Payments__c) {
            String amt = c.Total_Payments__c != null
                ? '$' + c.Total_Payments__c.setScale(2).toPlainString()
                : '$0.00';
            return 'A payment of ' + amt + ' has been applied to your claim.';
        }

        return 'Your claim information has been updated.';
    }
}