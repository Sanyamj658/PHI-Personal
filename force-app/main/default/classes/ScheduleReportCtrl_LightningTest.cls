@isTest
public class ScheduleReportCtrl_LightningTest {
    
	@isTest(SeeAllData=true)
	private static void testScheduleReportPicklistOptions() {
		Test.startTest();
		Map<String, List<ScheduleReportCtrl_Lightning.PicklistOption>> scheduleReportPicklistOptions = ScheduleReportCtrl_Lightning.getScheduleReportPicklistOptions();
		Test.stopTest();
		Assert.isTrue(!scheduleReportPicklistOptions.isEmpty(), 'Response should contains picklist options.');
	}

	@isTest
	private static void testSaveScheduleReportWithBlankParamterValues() {       
		Test.startTest();
		Boolean result = ScheduleReportCtrl_Lightning.saveScheduleReport('', '', '', '');
		Test.stopTest();
		Assert.isFalse(result, 'Schedule Report should not be created.');
	}

	@isTest(SeeAllData=true)
	private static void testSaveScheduleReport() {		
		Report reportRecord = [SELECT Id, Name FROM Report LIMIT 1];
		Account accountRecord = new Account(
			Name = 'Test Account',
			Email__c = 'testprimary@test.com',
			Contact_1_Email__c = 'testcontact1email@test.com',
			Contact_2_Email__c = 'testcontact2email@test.com',
			Contact_3_Email__c = 'testcontact3email@test.com',
			Contact_4_Email__c = 'testcontact4email@test.com',
			Contact_5_Email__c = 'testcontact5email@test.com',
            Account_Manager_Name__c = 'Test Manager'
		);
		insert accountRecord;
		
		Test.startTest();
		Boolean result = ScheduleReportCtrl_Lightning.saveScheduleReport(reportRecord.Id, accountRecord.Id, '.csv', 'Test Report Subject');
		Test.stopTest();
		
		List<Schedule_Report__c> scheduleReports = [SELECT Id FROM Schedule_Report__c WHERE Report_Name__c = :reportRecord.Name];
		Assert.isTrue(!scheduleReports.isEmpty(), 'Record should be inserted for Schedule_Report.');
	}	
}