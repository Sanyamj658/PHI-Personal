/**
 * ─────────────────────────────────────────────────────────────────────────────────────────────────┐
 * This class is the controller class of Schedule Report lightning component.
 * ──────────────────────────────────────────────────────────────────────────────────────────────────
 * @author      : concret.io
 * @createdOn   : 09-Dec-2024    
 * ──────────────────────────────────────────────────────────────────────────────────────────────────
 */
public class ScheduleReportCtrl_Lightning {
	@AuraEnabled
	public static Boolean saveScheduleReport(String selectReport, String accountId, String reportFormat, String reportSubject) {
		try {
			if (String.isBlank(selectReport) || String.isBlank(accountId) 
				|| String.isBlank(reportFormat) || String.isBlank(reportSubject)
			) {
				return false;
			}
			Schedule_Report__c scheduleReportRecord = new Schedule_Report__c();

			List<Report> reports = [SELECT Id, Name FROM Report WHERE Id = :selectReport];
			if (!reports.isEmpty()) {
				scheduleReportRecord.Report_Name__c = reports[0].Name;
				scheduleReportRecord.Select_Report__c = selectReport.substring(0,15);
			}
			scheduleReportRecord.Report_Format__c = reportFormat;
			scheduleReportRecord.Subject__c = reportSubject;

			List<Account> accounts = [SELECT Id, Name, Email__c, Contact_1_Email__c, Contact_2_Email__c, 
				Contact_3_Email__c, Contact_4_Email__c, Contact_5_Email__c
				FROM Account WHERE Id = :accountId
			];
			if (!accounts.isEmpty()) {
				scheduleReportRecord.Select_Contacts__c = accounts[0].Name;
				scheduleReportRecord.Email__c = accounts[0].Email__c;
				scheduleReportRecord.Email1__c = accounts[0].Contact_1_Email__c;
				scheduleReportRecord.Email2__c = accounts[0].Contact_2_Email__c;
				scheduleReportRecord.Email3__c = accounts[0].Contact_3_Email__c;
				scheduleReportRecord.Email4__c = accounts[0].Contact_4_Email__c;
				scheduleReportRecord.Email5__c = accounts[0].Contact_5_Email__c;
			}
			insert scheduleReportRecord;
			return true;
		} catch (Exception excp) {
			throw new AuraHandledException(excp.getMessage());
		}
	}

	@AuraEnabled
	public static Map<String, List<PicklistOption>> getScheduleReportPicklistOptions() {
		try {
			// Fetch Report options
			List<PicklistOption> reportOptions = new List<PicklistOption>();
			reportOptions.add(new PicklistOption('--None--', ''));
			for (Report reportObj : [SELECT Id, Name FROM Report ORDER BY Name LIMIT 25000]) {
				reportOptions.add(
					new PicklistOption(reportObj.Name, reportObj.Id)
				);
			}
			// Fetch  Report contact options
			List<PicklistOption> reportContactOptions = new List<PicklistOption>();
			reportContactOptions.add(new PicklistOption('--None--', ''));
			for (Account accountObj : [SELECT Id, Name FROM Account WHERE Email__c != null ORDER BY Name LIMIT 25000]) {
				reportContactOptions.add(
					new PicklistOption(accountObj.Name, accountObj.Id)
				);
			}
			// Fetch Report format options
			List<PicklistOption> reportFormatOptions = new List<PicklistOption>();
			reportFormatOptions.add(new PicklistOption('--None--', ''));
			for (Schema.PicklistEntry entryObj : Schedule_Report__c.Report_Format__c.getDescribe().getPicklistValues()) {
				if (entryObj.isActive()) {
					reportFormatOptions.add(
						new PicklistOption(entryObj.getLabel(), entryObj.getValue())
					);
				}
			}
			return new Map<String, List<PicklistOption>>{
				'Select_Reports' => reportOptions,
				'Select_Contacts' => reportContactOptions,
				'Select_Report_Formats' => reportFormatOptions
			};
		} catch (Exception excp) {
			throw new AuraHandledException(excp.getMessage());
		}
	}

	public class PicklistOption {
		@AuraEnabled public String label { get; set; }
		@AuraEnabled public String value { get; set; }
		public PicklistOption(String label, String value) {
			this.label = label;
			this.value = value;
		}
	}
}