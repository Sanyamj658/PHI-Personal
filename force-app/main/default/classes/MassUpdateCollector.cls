/**
* Description: This class will update the colletor/claimed assigned to on claims and their related patient's open activities.
* CreatedBy  : Concret.io
* CreatedDate: 02/11/2023
**/
public class MassUpdateCollector {
    
    //Wrapper class for taking input from flow
    public class UpdateCollectorRequest{
        @InvocableVariable (required=true)
        public List<String> claimIds;
        
        @InvocableVariable (required=true)
        public String collector;
    }
    
    //Method is used for updating the collectors on the claims and the tasks
    @InvocableMethod(label='Update Claims And Open Activites' description='Update claims and their related patient open activities.')
    public static List<String> updateCollector(List<UpdateCollectorRequest> updateCollectorRequests) {
        try {
            List<SObject> recordsToUpdate = new List<SObject>();
            Set<String> filters = new Set<String>{'3%', '6%'};
            Set<Id> patientIds = new Set<Id>();
            //getting selected claims
            List<Claim__c> claims = [
                SELECT 
                		Id, 
                		Patient__c, 
                		Collector__c, 
                		Insurance_Policy_Limit__c 
                FROM 
                		Claim__c 
                WHERE 
                		Id IN :updateCollectorRequests[0].claimIds
            ];
            for(Claim__c claim : claims) {
                if(claim.Collector__c != updateCollectorRequests[0].collector) {
                    if(claim.Insurance_Policy_Limit__c == NULL) {
                        claim.Insurance_Policy_Limit__c = 'N/A';
                    }
                    claim.Collector__c = updateCollectorRequests[0].collector;
                    recordsToUpdate.add(claim); 
                }
                patientIds.add(claim.Patient__c);
            }
            
            //processing open activities of patients whose subject starts with "3" OR "6"
            List<Contact> patients = [
                SELECT 
                		Id, 
                		(SELECT 
                         		Id, 
                     			Subject, 
                     			Claim_Assigned_To__c 
                         FROM 
                         		Tasks 
                         WHERE 
                         		Status = 'Open' AND 
                         		Subject LIKE :filters AND 
                         		Claim_Assigned_To__c != :updateCollectorRequests[0].collector 
                        ), 
                		(SELECT 
                         		Id, 
                         		Subject, 
                         		Claim_Assigned_To__c 
                         FROM 
                         		Events 
                         WHERE 	
                         		StartDateTime >= :System.now() AND 
                         		Subject LIKE :filters AND 
                         		Claim_Assigned_To__c != :updateCollectorRequests[0].collector 
                        ) 
                FROM 
                		Contact 
                WHERE 
                		Id IN :patientIds
            ];
            
            for(Contact patient: patients) {
                for(Task tsk : patient.Tasks) {
                    tsk.Claim_Assigned_To__c = updateCollectorRequests[0].collector;
                    recordsToUpdate.add(tsk);
                }
                for(Event evt : patient.Events) {
                    evt.Claim_Assigned_To__c = updateCollectorRequests[0].collector;
                    recordsToUpdate.add(evt);
                }
            }
            // Sort according to sobject type to prevent chunk exception
            recordsToUpdate.sort();
           	// Updating records
            UPDATE recordsToUpdate;
            return new List<String>{'Collector on the Claim(s) and the Patient\'s Open Activities are successfully updated.'};
                
		} catch (Exception e) {
            return new List<String>{
                'Collector on the Claim(s) and the Patient\'s Open Activities cannot be updated due to the follwing reason: \n' + e.getMessage()
           	};
       	}
    }  
}