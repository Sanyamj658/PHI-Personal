@isTest
private class CalculationsTest {
static testMethod void test(){
    
    Account a = new Account(Name='Sample Account', Account_Manager_Name__c = 'PHI Manager');
    insert a;
            Insurance_Company__c insCompany = new Insurance_Company__c(
            Name = 'Test Insurance Company', 
            Eligibility_Coverage_Phone__c = '0123', 
            Pre_Cert_Auth_Phone__c = '0123'
        );
    INSERT insCompany;   
    Contact c = new Contact(Accountid=a.id,lastname='test1', DX_s__c='test', Plan_Type__c=getPicklistValues('Contact', 'Plan_Type__c')[0], Primary_Insurance__c= insCompany.id);
    insert c;
    Claim__c cl = new Claim__c(Date_Received__c=system.today(),
                               From_DOS__c=system.today(),
                               To_DOS__c=system.today(),
                               Pending_Status__c='Write-Off',
                               Claim_Rate__c=10,
                               Medical_Provider__c=a.id,
                               Patient__c=c.id,
                               Facility_Charges__c=1000,
                               Professional_Charges__c=1000,
                               Insurance_Company__c = insCompany.id,
                                Invoice_Number__c = 'inv1',
                               Insurance_Policy_Limit__c = 'N/A'
                              );
    
    insert cl;  
    List<Claim_Payment__c> cpList = new List<Claim_Payment__c>();
    Claim_Payment__c cp1 = new Claim_Payment__c(Claim_Number__c=cl.id,Client_Customer__c='',Payment_Type__c='Insurance Payment',Amount__c=100,Payment_Date__c=system.today(), Batch_Deposit_Total__c=1, Bank_Account__c='BOA 1905', Payment_Source__c='Wire', Batch_Deposit_Date__c=Date.today());
    Claim_Payment__c cp2 = new Claim_Payment__c(Claim_Number__c=cl.id,Client_Customer__c='',Payment_Type__c='Patient Payment',Amount__c=100,Payment_Date__c=system.today(), Batch_Deposit_Total__c=1, Bank_Account__c='BOA 1905', Payment_Source__c='Wire', Batch_Deposit_Date__c=Date.today());
    Claim_Payment__c cp3 = new Claim_Payment__c(Claim_Number__c=cl.id,Client_Customer__c='',Payment_Type__c='Network Discounts',Amount__c=100,Payment_Date__c=system.today(), Batch_Deposit_Total__c=1, Bank_Account__c='BOA 1905', Payment_Source__c='Wire', Batch_Deposit_Date__c=Date.today());
    Claim_Payment__c cp4 = new Claim_Payment__c(Claim_Number__c=cl.id,Client_Customer__c='',Payment_Type__c='Manual Adjustment',Amount__c=100,Payment_Date__c=system.today(), Batch_Deposit_Total__c=1, Bank_Account__c='BOA 1905', Payment_Source__c='Wire', Batch_Deposit_Date__c=Date.today());
    Claim_Payment__c cp5 = new Claim_Payment__c(Claim_Number__c=cl.id,Client_Customer__c='',Payment_Type__c='Bank fees',Amount__c=100,Payment_Date__c=system.today(), Batch_Deposit_Total__c=1, Bank_Account__c='BOA 1905', Payment_Source__c='Wire', Batch_Deposit_Date__c=Date.today());
    Claim_Payment__c cp6 = new Claim_Payment__c(Claim_Number__c=cl.id,Client_Customer__c='',Payment_Type__c='Legal Fees',Amount__c=100,Payment_Date__c=system.today(), Batch_Deposit_Total__c=1, Bank_Account__c='BOA 1905', Payment_Source__c='Wire', Batch_Deposit_Date__c=Date.today());
    Claim_Payment__c cp7 = new Claim_Payment__c(Claim_Number__c=cl.id,Client_Customer__c='',Payment_Type__c='Patient down payment WF',Amount__c=100,Payment_Date__c=system.today(), Batch_Deposit_Total__c=1, Bank_Account__c='BOA 1905', Payment_Source__c='Wire', Batch_Deposit_Date__c=Date.today());
    Claim_Payment__c cp8 = new Claim_Payment__c(Claim_Number__c=cl.id,Client_Customer__c='',Payment_Type__c='Patient down payment NF',Amount__c=100,Payment_Date__c=system.today(), Batch_Deposit_Total__c=1, Bank_Account__c='BOA 1905', Payment_Source__c='Wire', Batch_Deposit_Date__c=Date.today());
    Claim_Payment__c cp9 = new Claim_Payment__c(Claim_Number__c=cl.id,Client_Customer__c='Client Payment',Payment_Type__c='',Amount__c=100,Payment_Date__c=system.today(), Batch_Deposit_Total__c=1, Bank_Account__c='BOA 1905', Payment_Source__c='Wire', Batch_Deposit_Date__c=Date.today());
    cpList.add(cp1); cpList.add(cp2);cpList.add(cp3);cpList.add(cp4);
    cpList.add(cp5);cpList.add(cp6); cpList.add(cp7);cpList.add(cp8);cpList.add(cp9);
    test.startTest();
         insert cp1;
         delete cp1;
         insert cp2;
         insert cp3;
         insert cp4;
         insert cp5;
         insert cp6;
         insert cp7;
         insert cp8;
         insert cp9;
    test.stopTest();
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

}