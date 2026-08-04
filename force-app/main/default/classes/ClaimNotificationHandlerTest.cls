@IsTest
private class ClaimNotificationHandlerTest {

    @TestSetup
    static void setup() {

        Account acc = new Account(
            Name='Test Provider',
            Account_Manager_Name__c='Manager'
        );
        insert acc;

        Insurance_Company__c ins = new Insurance_Company__c(
            Name='Insurance',
            Eligibility_Coverage_Phone__c='111',
            Pre_Cert_Auth_Phone__c='111'
        );
        insert ins;

        Contact con = new Contact(
            LastName='Patient',
            AccountId=acc.Id,
            Primary_Insurance__c=ins.Id,
            Plan_Type__c='Other Plan',
            DX_s__c='DX',
            Email = 'test@gmail.com',
            Account_Status__c='Verification work in process'
        );
        insert con;

        Case cs = new Case(
            Status='New',
            Origin='Phone',
            Subject='Claim Case',
            ContactId=con.Id
        );
        insert cs;
    }

    private static Claim__c createClaim() {

        Account acc = [SELECT Id FROM Account LIMIT 1];
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        Insurance_Company__c ins = [SELECT Id FROM Insurance_Company__c LIMIT 1];
        Case cs = [SELECT Id FROM Case LIMIT 1];

        Claim__c c = new Claim__c(
            Date_Received__c=System.today(),
            From_DOS__c=System.today(),
            To_DOS__c=System.today(),
            Pending_Status__c='Write-Off',
            Claim_Rate__c=10,
            Medical_Provider__c=acc.Id,
            Patient__c=con.Id,
            Facility_Charges__c=100,
            Professional_Charges__c=100,
            Insurance_Company__c=ins.Id,
            Invoice_Number__c='INV-1234',
            Insurance_Policy_Limit__c='N/A',
            Case__c=cs.Id
        );

        return c;
    }

    @IsTest
    static void testHandleAfterInsert() {

        Claim__c claim = createClaim();

        Test.startTest();
        insert claim;
        Test.stopTest();

        System.assertNotEquals(null, claim.Id);
    }

    @IsTest
    static void testClaimWithoutCase() {

        Account acc = [SELECT Id FROM Account LIMIT 1];
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        Insurance_Company__c ins = [SELECT Id FROM Insurance_Company__c LIMIT 1];

        Claim__c claim = new Claim__c(
            Date_Received__c=System.today(),
            From_DOS__c=System.today(),
            To_DOS__c=System.today(),
            Pending_Status__c='Write-Off',
            Claim_Rate__c=10,
            Medical_Provider__c=acc.Id,
            Patient__c=con.Id,
            Facility_Charges__c=100,
            Professional_Charges__c=100,
            Insurance_Company__c=ins.Id,
            Invoice_Number__c='INV-NoCase',
            Insurance_Policy_Limit__c='N/A'
        );

        Test.startTest();
        insert claim;
        Test.stopTest();

        System.assertNotEquals(null, claim.Id);
    }

}