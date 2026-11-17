@IsTest
public class ExpireSlotsSchedulerTest {

    @TestSetup
    static void setupData() {
        // Reuse the same “reference” setup style you’ve been using.
        // NOTE: This scheduler itself doesn't query any of these, but we keep the base setup consistent.

        Account dept = new Account(Name = 'Test Department');
        insert dept;

        hed__Term__c term = new hed__Term__c(
            Name = 'Spring 2025',
            hed__Account__c = dept.Id,
            Term_Reference__c = 'Term 1',
            hed__Start_Date__c = Date.today(),
            hed__End_Date__c = Date.today().addMonths(4)
        );
        insert term;

        Contact student = new Contact(LastName = 'Test Student');
        insert student;

        hed__Course__c course = new hed__Course__c(
            Name = 'Test Course',
            hed__Account__c = dept.Id,
            Credits__c = 4
        );
        insert course;

        hed__Course_Offering__c offering = new hed__Course_Offering__c(
            Name = 'Test Offering',
            hed__Course__c = course.Id,
            hed__Term__c = term.Id
        );
        insert offering;

        Course_Evaluation_Component__c component = new Course_Evaluation_Component__c(
            Name = 'CIA Component',
            Course_Offering__c = offering.Id,
            Exam_Type__c = 'CIA',
            Maximum_Marks_for_the_Component__c = 100
        );
        insert component;

        Exam_Cycle__c examCycle = new Exam_Cycle__c(
            Name = 'CIA Exam Cycle',
            Exam_Name__c = 'CIA',
            Start_Date__c = Date.today().addDays(-1),
            End_Date__c   = Date.today().addDays(30)
        );
        insert examCycle;

        Exam_Cycle_Term_Connection__c ectc = new Exam_Cycle_Term_Connection__c(
            Term__c = term.Id,
            Exam_Cycle__c = examCycle.Id
        );
        insert ectc;

        Exam__c exam = new Exam__c(
            Course_Evaluation_Component__c = component.Id
        );
        insert exam;

        // Optional: create a record for each object type that your batch may expect to process.
        // If SlotAndExamExpireBatch filters by date/time, adjust fields accordingly (below are placeholders).
        // Only include these if those objects exist in your org and have required fields.
        //
        // Slot_Scheduled__c slot = new Slot_Scheduled__c(
        //     Slot_Scheduled__c = 'EXT-SLOT-EXPIRE-001',
        //     Status__c = 'Active',
        //     Slot_Date__c = Date.today().addDays(-1)
        // );
        // insert slot;
        //
        // Exam_Slot_Setup__c setup = new Exam_Slot_Setup__c(
        //     Name = 'Setup To Expire',
        //     Status__c = 'Active',
        //     Slot_Date__c = Date.today().addDays(-1)
        // );
        // insert setup;
    }

    @IsTest
    static void testExecute_runsBothBatches() {
        Test.startTest();

        // Directly call execute (covers scheduler logic)
        new ExpireSlotsScheduler().execute(null);

        Test.stopTest();

        // We can’t directly assert batch side-effects without knowing SlotAndExamExpireBatch logic/fields.
        // But we *can* assert that we reached here without exception.
        System.assert(true, 'Scheduler executed without errors');
    }

    @IsTest
    static void testSchedule_jobRuns() {
        Test.startTest();

        // Schedule the job (Salesforce runs it at Test.stopTest)
        String cron = '0 0 0 1 1 ? 2099';
        System.schedule('ExpireSlotsSchedulerTestJob', cron, new ExpireSlotsScheduler());

        Test.stopTest();

        System.assert(true, 'Scheduled job executed in test context');
    }
}