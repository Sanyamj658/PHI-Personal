@isTest
public class PatientClaimReportCtrl_LightningTest {
	@isTest
	private static void testCollectorsAndMedicalProviders() {
		Account accountRecord = new Account(Name = 'Test Account', Account_Manager_Name__c = 'Test Manager');
		insert accountRecord;
		Test.startTest();
		PatientClaimReportCtrl_Lightning.getCollectorsAndMedicalProviders();
		Test.stopTest();
	}
}