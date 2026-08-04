public without sharing class ClaimCollectorInfoController {

	//Mock
    public static List<Claim__History> mockHistoryList;

    @AuraEnabled(cacheable = true)
    public static Map<String, Object> getCollectorAndARdays(Id claimId) {
        Integer daysTaken;
        String latestCollector;
        Date collectorChangeDate;
        Date paymentReceivedDate;

        List<Claim__c> claimList = [SELECT Collector__c, CreatedDate FROM Claim__c WHERE Id = :claimId AND Collector__c != null AND Collector__c NOT IN ('Admin','Administrator') LIMIT 1];
        List<Claim__History> historyRecords = getClaimHistory(claimId);

        if(!claimList.isEmpty()) {
            for (Claim__History record : historyRecords) {
                if (paymentReceivedDate == null && record.Field == 'Pending_Status__c' && String.valueOf(record.NewValue) == 'Payment Received') {
                    paymentReceivedDate = record.CreatedDate.date();
                }

                if (collectorChangeDate == null && record.Field == 'Collector__c' && String.valueOf(record.NewValue) != 'Admin' && String.valueOf(record.NewValue) != 'Administrator') {
                    collectorChangeDate = record.CreatedDate.date();
                    latestCollector = String.valueOf(record.NewValue);
                }

                if (paymentReceivedDate != null && collectorChangeDate != null) {
                    break;
                }
            }
                
            // if collector wasn't changed but is valid on record
            if(collectorChangeDate == null && paymentReceivedDate != null) {
                collectorChangeDate = claimList[0].CreatedDate.date();
                latestCollector = claimList[0].Collector__c;
            }

            // Calculate AR Days if both dates are known
            if (paymentReceivedDate != null && collectorChangeDate != null) {
                daysTaken = collectorChangeDate.daysBetween(paymentReceivedDate);
            }

            return new Map<String, Object>{
                'daysTaken' => daysTaken,
                'latestCollector' => latestCollector
            };
        }

        return new Map<String, Object>{
                'daysTaken' => null,
                'latestCollector' => null
        };
    }

    private static List<Claim__History> getClaimHistory(Id claimId) {
        if (Test.isRunningTest() && mockHistoryList != null) {
            return mockHistoryList;
        }

        return [
            SELECT Id, Field, OldValue, NewValue, CreatedDate
            FROM Claim__History
            WHERE Parent.Id = :claimId
            AND (Field = 'Collector__c' OR Field = 'Pending_Status__c')
            ORDER BY CreatedDate DESC
        ];
    }
}