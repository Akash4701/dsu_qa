trigger ComponentScoresTrigger on Component_Scores__c (before insert, before update, after insert, after update) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            ComponentScoresHandler.onBeforeInsert(Trigger.new);
        }
        if (Trigger.isUpdate) {
            ComponentScoresHandler.onBeforeUpdate(Trigger.old, Trigger.new);
        }
    }
    
    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            ComponentScoresHandler.onAfterInsert(Trigger.new);
        }
        if (Trigger.isUpdate) {
            ComponentScoresHandler.onAfterUpdate(Trigger.old, Trigger.new); // FIXED: Pass oldRecords
        }
    }
}