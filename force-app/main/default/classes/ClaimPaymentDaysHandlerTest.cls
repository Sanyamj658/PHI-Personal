@isTest(seeAllData=false)
private class ClaimPaymentDaysHandlerTest {

    static testMethod void testUpdateClaimPaymentDates_WithPayments() {
        // Create supporting insurance and claim
        Insurance_Company__c ins = new Insurance_Company__c(Name='TestInsurance');
        insert ins;

        Claim__c c = new Claim__c(Date_Sent_to_Ins_Co__c=Date.newInstance(2026,1,1), Pending_Status__c='Payment Received');
        insert c;

        // Create a matching claim payment (Insurance Payment)
        Claim_Payment__c cp = new Claim_Payment__c(
            Claim_Number__c = c.Id,
            Payment_Type__c = 'Insurance Payment',
            Payment_Date__c = Date.newInstance(2026,1,10),
            Who_received_the_money__c = 'Payment Received'
        );
        insert cp;

        Test.startTest();
        ClaimPaymentDaysHandler.updateClaimPaymentDates(new Set<Id>{c.Id});
        Test.stopTest();

        c = [SELECT DaysInAR__c, Average_Claim_Payment_Settlement_Days__c FROM Claim__c WHERE Id = :c.Id];
        System.assertEquals(9, c.DaysInAR__c.intValue(), 'DaysInAR should be 9');
        System.assertEquals(9, c.Average_Claim_Payment_Settlement_Days__c.intValue(), 'Average days should be 9');
    }

    static testMethod void testUpdateClaimPaymentDates_NoPayments_PendingStatus() {
        // Create claim with no payments and pending status in the set -> DaysInAR = today - Date_Sent
        Insurance_Company__c ins = new Insurance_Company__c(Name='TestInsurance2');
        insert ins;

        Date sentDate = Date.today().addDays(-5);
        Claim__c c = new Claim__c(Date_Sent_to_Ins_Co__c=sentDate, Pending_Status__c='Payment Received');
        insert c;

        Test.startTest();
        ClaimPaymentDaysHandler.updateClaimPaymentDates(new Set<Id>{c.Id});
        Test.stopTest();

        c = [SELECT DaysInAR__c, Average_Claim_Payment_Settlement_Days__c FROM Claim__c WHERE Id = :c.Id];
        System.assertEquals(5, c.DaysInAR__c.intValue(), 'DaysInAR should equal days since sent date');
        System.assertEquals(null, c.Average_Claim_Payment_Settlement_Days__c, 'Average should be null when no insurance payment');
    }

    static testMethod void testAssignCollectorToTask_UpdatesTaskField() {
        // Create contact and an open Task related to that contact
        Insurance_Company__c ins = new Insurance_Company__c(Name='TestInsurance3');
        insert ins;

        Contact con = new Contact(LastName='Tester', Primary_Insurance__c = ins.Id, DX_s__c = 'Test', Plan_Type__c = 'Other Plan');
        insert con;

        Task t = new Task(WhoId = con.Id, Status = 'Open', Subject='Follow up');
        insert t;

        Map<Id,String> mapInput = new Map<Id,String>{ con.Id => 'Collector A' };

        Test.startTest();
        ClaimPaymentDaysHandler.assignCollectorToTask(mapInput);
        Test.stopTest();

        t = [SELECT Claim_Assigned_To__c FROM Task WHERE Id = :t.Id];
        System.assertEquals('Collector A', t.Claim_Assigned_To__c, 'Task should have Claim_Assigned_To__c updated');
    }
}
