/**
 * Creates the Feedback Items of newly inserted Feedback Schedulers (called from the trigger handler).
 *
 * Scale: items are built in the same transaction while the schedule is small, so the user sees them
 * straight away. A scheduler whose audience would not fit in one transaction (row cap below, remaining
 * DML rows, or SOQL budget) is handed to FeedbackItemGenerationBatch instead, which pages through the
 * audience 2,000 at a time. Nothing here queries or inserts inside an unbounded loop.
 */
public with sharing class FeedbackItemGenerationService {

    /** Most audience rows built synchronously for one scheduler; larger audiences go to the batch job. */
    @TestVisible private static Integer syncRowLimit = 5000;
    @TestVisible private static final Integer DML_SAFETY_MARGIN = 500;
    @TestVisible private static final Integer SOQL_SAFETY_MARGIN = 5;
    @TestVisible private static final Integer BATCH_SCOPE = 2000;

    public static void generateFor(List<Feedback_Scheduler__c> insertedSchedulers) {
        Set<Id> schedulerIds = new Set<Id>();
        for (Feedback_Scheduler__c scheduler : insertedSchedulers) {
            schedulerIds.add(scheduler.Id);
        }

        List<Feedback_Item__c> items = new List<Feedback_Item__c>();
        List<Id> deferred = new List<Id>();
        Integer dmlBudget = Limits.getLimitDmlRows() - Limits.getDmlRows() - DML_SAFETY_MARGIN;

        for (Feedback_Scheduler__c scheduler : FeedbackSchedulerSelector.withType(schedulerIds)) {
            FeedbackItemSource source = FeedbackItemSources.forType(scheduler.Feedback_Master__r?.Feedback_Type__c);
            if (source == null || scheduler.Term__c == null) {
                continue; // every source is built from the term's enrolments
            }
            Integer cap = Math.min(syncRowLimit, dmlBudget);
            if (cap <= 0 || Limits.getQueries() >= Limits.getLimitQueries() - SOQL_SAFETY_MARGIN) {
                deferred.add(scheduler.Id);
                continue;
            }
            // One row past the cap tells us the audience is too big for this transaction.
            Integer probe = cap + 1;
            List<SObject> rows = Database.queryWithBinds(
                source.query() + ' LIMIT :probe', withProbe(source.binds(scheduler), probe), source.accessLevel());
            if (rows.size() > cap) {
                deferred.add(scheduler.Id);
                continue;
            }
            dmlBudget -= rows.size();
            items.addAll(source.toItems(scheduler, rows));
        }

        if (!items.isEmpty()) {
            insert items;
        }
        for (Id schedulerId : deferred) {
            Database.executeBatch(new FeedbackItemGenerationBatch(schedulerId), BATCH_SCOPE);
        }
    }

    private static Map<String, Object> withProbe(Map<String, Object> binds, Integer probe) {
        Map<String, Object> all = new Map<String, Object>(binds);
        all.put('probe', probe);
        return all;
    }
}