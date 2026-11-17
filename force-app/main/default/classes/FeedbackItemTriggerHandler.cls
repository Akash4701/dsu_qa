/**
 * Thin router for the Feedback_Item__c trigger: when an item's OWN Start_Date__c or End_Date__c changes,
 * its Assignee is notified (independent of the parent Feedback_Scheduler__c). The sending, and the daily
 * email-allowance handling for mass changes, live in FeedbackExtensionEmailService.
 */
public with sharing class FeedbackItemTriggerHandler extends TriggerHandler {

    public override void processAfterUpdate() {
        // Best-effort: a notification failure must never undo the date update itself.
        try {
            FeedbackExtensionEmailService.notify(
                changedDateItemIds((List<Feedback_Item__c>) Trigger.new, (Map<Id, Feedback_Item__c>) Trigger.oldMap));
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, '[FeedbackItemTriggerHandler] Feedback extension notification failed: ' + e.getMessage());
        }
    }

    @TestVisible
    private static List<Id> changedDateItemIds(List<Feedback_Item__c> newItems, Map<Id, Feedback_Item__c> oldItemMap) {
        List<Id> changedIds = new List<Id>();
        if (oldItemMap == null) {
            return changedIds;
        }
        for (Feedback_Item__c newItem : newItems) {
            Feedback_Item__c oldItem = oldItemMap.get(newItem.Id);
            if (oldItem != null
                && (newItem.Start_Date__c != oldItem.Start_Date__c || newItem.End_Date__c != oldItem.End_Date__c)) {
                changedIds.add(newItem.Id);
            }
        }
        return changedIds;
    }
}