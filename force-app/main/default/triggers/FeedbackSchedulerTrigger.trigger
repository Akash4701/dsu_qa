trigger FeedbackSchedulerTrigger on Feedback_Scheduler__c (after insert, after update, before delete) {
    new FeedbackSchedulerTriggerHandler().process();
}