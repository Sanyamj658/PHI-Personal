/***********************************************************************************

Author          |Date       | Comments
Atul Dobhal     |08/06/2018 | Controller to dispaly patient and claim report

************************************************************************************/

public class PatientClaimReportController{
    public transient List<Contact> patientList;
    public transient Map<Id,Contact> PatientMap;
    public transient Map<Id,Contact> PatientMapFilter;
    public transient List<PatientClaimWrapper> PatientClaimWrapperList;
    public transient List<limitWrapper> limitWrapperList{get;set;}
    public Date fromdate;
    public Date todate;
    public Set<Id> patientSet;
    public transient List<Claim__c> claimList;
    Public transient Map<Id,List<Claim__c>> patientClaimMap;
    public Set<Id> claimSet;
    public integer listLimit;
    public integer counter;
    public integer loopCount;
    public DateTime dueDateEvent;
    public List<String> collectorList;
    public List<String> providerList;
    
    public PatientClaimReportController(){
        collectorList = New List<String>();
        providerList = New List<String>();
        patientList = New List<Contact>();
        PatientMap = New Map<Id,Contact>();
        PatientMapFilter = New Map<Id,Contact>();
        PatientClaimWrapperList = New List<PatientClaimWrapper>();
        patientSet = New Set<Id>();
        claimList = New List<Claim__c>();
        patientClaimMap = New Map<Id,List<Claim__c>>();
        limitWrapperList = New List<limitWrapper>();
        claimSet = New Set<Id>();
        listLimit = 9999;
        counter = 0;
        loopCount=0;
        dueDateEvent = date.today();
        Set<Id> patientIds = new Set<Id>();
        
        String fDate = ApexPages.currentPage().getParameters().get('fromDate');
        String tDate = ApexPages.currentPage().getParameters().get('toDate');
        String collector = ApexPages.currentPage().getParameters().get('collector');
        String provider = ApexPages.currentPage().getParameters().get('provider');
       
       
        System.debug('collector '+collector);
        System.debug('provider '+provider);
        
        
		If(collector != null && collector !=''){
            collector = collector.replaceAll('[\\[\\]]', '');
            if(collector != null && collector !='')
            collectorList = collector.split(', ');
            //collectorSet.addAll(collectorList);
		}
		
		If(provider != null && provider !=''){
            provider = provider.replaceAll('[\\[\\]]', '');
            System.debug('provider-->'+provider);
            if(provider != null && provider !='')
			providerList = provider.split(', ');
            //providerSet.addAll(providerList);
		}
		
		system.debug('providerList-->'+providerList);
        DateTime newFromDate = null;
        DateTime newToDate = null;
        
        try{
            if(fDate != 'null' && fDate != null  && fDate != ''){
                fromdate = date.valueOf(fDate);
                newFromDate = dateTime.newInstance(fromdate.year(), fromdate.month(), fromdate.day());
            }
            if(tDate != 'null' && tDate != null && tDate != ''){
                todate = date.valueOf(tDate);
                newToDate = dateTime.newInstance(todate.year(), todate.month(), todate.day());
            }
            
            System.debug('newFromDate '+newFromDate);
            System.debug('newToDate '+newToDate);
            List<Task> taskList = new List<Task>();
            List<Event> eventList = new List<Event>();
            if(newFromDate != null && newToDate != null){
                taskList = [SELECT WhatId, WhoId FROM Task WHERE Status = 'Open' AND ActivityDate >=: newFromDate.date() AND ActivityDate <=: newToDate.date()];
                eventList = [SELECT WhatId,WhoId FROM Event WHERE  EndDateTime >=: newFromDate AND EndDateTime <=: newToDate AND EndDateTime >=: dueDateEvent];
            }else{
                taskList = [SELECT WhatId, WhoId FROM Task WHERE Status = 'Open'];
                eventList = [SELECT WhatId,WhoId FROM Event WHERE EndDateTime >=: dueDateEvent];
            }
            
            for(Task objTask : taskList){
                if(objTask.WhoId != null && objTask.WhoId.getSobjectType().getDescribe().getName() == 'Contact'){
                    patientSet.add(objTask.WhoId);
                }
                if(objTask.WhatId != null && objTask.WhatId.getSobjectType().getDescribe().getName() == 'Claim__c'){
                    claimSet.add(objTask.WhatId);
                }
            }
            
            for(Event objEvent : eventList){
                if(objEvent.WhoId != null && objEvent.WhoId.getSobjectType().getDescribe().getName() == 'Contact'){
                    patientSet.add(objEvent.WhoId);
                }
                
                if(objEvent.WhatId != null && objEvent.WhatId.getSobjectType().getDescribe().getName() == 'Claim__c'){
                    claimSet.add(objEvent.WhatId);
                }
            }
            
            System.debug('collectorListSize-->'+collectorList.size());
            System.debug('providerListSize-->'+providerList.size());
            if(collectorList.size() > 0 && providerList.size() > 0){
                System.debug('Both present');
                System.debug('patientSet-->'+patientSet);
                System.debug('claimSet-->'+claimSet);
				System.debug('collectorList-->'+collectorList);
				System.debug('providerList-->'+providerList);
                for(Claim__c objClaim : [SELECT Id, Patient__c, Collector__c, Medical_Provider__c FROM Claim__c WHERE Collector__c IN: collectorList AND Medical_Provider__c IN: providerList AND (Id IN: claimSet OR Patient__c IN: patientSet)]){
                    patientSet.add(objClaim.patient__c);
                    patientIds.add(objClaim.patient__c);
                    System.debug('patientSet-->'+patientSet);
                    System.debug('patientIds-->'+patientIds);
                }
            }else if(collectorList.size() > 0 || providerList.size() > 0){
                System.debug('atleast One present');
                System.debug('patientSet-->'+patientSet);
                System.debug('claimSet-->'+claimSet);
                for(Claim__c objClaim : [SELECT Id, Patient__c, Collector__c, Medical_Provider__c FROM Claim__c WHERE (Patient__c IN: patientSet OR Id IN: claimSet) AND (Collector__c IN: collectorList OR Medical_Provider__c IN: providerList)]){
                    patientSet.add(objClaim.patient__c);
                    patientIds.add(objClaim.patient__c);
                    System.debug('patientSet-->'+patientSet);
                	System.debug('patientIds-->'+patientIds);
                }
            }else{
                System.debug('Both not present');
                System.debug('patientSet-->'+patientSet);
                System.debug('claimSet-->'+claimSet);
                for(Claim__c objClaim : [SELECT Id, Patient__c, Collector__c, Medical_Provider__c FROM Claim__c WHERE Patient__c IN: patientSet OR Id IN: claimSet]){
                    patientSet.add(objClaim.patient__c);
                	System.debug('patientSet-->'+patientSet);
                }
            }
            
            patientList = [SELECT Id,Name,Primary_Insurance__r.Name,Primary_Assistance_Co__r.Name,(SELECT Id,Subject,EndDateTime FROM Events WHERE EndDateTime >=: dueDateEvent), (SELECT Id,Subject,ActivityDate FROM Tasks WHERE Status = 'Open') FROM Contact WHERE Id IN: patientSet];
            //claimSet = [SELECT Id FROM Claim__c WHERE Patient__c IN: patientList];
            System.debug('patientList-->'+patientList);
			
            if(!patientList.isEmpty()){
                for(Contact objPatient : patientList){
                    //patientSet.add(objPatient.Id);
                    PatientMap.put(objPatient.Id,objPatient);
                    if((collector != 'null' || provider != 'null') && patientIds.contains(objPatient.Id)){
                        PatientMapFilter.put(objPatient.Id,objPatient);
                    }
                }
                
                if(collectorList.size() > 0 && providerList.size() > 0){
                    claimList = [SELECT Id,Name,Patient__c,Medical_Provider__r.Name,Collector__c,Pending_Status__c,Date_Received__c,Date_Sent_to_Ins_Co__c,From_DOS__c,To_DOS__c,Days_in_AR__c,Facility_Charges__c,Professional_Charges__c,Claim_Balance_del__c,Total_Charge__c,(SELECT Id,Subject,EndDateTime FROM Events WHERE EndDateTime >=: dueDateEvent),(SELECT Id,Subject,ActivityDate FROM Tasks WHERE Status = 'Open') FROM Claim__c WHERE Patient__c IN: patientSet AND Collector__c IN: collectorList AND Medical_Provider__c IN: providerList];
                }else if(collectorList.size() > 0 || providerList.size() > 0){
                    claimList = [SELECT Id,Name,Patient__c,Medical_Provider__r.Name,Collector__c,Pending_Status__c,Date_Received__c,Date_Sent_to_Ins_Co__c,From_DOS__c,To_DOS__c,Days_in_AR__c,Facility_Charges__c,Professional_Charges__c,Claim_Balance_del__c,Total_Charge__c,(SELECT Id,Subject,EndDateTime FROM Events WHERE EndDateTime >=: dueDateEvent),(SELECT Id,Subject,ActivityDate FROM Tasks WHERE Status = 'Open') FROM Claim__c WHERE Patient__c IN : patientSet AND (Collector__c IN: collectorList OR Medical_Provider__c IN: providerList)];
                }else{
                    claimList = [SELECT Id,Name,Patient__c,Medical_Provider__r.Name,Collector__c,Pending_Status__c,Date_Received__c,Date_Sent_to_Ins_Co__c,From_DOS__c,To_DOS__c,Days_in_AR__c,Facility_Charges__c,Professional_Charges__c,Claim_Balance_del__c,Total_Charge__c,(SELECT Id,Subject,EndDateTime FROM Events WHERE EndDateTime >=: dueDateEvent),(SELECT Id,Subject,ActivityDate FROM Tasks WHERE Status = 'Open') FROM Claim__c WHERE Patient__c IN : patientSet];
                }
            }
			
			System.debug('PatientMapFilter-->'+PatientMapFilter);
			System.debug('claimList-->'+claimList);
            
            if(!claimList.isEmpty()){
                for(Claim__c objClaim : claimList){
                    if(!patientClaimMap.containskey(objClaim.Patient__c)){
                        patientClaimMap.put(objClaim.Patient__c,New List<Claim__c>());
                    }
                    patientClaimMap.get(objClaim.Patient__c).add(objClaim);
                }
                if(collectorList.size() > 0 || providerList.size() > 0){
                    for(Id patientId : PatientMapFilter.keyset()){
                        if(counter < listLimit){
                            PatientClaimWrapperList.add(New PatientClaimWrapper(PatientMapFilter.get(patientId),patientClaimMap.get(patientId)));
                            counter++;
                        }else{
                            loopCount++;
                            limitWrapperList.add(new limitWrapper(loopCount,PatientClaimWrapperList));
                            PatientClaimWrapperList = New List<PatientClaimWrapper>();
                            PatientClaimWrapperList.add(New PatientClaimWrapper(PatientMapFilter.get(patientId),patientClaimMap.get(patientId)));
                            counter = 0;
                        }
                    }
                }else{
                    for(Id patientId : PatientMap.keyset()){
                        if(counter < listLimit){
                            PatientClaimWrapperList.add(New PatientClaimWrapper(PatientMap.get(patientId),patientClaimMap.get(patientId)));
                            counter++;
                        }else{
                            loopCount++;
                            limitWrapperList.add(new limitWrapper(loopCount,PatientClaimWrapperList));
                            PatientClaimWrapperList = New List<PatientClaimWrapper>();
                            PatientClaimWrapperList.add(New PatientClaimWrapper(PatientMap.get(patientId),patientClaimMap.get(patientId)));
                            counter = 0;
                        }
                    }
                }
                
                if(limitWrapperList.isEmpty()){
                    loopCount++;
                    limitWrapperList.add(new limitWrapper(loopCount,PatientClaimWrapperList));
                }
            }
        }catch(Exception e){
            System.debug('Exception '+e.getStackTraceString());
            System.debug('Message '+e.getMessage());
        }
        
    }
    public class PatientClaimWrapper {
        public Contact objPatient { get; set; }
        public List<Claim__c> claimList { get; set; }
        
        public PatientClaimWrapper(Contact objPatient, List<Claim__c> claimList) {
            this.objPatient = objPatient;
            this.claimList = claimList;
        }
    }
    
    public class limitWrapper{
        public integer blockNumber {get;set;}
        public List<PatientClaimWrapper> PatientClaimWrapperCountList{get;set;}
        public limitWrapper(integer index,List<PatientClaimWrapper> PatientClaimWrapperCountList)
        {
            blockNumber = index;
            this.PatientClaimWrapperCountList = PatientClaimWrapperCountList;
        }
    }
    
}