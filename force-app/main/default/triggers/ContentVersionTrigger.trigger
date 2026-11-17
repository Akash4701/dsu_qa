trigger ContentVersionTrigger on ContentVersion (after insert,before insert) {
    if (Trigger.isAfter && Trigger.isInsert) {
        ContentVersionTriggerHandler.handleAfterInsert(Trigger.new);
    }
}