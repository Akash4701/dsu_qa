/**
 * Thin router for the Feedback_Scheduler__c trigger. Each event delegates to one service that owns
 * the logic, the SOQL (FeedbackSchedulerSelector) and the volume handling:
 *   after insert -> FeedbackItemGenerationService  (build items for the audience)
 *   after update -> FeedbackItemDateSyncService    (cascade changed dates)
 *   before delete -> FeedbackItemCleanupService    (remove the items while the lookup still points at the scheduler)
 */
public with sharing class FeedbackSchedulerTriggerHandler extends TriggerHandler {

    public override void processAfterInsert() {
        FeedbackItemGenerationService.generateFor((List<Feedback_Scheduler__c>) Trigger.new);
    }

    public override void processAfterUpdate() {
        FeedbackItemDateSyncService.onSchedulersUpdated(
            (List<Feedback_Scheduler__c>) Trigger.new, (Map<Id, Feedback_Scheduler__c>) Trigger.oldMap);
    }

    public override void processBeforeDelete() {
        FeedbackItemCleanupService.onSchedulersDeleting((List<Feedback_Scheduler__c>) Trigger.old);
    }
}