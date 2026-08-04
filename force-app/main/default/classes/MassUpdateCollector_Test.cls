/**
* Description: This class is to test the MassUpdateCollector class.
* CreatedBy  : Concret.io
* CreatedDate: 02/11/2023
**/
@isTest
public class MassUpdateCollector_Test {
    //Test method to check update collector functionality
    @isTest
    static void updateColletor_Test() {
        String planType = getPicklistValues('Contact', 'Plan_Type__c')[0];
        String name = getPicklistValues('Task', 'Name__c')[0];
        List<String> collectorPicklistValues = getPicklistValues('Claim__c', 'Collector__c');
        String collector = collectorPicklistValues[0];
        
        Account acc= new Account(Name = 'Test Medical Provider');
        INSERT acc;
        
        Insurance_Company__c insCompany = new Insurance_Company__c(
            Name = 'Test Insurance Company', 
            Eligibility_Coverage_Phone__c = '0123', 
            Pre_Cert_Auth_Phone__c = '0123'
        );
        INSERT insCompany;       
        
        List<Contact> patients = new List<Contact>();
        for(Integer i = 0; i < 100; i++) {
            patients.add(
                new Contact(
                    LastName = 'Patient ' + i, 
                    Primary_Insurance__c = insCompany.id, 
                    AccountId = acc.Id, 
                    Plan_Type__c = planType
                )
            );
        }
        INSERT patients;
        
        List<Claim__c> claims = new List<Claim__c>();
        for(Integer i = 0; i < 100; i++) {
            claims.add(
                new Claim__c(
                    Patient__c = patients[i].id, 
                    Medical_Provider__c = acc.id, 
                    Insurance_Company__c = insCompany.id, 
                    Invoice_Number__c = 'inv' + i, 
                    From_DOS__c = System.Today(), 
                    To_DOS__c = System.Today(), 
                    Insurance_Policy_Limit__c = 'N/A', 
                    Collector__c = collectorPicklistValues[0]
                )
            );
        }
        INSERT claims;
        
        Date activityDate = System.today() + 1;
        DateTime startDateTime = System.now() + 1;
        DateTime endDateTime = System.now() + 2;
        List<SObject> recordsToInsert = new List<SObject>();
        for(Integer i = 0; i < 50; i++) {
            recordsToInsert.add(
                new Task(
                    Subject = '3-Payment Follow Up with Insurance', 
                    ActivityDate = activityDate, Claim_Assigned_To__c = collector, 
                    WhoId = patients[i].id, 
                    Name__c = name
                )
            );
            
            recordsToInsert.add(
                new Task(
                    Subject = '6-Awaiting Client Decision', 
                    ActivityDate = activityDate, Claim_Assigned_To__c = collector, 
                    WhoId = patients[i].id, 
                    Name__c = name
                )
            );
            
            recordsToInsert.add(
                new Event(
                    Subject = '3-Payment Follow Up with Insurance', 
                    StartDateTime = startDateTime, 
                    EndDateTime = endDateTime, 
                    Claim_Assigned_To__c = collector, 
                    WhoId = patients[i].id, 
                    Name__c = name
                )
            );
            
            recordsToInsert.add(
                new Event(
                    Subject = '6-Awaiting Client Decision', 
                    StartDateTime = startDateTime, 
                    EndDateTime = endDateTime, 
                    Claim_Assigned_To__c = collector, 
                    WhoId = patients[i].id, 
                    Name__c = name
                )
            );
        }
        recordsToInsert.sort();
        INSERT recordsToInsert;
        
        Test.startTest();
        if(collectorPicklistValues.size() >= 2) {
            collector = collectorPicklistValues[1];
        }
        
        MassUpdateCollector.UpdateCollectorRequest updateCollectorRequest = new MassUpdateCollector.UpdateCollectorRequest();
        updateCollectorRequest.claimIds = new List<Id>(new Map<Id,Claim__c>(claims).keyset());
        updateCollectorRequest.collector = collector;
        List<String> results = MassUpdateCollector.updateCollector(new List<MassUpdateCollector.UpdateCollectorRequest>{updateCollectorRequest});
        Test.stopTest();
        
        Assert.areEqual('Collector on the Claim(s) and the Patient\'s Open Activities are successfully updated.', results[0], 'Collectors are not updated successfully');
        Assert.areEqual(100, [SELECT Id, Collector__c FROM Claim__c WHERE Collector__c =:collector].size(), 'Collector not updated on the Claim');
        Assert.areEqual(100, [SELECT Id, Claim_Assigned_To__c FROM Task WHERE Claim_Assigned_To__c =:collector].size(), 'Collector not updated on the Task');
        Assert.areEqual(100, [SELECT Id, Claim_Assigned_To__c FROM Event WHERE Claim_Assigned_To__c =:collector].size(), 'Collector not updated on the Event');      
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