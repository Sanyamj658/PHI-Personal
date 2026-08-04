public class PatientMailSample {
    
    public String emailTo {get; set;}
    public String emailBody {get; set;}
    public String emailBody1 {get; set;}
    public String response {get; set;}
    public String subject1 {get; set;}
    public id pid {get; set;}
    public PatientMailSample(){
        pid = ApexPages.currentPage().getParameters().get('id');
        system.debug('***patientId:'+pid);
        Contact p = [SELECT id,lastname,firstname,email,account.name from Contact where id=:pid];
        system.debug('***PatientName:'+p.lastname+''+p.firstname);
        Claim__c c = [SELECT id,Date_Received__c,Total_Charge__c,From_DOS__c,To_DOS__c  From Claim__c WHERE Patient__c=:pid ORDER BY createddate DESC LIMIT 1];
        system.debug('***List of Claims:'+c);
        Datetime fromDate = c.From_DOS__c.adddays(1);
        system.debug('c.From_DOS__c'+c.From_DOS__c);
        //String fromDateOutput = fromDate.format('MM/dd/yyyy');
        String fromDateOutput = String.ValueOf(date.newinstance(fromDate.year(),fromDate.month(),fromDate.day()));
        system.debug('fromDateOutput '+fromDateOutput);
        Datetime toDate = c.To_DOS__c.adddays(1);
        String toDateOutput = toDate.format('MM/dd/yyyy');
        // subject1= p.account.name +' – DOS: '+ fromDateOutput;
        subject1= 'Claim Submitted on Behalf of '+  p.account.name +' – Your Attention Required';
        emailTo=p.email;
        if(p.firstname == null){
            p.firstname = '';
        }
      /*  String setBody='Dear'+' '+p.firstname+' '+p.lastname+'';
        setBody=setBody+'\n'+'\n';
        setBody=setBody+'Passage Health International is the extended business office that manages the billing for '+p.account.name +' . As a courtesy we have submitted a claim to your insurance company for medical service rendered on '+fromDateOutput+'.';
        setBody=setBody+'\n'+'\n';        
        setBody=setBody+'In order to ensure your claim is processed in a timely manner we ask that you contact your insurance company for the following:';
        setBody=setBody+'\n'+'\n';
        setBody=setBody+'  -  '+'Advise them that medical services were rendered from '+p.account.name+' on '+fromDateOutput+'.';
        setBody=setBody+'\n';
        setBody=setBody+'  -  '+'Advise them that a claim is being submitted for direct payment from '+p.account.name+' c/o Passage Health International on your behalf. If the insurance company provides you with a case or claim number please let us know by calling or emailing us at info@passagehi.com.';
        setBody=setBody+'\n'+'\n';
        setBody=setBody+'Once the claims is adjudicated by your insurance it is likely that you will receive an Explanation of Benefits (EOB). An EOB is not a bill, it is an explanation of how your insurance company applied your benefits towards the bill, including payments made to the provider and an explanation of any unpaid portions for which you are responsible. If you have any questions regarding an EOB, or any other correspondence from the insurer related to this episode of care, please contact us at + 1 (954) 526-9751.';
        setBody=setBody+'\n'+'\n';
        setBody=setBody+'Emergency services are reimbursed by most insurance companies and health plans. However, there may be instances in which your insurance company may not cover a portion of or all the service rendered. In these cases, Passage Health International will work with you to submit an appeal to help ensure your benefits are properly applied. Therefore, it is important that we receive your cooperation as the bill is ultimately your responsibility.';
        setBody=setBody+'\n'+'\n';
        setBody=setBody+'Occasionally, the insurance company will send payment directly to the insured. When this occurs please endorse the back of the check notating “payable to Passage Health Intl.” and send it to the address below. Please also include a copy of the EOB.';
        setBody=setBody+'\n'+'\n';
        setBody=setBody+'Passage Health International';
        setBody=setBody+'\n';
        setBody=setBody+'Attn: International Billing Office';
        setBody=setBody+'\n';
        setBody=setBody+'5900 N ANDREWS AVE. STE 802';
        setBody=setBody+'\n';
        setBody=setBody+'FORT LAUDERDALE FL. 33309'+'\n';
        setBody=setBody+'\n';
        setBody=setBody+'Thank you,';    
        emailBody=setBody;       
        */
          String setBody='Dear'+' '+p.firstname+' '+p.lastname+',';
        setBody=setBody+'\n'+'\n';
        setBody=setBody+'I am writing to inform you that Passage Health International is the extended business office managing the billing for '+p.account.name +' . As a courtesy we have submitted a claim to your insurance company for medical service rendered on '+fromDateOutput+'.';
        setBody=setBody+'\n'+'\n';        
        setBody=setBody+'To ensure your claim is processed promptly, we kindly ask that you contact your insurance company and provide them with the following information:';
        setBody=setBody+'\n'+'\n';
        setBody=setBody+'  •  '+'Inform them that medical services were rendered by '+p.account.name+' on '+fromDateOutput+'.';
        setBody=setBody+'\n';
        setBody=setBody+'  •  '+'Let them know that a claim has been submitted for direct payment to '+p.account.name+' c/o Passage Health International, on your behalf. If the insurance company issues you a case or claim number, please share it with us by calling or emailing us at info@passagehi.com.';
        setBody=setBody+'\n'+'\n';
        setBody=setBody+'Once your claim is adjudicated, you will likely receive an Explanation of Benefits (EOB). Please note that an EOB is not a bill; it simply explains how your insurance company applied your benefits toward the bill, including any payments made to the provider and any unpaid portions for which you may be responsible. If you have any questions regarding your EOB or any other correspondence from the insurer related to this care, please feel free to contact us at +1 (954) 526-9751.';
        setBody=setBody+'\n'+'\n';
        setBody=setBody+'Emergency services are typically reimbursed by most insurance companies and health plans. However, there may be instances where your insurance company does not cover a portion or all of the services rendered. In such cases, Passage Health International will assist you in submitting an appeal to ensure your benefits are properly applied. Therefore, your cooperation is essential, as the bill ultimately remains your responsibility. If you require assistance with any outstanding balance, please reach out to our financial aid department for payment options.';
        setBody=setBody+'\n'+'\n';
        setBody=setBody+'Occasionally, insurance companies may send payment directly to the insured. If this occurs, please endorse the back of the check with “Payable to Passage Health International” and send it to the address below, along with a copy of the EOB.';
        setBody=setBody+'\n'+'\n';
        setBody=setBody+'Passage Health International';
        setBody=setBody+'\n';
        setBody=setBody+'Attn: International Billing Office';
        setBody=setBody+'\n';
        setBody=setBody+'5900 North Andrews Ave, Suite 802';
        setBody=setBody+'\n';
        setBody=setBody+'Fort Lauderdale, FL 33309'+'\n';
        setBody=setBody+'\n';
		setBody=setBody+'Thank you for your attention to this matter. We appreciate your cooperation.';
        setBody=setBody+'\n';
        setBody=setBody+'Regards,';    
        emailBody=setBody;       
        
    
    }
    public PageReference sendEmail(){
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[] {emailTo});
        mail.setReplyTo('noreply@yourcompany.com');
        mail.setSenderDisplayName('Passage Health International');
        mail.setSubject(subject1);
        //mail.setHTMLBody(emailBody);
        mail.setPlainTextBody(emailBody);
        try{
            Messaging.SendEmailResult[] resultMail = Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
            if(resultMail[0].isSuccess())       
                response = 'ok sent!';
            else{
                response = resultMail[0].getErrors().get(0).getMessage();
            }
        }catch(System.EmailException ex){
            response = ex.getMessage();
        }
        PageReference pg = new PageReference('/'+pid);
        pg.setRedirect(true);   
        return pg;
    }
}