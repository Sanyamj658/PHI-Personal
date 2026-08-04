trigger calculations on Claim_Payment__c (Before insert,Before update) {

For(Claim_Payment__c cp : Trigger.New){
if(cp.Paid_to_client__c==NULL){
    cp.Paid_to_client__c=0;
}
cp.Earned_fee_workflow__c=cp.Earned_Fee__c;
if(cp.Payment_Type__c=='Insurance Payment'||cp.Payment_Type__c=='Patient Payment'||cp.Payment_Type__c=='Patient Refund'){
    cp.Due_to_Client1__c=cp.Amount__c - cp.Earned_Fee__c - cp.Paid_to_client__c;
}
else if(cp.Payment_Type__c=='Legal Fees'||cp.Payment_Type__c=='Patient down payment WF'||cp.Payment_Type__c=='Network Discounts'||cp.Payment_Type__c=='Manual Adjustment'||cp.Payment_Type__c=='Bank fees'||cp.Payment_Type__c=='Patient down payment NF'){
    cp.Due_to_Client1__c=0;
}
else{
//do nothing
}
}

}