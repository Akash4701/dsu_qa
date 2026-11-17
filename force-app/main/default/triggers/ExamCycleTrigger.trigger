trigger ExamCycleTrigger on Exam_Cycle__c (after insert, after update) {
    ExamCycleTriggerHandler.handlePublishHallTicket(Trigger.new, Trigger.oldMap, Trigger.isInsert);
}