trigger ExamTrigger on Exam__c (before insert, before update) {
    if (Trigger.isBefore && (Trigger.isInsert || Trigger.isUpdate)) {
        ExamTriggerHandler.beforeInsertUpdate(
            Trigger.new,
            Trigger.isUpdate ? Trigger.oldMap : null
        );
    }
}