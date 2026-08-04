@isTest
private class MyTest {
static testMethod void test(){
    
    Account a = new Account(Name='Sample Account');
    insert a;
    Contact c = new Contact(LastName='Sample Contact',accountid=a.id);
    insert c;
    Case case1 = new Case(status='Open',Contactid=c.id );
    insert case1;
    List<Task> tasks = new List<Task>();
    
    tasks.add(new Task(
    Subject='Sample Task',
    ActivityDate = Date.today(),
    WhatId = a.Id,
    WhoId = c.Id,
    OwnerId = UserInfo.getUserId(),
    Status='Open'));
    
    tasks.add(new Task(
    Subject='Sample Task1',
    ActivityDate = Date.today()+7,
    WhatId = a.Id,
    WhoId = c.Id,
    OwnerId = UserInfo.getUserId(),
    Status='Open'));
    
    insert tasks;
    
       
    test.startTest();
    try
   {
       for(Task t : tasks){
           t.status = 'Completed';
           update t;
       }
            
   }
   catch (Exception e)
   {
       // expected
   } 
    test.stopTest();
}
}