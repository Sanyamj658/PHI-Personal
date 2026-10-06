public class ClaimNotificationHandler {
    // Notifies the patient when a new claim is created.
    public static void handleAfterInsert(List<Claim__c> newClaims) {
        try {
            notifyForClaims(newClaims, null);
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'ClaimNotificationHandler.handleAfterInsert failed: ' + ex.getMessage());
        }
    }

    // Notifies only for claims whose status, payments or balance changed.
    public static void handleAfterUpdate(List<Claim__c> newClaims, Map<Id, Claim__c> oldMap) {
        try {
            List<Claim__c> changed = new List<Claim__c>();
            for (Claim__c c : newClaims) {
                if (hasRelevantChange(c, oldMap != null ? oldMap.get(c.Id) : null)) {
                    changed.add(c);
                }
            }
            if (!changed.isEmpty()) {
                notifyForClaims(changed, oldMap);
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'ClaimNotificationHandler.handleAfterUpdate failed: ' + ex.getMessage());
        }
    }

    // Returns true if the claim is new or its status/payment/balance fields changed.
    private static Boolean hasRelevantChange(Claim__c newClaim, Claim__c oldClaim) {
        if (oldClaim == null) {
            return true;
        }
        return (newClaim.Pending_Status__c != oldClaim.Pending_Status__c)
            || (newClaim.Total_Payments__c != oldClaim.Total_Payments__c)
            || (newClaim.Claim_Balance_Due__c != oldClaim.Claim_Balance_Due__c);
    }

    // Looks up patient emails through the claim's Case and dispatches Claim_Update notifications.
    private static void notifyForClaims(List<Claim__c> claims, Map<Id, Claim__c> oldMap) {
        try {
            Set<Id> caseIds = new Set<Id>();
            for (Claim__c c : claims) {
                if (c.Case__c != null) {
                    caseIds.add(c.Case__c);
                }
            }
            if (caseIds.isEmpty()) {
                return;
            }

            Map<Id, String> caseEmailMap = new Map<Id, String>();
            for (Case cs : [SELECT Id, ContactEmail FROM Case WHERE Id IN :caseIds AND ContactEmail != null]) {
                caseEmailMap.put(cs.Id, cs.ContactEmail);
            }

            List<NotificationService.Request> requests = new List<NotificationService.Request>();
            for (Claim__c c : claims) {
                String email = caseEmailMap.get(c.Case__c);
                if (String.isBlank(email)) {
                    continue;
                }

                String title = 'Claim Update';
                String body = buildBody(c, oldMap);

                NotificationService.Request r = new NotificationService.Request(email, title, body);
                r.type = 'Claim_Update';
                r.relatedRecordId = String.valueOf(c.Id);
                r.relatedRecordType = 'Claim';
                requests.add(r);
            }

            if (!requests.isEmpty()) {
                NotificationService.dispatch(requests);
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'ClaimNotificationHandler.notifyForClaims failed: ' + ex.getMessage());
        }
    }

    // Builds the notification message based on which claim field changed.
    private static String buildBody(Claim__c c, Map<Id, Claim__c> oldMap) {
        if (oldMap == null) {
            return 'A new claim has been added to your account.';
        }

        Claim__c old = oldMap.get(c.Id);
        if (old == null) {
            return 'Your claim information has been updated.';
        }

        if (c.Pending_Status__c != old.Pending_Status__c && String.isNotBlank(c.Pending_Status__c)) {
            return 'Your claim status has been updated to ' + c.Pending_Status__c + '.';
        }

        if (c.Claim_Balance_Due__c != old.Claim_Balance_Due__c) {
            String amt = c.Claim_Balance_Due__c != null ? '$' + c.Claim_Balance_Due__c.setScale(2).toPlainString() : '$0.00';
            return 'Your claim balance has been updated. Balance due: ' + amt + '.';
        }

        if (c.Total_Payments__c != old.Total_Payments__c) {
            String amt = c.Total_Payments__c != null ? '$' + c.Total_Payments__c.setScale(2).toPlainString() : '$0.00';
            return 'A payment of ' + amt + ' has been applied to your claim.';
        }

        return 'Your claim information has been updated.';
    }
}