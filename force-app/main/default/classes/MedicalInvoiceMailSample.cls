public class MedicalInvoiceMailSample {
    
    public String emailTo {get; set;}
    public String emailBody1 {get; set;}
    public String response {get; set;}
    public String subject1 {get; set;}
    public id pid {get; set;}
    public MedicalInvoiceMailSample(){
        pid = ApexPages.currentPage().getParameters().get('id');
        system.debug('***patientId:'+pid);
        Contact p = [SELECT id,lastname,firstname,email,account.name from Contact where id=:pid];
        system.debug('***PatientName:'+p.lastname+''+p.firstname);        
        Claim__c c = [SELECT id,Date_Received__c,From_DOS__c,To_DOS__c From Claim__c WHERE Patient__c=:pid ORDER BY createddate DESC LIMIT 1];
        system.debug('***List of Claims:'+c);
        Datetime fromDate = c.From_DOS__c.adddays(1);
        String fromDateOutput = fromDate.format('MM/dd/yyyy');
        // subject1= p.account.name +' – DOS: '+ fromDateOutput;
        subject1= 'Action Required: Insurance Information Needed for Your ' + p.account.name + ' Claim';
        emailTo=p.email;
        if(p.firstname == null){
            p.firstname = '';
        }
        String setBody1='Dear'+' '+p.firstname+' '+p.lastname+'';
        setBody1=setBody1+'\n'+'\n';
        setBody1 = setBody1 + 'Passage Health International serves as an extended business office for '+ p.account.name+', assisting with the billing of medical services. As a courtesy to you, we submitted a claim to your insurance company for services provided on '+ fromDateOutput+'.';
        setBody1=setBody1+'\n'+'\n';
        setBody1=setBody1+'However, your insurance company has informed us that they are missing certain forms or additional information needed to process your claim. We kindly ask that you contact them directly to provide the requested details so your claim can move forward.';
        setBody1=setBody1+'\n'+'\n';
        setBody1=setBody1+'It is important that we receive your cooperation, as the balance may ultimately become your responsibility if the insurance company is unable to process the claim.';
        setBody1=setBody1+'\n'+'\n';
        setBody1=setBody1+'Your prompt attention to this matter will help avoid any delays in the insurance process. If you have any questions or need assistance, please don’t hesitate to contact us at 1-954-526-9751, Monday through Friday from 9:00 a.m. to 5:30 p.m. Eastern Time, or email us at info@passagehi.com.';
        setBody1=setBody1+'\n'+'\n';
        setBody1 = setBody1 + 'Thank you for your cooperation.';
        setBody1=setBody1+'\n'+'\n';
        setBody1=setBody1+'Warm regards,'+'\n'+'\n';
       /* setBody1=setBody1+'Passage Health International'+'\n';
        setBody1=setBody1+'5900 N ANDREWS AVE. STE 802 FORT LAUDERDALE FL. 33309'+'\n';
        setBody1=setBody1+'Office: 1 954 526 9751'+'\n';
        setBody1=setBody1+'Fax: 1 954 376 6163'+'\n';
        setBody1=setBody1+'info@passagehi.com';*/
        emailBody1=setBody1;        
    }
    public PageReference sendEmail(){
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[] {emailTo});
        mail.setReplyTo('noreply@yourcompany.com');
        mail.setSenderDisplayName('Passage Health International');
        mail.setSubject(subject1);
        mail.setPlainTextBody(emailBody1);
        //mail.setHTMLBody(emailBody1);
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