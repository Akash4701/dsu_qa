/**
 * Chunked version of FeedbackItemDateSyncService for a scheduler with more items than fit in one
 * transaction. The scheduler's current dates are re-read per chunk, so a second edit while the job is
 * running simply wins.
 */
public with sharing class FeedbackItemDateSyncBatch implements Database.Batchable<SObject> {
    private final Id schedulerId;

    public FeedbackItemDateSyncBatch(Id schedulerId) {
        this.schedulerId = schedulerId;
    }

    public Database.QueryLocator start(Database.BatchableContext context) {
        return FeedbackSchedulerSelector.itemLocatorForScheduler(schedulerId);
    }

    public void execute(Database.BatchableContext context, List<Feedback_Item__c> scope) {
        Feedback_Scheduler__c scheduler = FeedbackSchedulerSelector.byId(schedulerId);
        if (scheduler == null) {
            return;
        }
        List<Feedback_Item__c> changed = new List<Feedback_Item__c>();
        FeedbackItemDateSyncService.applyDates(scheduler, scope, changed);
        if (!changed.isEmpty()) {
            update changed;
        }
    }

    public void finish(Database.BatchableContext context) {
        // No follow-up needed.
    }
}