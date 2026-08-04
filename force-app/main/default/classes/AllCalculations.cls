public class AllCalculations {
    public  AllCalculations(){
    
    }
public void ai(Id id1,Boolean insFlag,Boolean updFlag,Boolean delFlag){
    Claim__c claim = [Select id,Payable_to_Client__c,Total_Earned_Fees_Display__c,Total_Earned_Fees__c,Claim_Rate__c,Claim_Balance_Due__c,Professional_Charges__c,Facility_Charges__c,Total_Charge__c from Claim__c where id=:id1];
    //system.debug('Payable to Client:'+claim.Payable_to_Client__c);
    system.debug('Claim Balance Due:'+claim.Claim_Balance_Due__c);    
    List<Claim_Payment__c> cpList = [SELECT Id,Amount__c,Client_Customer__c,Claim_Number__c,Payment_Date__c,Due_to_Client1__c,Earned_Fee__c,Earned_fee_workflow__c,Paid_to_client__c,Payment_Type__c FROM Claim_Payment__c WHERE Claim_Number__c =: claim.id ORDER BY Payment_Type__c DESC];
    //system.debug('size of payments:'+cpList.size());
    //claim.Payable_to_Client__c=0;
    claim.Claim_Balance_Due__c=0;
    Decimal ipAmount=0.0;
    Decimal ipEarnedFee=0.0;
    Decimal ipPaidToClient=0.0;
    //Decimal ipAmount1=0.0;
    //Decimal ppAmount1=0.0;
    Decimal ndAmount=0.0;
    Decimal maAmount=0.0;
    Decimal prAmount=0.0;
    Decimal bfAmount=0.0;
    Decimal lfAmount=0.0;
    Decimal pdwfAmount=0.0;
    Decimal pdwfEarnedFee=0.0;
    Decimal pdnfAmount=0.0;
    Integer count1=0;
    Integer count2=0;
    Integer count3=0;
    Boolean pdwf=false;
    Decimal ClientAmount=0.0;
    //Decimal ipAmount2=0.0;
    For(Claim_Payment__c cp : cpList){
        if(cp.Payment_Type__c=='Patient down payment WF'|| cp.Payment_Type__c=='Patient down payment NF'){
            count1=1;
            count2=1;
        }else{
            count3=count3+1;
        }
    }
    system.debug('***count1 & 2:'+count1+''+count2);
    if(count1==1 && count2==1){
        pdwf=true;
    }
    For(Claim_Payment__c claimPayment : cpList){
    
        // AddedBy: Concret.io 14th Aug 2025 
        // Task: Added 'Courtesy Payment' check to include in Earned Fee & Claim Balance Due calculation
        if(claimPayment.Payment_Type__c=='Insurance Payment'|| claimPayment.Payment_Type__c=='Patient Payment' || claimPayment.Payment_Type__c == 'Courtesy Payment'){
              system.debug('claimPayment.Amount__c:'+claimPayment.Amount__c);
            system.debug('claimPayment.Earned_Fee__c:'+claimPayment.Earned_Fee__c); 
              system.debug('claimPayment.Paid_to_client__c:'+claimPayment.Paid_to_client__c); 
              ipAmount=ipAmount+claimPayment.Amount__c;
              ipEarnedFee=ipEarnedFee+claimPayment.Earned_Fee__c;
              ipPaidToClient=ipPaidToClient+(claimPayment.Paid_to_client__c==Null?0:claimPayment.Paid_to_client__c);
        }
       // if(claimPayment.Payment_Type__c=='Insurance Payment'){
        //    ipAmount1=ipAmount1+claimPayment.Amount__c;
       // }
       // if(claimPayment.Payment_Type__c=='Patient Payment'){
       //     ppAmount1=ppAmount1+claimPayment.Amount__c;
       // }
        if(claimPayment.Payment_Type__c=='Network Discounts'){
            ndAmount=ndAmount+claimPayment.Amount__c;
        }
        if(claimPayment.Payment_Type__c=='Manual Adjustment'){
            maAmount=maAmount+claimPayment.Amount__c;
        }
        if(claimPayment.Payment_Type__c=='Patient Refund'){
            prAmount=prAmount+claimPayment.Amount__c;
        }
        if(claimPayment.Payment_Type__c=='Bank fees'){
            bfAmount=bfAmount+claimPayment.Amount__c;
        }
        if(claimPayment.Payment_Type__c=='Legal Fees'){
            lfAmount=lfAmount+claimPayment.Amount__c;
        }
        if(claimPayment.Payment_Type__c=='Patient down payment WF'){
            ipEarnedFee=ipEarnedFee+claimPayment.Earned_Fee__c;
            pdwfAmount=pdwfAmount+claimPayment.Amount__c;
        }
        if(claimPayment.Payment_Type__c=='Patient down payment NF'){
            pdnfAmount=pdnfAmount+claimPayment.Amount__c;
        }
        //if(ipAmount1==0 || ppAmount1==0){
           // ipAmount2 = ipAmount1-ppAmount1;
           // if(ipAmount2<0)
            // ipAmount2 = -(ipAmount2);
        // }
         //else{
             //ipAmount2 = ipAmount1-ppAmount1;
         //} 
      //  system.debug('***ipEarnedFee before:'+ipEarnedFee);
      //  system.debug('***condition check:'+(pdwfAmount+ipAmount>=claim.Total_Charge__c));
      //  system.debug('***ipEarnedFee:'+ipEarnedFee);
      //  system.debug('***ipAmount:'+ipAmount);
        //system.debug('***ipAmount1:'+ipAmount1);
        //system.debug('***ppAmount1:'+ppAmount1);
      //  system.debug('***pdwfAmount:'+pdwfAmount);
     //   system.debug('****pdwf boolean:'+pdwf);
     //   system.debug('****:'+claimPayment.Client_Customer__c);
      //  system.debug('****:'+claimPayment.Payment_Type__c);
        if(claimPayment.Client_Customer__c=='Client Payment' && (claimPayment.Payment_Type__c==Null || claimPayment.Payment_Type__c=='Client Payment')){
        ClientAmount=ClientAmount+claimPayment.Amount__c;
      //  system.debug('***Client Amount:'+ClientAmount);
        }
        
        if(!pdwf){   
            system.debug('***Without PDWF & PDNF');
            if(ipAmount>=claim.Total_Charge__c)
                ipEarnedFee=(claim.Total_Charge__c*claim.Claim_Rate__c)/100;
            if(claimPayment.Payment_Type__c<>'Bank fees' && claimPayment.Payment_Type__c<>'Legal Fees'){
                System.debug('****************');
                System.debug('Claim Balance Due:'+claim.Claim_Balance_Due__c);
                System.debug('****************');
            claim.Claim_Balance_Due__c=Claim.Total_Charge__c-ipAmount-ndAmount-maAmount;
            }
                
            // AddedBy: Concret.io 14th Aug 2025 
            // Task: Added 'Courtesy Payment' to Payable to Client calculation
            if(claimPayment.Client_Customer__c=='Client Payment'||claimPayment.Payment_Type__c=='Legal Fees'|| claimPayment.Payment_Type__c=='Bank fees' || claimPayment.Payment_Type__c=='Insurance Payment' || claimPayment.Payment_Type__c=='Patient Payment' || claimPayment.Payment_Type__c == 'Courtesy Payment'){
                //System.debug('*** ip+pp Amount:'+ipAmount);
                //System.debug('***ip Amount2:'+ipAmount2);
                //System.debug('*** bf Amount:'+bfAmount);
                //System.debug('*** lf Amount:'+lfAmount);
                //System.debug('*** ip Earned Fee:'+ipEarnedFee);
                //System.debug('*** ip paid to Client:'+ipPaidToClient);
                //System.debug('*** Client Amount:'+ClientAmount);
                //if(maAmount==0){
                claim.Payable_to_Client__c=ipAmount-bfAmount-lfAmount-ipEarnedFee-ipPaidToClient-ClientAmount;
                //}else{
                //claim.Payable_to_Client__c=ipAmount2-ipEarnedFee;
            //}
            }
        }
        else{
            if(pdwfAmount+ipAmount>=claim.Total_Charge__c)
            ipEarnedFee=(claim.Total_Charge__c*claim.Claim_Rate__c)/100;
            
          if(claimPayment.Payment_Type__c<>'Bank fees' && claimPayment.Payment_Type__c<>'Legal Fees'){
            System.debug('****************');
            System.debug('Claim Balance Due:'+claim.Claim_Balance_Due__c);
            System.debug('****************');
            claim.Claim_Balance_Due__c=Claim.Total_Charge__c-ipAmount-pdwfAmount-pdnfAmount-ndAmount-maAmount;
        }        
        if(claimPayment.Payment_Type__c<>'Patient down payment WF' && claimPayment.Payment_Type__c<>'Patient down payment NF'){
            system.debug('***Wrong Entry***');
            claim.Payable_to_Client__c=(ipAmount-ipEarnedFee)-bfAmount-lfAmount-ipPaidToClient-ClientAmount;
        }
        }
        
      //  system.debug('Payable to Client:'+claim.Payable_to_Client__c);
      //  system.debug('Claim Balance Due:'+claim.Claim_Balance_Due__c); 
        claim.Total_Earned_Fees_Display__c=ipEarnedFee;
        if(claim.Claim_Balance_Due__c<0){
            claim.Total_Earned_Fees_Display__c=0;
            claim.Payable_to_Client__c=0;
            claim.Claim_Balance_Due__c=claim.Claim_Balance_Due__c-prAmount;
            if(ipEarnedFee>((claim.Total_Charge__c*claim.Claim_Rate__c)/100)){
            claim.Total_Earned_Fees_Display__c=(claim.Total_Charge__c*claim.Claim_Rate__c)/100;}
            else{
                claim.Total_Earned_Fees_Display__c=ipEarnedFee;
            }
        }
    
    }
    update claim;
    if(delFlag){
        if(cpList.size()==0){
            claim.Claim_Balance_Due__c=0;
            claim.Payable_to_Client__c=0;
            update claim;
        }
    }    
  }   
}