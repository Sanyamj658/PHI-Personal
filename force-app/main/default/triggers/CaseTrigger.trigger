trigger CaseTrigger on Case (before update, before delete) {    
    if (Trigger.isBefore && (Trigger.isUpdate || Trigger.isDelete)) {   
        Map<Id,Case> caseMap = new Map<Id,Case>();        
        if(Trigger.isUpdate) {
            for(Case caseObject : Trigger.new) {
                if(Trigger.oldMap.containsKey(caseObject.Id) 
                   && (
                       caseObject.AccountId != Trigger.oldMap.get(caseObject.Id).AccountId 
                       || caseObject.ContactId != Trigger.oldMap.get(caseObject.Id).ContactId
                   )
                ) {
                    caseMap.put(caseObject.Id, caseObject);
                }
            }
        } else if(Trigger.isDelete) {
            caseMap = Trigger.oldMap;
        }
        if (!caseMap.isEmpty()) {
            CaseTriggerHandler.validateCaseModificationWithClaims(caseMap, (Trigger.isUpdate ? 'Update' : 'Delete'));
        }
    }
}