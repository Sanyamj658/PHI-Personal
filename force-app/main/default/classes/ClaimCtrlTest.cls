@isTest
public class ClaimCtrlTest {
	@isTest
	private static void testDeleteClaimNotExist() {
		Test.startTest();
		Boolean response = ClaimCtrl.deleteClaim('');
		Test.stopTest();
		Assert.isFalse(response, 'There is no claim.');
	}

	@isTest
	private static void testDeleteClaim() {
		Account accountRecord = new Account(Name = 'Test Medical Provider', Account_Manager_Name__c = 'Test Manager');
		insert accountRecord;

		Insurance_Company__c insuranceCompany = new Insurance_Company__c(
			Name = 'Test Insurance Company', 
			Eligibility_Coverage_Phone__c = '0123', 
			Pre_Cert_Auth_Phone__c = '0123'
		);
		insert insuranceCompany;
		
		Contact contactRecord = new Contact(
			AccountId = accountRecord.Id,
			LastName = 'Test Patient',
			DX_s__c = 'Test DX',
			Plan_Type__c = 'Other Plan',
			Primary_Insurance__c = insuranceCompany.Id,
			Account_Status__c='Verification work in process'
		);
		insert contactRecord;

		Claim__c claimRecord = new Claim__c(
			Date_Received__c = System.today(),
			From_DOS__c = System.today(),
			To_DOS__c = System.today(),
			Pending_Status__c = 'Write-Off',
			Claim_Rate__c = 10,
			Medical_Provider__c = accountRecord.Id,
			Patient__c = contactRecord.Id,
			Facility_Charges__c = 1000,
			Professional_Charges__c = 1000,
			Insurance_Company__c = insuranceCompany.Id,
			Invoice_Number__c = 'invoice0001',
			Insurance_Policy_Limit__c = 'N/A'
		);
		insert claimRecord;

		Test.startTest();
		Boolean response = ClaimCtrl.deleteClaim(claimRecord.Id);
		Test.stopTest();
		Assert.isTrue(response, 'Claim should be deleted.');
		List<Claim__c> claims = [SELECT Id FROM Claim__c];
		Assert.isTrue(claims.isEmpty(), 'Claim record is deleted.');
	}
}