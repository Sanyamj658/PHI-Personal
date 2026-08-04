@isTest
public class ClaimAgingAlertBatchTest {
    @testSetup
    static void setup() {
        Account a = new Account(Name='Sample Account');
        insert a;
        Insurance_Company__c insCompany = new Insurance_Company__c(
            Name = 'Test Insurance Company', 
            Eligibility_Coverage_Phone__c = '0123', 
            Pre_Cert_Auth_Phone__c = '0123'
        );
        INSERT insCompany;   
        Contact c = new Contact(Accountid=a.id,lastname='test1', DX_s__c='test', Plan_Type__c=getPicklistValues('Contact', 'Plan_Type__c')[0], Primary_Insurance__c= insCompany.id);
        insert c;
        
        
        
        
        
        List<Claim__c> claims = new List<Claim__c>();
        Date today = Date.today();
        
        // Claims for 180 days ago
        for (Integer i = 0; i < 5; i++) {
            claims.add(new Claim__c(Date_Received__c=system.today(),
                                    From_DOS__c=system.today(),
                                    To_DOS__c=system.today(),
                                    Pending_Status__c='Payment Received Partial',
                                    Claim_Rate__c=10,
                                    Medical_Provider__c=a.id,
                                    Patient__c=c.id,
                                    Facility_Charges__c=1000,
                                    Professional_Charges__c=1000,
                                    Insurance_Company__c = insCompany.id,
                                    Invoice_Number__c = 'inv2' + i,
                                    Insurance_Policy_Limit__c = 'N/A',
                                    Date_Sent_to_Ins_Co__c = today.addDays(-180)
                                   ));
        }
        
        // Claims for 360 days ago
        for (Integer i = 0; i < 5; i++) {
            claims.add(new Claim__c(Date_Received__c=system.today(),
                                    From_DOS__c=system.today(),
                                    To_DOS__c=system.today(),
                                    Pending_Status__c='Payment Received Partial',
                                    Claim_Rate__c=10,
                                    Medical_Provider__c=a.id,
                                    Patient__c=c.id,
                                    Facility_Charges__c=1000,
                                    Professional_Charges__c=1000,
                                    Insurance_Company__c = insCompany.id,
                                    Invoice_Number__c = 'inv1' + i,
                                    Insurance_Policy_Limit__c = 'N/A',
                                    Date_Sent_to_Ins_Co__c = today.addDays(-360)
                                   ));
        }
        
        insert claims;
    }
    
            //Method to get active values of a picklist field
    public static List<String> getPicklistValues(String objectName, String fieldName) {
        List<String> values = new List<String>();
        for(Schema.DescribeSobjectResult res : Schema.describeSObjects(new List<String>{objectName})) {
            for (Schema.PicklistEntry entry : res.fields.getMap().get(fieldName).getDescribe().getPicklistValues()) {
                if (entry.isActive()) {
                    values.add(entry.getValue());
                }
            }
        }
        return values;
    }

    @isTest
    static void testBatchFor180DaysOld() {
        Test.startTest();
        ClaimAgingAlertBatch batch = new ClaimAgingAlertBatch(180);
        Database.executeBatch(batch);
        Test.stopTest();

        // Verify emails sent for 180 days old claims
        List<EmailMessage> sentEmails = [SELECT Id, Subject, HtmlBody FROM EmailMessage];
        System.assertEquals(5, sentEmails.size());

        for (EmailMessage email : sentEmails) {
            System.assert(email.Subject.contains('This claim is aging and needs your immediate attention'));
        }
    }

    @isTest
    static void testBatchFor360DaysOld() {
        Test.startTest();
        ClaimAgingAlertBatch batch = new ClaimAgingAlertBatch(360);
        Database.executeBatch(batch);
        Test.stopTest();

        // Verify emails sent for 360 days old claims
        List<EmailMessage> sentEmails = [SELECT Id, Subject, HtmlBody FROM EmailMessage];
        System.assertEquals(5, sentEmails.size());

        for (EmailMessage email : sentEmails) {
            System.assert(email.Subject.contains('This claim needs urgent attention !!!'));
        }
    }

    @isTest
    static void testSchedulableContext() {
        Test.startTest();
        String cronExp = '0 0 1 * * ?'; // Daily at 1 AM
        ClaimAgingAlertBatch.scheduleBatch('Test Claim Aging Alert Job');
        Test.stopTest();

        CronTrigger ct = [SELECT Id, CronExpression, TimesTriggered, NextFireTime
                          FROM CronTrigger WHERE CronJobDetail.Name = 'Test Claim Aging Alert Job'];
        System.assertEquals(cronExp, ct.CronExpression);
    }

    @isTest
    static void testExecuteSchedulable() {
        Test.startTest();
        ClaimAgingAlertBatch batch = new ClaimAgingAlertBatch(0); // Placeholder
        batch.execute(null);
        Test.stopTest();

        // Verify emails sent for both 180 and 360 days old claims
        List<EmailMessage> sentEmails = [SELECT Id, Subject, HtmlBody FROM EmailMessage];
        System.assertEquals(10, sentEmails.size());
    }
}