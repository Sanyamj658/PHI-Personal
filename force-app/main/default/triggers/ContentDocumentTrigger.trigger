trigger ContentDocumentTrigger on ContentDocument (before delete) {
    if(Trigger.isBefore && Trigger.isDelete) {
        String adminProfile = 'System Administrator';
        String userProfile = [SELECT Name FROM Profile WHERE Id = :UserInfo.getProfileId() LIMIT 1].Name;        
        if(!adminProfile.equalsIgnoreCase(userProfile)) {
            for(ContentDocument cd : Trigger.old) {
                cd.addError('Only System Administrator can delete this record'); 
            }
        }
    }
}