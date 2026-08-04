/**
 * ─────────────────────────────────────────────────────────────────────────────────────────────────┐
 * This class is the controller class of Delete Claim Record lightning component.
 * ──────────────────────────────────────────────────────────────────────────────────────────────────
 * @author      : concret.io
 * @createdOn   : 16-Dec-2024    
 * ──────────────────────────────────────────────────────────────────────────────────────────────────
 */
public class ClaimCtrl {
	@AuraEnabled
	public static Boolean deleteClaim(String claimId){
		try {
			List<Claim__c> claims = [SELECT Id FROM Claim__c WHERE Id = :claimId];
			if (!claims.isEmpty()) {
				delete claims;
				return true;
			}
			return false;
		} catch (Exception excp) {
			throw new AuraHandledException(excp.getMessage());
		}
	}
}