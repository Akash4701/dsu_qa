global class ExpireSlotsScheduler implements Schedulable {

    global void execute(SchedulableContext sc) {
        // Run for Slot_scheduled__c
        Database.executeBatch(
            new SlotAndExamExpireBatch('Slot_scheduled__c'),
            200
        );

        // Run for Exam_Slot_Setup__c
        Database.executeBatch(
            new SlotAndExamExpireBatch('Exam_Slot_Setup__c'),
            200
        );
    }
}