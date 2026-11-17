/**
 * Builds the Feedback Items of one Feedback Scheduler whose audience is too large for a single
 * transaction. Pages through the same audience query the synchronous path uses (FeedbackItemSource),
 * so behaviour is identical, just chunked. Stateless: the scheduler is re-read per chunk.
 */
public with sharing class FeedbackItemGenerationBatch implements Database.Batchable<SObject> {
    private final Id schedulerId;

    public FeedbackItemGenerationBatch(Id schedulerId) {
        this.schedulerId = schedulerId;
    }

    public Database.QueryLocator start(Database.BatchableContext context) {
        Feedback_Scheduler__c scheduler = FeedbackSchedulerSelector.byId(schedulerId);
        FeedbackItemSource source = scheduler == null
            ? null : FeedbackItemSources.forType(scheduler.Feedback_Master__r?.Feedback_Type__c);
        if (source == null) {
            // Nothing to build (scheduler deleted or type changed): an empty locator ends the job.
            return Database.getQueryLocator('SELECT Id FROM Feedback_Item__c WHERE Id = NULL');
        }
        return Database.getQueryLocatorWithBinds(source.query(), source.binds(scheduler), source.accessLevel());
    }

    public void execute(Database.BatchableContext context, List<SObject> scope) {
        Feedback_Scheduler__c scheduler = FeedbackSchedulerSelector.byId(schedulerId);
        FeedbackItemSource source = scheduler == null
            ? null : FeedbackItemSources.forType(scheduler.Feedback_Master__r?.Feedback_Type__c);
        if (source == null || scope.isEmpty()) {
            return;
        }
        List<Feedback_Item__c> items = source.toItems(scheduler, scope);
        if (!items.isEmpty()) {
            insert items;
        }
    }

    public void finish(Database.BatchableContext context) {
        // No follow-up: items are visible on the scheduler as soon as each chunk commits.
    }
}