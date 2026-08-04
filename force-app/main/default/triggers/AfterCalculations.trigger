trigger AfterCalculations on Claim_Payment__c (after insert, after update, after delete, after undelete) {
    
    if(Trigger.isAfter && (Trigger.isInsert || Trigger.isUpdate)){
        Claim_Payment__c CP = [SELECT Id,Amount__c,Claim_Number__c,Payment_Date__c,Due_to_Client1__c,Earned_Fee__c,Earned_fee_workflow__c,Paid_to_client__c,Payment_Type__c FROM Claim_Payment__c WHERE Id IN: Trigger.newMap.keySet()];
        AllCalculations ac = new AllCalculations();
        ac.ai(CP.Claim_Number__c,Trigger.isInsert,Trigger.isUpdate,Trigger.isDelete);

        // AddedBy: Concret.io 20th May 2025 
        // Task: Calculate AR Days and Average Payment Settlement Days for Claim        
        Set<Id> claimIds = new Set<Id>();
        for(Claim_Payment__c payment : Trigger.new) {
            Boolean flag =  payment.Claim_Number__c!=null 
                && payment.Payment_Date__c!=null 
                && payment.Who_received_the_money__c == 'Payment Received' 
                && (payment.Payment_Type__c == 'Patient Payment' || payment.Payment_Type__c == 'Insurance Payment');
            if(!flag) {
                continue;
            }
            if(Trigger.isInsert) {
                claimIds.add(payment.Claim_Number__c);
            } else if(Trigger.isUpdate) {
                Claim_Payment__c oldPayment = Trigger.oldMap.get(payment.Id);
                if( oldPayment != null && (
                                (oldPayment.Claim_Number__c != null && payment.Claim_Number__c != oldPayment.Claim_Number__c) ||
                                payment.Payment_Date__c != oldPayment.Payment_Date__c ||
                                payment.Who_received_the_money__c != oldPayment.Who_received_the_money__c ||
                                payment.Payment_Type__c != oldPayment.Payment_Type__c)
                ) {
                    claimIds.add(payment.Claim_Number__c);
                    claimIds.add(oldPayment.Claim_Number__c);
                }
            }
        }
        if(!claimIds.isEmpty()) {
            ClaimPaymentDaysHandler.updateClaimPaymentDates(claimIds);
        }       
    }    

    // AddedBy: Concret.io 20th May 2025 
    // Task: Calculate AR Days and Average Payment Settlement Days for Claim    
    if(Trigger.isAfter && Trigger.isDelete) {
        Set<Id> claimIds = new Set<Id>();
        for(Claim_Payment__c payment : Trigger.old) {
            Boolean flag =  payment.Claim_Number__c !=null 
                && payment.Payment_Date__c!=null 
                && payment.Who_received_the_money__c == 'Payment Received' 
                && (payment.Payment_Type__c == 'Patient Payment' || payment.Payment_Type__c == 'Insurance Payment');
            if(flag) {
                claimIds.add(payment.Claim_Number__c); //updateClaimPaymentDates
            } 
        }

        if(!claimIds.isEmpty()) {
            ClaimPaymentDaysHandler.updateClaimPaymentDates(claimIds);
        }  
    }

    if(Trigger.isDelete){
        AllCalculations ac1 = new AllCalculations();
        for( Claim_Payment__c cp1 : Trigger.old){
            ac1.ai(cp1.Claim_Number__c,Trigger.isInsert,Trigger.isUpdate,Trigger.isDelete);
        }
    } 
}