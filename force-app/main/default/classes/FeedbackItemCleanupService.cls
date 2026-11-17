/**
 * Removes the Feedback Items of Feedback Schedulers being deleted. Runs in BEFORE delete: the lookup is
 * SetNull, so once the delete commits it is cleared and the items could no longer be found (orphans).
 *
 * Scale: up to one transaction's worth of items is deleted inline; anything larger is collected as Ids
 * (they can no longer be found by scheduler afterwards) and handed to FeedbackItemDeleteBatch.
 */
public with sharing class FeedbackItemCleanupService {

    @TestVisible private static Integer syncRowLimit = 5000;
    @TestVisible private static final Integer DML_SAFETY_MARGIN = 500;
    @TestVisible private static final Integer BATCH_SCOPE = 2000;

    public static void onSchedulersDeleting(List<Feedback_Scheduler__c> deleted) {
        Set<Id> schedulerIds = new Map<Id, Feedback_Scheduler__c>(deleted).keySet();
        if (schedulerIds.isEmpty()) {
            return;
        }
        // Ids are small; read as many as the transaction's query-row budget allows in a single query.
        Integer queryRowBudget = Math.max(1, Limits.getLimitQueryRows() - Limits.getQueryRows() - DML_SAFETY_MARGIN);
        List<Id> itemIds = FeedbackSchedulerSelector.itemIdsForSchedulers(schedulerIds, queryRowBudget);
        if (itemIds.isEmpty()) {
            return;
        }
        Integer dmlBudget = Limits.getLimitDmlRows() - Limits.getDmlRows() - DML_SAFETY_MARGIN;
        if (itemIds.size() <= Math.min(syncRowLimit, dmlBudget)) {
            Database.delete(itemIds, false);
        } else {
            Database.executeBatch(new FeedbackItemDeleteBatch(itemIds), BATCH_SCOPE);
        }
    }
}