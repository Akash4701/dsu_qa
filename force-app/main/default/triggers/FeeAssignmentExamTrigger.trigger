trigger FeeAssignmentExamTrigger on Fee_Assignment__c (after insert, after update) {
    if (Trigger.isAfter && Trigger.isInsert) {
        FeeAssignmentExamHandler.handleAfterInsert(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        FeeAssignmentExamHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
    }
}