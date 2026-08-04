// AddedBy: Concret.io 14th July 2025 
// Task: Calculate AR Days based on the Latest Valid Collector on Claim

public with sharing class LatestCollectorARDaysBtch implements Database.Batchable<sObject> {

    public Database.QueryLocator start(Database.BatchableContext bc) {
        String query = 'SELECT Id, Name, Pending_Status__c, Collector__c, CreatedDate FROM Claim__c WHERE Pending_Status__c = \'Payment Received\' AND Collector__c NOT IN (\'Admin\',\'Administrator\')';
        try {
            return Database.getQueryLocator(query);
        } 
        catch(Exception ex) {
            System.debug('Exception occurred in LatestCollectorARDaysBtch - Start Method: '+ ex.getMessage());
            return null;
        }
    }

    public void execute(Database.BatchableContext bc, List<Claim__c> claimList) {
        Set<Id> claimIds = new Set<Id>();
        List<Claim__c> claimToUpdateList = new List<Claim__c>();
        Map<Id,Date> claimIdWithLatestCollectorDateMap = new Map<Id,Date>();
        Map<Id,Date> claimIdWithPaymentReceivedDateMap = new Map<Id,Date>();

        for(Claim__c claim : claimList) {
            claimIds.add(claim.Id);
        }

        List<Claim__History> claimHistoryList = [   SELECT Id, Field, OldValue, NewValue, CreatedDate, Parent.Id
                                                    FROM Claim__History
                                                    WHERE Parent.Id IN : claimIds
                                                    AND (Field = 'Collector__c' OR Field = 'Pending_Status__c')
                                                    ORDER BY CreatedDate DESC
                                                ];
        for(Claim__History history : claimHistoryList) {
            if(history.Field == 'Collector__c' && (String.valueOf(history.NewValue) != 'Admin' && String.valueOf(history.NewValue) != 'Administrator')) {
                if(!claimIdWithLatestCollectorDateMap.containsKey(history.Parent.Id)) {
                    claimIdWithLatestCollectorDateMap.put(history.Parent.Id, history.CreatedDate.date());
                }
            }
            
            if(history.Field == 'Pending_Status__c' && String.valueOf(history.NewValue) == 'Payment Received') {
                if(!claimIdWithPaymentReceivedDateMap.containsKey(history.Parent.Id)) {
                    claimIdWithPaymentReceivedDateMap.put(history.Parent.Id, history.CreatedDate.date());
                }
            }
        }

        if(!claimIdWithLatestCollectorDateMap.isEmpty() && !claimIdWithPaymentReceivedDateMap.isEmpty()) {
            for(Claim__c claim : claimList) {
                if(claimIdWithLatestCollectorDateMap.containsKey(claim.Id) && claimIdWithPaymentReceivedDateMap.containsKey(claim.Id)) {
                    Date collectorChangeDate = claimIdWithLatestCollectorDateMap.get(claim.Id);
                    Date paymentReceivedDate = claimIdWithPaymentReceivedDateMap.get(claim.Id);

                    System.debug('collectorChangeDate: '+collectorChangeDate);
                    System.debug('paymentReceivedDate: '+paymentReceivedDate);

                    claim.Latest_Collector_AR_Days__c = collectorChangeDate.daysBetween(paymentReceivedDate);
                    System.debug('claim.Latest_Collector_AR_Days__c: '+claim.Latest_Collector_AR_Days__c);

                }    
                else if(!claimIdWithLatestCollectorDateMap.containsKey(claim.Id) && claimIdWithPaymentReceivedDateMap.containsKey(claim.Id)) {
                    Date collectorCreatedDate = claim.CreatedDate.date();
                    Date paymentReceivedDate = claimIdWithPaymentReceivedDateMap.get(claim.Id);

                    System.debug('collectorCreatedDate: '+collectorCreatedDate);
                    System.debug('paymentReceivedDate: '+paymentReceivedDate);

                    claim.Latest_Collector_AR_Days__c = collectorCreatedDate.daysBetween(paymentReceivedDate);
                    System.debug('claim.Latest_Collector_AR_Days__c: '+claim.Latest_Collector_AR_Days__c);
                }            
            }
        }

        if(!claimList.isEmpty()) {
            System.debug('claimList: '+claimList);
            update claimList;
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('Finish Called - LatestCollectorARDaysBtch');
    }
}


// Database.executeBatch(new LatestCollectorARDaysBtch(), 200);