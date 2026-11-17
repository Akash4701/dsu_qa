@IsTest
public class SlotAndExamExpireBatchTest {

    @TestSetup
    static void setupData() {

        // -----------------------------
        // 1) Slot_scheduled__c records
        // -----------------------------
        // Make it already "ended" so batch marks Is_Expired__c = true
        Slot_scheduled__c pastSlot = new Slot_scheduled__c(
            End_Date_Time__c = System.now().addMinutes(-5),
            Is_Expired__c = false
        );
        insert pastSlot;

        // -----------------------------------------
        // 2) Exam_Slot_Setup__c records (RT based)
        // -----------------------------------------
        Map<String, Id> rtMap = new Map<String, Id>();
        for (RecordType rt : [
            SELECT Id, DeveloperName
            FROM RecordType
            WHERE SobjectType = 'Exam_Slot_Setup__c'
            AND DeveloperName IN ('Individual', 'Recurring')
        ]) {
            rtMap.put(rt.DeveloperName, rt.Id);
        }

        Id individualRtId = rtMap.get('Individual');
        Id recurringRtId  = rtMap.get('Recurring');

        // INDIVIDUAL:
        // Validation in your org: Start_Date__c must NOT be in the past
        // Batch expiry uses: Start_Date__c + End_Time__c
        // So set Start_Date__c = today, End_Time__c = 00:00 => endDt is today 00:00 which is <= now (expired)
        if (individualRtId != null) {
            Exam_Slot_Setup__c indivExpired = new Exam_Slot_Setup__c(
                RecordTypeId = individualRtId,
                Start_Date__c = Date.today(),
                End_Time__c = Time.newInstance(0, 0, 0, 0),
                Is_Expired__c = false
            );
            insert indivExpired;
        }

        // RECURRING:
        // Your org validation: End_Date__c must be AFTER Start_Date__c
        // Batch expiry uses: End_Date__c + End_Time__c
        // We'll keep it future-safe (covers recurring branch; may or may not mark expired depending on time)
        if (recurringRtId != null) {
            Exam_Slot_Setup__c recurFuture = new Exam_Slot_Setup__c(
                RecordTypeId = recurringRtId,
                Start_Date__c = Date.today().addDays(2),
                End_Date__c   = Date.today().addDays(3),
                End_Time__c   = Time.newInstance(23, 59, 0, 0),
                Is_Expired__c = false
            );
            insert recurFuture;
        }
    }

    @IsTest
    static void testBatch_SlotScheduled() {
        Test.startTest();
        Database.executeBatch(new SlotAndExamExpireBatch('Slot_scheduled__c'), 200);
        Test.stopTest();
    }

    @IsTest
    static void testBatch_ExamSlotSetup() {
        Test.startTest();
        Database.executeBatch(new SlotAndExamExpireBatch('Exam_Slot_Setup__c'), 200);
        Test.stopTest();
    }

    @IsTest
    static void testBatch_StartFallbackQueryLocator() {
        // Covers:
        // return Database.getQueryLocator('SELECT Id FROM Account WHERE Id = null');
        Test.startTest();
        Database.executeBatch(new SlotAndExamExpireBatch('UNKNOWN_OBJECT_NAME'), 200);
        Test.stopTest();
    }
}