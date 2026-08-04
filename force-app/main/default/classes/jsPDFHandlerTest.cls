@isTest
public class jsPDFHandlerTest {    
    @testSetup
    static void setup(){        
        //Create Medical Provider
        Account medicalProvider = new Account();
        medicalProvider.name='Test Medical Provider';
        insert medicalProvider;  
        
        // Create Insurance Company
        Insurance_Company__c insuranceCompanyTest = new Insurance_Company__c();
        insuranceCompanyTest.name = 'LIC';
        insuranceCompanyTest.eligibility_Coverage_Phone__c = '9999999999';
        insuranceCompanyTest.Pre_Cert_Auth_Phone__c = '1111111111';
        insert insuranceCompanyTest;  
        
        //Create Test Patient
        Contact patient = new contact();
        patient.firstName = 'Patient';
        patient.LastName = 'Test';
        patient.Primary_Insurance__c = insuranceCompanyTest.Id;
        patient.Plan_Type__c = 'Other Plan';
        patient.Account_Status__c = 'Payment received';
        insert patient;
            
        // Create a test Claim__c record
        Claim__c testClaim = new Claim__c();
        testClaim.Patient__c = patient.Id;
        testClaim.Medical_Provider__c = medicalProvider.Id;
        testClaim.Insurance_Company__c = insuranceCompanyTest.Id;
        testClaim.Invoice_Number__c = '12345';
        testClaim.Date_Received__c = System.today();
        testClaim.From_DOS__c = System.today()-5;
        testClaim.To_DOS__c = System.today();
        testClaim.Claim_Rate__c = 15;
        testClaim.Biller__c = 'Admin';
        testClaim.Collector__c = 'Admin';
        testClaim.Collectability_Percentage__c = 100;
        testClaim.Insurance_Policy_Limit__c = '100000';        
        insert testClaim;
    }

    //Success Case....
    @isTest
    static void testFetchClaimDetails_Success() {        
        //Fetch the Records from testSetup
        Contact patient = [Select Id from Contact WHERE Name = 'Patient Test' LIMIT 1];
        Claim__c testClaim = [SELECT Id FROM Claim__c WHERE Invoice_Number__c = '12345' LIMIT 1];
        Account medicalProvider = [Select Id from Account WHERE Name = 'Test Medical Provider' LIMIT 1];
        Insurance_Company__c insuranceCompanyTest = [Select Id from Insurance_Company__c WHERE Name = 'LIC' LIMIT 1];        
        
        Test.startTest();
        	Claim__c fetchedClaim = jsPDFHandler.fetchClaimDetails(testClaim.Id);  
        Test.stopTest();

        // Assertions....
        System.assertNotEquals(null, fetchedClaim);
        System.assertEquals(patient.Id, fetchedClaim.Patient__c);
        System.assertEquals(medicalProvider.Id, fetchedClaim.Medical_Provider__c);
        System.assertEquals(insuranceCompanyTest.Id, fetchedClaim.Insurance_Company__c);          
	}

    //Failure Case....
	@isTest
    static void testFetchClaimDetails_Failure() {
        
        //Fetch the Records from testSetup
        Contact patient = [Select Id from Contact WHERE Name = 'Patient Test' LIMIT 1];
        Claim__c testClaim = [SELECT Id FROM Claim__c WHERE Invoice_Number__c = '12345' LIMIT 1];
        Account medicalProvider = [Select Id from Account WHERE Name = 'Test Medical Provider' LIMIT 1];
        Insurance_Company__c insuranceCompanyTest = [Select Id from Insurance_Company__c WHERE Name = 'LIC' LIMIT 1]; 
        
        Claim__c fetchedClaim;
        
        Test.startTest();
        try {
            fetchedClaim = jsPDFHandler.fetchClaimDetails('invalidRecordId');
        }
        catch (Exception ex) {
            System.assertNotEquals(null, ex);
        }
        Test.stopTest();
	}
}