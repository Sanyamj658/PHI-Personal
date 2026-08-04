public class CaseTriggerHandler {
    public static Map<String, String> operationTypeWithErrorMessages = new Map<String, String>{
        'Update' => 'Related Medical Provider or Patient cannot be updated because this case has associated claims.',
        'Delete' => 'The case cannot be deleted because it has associated claims.'
    };
    public static void validateCaseModificationWithClaims(Map<Id,Case> caseMap, String operationType) {
        Map<Id, Integer> caseIdWithRelatedNoOfClaims = new Map<Id, Integer>();
            for (AggregateResult aggregateObj : [SELECT Case__c, COUNT(Id) totalClaims 
            	FROM Claim__c
                WHERE Case__c IN :caseMap.keySet()
               	GROUP BY Case__c 
                HAVING COUNT(Id) > 0 
           	]) {
				caseIdWithRelatedNoOfClaims.put(
					(Id) aggregateObj.get('Case__c'),
                	Integer.valueOf(aggregateObj.get('totalClaims'))
                );
            }
            for (Case caseRecord : caseMap.values()) {
                if (caseIdWithRelatedNoOfClaims.containsKey(caseRecord.Id)
                    && caseIdWithRelatedNoOfClaims.get(caseRecord.Id) > 0
                ) {
                    caseRecord.addError(
                    	(operationTypeWithErrorMessages.containsKey(operationType) ? operationTypeWithErrorMessages.get(operationType) : 'Something went wrong, Please try again')
                    );
                }
            } 
    }
}