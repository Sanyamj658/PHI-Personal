public class FirebaseNotificationQueueable implements Queueable, Database.AllowsCallouts {
    private String payload;

    public FirebaseNotificationQueueable(String payload) {
        this.payload = payload;
    }

    public void execute(QueueableContext context) {
        try {
            FirebaseService.sendBulkNotificationsSync(payload);
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'FirebaseNotificationQueueable.execute failed: ' + ex.getMessage());
        }
    }
}