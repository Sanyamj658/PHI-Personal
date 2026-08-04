@isTest
public class EventAndTask_Test {
    
    @isTest static void createEvent(){
        
        Account acc = new Account(Name = 'Test Account');
        INSERT acc;
        
        User usr = [SELECT Id FROM User WHERE Profile.Name = 'Client Access User' AND IsActive = true LIMIT 1];
        
        System.assert(usr.Id != null);
        
        AccountShare share = new AccountShare(AccountId = acc.Id, UserOrGroupId = usr.Id, 
                                              AccountAccessLevel = 'Read',
                                             OpportunityAccessLevel = 'None',
                                             CaseAccessLevel = 'Read');
        INSERT share;
        
        Insurance_Company__c insuranceCompany = new Insurance_Company__c(
			Name = 'Test Insurance Company', 
			Eligibility_Coverage_Phone__c = '0123', 
			Pre_Cert_Auth_Phone__c = '0123'
		);
		insert insuranceCompany;
        
        Contact cont = new Contact(LastName = 'Patient', AccountId = acc.Id,DX_s__c = 'Test DX',
			Plan_Type__c = 'Other Plan',
			Primary_Insurance__c = insuranceCompany.Id,
			Account_Status__c='Verification work in process'
         );
        INSERT cont;

        INSERT new Event(Subject = 'Call', DurationInMinutes = 30, ActivityDateTime = System.now(), WhoId = cont.Id, Name__c = 'Admin');
        
        Event evt = [SELECT Id, IsVisibleInSelfService FROM Event LIMIT 1];
        
        System.assert(evt.IsVisibleInSelfService);
    }
    
    @isTest static void createTask(){
        
        Account acc = new Account(Name = 'Test Account');
        INSERT acc;
        
        User usr = [SELECT Id FROM User WHERE Profile.Name = 'Client Access User' AND IsActive = true LIMIT 1];
        
        System.assert(usr.Id != null);
        
        AccountShare share = new AccountShare(AccountId = acc.Id, UserOrGroupId = usr.Id, 
                                              AccountAccessLevel = 'Read',
                                             OpportunityAccessLevel = 'None',
                                             CaseAccessLevel = 'Read');
        INSERT share;
        Insurance_Company__c insuranceCompany = new Insurance_Company__c(
			Name = 'Test Insurance Company', 
			Eligibility_Coverage_Phone__c = '0123', 
			Pre_Cert_Auth_Phone__c = '0123'
		);
		insert insuranceCompany;
        Contact cont = new Contact(LastName = 'Patient', AccountId = acc.Id, DX_s__c = 'Test DX',
			Plan_Type__c = 'Other Plan',
			Primary_Insurance__c = insuranceCompany.Id,
			Account_Status__c='Verification work in process'
         );
        INSERT cont;
        
        Task tsk = new Task(Status = 'Open', Subject = 'Manage', WhoId = cont.Id, Start_Time__c = System.now(), Stop_Time__c = System.now().addMinutes(15), Name__c = 'Admin');
        INSERT tsk;
        
        tsk = [SELECT Id,IsVisibleInSelfService, Total_Time_Of_Completing_Task__c FROM Task LIMIT 1];
        
        System.assert(tsk.IsVisibleInSelfService);
        System.assertEquals(0.2, tsk.Total_Time_Of_Completing_Task__c);
    }
    
    @isTest static void updateTask(){
        
        Account acc = new Account(Name = 'Test Account');
        INSERT acc;
        Insurance_Company__c insuranceCompany = new Insurance_Company__c(
			Name = 'Test Insurance Company', 
			Eligibility_Coverage_Phone__c = '0123', 
			Pre_Cert_Auth_Phone__c = '0123'
		);
		insert insuranceCompany;
        Contact cont = new Contact(LastName = 'Patient', AccountId = acc.Id, DX_s__c = 'Test DX',
			Plan_Type__c = 'Other Plan',
			Primary_Insurance__c = insuranceCompany.Id,
			Account_Status__c='Verification work in process'
        );
        INSERT cont;
        
        Case cse = new Case(Status = 'Open', ContactId = cont.Id);
        INSERT cse;
        
        Task tsk = new Task(Status = 'Open', Subject = 'Manage', WhoId = cont.Id, Start_Time__c = System.now(), Stop_Time__c = System.now().addMinutes(8), Name__c = 'Admin');
        INSERT tsk;
        
        List<Task> updateTsk = [SELECT Id,IsVisibleInSelfService, Total_Time_Of_Completing_Task__c FROM Task LIMIT 1];
        System.assertEquals(0.1, updateTsk[0].Total_Time_Of_Completing_Task__c);
        
        Test.startTest();
        
        try
        {
            //custom validation case is still open
            tsk.Start_Time__c = null;
            tsk.Stop_Time__c = null;
            tsk.Status = 'Completed';
        	UPDATE tsk;
        }
        catch(Exception exe)
        {
            
        }
        updateTsk = [SELECT Id,IsVisibleInSelfService, Total_Time_Of_Completing_Task__c FROM Task LIMIT 1];
     	System.assertEquals(0.1, updateTsk[0].Total_Time_Of_Completing_Task__c);
        
        updateTsk = [SELECT Id FROM Task WHERE Status = 'Completed' LIMIT 1];
        
        System.assert(updateTsk.size() == 0);
        
        Task tsk2 = new Task(Status = 'Open', Subject = 'Manage', WhoId = cont.Id, Name__c = 'Admin');
        INSERT tsk2;
        
        //custom validation will not run because two task is open
        tsk.Status = 'Completed';
        tsk.Start_Time__c = null;
        tsk.Stop_Time__c = null;
        UPDATE tsk;
        
        updateTsk = [SELECT Id, Total_Time_Of_Completing_Task__c FROM Task WHERE Status = 'Completed' LIMIT 1];
        
        System.assertEquals(0, updateTsk[0].Total_Time_Of_Completing_Task__c);
        System.assert(updateTsk.size() != 0);
        
        Test.stopTest();
    }
}