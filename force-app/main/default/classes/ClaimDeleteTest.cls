@isTest(seealldata=true)
private class ClaimDeleteTest {
static testMethod void test(){
    User u = [SELECT id from user where userroleid=:'00EG000000131JW' LIMIT 1 ];
    
    Account a = new Account(name='test111');
    insert a;
    Contact p = new Contact(lastname='test111',AccountId=a.id);
    insert p;
    Claim__c c = new Claim__c(From_DOS__c=system.today(), To_DOS__c=system.today(), Patient__c=p.id, Medical_Provider__c=a.id);
    insert c;
    System.runAs(u) {
    ApexPages.StandardController controller = new ApexPages.StandardController(c); 
    CheckDelete cd = new CheckDelete(controller);
    test.startTest();
        cd.checkDelete();
    test.stopTest();
    }
}
static testMethod void test1(){
    User u1 = [SELECT id from user where userroleid<>:'00EG000000131JW' AND isActive=true LIMIT 1 ];
    
    Account a1 = new Account(name='test1111');
    insert a1;
    Contact p1 = new Contact(lastname='test1111',AccountId=a1.id);
    insert p1;
    Claim__c c1 = new Claim__c(From_DOS__c=system.today(), To_DOS__c=system.today(),Patient__c=p1.id, Medical_Provider__c=a1.id);
    insert c1;
    System.runAs(u1) {
    ApexPages.StandardController controller = new ApexPages.StandardController(c1); 
    CheckDelete cd = new CheckDelete(controller);
    test.startTest();
        cd.checkDelete();
    test.stopTest();
    }
}

}