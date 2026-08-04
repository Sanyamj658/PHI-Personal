@isTest(seeAllData=true)
public class TestScheduleReportController{
    static testMethod void myUnitTest() {
        ScheduleReportController SCR = new ScheduleReportController();
        SCR.subject='Hi';
        SCR.SelectedContact ='life support ambulances';
        SCR.selectedReport='Sample Report: # of Accounts';
        SCR.selectedReportFormat = '.csv';
         test.startTest();
            SCR.getReportList();
            SCR.getContactList();
        	SCR.getReportFormats();
            SCR.save();
            SCR.Cancel();
         test.stopTest();
    }
}