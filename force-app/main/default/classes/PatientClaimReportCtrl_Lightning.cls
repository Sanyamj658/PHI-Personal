/**
 * ─────────────────────────────────────────────────────────────────────────────────────────────────┐
 * This class is the controller class of Patient Claim Report lightning component.
 * ──────────────────────────────────────────────────────────────────────────────────────────────────
 * @author      : concret.io
 * @createdOn   : 09-Dec-2024    
 * ──────────────────────────────────────────────────────────────────────────────────────────────────
 */
public class PatientClaimReportCtrl_Lightning {
	@AuraEnabled
	public static Map<String, List<PicklistOption>> getCollectorsAndMedicalProviders() {
		try {
			// Fetch Collectors data
			List<PicklistOption> collectorOptions = new List<PicklistOption>();
			for (Schema.PicklistEntry entryObj : Claim__c.Collector__c.getDescribe().getPicklistValues()) {
				if (entryObj.isActive()) {
					collectorOptions.add(
						new PicklistOption(entryObj.getLabel(), entryObj.getValue())
					);
				}
			}
			// Fetch MedicalProviders data
			List<PicklistOption> medicalProviderOptions = new List<PicklistOption>();
			for (Account accountObj : [SELECT Id, Name FROM Account ORDER BY Name LIMIT 50000]) {
				medicalProviderOptions.add(
					new PicklistOption(accountObj.Name, accountObj.Id)
				);
			}

			return new Map<String, List<PicklistOption>>{
				'Collector' => collectorOptions, 
				'Medical_Provider' => medicalProviderOptions
			};
		} catch (Exception excp) {
			throw new AuraHandledException(excp.getMessage());
		}
	}

	public class PicklistOption {
		@AuraEnabled public String label { get; set; }
		@AuraEnabled public String value { get; set; }
		@AuraEnabled public Boolean  selected { get; set; }

		public PicklistOption(String label, String value) {
			this.label = label;
			this.value = value;
			this.selected = false;
		}
	}
}