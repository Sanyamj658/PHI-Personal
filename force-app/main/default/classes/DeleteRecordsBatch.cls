global class DeleteRecordsBatch implements Database.Batchable<SObject>, Schedulable {
    private String objectTypeName;
    private String criteria;
    private Boolean cascadeDelete;
    private String emailAddress;
    
    public static final Map<String, String> frequencyCronMap = new Map<String, String>{
        'Daily' => '0 0 1 * * ?',
        'Weekly' => '0 0 1 ? * 1',
        'Monthly' => '0 0 1 1 * ?',
        'Quarterly' => '0 0 1 1 1,4,7,10 ?'
    };

    global DeleteRecordsBatch(String objectTypeName, String criteria, Boolean cascadeDelete, String emailAddress) {
        this.objectTypeName = objectTypeName;
        this.criteria = criteria;
        this.cascadeDelete = cascadeDelete;
        this.emailAddress = emailAddress;
    }

    global Database.QueryLocator start(Database.BatchableContext bc) {
        //Hardcoding criteria to prevent any empty criteria(Which might led to deletion of all Attachments)
		//For future replace hard coded criteria with 'criteria' variable
        String query = 'SELECT Id FROM ' + objectTypeName + ' WHERE ' + 'Name = \'delete\' OR Name = \'deleted\' OR Name = \'deleted.pdf\'';
        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext bc, List<SObject> scope) {
        List<Id> recordIdsToDelete = new List<Id>();
        for (SObject record : scope) {
            recordIdsToDelete.add(record.Id);
        }
        if (cascadeDelete) {
            Database.delete(recordIdsToDelete, true);
        } else {
            Database.delete(recordIdsToDelete);
        }
    }

    global void finish(Database.BatchableContext bc) {
        // Perform any post-processing here
        if (emailAddress != null && emailAddress != '') {
            String subject = 'Delete Records Job Complete: ' + objectTypeName;
            String body = 'The delete records job for ' + objectTypeName + ' is complete.\n\n'
                         + 'Criteria used: ' + criteria + '\n\n'
                         + 'Cascade delete was ' + (cascadeDelete ? 'enabled' : 'disabled') + '.';
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new List<String>{emailAddress});
            email.setSubject(subject);
            email.setPlainTextBody(body);
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{email});
        }
    }

    global void execute(SchedulableContext sc) {
        DeleteRecordsBatch batch = new DeleteRecordsBatch(objectTypeName, criteria, cascadeDelete, emailAddress);
        Database.executeBatch(batch);
    }

    public static void scheduleBatch(String jobName, String objectTypeName, String criteria, Boolean cascadeDelete, String emailAddress, String frequency) {
        String cronExpression = frequencyCronMap.get(frequency);
        if (cronExpression != null) {
            DeleteRecordsBatch batch = new DeleteRecordsBatch(objectTypeName, criteria, cascadeDelete, emailAddress);
            System.schedule(jobName, cronExpression, batch);
        } else {
            throw new IllegalArgumentException('Invalid frequency value. Valid values are: ' + frequencyCronMap.keySet());
        }
    }
}