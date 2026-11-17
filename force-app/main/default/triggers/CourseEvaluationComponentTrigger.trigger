trigger CourseEvaluationComponentTrigger on Course_Evaluation_Component__c (after insert, after update) {
    if (Trigger.isAfter && Trigger.isInsert) {
        CourseEvaluationComponentHandler.handleAfterInsert(Trigger.new);
    }
    
    if (Trigger.isAfter && Trigger.isUpdate) {
        CourseEvaluationComponentHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
    }
}