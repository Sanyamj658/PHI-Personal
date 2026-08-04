// AddedBy: Concret.io 22th May 2025 
// Task: Process existing claim records to calculate AR Days and Average Payment Settlement Days for Claim

public class ProcessClaimSettlementDaysBtch implements Database.Batchable<sObject>, Database.stateful {
    private String customFilter = '';
    private Map<Id, String> failedClaimErrors = new Map<Id, String>();
    private List<String> emailRecipients = new List<String>{'aahuja@concret.io'};
    
    public ProcessClaimSettlementDaysBtch() {}
    
    public ProcessClaimSettlementDaysBtch(String customFilter) {
        this.customFilter = customFilter;
    }
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        String query = 'SELECT Id, Date_Sent_to_Ins_Co__c, DaysInAR__c, Pending_Status__c, Average_Claim_Payment_Settlement_Days__c '
            + ' FROM Claim__c WHERE Date_Sent_to_Ins_Co__c != null';
        try {
            if(String.isNotBlank(customFilter)) {
                query += ' AND ' + customFilter;
            }
            return Database.getQueryLocator(query);
        } catch(Exception ex) {
            System.debug('Exception occurred in Start Method: '+ ex.getMessage());
            return null;
        }
    }

    public void execute(Database.BatchableContext bc, List<Claim__c> claimList) {
        List<Claim__c> claimsToUpdate = new List<Claim__c>();
        Map<Id, Claim_Payment__c> claimWithLatestPaymentMap = new Map<Id, Claim_Payment__c>();
        Map<Id, Claim_Payment__c> claimWithLatestInsurancePaymentMap = new Map<Id, Claim_Payment__c>(); 

        try {
            Map<Id, Claim__c> claimMap = new Map<Id, Claim__c>(claimList);

            // Fetch all relevant claim payments
            List<Claim_Payment__c> claimPaymentList = getClaimPaymentList(claimMap.keySet()); 

            for(Claim_Payment__c cp : claimPaymentList) {
                if(!claimWithLatestPaymentMap.containsKey(cp.Claim_Number__c)) {
                    claimWithLatestPaymentMap.put(cp.Claim_Number__c, cp);   
                }
                if(!claimWithLatestInsurancePaymentMap.containsKey(cp.Claim_Number__c) && cp.Payment_Type__c == 'Insurance Payment') {
                    claimWithLatestInsurancePaymentMap.put(cp.Claim_Number__c, cp);   	
                }
            }

            for(Id claimId : claimMap.keySet()) { 
                Decimal daysInAR = 0;
                Boolean isClaimPaymentExist = false;

                Claim__c claim = claimMap.get(claimId);

                if(claim.Date_Sent_to_Ins_Co__c == null) {
                    claim.DaysInAR__c = null; 
                    claim.Average_Claim_Payment_Settlement_Days__c = null;
                } else {
                    if(claimWithLatestPaymentMap.containsKey(claimId)) {
                        Claim_Payment__c latestDatePaidClaimPayment = claimWithLatestPaymentMap.get(claimId);
                        daysInAR = claim.Date_Sent_to_Ins_Co__c.daysBetween(latestDatePaidClaimPayment.Payment_Date__c);
                        isClaimPaymentExist = true;
                    }

                    if(claimWithLatestInsurancePaymentMap.containsKey(claimId)) {
                        Claim_Payment__c insurancePayment = claimWithLatestInsurancePaymentMap.get(claimId);
                        claim.Average_Claim_Payment_Settlement_Days__c = claim.Date_Sent_to_Ins_Co__c.daysBetween(insurancePayment.Payment_Date__c);
                    } else {
                        claim.Average_Claim_Payment_Settlement_Days__c = null;
                    }

                    Set<String> pendingStatus = new Set<String>{
                        'Payment Received', 'Uncollectible / Partial Payment Received', 'Write Off / Partial Payment Received'
                    };

                    if(!isClaimPaymentExist && pendingStatus.contains(claim.Pending_Status__c)) {
                        claim.DaysInAR__c = claim.Date_Sent_to_Ins_Co__c.daysBetween(System.today());
                    } else if(!isClaimPaymentExist && !pendingStatus.contains(claim.Pending_Status__c)) {
                        claim.DaysInAR__c = null;
                    } else {                
                        claim.DaysInAR__c = daysInAR;
                    }
                }               
                claimsToUpdate.add(claim);
            }

            if(!claimsToUpdate.isEmpty()) {
                Database.SaveResult[] saveResultList = Database.update(claimsToUpdate, false);
                for(Integer i = 0; i < saveResultList.size(); i++) {
                    if(!saveResultList[i].isSuccess()) {
                        Id failedId = claimsToUpdate[i].Id;
                        String errorMsg = '';
                        for (Database.Error err : saveResultList[i].getErrors()) {
                            errorMsg += err.getMessage() + ' ';
                        }
                        failedClaimErrors.put(failedId, errorMsg.trim());
                    }
                }                
            } 
        } catch(Exception ex) {
            System.debug('Exception occurred in Execute Method: ' + ex.getMessage());
        }               
    }

    public void finish(Database.BatchableContext bc) {
        try {
            if (!failedClaimErrors.isEmpty()) {
                String body = 'The following Claim records failed to update:\n\n';
                for (Id claimId : failedClaimErrors.keySet()) {
                    body += 'Claim Id: ' + claimId + '\n Error: ' + failedClaimErrors.get(claimId) + '\n\n';
                }

                Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                email.setToAddresses(emailRecipients);
                email.setSubject('Claim Update Failed: Calculation of AR and Average Settlement Days');
                email.setPlainTextBody(body);
                Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
            }
        } catch(Exception ex) {
            System.debug('Exception occurred in finish: ' + ex.getMessage());
        }
    }

    public static List<Claim_Payment__c> getClaimPaymentList(Set<Id> claimIds) {
        List<Claim_Payment__c> claimPaymentList = new List<Claim_Payment__c>();
        if(!claimIds.isEmpty()) {
            claimPaymentList =  [
                SELECT Id, Claim_Number__c, Payment_Type__c, Payment_Date__c 
                FROM Claim_Payment__c 
                WHERE Claim_Number__c IN :claimIds 
                AND Payment_Date__c != null 
                AND Who_received_the_money__c = 'Payment Received' 
                AND Payment_Type__c IN ('Patient Payment', 'Insurance Payment') 
                ORDER BY Payment_Date__c DESC 
                LIMIT 45000
            ];
        }
        return claimPaymentList;        
    }
}