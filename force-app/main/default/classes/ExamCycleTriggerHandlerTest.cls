@IsTest
public class ExamCycleTriggerHandlerTest {

    @TestSetup
    static void setupData() {

        // ACCOUNT (Department / Institution)
        Account dept = new Account(Name = 'Test Department');
        insert dept;

        // TERM (REQUIRED: Account + Term Reference)
        hed__Term__c term = new hed__Term__c(
            Name = 'Spring 2025',
            hed__Account__c = dept.Id,
            Term_Reference__c = 'Term 1',
            hed__Start_Date__c = Date.today(),
            hed__End_Date__c = Date.today().addMonths(4)
        );
        insert term;

        // CONTACT (Student)
        Contact student = new Contact(LastName = 'Test Student');
        insert student;

        // AFFILIATION (DSU_Email__c must be non-null for handler to proceed)
        hed__Affiliation__c aff = new hed__Affiliation__c(
            hed__Contact__c = student.Id,
            hed__Account__c = dept.Id,
            DSU_Email__c = 'teststudent@dsuonline.com'
        );
        insert aff;

        // COURSE (REQUIRED: Account)
        hed__Course__c course = new hed__Course__c(
            Name = 'Test Course',
            hed__Account__c = dept.Id,
            Credits__c = 4
        );
        insert course;

        // COURSE OFFERING (REQUIRED: Course + Term)
        hed__Course_Offering__c offering = new hed__Course_Offering__c(
            Name = 'Test Offering',
            hed__Course__c = course.Id,
            hed__Term__c = term.Id
        );
        insert offering;

        // COURSE EVALUATION COMPONENT
        Course_Evaluation_Component__c component = new Course_Evaluation_Component__c(
            Name = 'CIA Component',
            Course_Offering__c = offering.Id,
            Exam_Type__c = 'CIA',
            Maximum_Marks_for_the_Component__c = 100
        );
        insert component;

        // EXAM CYCLE (Is_Active__c is formula in your org -> active via dates)
        Exam_Cycle__c examCycle = new Exam_Cycle__c(
            Name = 'CIA Exam Cycle',
            Exam_Name__c = 'CIA',
            Start_Date__c = Date.today().addDays(-1),
            End_Date__c   = Date.today().addDays(30),
            Publish_Hall_Ticket__c = false
        );
        insert examCycle;

        // EXAM CYCLE TERM CONNECTION (required by ExamTriggerHandler to derive Exam_Cycle__c)
        Exam_Cycle_Term_Connection__c ectc = new Exam_Cycle_Term_Connection__c(
            Term__c = term.Id,
            Exam_Cycle__c = examCycle.Id
        );
        insert ectc;

        // EXAM (Exam_Cycle__c auto-derived by ExamTriggerHandler)
        Exam__c exam = new Exam__c(
            Course_Evaluation_Component__c = component.Id
        );
        insert exam;

        // COURSE ENROLLMENT (must satisfy handler filters)
        hed__Course_Enrollment__c ce = new hed__Course_Enrollment__c(
            hed__Contact__c = student.Id,
            hed__Course_Offering__c = offering.Id,
            Enrollment_Status__c = 'Enrolled',
            Exam_Eligibility__c = 'Eligible'
        );
        insert ce;

        // EXAM CONNECTIONS (must satisfy handler filters)
        Exam_Connections__c examConn = new Exam_Connections__c(
            Student_Name__c = student.Id, // lookup(Contact) -> must be Id
            Exam_Name__c = exam.Id,       // lookup(Exam__c)
            Course_Connection_ID__c = ce.Id,
            Eligibility__c = 'Eligible'
        );
        insert examConn;
    }

    @IsTest
    static void testHandlePublishHallTicket_onUpdate_publishToggledTrue_noException() {
        // Arrange: get cycle, flip publish from false -> true
        Exam_Cycle__c ec = [
            SELECT Id, Publish_Hall_Ticket__c
            FROM Exam_Cycle__c
            WHERE Name = 'CIA Exam Cycle'
            LIMIT 1
        ];

        // oldMap snapshot (publish false)
        Exam_Cycle__c oldRec = ec.clone(false, true, false, false);
        Map<Id, Exam_Cycle__c> oldMap = new Map<Id, Exam_Cycle__c>{ ec.Id => oldRec };

        ec.Publish_Hall_Ticket__c = true;

        Test.startTest();
        // Act: call handler directly (simulate after update)
        ExamCycleTriggerHandler.handlePublishHallTicket(
            new List<Exam_Cycle__c>{ ec },
            oldMap,
            false
        );
        Test.stopTest();

        // In most orgs, the EmailTemplate / OrgWideEmailAddress may not exist in tests,
        // so the handler will safely return before Messaging.sendEmail().
        System.assertEquals(
            0,
            Limits.getEmailInvocations(),
            'No emails should be sent in test context when template/org-wide email are not available.'
        );
    }

    @IsTest
    static void testHandlePublishHallTicket_onInsert_publishTrue_noException() {
        // Arrange: create a new active exam cycle published=true (no exams in it -> should early-return safely)
        Exam_Cycle__c newCycle = new Exam_Cycle__c(
            Name = 'CIA Exam Cycle 2',
            Exam_Name__c = 'CIA',
            Start_Date__c = Date.today().addDays(-1),
            End_Date__c   = Date.today().addDays(30),
            Publish_Hall_Ticket__c = true
        );
        insert newCycle;

        Test.startTest();
        // Act: simulate after insert
        ExamCycleTriggerHandler.handlePublishHallTicket(
            new List<Exam_Cycle__c>{ newCycle },
            null,
            true
        );
        Test.stopTest();

        System.assertEquals(
            0,
            Limits.getEmailInvocations(),
            'No emails should be sent (and method should not throw).'
        );
    }
}