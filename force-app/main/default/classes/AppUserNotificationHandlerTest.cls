/**
 * AppUserNotificationHandlerTest
 * Covers: matchAppUserToPatients (full match → Active + patient link + welcome email,
 *         no match → InActive + inactive email, DOB / name mismatch, blank name,
 *         empty list, exception guard), buildWelcomeEmail, and the AppUserTrigger
 *         (before insert) that calls the handler.
 */
@IsTest
private class AppUserNotificationHandlerTest {

    private static final String PATIENT_EMAIL = 'john.doe@example.com';
    private static final Date   PATIENT_DOB   = Date.newInstance(1990, 1, 1);

    @TestSetup
    static void setup() {
        Insurance_Company__c insurance = new Insurance_Company__c(Name = 'Test Insurance');
        insert insurance;

        Contact patient = new Contact(
            FirstName            = 'John',
            LastName             = 'Doe',
            Email                = PATIENT_EMAIL,
            Date_of_Birth__c     = PATIENT_DOB,
            DX_s__c              = 'DX01',
            Primary_Insurance__c = insurance.Id,
            Plan_Type__c         = 'Other Plan'
        );
        insert patient;
    }

    private static Contact getPatient() {
        return [SELECT Id FROM Contact WHERE Email = :PATIENT_EMAIL LIMIT 1];
    }

    private static App_User__c buildAppUser(String name, String email, Date dob) {
        return new App_User__c(Name = name, Email__c = email, dob__c = dob, Status__c = 'Pending');
    }

    // ─── Full match: name + email + DOB → Active and linked to the Contact ───

    @IsTest
    static void testMatch_FullMatch_SetsActiveAndLinksPatient() {
        // Mixed case + spaces prove the name/email normalisation
        App_User__c appUser = buildAppUser(' JOHN  doe ', 'John.Doe@Example.com', PATIENT_DOB);

        Test.startTest();
        AppUserNotificationHandler.matchAppUserToPatients(new List<App_User__c>{ appUser });
        Test.stopTest();

        System.assertEquals('Active', appUser.Status__c, 'Matched user should be Active');
        System.assertEquals(getPatient().Id, appUser.Patient__c, 'Matched user should be linked to the Contact');
    }

    // ─── No Contact with this email → InActive ───────────────────────────────

    @IsTest
    static void testMatch_NoContactForEmail_SetsInactive() {
        App_User__c appUser = buildAppUser('John Doe', 'nobody@example.com', PATIENT_DOB);

        Test.startTest();
        AppUserNotificationHandler.matchAppUserToPatients(new List<App_User__c>{ appUser });
        Test.stopTest();

        System.assertEquals('InActive', appUser.Status__c);
        System.assertEquals(null, appUser.Patient__c);
    }

    // ─── Email matches but DOB differs → InActive ────────────────────────────

    @IsTest
    static void testMatch_DobMismatch_SetsInactive() {
        App_User__c appUser = buildAppUser('John Doe', PATIENT_EMAIL, Date.newInstance(2001, 2, 3));

        Test.startTest();
        AppUserNotificationHandler.matchAppUserToPatients(new List<App_User__c>{ appUser });
        Test.stopTest();

        System.assertEquals('InActive', appUser.Status__c);
        System.assertEquals(null, appUser.Patient__c);
    }

    // ─── Email + DOB match but the name differs → InActive ───────────────────

    @IsTest
    static void testMatch_NameMismatch_SetsInactive() {
        App_User__c appUser = buildAppUser('Jane Smith', PATIENT_EMAIL, PATIENT_DOB);

        Test.startTest();
        AppUserNotificationHandler.matchAppUserToPatients(new List<App_User__c>{ appUser });
        Test.stopTest();

        System.assertEquals('InActive', appUser.Status__c);
        System.assertEquals(null, appUser.Patient__c);
    }

    // ─── Blank name is normalised to '' and never matches ────────────────────

    @IsTest
    static void testMatch_BlankName_SetsInactive() {
        App_User__c appUser = buildAppUser(null, PATIENT_EMAIL, PATIENT_DOB);

        Test.startTest();
        AppUserNotificationHandler.matchAppUserToPatients(new List<App_User__c>{ appUser });
        Test.stopTest();

        System.assertEquals('InActive', appUser.Status__c);
    }

    // ─── Bulk: one matching and one non-matching user in the same call ───────

    @IsTest
    static void testMatch_Bulk_MixedResults() {
        App_User__c matching    = buildAppUser('John Doe', PATIENT_EMAIL, PATIENT_DOB);
        App_User__c nonMatching = buildAppUser('Someone Else', 'else@example.com', PATIENT_DOB);

        Test.startTest();
        AppUserNotificationHandler.matchAppUserToPatients(new List<App_User__c>{ matching, nonMatching });
        Test.stopTest();

        System.assertEquals('Active',   matching.Status__c);
        System.assertEquals('InActive', nonMatching.Status__c);
    }

    // ─── Empty list: nothing to query and no email is sent ───────────────────

    @IsTest
    static void testMatch_EmptyList_NoException() {
        Test.startTest();
        AppUserNotificationHandler.matchAppUserToPatients(new List<App_User__c>());
        Test.stopTest();

        System.assertEquals(0, Limits.getEmailInvocations(), 'No email should be sent for an empty list');
    }

    // ─── Exception guard: null Email__c throws inside the try block ──────────

    @IsTest
    static void testMatch_NullEmail_ExceptionIsCaught() {
        App_User__c appUser = buildAppUser('John Doe', null, PATIENT_DOB);

        Test.startTest();
        AppUserNotificationHandler.matchAppUserToPatients(new List<App_User__c>{ appUser });
        Test.stopTest();

        System.assertEquals('Pending', appUser.Status__c, 'Status is untouched when processing fails');
    }

    // ─── buildWelcomeEmail: uses the name, or "User" when the name is blank ──

    @IsTest
    static void testBuildWelcomeEmail_WithName() {
        Messaging.SingleEmailMessage mail =
            AppUserNotificationHandler.buildWelcomeEmail(buildAppUser('John Doe', PATIENT_EMAIL, PATIENT_DOB));

        System.assertEquals(PATIENT_EMAIL, mail.getToAddresses()[0]);
        System.assert(mail.getHtmlBody().contains('Dear John Doe'));
    }

    @IsTest
    static void testBuildWelcomeEmail_BlankName_UsesDefault() {
        Messaging.SingleEmailMessage mail =
            AppUserNotificationHandler.buildWelcomeEmail(buildAppUser(null, PATIENT_EMAIL, PATIENT_DOB));

        System.assert(mail.getHtmlBody().contains('Dear User'));
    }

    // ─── Trigger: before insert runs the matching automatically ──────────────

    @IsTest
    static void testTrigger_BeforeInsert_MatchesPatient() {
        App_User__c matching = buildAppUser('John Doe', PATIENT_EMAIL, PATIENT_DOB);
        App_User__c unmatched = buildAppUser('No Match', 'no.match@example.com', PATIENT_DOB);

        Test.startTest();
        insert new List<App_User__c>{ matching, unmatched };
        Test.stopTest();

        App_User__c savedMatch = [SELECT Status__c, Patient__c FROM App_User__c WHERE Id = :matching.Id];
        App_User__c savedOther = [SELECT Status__c, Patient__c FROM App_User__c WHERE Id = :unmatched.Id];

        System.assertEquals('Active', savedMatch.Status__c);
        System.assertEquals(getPatient().Id, savedMatch.Patient__c);
        System.assertEquals('Inactive', savedOther.Status__c);
        System.assertEquals(null, savedOther.Patient__c);
    }
}
