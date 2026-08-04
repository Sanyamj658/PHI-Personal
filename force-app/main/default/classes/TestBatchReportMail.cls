/**
 * This class contains unit tests for validating the behavior of Apex classes
 * and triggers.
 *
 * Unit tests are class methods that verify whether a particular piece
 * of code is working properly. Unit test methods take no arguments,
 * commit no data to the database, and are flagged with the testMethod
 * keyword in the method definition.
 *
 * All test methods in an organization are executed whenever Apex code is deployed
 * to a production organization to confirm correctness, ensure code
 * coverage, and prevent regressions. All Apex classes are
 * required to have at least 75% code coverage in order to be deployed
 * to a production organization. In addition, all triggers must have some code coverage.
 * 
 * The @isTest class annotation indicates this class only contains test
 * methods. Classes defined with the @isTest annotation do not count against
 * the organization size limit for all Apex scripts.
 *
 * See the Apex Language Reference for more information about Testing and Code Coverage.
 */
@isTest
public class TestBatchReportMail {
    @TestSetup
    private static void setupData(){
        insert new Schedule_Report__c(
            Email__c = 'test@test.com',
            Email1__c ='test1@test.com',
            Email2__c ='test4@test.com',
            Email3__c ='test5@test.com',
            Email4__c ='test6@test.com',
            Email5__c ='test7@test.com',
            Report_Name__c = 'test report', 
            Report_Format__c = '.csv',
            //Select_Contacts__c = '',
            //Select_Report__c, 
            Subject__c ='Test'
        	);
        insert new Schedule_Report__c(
            Email__c = 'test2@test.com',
            Email1__c ='test3@test.com',
            Email2__c ='test4@test.com',
            Email3__c ='test5@test.com',
            Email4__c ='test6@test.com',
            Email5__c ='test7@test.com',
            Report_Name__c = 'test report', 
            Report_Format__c = '.xls',
            Subject__c ='Test2'
        	);
    }
    
    static testMethod void myUnitTest() {
        BatchReportMail ucb1 =new BatchReportMail([SELECT Id FROM Schedule_Report__c LIMIT 1].Id);
        BatchReportMail ucb =new BatchReportMail();
        
        Test.startTest();
            ID batchprocessid = database.executeBatch(ucb);
        	System.assert(batchprocessid!=null);
        Test.stopTest();
    }
}