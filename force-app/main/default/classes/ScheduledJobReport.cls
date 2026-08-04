global class ScheduledJobReport implements Schedulable {
global void execute(SchedulableContext sc) {
              BatchReportMail brm = new BatchReportMail();
              database.executeBatch(brm,1);
    }
  }