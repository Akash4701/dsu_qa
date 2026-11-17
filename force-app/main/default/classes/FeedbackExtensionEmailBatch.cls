/**
 * Drains the Feedback Items whose date-change email was deferred for lack of daily email allowance
 * (Extension_Email_Pending__c). Runs daily as a scheduled job: each run sends as many as capacity allows
 * and leaves the rest flagged for the next run, so a mass date change completes over a few days instead of
 * failing. The job schedules itself the first time anything is deferred (ensureScheduled), so no manual
 * set-up is needed.
 */
public with sharing class FeedbackExtensionEmailBatch implements Database.Batchable<SObject>, Schedulable {

    public static final String JOB_NAME = 'Feedback Extension Email Catch-up';
    private static final String DAILY_AT_6AM = '0 0 6 * * ?';
    @TestVisible private static final Integer SCOPE = 200;

    // ---------- Scheduling ----------

    /** Creates the daily job if it is not already scheduled. Idempotent and safe to call from a trigger. */
    public static void ensureScheduled() {
        Integer existing = [
            SELECT COUNT() FROM CronTrigger WHERE CronJobDetail.Name = :JOB_NAME AND State != 'DELETED'
        ];
        if (existing == 0) {
            System.schedule(JOB_NAME, DAILY_AT_6AM, new FeedbackExtensionEmailBatch());
        }
    }

    public void execute(SchedulableContext context) {
        if (FeedbackExtensionEmailService.availableCapacity() > 0) {
            Database.executeBatch(new FeedbackExtensionEmailBatch(), SCOPE);
        }
    }

    // ---------- Batch ----------

    public Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator([
            SELECT Id FROM Feedback_Item__c WHERE Extension_Email_Pending__c = TRUE ORDER BY LastModifiedDate
        ]);
    }

    public void execute(Database.BatchableContext context, List<Feedback_Item__c> scope) {
        // Capacity can run out mid-job: send what fits, leave the remainder flagged for the next run.
        Integer capacity = FeedbackExtensionEmailService.availableCapacity();
        if (capacity <= 0) {
            return;
        }
        List<Id> ids = new List<Id>();
        for (Feedback_Item__c item : scope) {
            if (ids.size() < capacity) {
                ids.add(item.Id);
            }
        }
        FeedbackExtensionEmailService.sendAndClear(ids, true);
    }

    public void finish(Database.BatchableContext context) {
        // Anything still flagged is picked up by tomorrow's scheduled run.
    }
}