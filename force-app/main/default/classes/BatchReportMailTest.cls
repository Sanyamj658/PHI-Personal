/**
 * @description Test class for BatchReportMail.
 *
 * WHY @IsTest(SeeAllData=true)?
 * BatchReportMail calls Reports.ReportManager.runReport(...). The Analytics
 * (Reports) API cannot run against reports created in a test context because
 * reports cannot be created via Apex/DML. Salesforce therefore requires
 * SeeAllData=true so an already-existing report in the org can be executed.
 * This is the officially documented pattern for testing the Reports namespace.
 *
 * COVERAGE NOTE:
 * Inside BatchReportMail.execute(), the very first blob branch is guarded by
 * `if (Test.isRunningTest()) { ... }`, and hasNoRows() is guarded by
 * `if (!Test.isRunningTest() && ...)`. During any test run these guards force
 * the test path, so the following private helpers are never reached and cannot
 * be covered by an ordinary batch run:
 *   - generateExcelBlob, generateReportBlob, csvEscape, getFactWithDetails, hasNoRows
 * See the prose accompanying this file for a small, optional class change
 * (@TestVisible) plus a direct-invocation test that covers those methods.
 */
@IsTest(SeeAllData=true)
private class BatchReportMailTest {

    // ---------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------

    /** Returns an existing report Id from the org, or null if none exist. */
    private static Id getExistingReportId() {
        List<Report> reports = [SELECT Id FROM Report LIMIT 1];
        return reports.isEmpty() ? null : reports[0].Id;
    }

    /** Builds (but does not insert) a Schedule_Report__c with the given values. */
    private static Schedule_Report__c buildScheduleReport(String reportId, String format, Boolean withEmails) {
        Schedule_Report__c sr = new Schedule_Report__c(
            Select_Report__c = reportId,
            Report_Format__c = format,
            Subject__c       = 'Automated Test Subject'
        );
        if (withEmails) {
            sr.Email__c          = 'primary@example.com';
           
            sr.Email1__c         = 'one@example.com';
            sr.Email2__c         = 'two@example.com';
            sr.Email3__c         = 'three@example.com';
            sr.Email4__c         = 'four@example.com';
            sr.Email5__c         = 'five@example.com';
        }
        return sr;
    }

    /** Queries the AsyncApexJob row for a batch and asserts a clean completion. */
    private static void assertBatchCompleted(Id batchId, String context) {
        AsyncApexJob job = [
            SELECT Status, NumberOfErrors, JobItemsProcessed, TotalJobItems
            FROM AsyncApexJob
            WHERE Id = :batchId
        ];
        System.assertEquals('Completed', job.Status, context + ': batch should reach Completed status.');
        System.assertEquals(0, job.NumberOfErrors, context + ': batch should finish with no errors.');
    }

    // ---------------------------------------------------------------------
    // Tests
    // ---------------------------------------------------------------------

    /**
     * CSV path: reportId constructor scopes the batch to a single record, the
     * Test.isRunningTest() branch builds the test CSV blob, all recipient fields
     * are populated, and the email is dispatched.
     */
    @IsTest
    static void testBatchWithCsvFormat() {
        Schedule_Report__c sr = buildScheduleReport(getExistingReportId(), '.csv', true);
        insert sr;

        Test.startTest();
        Id batchId = Database.executeBatch(new BatchReportMail(sr.Id), 200);
        Test.stopTest();

        assertBatchCompleted(batchId, 'CSV format');
    }

    /**
     * Excel path: request an xlsx format so the format-branch logic is exercised
     * (the attachment name is still .xls per the class' XML-spreadsheet design).
     */
    @IsTest
    static void testBatchWithExcelFormat() {
        Schedule_Report__c sr = buildScheduleReport(getExistingReportId(), '.xlsx', true);
        insert sr;

        Test.startTest();
        Id batchId = Database.executeBatch(new BatchReportMail(sr.Id), 200);
        Test.stopTest();

        assertBatchCompleted(batchId, 'Excel format');
    }

    /**
     * No recipients: every email field is blank, so sendTo stays empty and
     * Messaging.sendEmail is skipped. The batch must still complete cleanly.
     */
    @IsTest
    static void testBatchWithoutEmailAddresses() {
        Schedule_Report__c sr = buildScheduleReport(getExistingReportId(), '.csv', false);
        insert sr;

        Test.startTest();
        Id batchId = Database.executeBatch(new BatchReportMail(sr.Id), 200);
        Test.stopTest();

        assertBatchCompleted(batchId, 'No recipients');
    }

    /**
     * Null / missing Report_Format__c should fall through to the default (CSV)
     * branch without throwing.
     */

    /**
     * Invalid report Id: runReport throws, the catch logs and `continue`s, and
     * the batch still completes with zero errors. Covers the try/catch branch.
     */
    @IsTest
    static void testBatchWithInvalidReport() {
        // 00O is the Report key prefix; this Id does not resolve to a real report.
        Schedule_Report__c sr = buildScheduleReport('00O000000000000AAA', '.csv', true);
        insert sr;

        Test.startTest();
        Id batchId = Database.executeBatch(new BatchReportMail(sr.Id), 200);
        Test.stopTest();

        assertBatchCompleted(batchId, 'Invalid report');
    }

    /**
     * Directly exercises start() (both constructors), finish(), and confirms the
     * QueryLocator is produced. The default constructor path is covered here
     * (via start only) so we never mass-process every Schedule_Report__c under
     * SeeAllData=true.
     */
    @IsTest
    static void testStartAndFinishDirectly() {
        Schedule_Report__c sr = buildScheduleReport(getExistingReportId(), '.csv', true);
        insert sr;

        Test.startTest();

        // Scoped constructor -> WHERE Id = '<recordId>'
        BatchReportMail scopedBatch = new BatchReportMail(sr.Id);
        Database.QueryLocator scopedLocator = scopedBatch.start(null);
        System.assertNotEquals(null, scopedLocator, 'Scoped start() should return a QueryLocator.');
        scopedBatch.finish(null);

        // Default constructor -> no WHERE clause
        BatchReportMail defaultBatch = new BatchReportMail();
        Database.QueryLocator defaultLocator = defaultBatch.start(null);
        System.assertNotEquals(null, defaultLocator, 'Default start() should return a QueryLocator.');
        defaultBatch.finish(null);

        Test.stopTest();
    }
}