trigger ClaimTrigger on Claim__c (before delete, after insert, after update) {
    
    if (Trigger.isBefore && Trigger.isDelete) {
        for (Claim__c claimRecord : Trigger.old) {
            claimRecord.addError('You are not authorized to delete the claim.');
        }
        
    } else if (Trigger.isAfter && Trigger.isInsert) {
        // Notify patient that a new claim has been created
        ClaimNotificationHandler.handleAfterInsert(Trigger.new);
        
    } else if (Trigger.isAfter && Trigger.isUpdate) {
        // AddedBy: Concret.io 20th May 2025
        // Task: Calculate AR Days and Average Payment Settlement Days for Claim
        Set<Id> claimIds = new Set<Id>();
        
        //
        Map<Id, String> patientIdWithClaimCollector = new Map<Id, String>();
        
        Set<String> finalPendingStatus = new Set<String>{
            'Payment Received', 'Uncollectible / Partial Payment Received', 'Write Off / Partial Payment Received'
        };
        for (Claim__c claim : Trigger.new) {
            Claim__c oldClaim = Trigger.oldMap.get(claim.Id);
            if (
                oldClaim != null && (
                (claim.Date_Sent_to_Ins_Co__c != oldClaim.Date_Sent_to_Ins_Co__c) ||
                (claim.Pending_Status__c != null && claim.Pending_Status__c != oldClaim.Pending_Status__c
                && finalPendingStatus.contains(claim.Pending_Status__c)
                )
                )
            ) {
                claimIds.add(claim.Id);
            }
            
            // AddedBy: Concret.io 13-Aug-2026 requested by Giancarlo
            // If Claim Collector change we added this functionality to update the Claim_Assigned_To__c field on the Task object for all open tasks related to the patient of the claim.
            if(claim.Collector__c != null && oldClaim.Collector__c != claim.Collector__c){
                patientIdWithClaimCollector.put(claim.Patient__c, claim.Collector__c);
            }
        }
        if (!claimIds.isEmpty()) {
            ClaimPaymentDaysHandler.updateClaimPaymentDates(claimIds);
        }
        if(!patientIdWithClaimCollector.isEmpty()){
            ClaimPaymentDaysHandler.assignCollectorToTask(patientIdWithClaimCollector);
        }
        
        // Notify patient of relevant claim field changes
        ClaimNotificationHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
    }
}