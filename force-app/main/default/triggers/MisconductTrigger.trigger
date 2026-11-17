trigger MisconductTrigger on Misconduct__c (before insert, before update) {
    if (Trigger.isBefore) {
        MisconductHandler.populateFromExamConnection(
            Trigger.new,
            Trigger.isInsert ? null : Trigger.oldMap
        );
    }
}