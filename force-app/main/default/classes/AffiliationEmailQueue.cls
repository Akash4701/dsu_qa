public class AffiliationEmailQueue implements Queueable {
    private List<Id> affilIds;
    private String subject;
    private String body;
    private List<Id> fileDocIds;

    public AffiliationEmailQueue(List<Id> affilIds, String subject, String body, List<Id> fileDocIds) {
        this.affilIds = affilIds;
        this.subject  = subject;
        this.body     = body;
        this.fileDocIds = (fileDocIds == null) ? new List<Id>() : fileDocIds;
    }

    public void execute(QueueableContext qc) {
        AffiliationEmailService.send(affilIds, subject, body, fileDocIds);
    }
}