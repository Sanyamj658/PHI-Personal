public class FirebaseNotificationQueueable
    implements Queueable, Database.AllowsCallouts {

    private String payload;

    public FirebaseNotificationQueueable(String payload) {
        this.payload = payload;
    }

    public void execute(QueueableContext context) {
        FirebaseService.sendBulkNotificationsSync(payload);
    }
}