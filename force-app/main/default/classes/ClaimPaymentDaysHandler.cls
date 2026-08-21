// AddedBy: Concret.io 20th May 2025
// Task: Calculate AR Days and Average Payment Settlement Days for Claim
public class ClaimPaymentDaysHandler {
    //public static boolean isCourtsyPaymentUpdated = false;
    public static void updateClaimPaymentDates(Set<Id> claimIds) {
        List<Claim__c> claimsToUpdate = new List<Claim__c>();
        Map<Id,Claim_Payment__c> claimWithLatestPaymentMap = new Map<Id,Claim_Payment__c>();
        Map<Id,Claim_Payment__c> claimWithLatestInsurancePaymentMap = new Map<Id,Claim_Payment__c>();
        
        //Query Claims
        Map<Id,Claim__c> claimMap = new Map<Id,Claim__c>(
            [SELECT Id, Date_Sent_to_Ins_Co__c, DaysInAR__c, Pending_Status__c, Average_Claim_Payment_Settlement_Days__c 
                FROM 
                Claim__c 
                WHERE Id IN :claimIds
            ]
            );
        
        // Fetch all relevant claim payments
        List<Claim_Payment__c> claimPaymentList = getClaimPaymentList(claimIds);
        
        for(Claim_Payment__c cp : claimPaymentList) {
            if(!claimWithLatestPaymentMap.containsKey(cp.Claim_Number__c)) {
                claimWithLatestPaymentMap.put(cp.Claim_Number__c, cp);
            }
            if(!claimWithLatestInsurancePaymentMap.containsKey(cp.Claim_Number__c) && cp.Payment_Type__c == 'Insurance Payment') {
                claimWithLatestInsurancePaymentMap.put(cp.Claim_Number__c, cp);
            }
        }
        
        for(Id claimId : claimIds) {
            Decimal daysInAR = 0;
            Boolean isClaimPaymentExist = false;
            
            Claim__c claim = claimMap.get(claimId);
            
            if(claim.Date_Sent_to_Ins_Co__c == null) {
                claim.DaysInAR__c = null;
                claim.Average_Claim_Payment_Settlement_Days__c = null;
            }
            else {
                if(claimWithLatestPaymentMap.containsKey(claimId)) {
                    Claim_Payment__c latestDatePaidClaimPayment = claimWithLatestPaymentMap.get(claimId);
                    daysInAR = claim.Date_Sent_to_Ins_Co__c.daysBetween(latestDatePaidClaimPayment.Payment_Date__c);
                    isClaimPaymentExist = true;
                }
                
                if(claimWithLatestInsurancePaymentMap.containsKey(claimId)) {
                    Claim_Payment__c insurancePayment = claimWithLatestInsurancePaymentMap.get(claimId);
                    claim.Average_Claim_Payment_Settlement_Days__c = claim.Date_Sent_to_Ins_Co__c.daysBetween(insurancePayment.Payment_Date__c);
                }
                else {
                    claim.Average_Claim_Payment_Settlement_Days__c = null;
                }
                Set<String> pendingStatus = new Set<String>{
                    'Payment Received', 'Uncollectible / Partial Payment Received', 'Write Off / Partial Payment Received'
                };
                if(!isClaimPaymentExist && pendingStatus.contains(claim.Pending_Status__c)) {
                    claim.DaysInAR__c = claim.Date_Sent_to_Ins_Co__c.daysBetween(System.today());
                }
                else if(!isClaimPaymentExist && !pendingStatus.contains(claim.Pending_Status__c)) {
                    claim.DaysInAR__c = null;
                }
                else {
                    claim.DaysInAR__c = daysInAR;
                }
            }
            claimsToUpdate.add(claim);
            System.debug('claimsToUpdate: '+claimsToUpdate);
        }
        if(!claimsToUpdate.isEmpty()) {
            update claimsToUpdate;
        }
    }
    
    public static List<Claim_Payment__c> getClaimPaymentList(Set<Id> claimIds) {
        return [SELECT Id, Claim_Number__c, Payment_Type__c, Payment_Date__c 
                FROM Claim_Payment__c 
                WHERE Claim_Number__c IN :claimIds 
                AND Payment_Date__c != null 
                AND Who_received_the_money__c = 'Payment Received' 
                AND Payment_Type__c IN ('Patient Payment', 'Insurance Payment') 
                ORDER BY Payment_Date__c DESC LIMIT 45000
        ];
    }
    
    // AddedBy: Concret.io 11th Aug 2025
    // Task: Calculate the Sum of Courstesy Claim Payment for Claim
    // public static void updateClaimPayableToClient(Set<Id> claimIds) {
        //     System.debug('claimIds: '+claimIds);
        
        //     List<Claim__c> claimsToUpdate = new List<Claim__c>();
        //     Map<Id,Decimal> claimIdwithSumCourtestAmtMap = new Map<Id,Decimal>();
        
        //     List<Claim_Payment__c> existingCourtesyPaymentList = [SELECT Id, Claim_Number__c, Payment_Type__c, Amount__c FROM Claim_Payment__c WHERE Claim_Number__c IN :claimIds AND Payment_Type__c = 'Courtesy Payment'];
        
        //     for(Claim_Payment__c courtesyPayment : existingCourtesyPaymentList) {
            //         if(!claimIdwithSumCourtestAmtMap.containsKey(courtesyPayment.Claim_Number__c)) {
                //             claimIdwithSumCourtestAmtMap.put(courtesyPayment.Claim_Number__c, 0);
            //         }
            //         Decimal courtesyAmt = claimIdwithSumCourtestAmtMap.get(courtesyPayment.Claim_Number__c) + courtesyPayment.Amount__c;
            //         claimIdwithSumCourtestAmtMap.put(courtesyPayment.Claim_Number__c, courtesyAmt);
        //     }
        
        //     System.debug('claimIdwithSumCourtestAmtMap: '+claimIdwithSumCourtestAmtMap);
        //     for(Id claimId : claimIds) {
            //         Claim__c claimRecord = new Claim__c(Id=claimId);
            //         claimRecord.Payable_to_Client__c = claimIdwithSumCourtestAmtMap.get(claimId);
            
            //         claimsToUpdate.add(claimRecord);
        //     }
        //     System.debug('claimsToUpdate: '+claimsToUpdate);
        
        //     if(!claimsToUpdate.isEmpty()) {
            //         isCourtsyPaymentUpdated = true;
            //         update claimsToUpdate;
        //     }
    // }
    
    
    // AddedBy: Concret.io 13-Aug-2026
    //Updating a task Claim_Assigned_to__c with the claim collector for a record
    public static void assignCollectorToTask(Map<Id, String> patientIdWithClaimCollector) {
        List<Task> tasksToUpdate = [ SELECT Id, WhoId, Claim_Assigned_To__c
            FROM Task
            WHERE WhoId IN :patientIdWithClaimCollector.keySet()
            AND Status = 'Open'];
        for (Task taskObj : tasksToUpdate) {
            taskObj.Claim_Assigned_To__c = patientIdWithClaimCollector.get(taskObj.WhoId);
        }
        
        if (!tasksToUpdate.isEmpty()) {
            update tasksToUpdate;
        }
    }
}