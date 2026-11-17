public class AffiliationEmailBatch implements Database.Batchable<Id> {
    private List<Id> affilIds;
    private String subject;
    private String body;
    private List<Id> fileDocIds;

    public AffiliationEmailBatch(List<Id> affilIds, String subject, String body, List<Id> fileDocIds) {
        this.affilIds = (affilIds == null) ? new List<Id>() : affilIds;
        this.subject = subject;
        this.body = body;
        this.fileDocIds = (fileDocIds == null) ? new List<Id>() : fileDocIds;
    }

    public Iterable<Id> start(Database.BatchableContext bc) {
        return affilIds;
    }

    public void execute(Database.BatchableContext bc, List<Id> scope) {
        AffiliationEmailService.send(scope, subject, body, fileDocIds);
    }

    public void finish(Database.BatchableContext bc) {
    }
}