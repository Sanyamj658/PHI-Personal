@isTest
public class TestScheduledJobReport {
    static testMethod void myUnitTest() {
        ScheduledJobReport SJR = new ScheduledJobReport();
        String sch = '0 0 23 * * ?';
         test.startTest();
        system.schedule('Test',sch,SJR); 
         test.stopTest();
    }
}