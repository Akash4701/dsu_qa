trigger FeedbackItemTrigger on Feedback_Item__c (after update) {
    new FeedbackItemTriggerHandler().process();
}