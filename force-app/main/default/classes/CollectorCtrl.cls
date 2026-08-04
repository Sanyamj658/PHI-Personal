/**
 * ─────────────────────────────────────────────────────────────────────────────────────────────────┐
 * This class is the controller class of Open New Claim lightning component.
 * ──────────────────────────────────────────────────────────────────────────────────────────────────
 * @author      : concret.io
 * @createdOn   : 17-Dec-2024    
 * ──────────────────────────────────────────────────────────────────────────────────────────────────
 */
public class CollectorCtrl {
	@AuraEnabled
	public static String getCollectorForPatient(String patientId) {
		try {
			if (String.isBlank(patientId)) {
				return '';
			}
			List<Collector__c> collectors = [SELECT Collectors__c FROM Collector__c 
				WHERE Patient__c = :patientId ORDER BY CreatedDate DESC LIMIT 1];
			if (!collectors.isEmpty()) {
				return collectors[0].Collectors__c;
			}
			return '';
		} catch (Exception excp) {
			throw new AuraHandledException(excp.getMessage());
		}
	}
}