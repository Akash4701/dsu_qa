/**
 * Deletes a known list of Feedback Item Ids in chunks. Takes Ids rather than a scheduler because the
 * scheduler (and so the lookup used to find its items) is already gone when this runs.
 */
public with sharing class FeedbackItemDeleteBatch implements Database.Batchable<Id> {
    private final List<Id> itemIds;

    public FeedbackItemDeleteBatch(List<Id> itemIds) {
        this.itemIds = itemIds;
    }

    public Iterable<Id> start(Database.BatchableContext context) {
        return itemIds;
    }

    public void execute(Database.BatchableContext context, List<Id> scope) {
        Database.delete(scope, false);
    }

    public void finish(Database.BatchableContext context) {
        // No follow-up needed.
    }
}