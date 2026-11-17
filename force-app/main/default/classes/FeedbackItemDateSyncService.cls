/**
 * Copies a Feedback Scheduler's Start/End dates onto its Feedback Items when, and only when, the
 * scheduler's dates changed and its type uses scheduler-level dates (see FeedbackItemSources.isDateDriven).
 * Only items whose dates actually differ are written, so unchanged items are not re-saved (which would
 * re-run the Feedback Item trigger and its extension email logic for nothing).
 *
 * Scale: small schedulers sync in the same transaction; a scheduler with more items than fit is handed
 * to FeedbackItemDateSyncBatch, in chunks of 200 so each chunk's extension emails stay within limits.
 */
public with sharing class FeedbackItemDateSyncService {

    @TestVisible private static Integer syncRowLimit = 5000;
    @TestVisible private static final Integer DML_SAFETY_MARGIN = 500;
    @TestVisible private static final Integer SOQL_SAFETY_MARGIN = 5;
    @TestVisible private static final Integer BATCH_SCOPE = 200;

    public static void onSchedulersUpdated(List<Feedback_Scheduler__c> updated, Map<Id, Feedback_Scheduler__c> oldById) {
        Set<Id> changedIds = new Set<Id>();
        for (Feedback_Scheduler__c scheduler : updated) {
            Feedback_Scheduler__c before = oldById?.get(scheduler.Id);
            if (before != null
                && (before.Start_Date__c != scheduler.Start_Date__c || before.End_Date__c != scheduler.End_Date__c)) {
                changedIds.add(scheduler.Id);
            }
        }
        if (changedIds.isEmpty()) {
            return;
        }

        List<Feedback_Item__c> toUpdate = new List<Feedback_Item__c>();
        List<Id> deferred = new List<Id>();
        Integer dmlBudget = Limits.getLimitDmlRows() - Limits.getDmlRows() - DML_SAFETY_MARGIN;

        for (Feedback_Scheduler__c scheduler : FeedbackSchedulerSelector.withType(changedIds)) {
            if (!FeedbackItemSources.isDateDriven(scheduler.Feedback_Master__r?.Feedback_Type__c)) {
                continue;
            }
            Integer cap = Math.min(syncRowLimit, dmlBudget);
            if (cap <= 0 || Limits.getQueries() >= Limits.getLimitQueries() - SOQL_SAFETY_MARGIN) {
                deferred.add(scheduler.Id);
                continue;
            }
            List<Feedback_Item__c> items = FeedbackSchedulerSelector.itemsForScheduler(scheduler.Id, cap + 1);
            if (items.size() > cap) {
                deferred.add(scheduler.Id);
                continue;
            }
            Integer changed = applyDates(scheduler, items, toUpdate);
            dmlBudget -= changed;
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
        for (Id schedulerId : deferred) {
            Database.executeBatch(new FeedbackItemDateSyncBatch(schedulerId), BATCH_SCOPE);
        }
    }

    /** Sets the scheduler's dates on every item that differs, adding those items to `changedItems`. */
    public static Integer applyDates(
        Feedback_Scheduler__c scheduler, List<Feedback_Item__c> items, List<Feedback_Item__c> changedItems
    ) {
        Integer changed = 0;
        for (Feedback_Item__c item : items) {
            if (item.Start_Date__c != scheduler.Start_Date__c || item.End_Date__c != scheduler.End_Date__c) {
                item.Start_Date__c = scheduler.Start_Date__c;
                item.End_Date__c = scheduler.End_Date__c;
                changedItems.add(item);
                changed++;
            }
        }
        return changed;
    }
}