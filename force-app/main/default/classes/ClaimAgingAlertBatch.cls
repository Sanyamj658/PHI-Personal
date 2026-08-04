global class ClaimAgingAlertBatch implements Database.Batchable<SObject>, Schedulable {
    private Integer daysOld;
    private Map<String, String> userMap;

    public ClaimAgingAlertBatch(Integer daysOld) {
        this.daysOld = daysOld;
        this.userMap = new Map<String, String>();

        // Fetch all User__mdt records and create the user map
        for (User__mdt user : [SELECT Name__c, Email__c FROM User__mdt]) {
            userMap.put(user.Name__c, user.Email__c);
        }
    }

    global Database.QueryLocator start(Database.BatchableContext bc) {
        //String query = 'SELECT Id, Name, Collector__c FROM Claim__c WHERE Date_Sent_to_Ins_Co__c != null AND Date_Sent_to_Ins_Co__c = N_DAYS_AGO:' + daysOld + ' AND Collector__c != null';
        String query = 'SELECT Id, Name, Collector__c ' +
               'FROM Claim__c ' +
               'WHERE Date_Sent_to_Ins_Co__c != null ' +
               'AND Date_Sent_to_Ins_Co__c = N_DAYS_AGO:' + daysOld + ' ' +
               'AND Collector__c != null ' +
               'AND (Pending_Status__c = \'Payment Received Partial\' ' +
               'OR Pending_Status__c = \'Pending Balance from Patient\' ' +
               'OR Pending_Status__c = \'Pending Payment from Insurance\' ' +
               'OR Pending_Status__c = \'Pending Payment from Patient\' ' +
               'OR Pending_Status__c = \'Pending payment from Secondary Insurance\')';

        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext bc, List<SObject> scope) {
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        String emailBody = getEmailBody(daysOld);

        for (SObject record : scope) {
            Claim__c claim = (Claim__c) record;
            String collectorName = claim.Collector__c;
            String emailAddress = userMap.containsKey(collectorName) ? userMap.get(collectorName) : userMap.get('Back up');
            String subject = getEmailSubject(daysOld, claim.Name);

            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new List<String>{emailAddress});
            email.setSubject(subject);
            email.setHtmlBody(emailBody);
            emails.add(email);
        }

        Messaging.sendEmail(emails);
    }

    global void finish(Database.BatchableContext bc) {
        // Perform any post-processing here if needed
    }

    global void execute(SchedulableContext sc) {
        Database.executeBatch(new ClaimAgingAlertBatch(180));
        Database.executeBatch(new ClaimAgingAlertBatch(360));
    }

    public static void scheduleBatch(String jobName) {
        String cronExpression = '0 0 1 * * ?'; // Schedule to run daily at 1 AM
        ClaimAgingAlertBatch batch = new ClaimAgingAlertBatch(0); // Parameters are placeholders for schedulable context
        System.schedule(jobName, cronExpression, batch);
    }

    private String getEmailBody(Integer daysOld) {
        if (daysOld == 180) {
            return '<p>Collector,</p>'
                + '<p>Have you taken all necessary steps to keep this claim current? Please advise management if the following actions have been completed on this claim:</p>'
                + '<ol>'
                + '<li><strong>Patient Engagement:</strong><br>'
                + 'First email<br>'
                + 'Second email<br>'
                + 'Phone calls<br>'
                + 'Patient statement<br>'
                + 'Demand letter <span style="color:red;">(when applicable)</span></li>'
                + '<li><strong>Insurance Follow-ups:</strong><br>'
                + 'Follow-ups every two weeks</li>'
                + '<li><strong>System Documentation:</strong><br>'
                + 'Properly documented notes (e.g., reference numbers, name of representative, claim number)<br>'
                + 'Attachments properly renamed (e.g., EOB, PRA, EOP, communication letters from insurance)</li>'
                + '<li><strong>Appeal Process:</strong><br>'
                + 'First level appeal<br>'
                + 'Second level appeal<br>'
                + 'External review <span style="color:red;">(when applicable)</span></li>'
                + '<li><strong>TLO Report:</strong><br>'
                + 'Run and attached to the patient profile</li>'
                + '</ol>'
                + '<p>If you can respond affirmatively to all the above, it is time to escalate this account to the head of claims, account manager, general counsel, and/or management for next steps.</p>'
                + '<p>Thank you,</p>'
                + '<p>PHI Administration</p>';
        } else if (daysOld == 360) {
            return '<p>Collector,</p>'
                + '<p>This claim has reached 360 days in the system without resolution. You must bring this account to the account manager\'s attention immediately without any further delay for analysis.</p>'
                + '<p>Thank you,</p>'
                + '<p>PHI Administration</p>';
        } else {
            return '';
        }
    }

    private String getEmailSubject(Integer daysOld, String claimNumber) {
        if (daysOld == 180) {
            return claimNumber + ' - This claim is aging and needs your immediate attention';
        } else if (daysOld == 360) {
            return claimNumber + ' - This claim needs urgent attention !!!';
        } else {
            return '';
        }
    }
}