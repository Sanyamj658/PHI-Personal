/**
* Auto Generated and Deployed by the Declarative Lookup Rollup Summaries Tool package (dlrs)
**/
@IsTest
private class dlrs_Claim_PaymentTest
{
    @IsTest
    private static void testTrigger()
    {	 Account a = new Account(name='zzzzzztest111');
     insert a;
     Insurance_Company__c sobj1 = new Insurance_Company__c(
         Name = 'United Healthcare - AARP (UT 31362) (Yellow Flag)',                                                                                                                                                                                                                                                                                        // Insurance Company Name
         Address_Line_1__c = 'P.O. Box 31362',                                                                                                                                                                                                                                                                                                              // Address
         City__c = 'Salt Lake City',                                                                                                                                                                                                                                                                                                                        // City
         State__c = 'Utah',                                                                                                                                                                                                                                                                                                                                 // State/Province
         Zipcode__c = '84131-0362',                                                                                                                                                                                                                                                                                                                         // Zip/Postal Code
         Country__c = 'USA',                                                                                                                                                                                                                                                                                                                                // Country
         Eligibility_Coverage_Phone__c = '(800) 643-4845',                                                                                                                                                                                                                                                                                                  // Eligibility - Coverage Phone
         Website__c = 'http://unitedhealthcareonline.com',                                                                                                                                                                                                                                                                                                  // Website                                                                                                                                                                                                                                                                                 // Claim Status Phone
         Submit_Format__c = 'Address',                                                                                                                                                                                                                                                                                                                      // Submit Format
         Pre_Cert_Auth_Phone__c = '877 842-3210 / 888 866 8297 Claim Status',                                                                                                                                                                                                                                                                               // Pre Cert. - Auth. Phone                                                                                                                                                                                                                                                                                             // Other Phone
         Notes__c = 'Fax: 866-704-9645THIS ADDRESS IS ALSO GOOD FOR MEDICARE COMPLETE',  // Notes
         Contacts_Information__c = 'inneapolis MN 55440-9472, USA'                                                // Contacts Information
     );
     insert sobj1;
     
     Contact p = new Contact(lastname='zzzzzzzzztest111',AccountId=a.id, Plan_Type__c='Other Plan',High_Dollar_Claim__c = true, Account_Status__c= 'Closed', Primary_Insurance__c=sobj1.Id);
     insert p;
     Claim__c c = new Claim__c(
                               Insurance_Policy_Limit__c = 'none',               // Insurance Policy Limit
                               Patient__c = p.id,                           // Patient
                               Professional_Charges__c = 2989.54,                  // Professional Charges
                               Medical_Provider__c = a.id,                  // Medical Provider
                               Facility_Charges__c = 11823.83,                     // Facility Charges
                               Insurance_Company__c = sobj1.Id,                 // Insurance Company
                               Invoice_Number__c = '00031934',                     // Invoice Number
                               Claim_Balance_Due__c = 0.00,                        // Claim Balance Due
                               Date_Received__c = Date.valueOf(Date.today()),       // Date Received
                               From_DOS__c = Date.valueOf(Date.today()),            // From DOS
                               To_DOS__c = Date.valueOf(Date.today()),              // To DOS
                               Date_Sent_to_Ins_Co__c = Date.valueOf(Date.today()),  // Date Sent to Ins Co
                               Pending_Status__c = 'Payment Received',             // Pending Status
                               Claim_Rate__c = 15.0,                               // Claim Rate
                               Payable_to_Client__c = 4509.74,                     // Payable to Client
                               Biller__c = 'Admin',                                // Biller
                               Total_Earned_Fees_Display__c = 2222.01,             // Total Earned Fees
                               Collector__c = 'D Qadir',                           // Collector
                               Collectability_Percentage__c = 100                 );
     insert c;
     Claim_Payment__c sobj = new Claim_Payment__c(
         Claim_Number__c = c.Id,
         Client_Customer__c = 'Payments',                 // Client/Customer
         Payment_Type__c = 'Insurance Payment',           // Payment Type
         Who_received_the_money__c = 'Payment Received',  // Who received the money
         Amount__c = 5358.52,                             // Amount
         Payment_Date__c = Date.valueOf(Date.today()),     // Date Paid
         Paid_to_client__c = 0.00,                        // Paid to client
         Due_to_Client1__c = 4554.74,                     // Due to Client
         Paid_Earn_Fees__c = 803.78,                      // Paid Earn Fees
         Show_in_Report__c = false,                       // Show in Report
         Collector__c = 'Danish Qadir',                   // Collector
         Batch_Deposit_Total__c = 26083.06,               // Batch Deposit Total
         Facility_Fee_For_Invoice__c = 5358.52           // Facility Fee For Invoice
     );
     
     // Force the dlrs_Claim_PaymentTrigger to be invoked, fails the test if org config or other Apex code prevents this.
     dlrs.RollupService.testHandler(sobj);
    }
}