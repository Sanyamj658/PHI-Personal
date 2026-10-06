// Lightning controller that validates and sends app invitation emails to Contacts.
public with sharing class AppUserInvitationController {
    // Developer name of the email template used for app invitations.
    private static final String Invitation_Template = 'App_Invitation_Template';

    // Checks that the Contact has an email and is not already a registered App User.
    @AuraEnabled
    public static Map<String, Object> checkInvitationEligibility(Id contactId) {
        if (contactId == null) {
            return buildResponse(false, 'Invalid Contact Id.');
        }

        try {
            Contact contactRecord = getContact(contactId);

            if (contactRecord == null || String.isBlank(contactRecord.Email)) {
                return buildResponse(false, 'This Contact does not have an email address.');
            }

            // Block the invitation if an App User with the same email and DOB already exists.
            Boolean userExists = isAppUserExists(contactRecord.Email, contactRecord.Date_of_Birth__c);
            if (userExists) {
                return buildResponse(false, 'App User is already registered with the same Email and DOB.');
            }

            return buildResponse(true, 'Ready to send invitation.');
        } catch (Exception ex) {
            throw new AuraHandledException('Error checking invitation eligibility: ' + ex.getMessage());
        }
    }

    // Sends the invitation email template to the Contact and logs it as an activity.
    @AuraEnabled
    public static String sendInvitationEmail(Id contactId) {
        if (contactId == null) {
            throw new AuraHandledException('Invalid Contact Id.');
        }

        try {
            EmailTemplate emailTemplate = getEmailTemplate();

            if (emailTemplate == null) {
                throw new AuraHandledException('Email template not found. Please ask your Admin to create "App_Invitation_Template".');
            }

            Messaging.SingleEmailMessage emailMessage = new Messaging.SingleEmailMessage();
            emailMessage.setTemplateId(emailTemplate.Id);
            emailMessage.setTargetObjectId(contactId);
            emailMessage.setSaveAsActivity(true);

            // Send the email and surface the first error message if it fails.
            Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[] { emailMessage });

            if (results.isEmpty() || !results[0].isSuccess()) {
                String errorMessage = 'Unknown email sending error.';

                if (!results.isEmpty() && !results[0].getErrors().isEmpty()) {
                    errorMessage = results[0].getErrors()[0].getMessage();
                }

                throw new AuraHandledException(errorMessage);
            }

            return 'Success';
        } catch (AuraHandledException ex) {
            // Rethrow AuraHandledException as-is so the UI shows the original message.
            throw ex;
        } catch (Exception ex) {
            throw new AuraHandledException('Error sending email: ' + ex.getMessage());
        }
    }

    // Fetches the Contact by Id, returning null on failure.
    private static Contact getContact(Id contactId) {
        try {
            List<Contact> contacts = [
                SELECT Id, Email, Date_of_Birth__c, FirstName, LastName
                FROM Contact
                WHERE Id = :contactId
                LIMIT 1
            ];
            return contacts.isEmpty() ? null : contacts[0];
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'AppUserInvitationController.getContact failed: ' + ex.getMessage());
            return null;
        }
    }

    // Returns true if an App User already exists for the given email and DOB.
    private static Boolean isAppUserExists(String emailAddress, Date dob) {
        try {
            Integer countUsers = [
                SELECT COUNT()
                FROM App_User__c
                WHERE Email__c = :emailAddress
                AND DOB__c = :dob
                
            ];
            return countUsers > 0;
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'AppUserInvitationController.isAppUserExists failed: ' + ex.getMessage());
            return false;
        }
    }

    // Looks up the invitation email template by developer name.
    private static EmailTemplate getEmailTemplate() {
        try {
            List<EmailTemplate> templates = [
                SELECT Id
                FROM EmailTemplate
                WHERE DeveloperName = :Invitation_Template
                LIMIT 1
            ];
            return templates.isEmpty() ? null : templates[0];
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'AppUserInvitationController.getEmailTemplate failed: ' + ex.getMessage());
            return null;
        }
    }

    // Builds the eligibility response map returned to the LWC.
    private static Map<String, Object> buildResponse(Boolean isEligible, String message) {
        return new Map<String, Object>{
            'isEligible' => isEligible,
            'message' => message
        };
    }
}