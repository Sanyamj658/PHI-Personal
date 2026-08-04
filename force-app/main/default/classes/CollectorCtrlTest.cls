@isTest
public class CollectorCtrlTest {
	@isTest
	private static void testGetCollectorForPatientNoPatient() {
		Test.startTest();
		String response = CollectorCtrl.getCollectorForPatient('');
		Test.stopTest();
		Assert.isTrue(String.isBlank(response), 'No Collector exist.');
	}

	@isTest
	private static void testGetCollectorForPatientNoCollector() {
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

		Test.startTest();
		String response = CollectorCtrl.getCollectorForPatient(contactRecord.Id);
		Test.stopTest();
		Assert.isTrue(String.isBlank(response), 'No Collector exist.');
	}

	@isTest
	private static void testGetCollectorForPatient() {
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

		Collector__c collectorRecord = new Collector__c();
		collectorRecord.Patient__c = contactRecord.id;
		collectorRecord.Collectors__c = 'Admin';
		insert collectorRecord;

		Test.startTest();
		String response = CollectorCtrl.getCollectorForPatient(contactRecord.Id);
		Test.stopTest();
		Assert.areEqual('Admin', response, 'Related collector should be exist.');
	}
}