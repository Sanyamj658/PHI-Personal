public with sharing class AppUserInvitationController {

    // Constants
    private static final String Invitation_Template = 'App_Invitation_Template';
    // private static final String VERIFIED_EMAIL = 'aabhargupta2310@gmail.com';

    /**
     * Checks whether a Contact is eligible to receive an invitation email.
     */
    
    @AuraEnabled
    public static Map<String, Object> checkInvitationEligibility(Id contactId) {
        Map<String, Object> response = new Map<String, Object>();

        if (contactId == null) {
            return buildResponse(false, 'Invalid Contact Id.');
        }

        try {
            Contact contactRecord = getContact(contactId);

            if (contactRecord == null || String.isBlank(contactRecord.Email)) {
                return buildResponse(false, 'This Contact does not have an email address.');
            }

            Boolean userExists = isAppUserExists(contactRecord.Email, contactRecord.Date_of_Birth__c);
            System.debug('Contact Email: ' + contactRecord.Email);
System.debug('Contact DOB: ' + contactRecord.Date_of_Birth__c);
System.debug('User Exists: ' + userExists);

            if (userExists) {
                return buildResponse(
                    false,
                    'App User is already registered with the same Email and DOB.' 
                );
            }

            return buildResponse(true, 'Ready to send invitation.');

        } catch (Exception ex) {
            throw new AuraHandledException(
                'Error checking invitation eligibility: ' + ex.getMessage()
            );
        }
    }

    /**
     * Sends invitation email using Email Template and Org-Wide Email Address.
     */
    @AuraEnabled
    public static String sendInvitationEmail(Id contactId) {

        if (contactId == null) {
            throw new AuraHandledException('Invalid Contact Id.');
        }

        try {
            EmailTemplate emailTemplate = getEmailTemplate();

            if (emailTemplate == null) {
                throw new AuraHandledException(
                    'Email template not found. Please ask your Admin to create "App_Invitation_Template".'
                );
            }

            // OrgWideEmailAddress orgWideEmail = getOrgWideEmailAddress();

            // if (orgWideEmail == null) {
            //     throw new AuraHandledException(
            //         'Org-Wide Email Address not found for: ' + VERIFIED_EMAIL
            //     );
            // }

            Messaging.SingleEmailMessage emailMessage = new Messaging.SingleEmailMessage();
            emailMessage.setTemplateId(emailTemplate.Id);
            emailMessage.setTargetObjectId(contactId);
            emailMessage.setSaveAsActivity(true);
            // emailMessage.setOrgWideEmailAddressId(orgWideEmail.Id);

            Messaging.SendEmailResult[] results =
                Messaging.sendEmail(new Messaging.SingleEmailMessage[] { emailMessage });

            if (results.isEmpty() || !results[0].isSuccess()) {
                String errorMessage = 'Unknown email sending error.';

                if (!results.isEmpty() && !results[0].getErrors().isEmpty()) {
                    errorMessage = results[0].getErrors()[0].getMessage();
                }

                throw new AuraHandledException(errorMessage);
            }

            return 'Success';

        } catch (AuraHandledException ex) {
            throw ex;

        } catch (Exception ex) {
            throw new AuraHandledException(
                'Error sending email: ' + ex.getMessage()
            );
        }
    }

    /**
     * Fetch Contact record.
     */
    private static Contact getContact(Id contactId) {
        List<Contact> contacts = [
            SELECT Id, Email, Date_of_Birth__c
            FROM Contact
            WHERE Id = :contactId
            LIMIT 1
        ];
        System.debug('Fetched Contact with Id: ' + contactId + ', Records found: ' + contacts.size());
        System.debug('Contact Query Result: ' + contacts);
        System.debug('Contact Email: ' + (contacts.isEmpty() ? 'No Contact Found' : contacts[0].Email));
        System.debug('Contact DOB: ' + 'No Contact Found     :   ' +  contacts[0].Date_of_Birth__c);
        return contacts.isEmpty() ? null : contacts[0];
    }

    /**
     * Checks whether App_User__c already exists for given email.
     */
    // private static Boolean isAppUserExists(String emailAddress, DATE dob) {
    //      System.debug('Email = ' + emailAddress);
    //     System.debug('DOB = ' + dob);
    //     return [
    //         SELECT COUNT()
    //         FROM App_User__c
    //         WHERE Email__c = :emailAddress AND DOB__C = :dob
    //     ] > 0;
    // }

    private static Boolean isAppUserExists(String emailAddress, Date dob) {

    System.debug('Email = ' + emailAddress);
    System.debug('DOB = ' + dob);

    Integer countUsers = [
        SELECT COUNT()
        FROM App_User__c
        WHERE Email__c = :emailAddress
        AND DOB__c = :dob
    ];

    System.debug('Matching Users = ' + countUsers);

    return countUsers > 0;
}

    /**
     * Fetch Email Template.
     */
    private static EmailTemplate getEmailTemplate() {
        List<EmailTemplate> templates = [
            SELECT Id
            FROM EmailTemplate
            WHERE DeveloperName = :Invitation_Template
            LIMIT 1
        ];

        return templates.isEmpty() ? null : templates[0];
    }

    /**
     * Fetch Org-Wide Email Address.
     
    private static OrgWideEmailAddress getOrgWideEmailAddress() {
        List<OrgWideEmailAddress> oweaList = [
            SELECT Id, Address
            FROM OrgWideEmailAddress
            WHERE Address = :VERIFIED_EMAIL
            LIMIT 1
        ];

        return oweaList.isEmpty() ? null : oweaList[0];
    }  */

    /**
     * Standard response builder.
     */
    private static Map<String, Object> buildResponse(
        Boolean isEligible,
        String message
    ) {
        return new Map<String, Object>{
            'isEligible' => isEligible,
            'message' => message
        };
    }
}