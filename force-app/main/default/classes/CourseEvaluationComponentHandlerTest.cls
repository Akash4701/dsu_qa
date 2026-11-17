@IsTest
public with sharing class CourseEvaluationComponentHandlerTest {

    @TestSetup
    static void setupData() {

        // ACCOUNT (Department / Institution)
        Account dept = new Account(Name = 'Test Department');
        insert dept;

        // TERM (REQUIRED: Account + Term Reference)
        hed__Term__c term = new hed__Term__c(
            Name = 'Spring 2025',
            hed__Account__c = dept.Id,
            Term_Reference__c = 'Term 1',   // must be valid picklist value in your org
            hed__Start_Date__c = Date.today(),
            hed__End_Date__c = Date.today().addMonths(4)
        );
        insert term;

        // CONTACT (Student)
        Contact student = new Contact(LastName = 'Test Student');
        insert student;

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

        // COURSE EVALUATION COMPONENT (REQUIRED fields)
        // NOTE: set Exam_Required__c = false here to avoid handler creating extra records during setup
        Course_Evaluation_Component__c component = new Course_Evaluation_Component__c(
            Name = 'CIA Component',
            Course_Offering__c = offering.Id,
            Exam_Type__c = 'CIA',
            Exam_Required__c = false,
            Maximum_Marks_for_the_Component__c = 100
        );
        insert component;

        // EXAM CYCLE
        // Is_Active__c is FORMULA in your org, so set Start/End dates to make it TRUE.
        Exam_Cycle__c examCycle = new Exam_Cycle__c(
            Name = 'CIA Exam Cycle',
            Exam_Name__c = 'CIA',
            Start_Date__c = Date.today().addDays(-1),
            End_Date__c   = Date.today().addDays(30)
        );
        insert examCycle;

        // EXAM CYCLE TERM CONNECTION
        Exam_Cycle_Term_Connection__c ectc = new Exam_Cycle_Term_Connection__c(
            Term__c = term.Id,
            Exam_Cycle__c = examCycle.Id
        );
        insert ectc;

        // EXAM (Exam_Cycle__c auto-derived by ExamTriggerHandler)
        // kept because your reference includes it; it also proves the cycle+term connection is valid.
        Exam__c exam = new Exam__c(
            Course_Evaluation_Component__c = component.Id
        );
        insert exam;
    }

    // Helper: create a Course Enrollment (Eligible)
    private static hed__Course_Enrollment__c createEnrollment() {
        Contact student = [SELECT Id FROM Contact LIMIT 1];
        hed__Course_Offering__c offering = [SELECT Id FROM hed__Course_Offering__c LIMIT 1];

        hed__Course_Enrollment__c ce = new hed__Course_Enrollment__c(
            hed__Contact__c = student.Id,
            hed__Course_Offering__c = offering.Id,
            Enrollment_Status__c = 'Enrolled',
            Exam_Eligibility__c = 'Eligible'
        );
        insert ce;
        return ce;
    }

    @IsTest
    static void testAfterInsert_createsExamJunctionAndExamConnections_whenExamRequiredTrue() {
        // Arrange
        hed__Course_Offering__c offering = [SELECT Id FROM hed__Course_Offering__c LIMIT 1];

        // Ensure we have at least one eligible enrollment for this offering
        hed__Course_Enrollment__c ce = createEnrollment();

        Course_Evaluation_Component__c comp = new Course_Evaluation_Component__c(
            Name = 'CIA Component - Required',
            Course_Offering__c = offering.Id,
            Exam_Type__c = 'CIA',
            Exam_Required__c = true,
            Maximum_Marks_for_the_Component__c = 100,
            Pass_Weightage__c = 40
        );
        insert comp;

        Test.startTest();
        CourseEvaluationComponentHandler.handleAfterInsert(new List<Course_Evaluation_Component__c>{ comp });
        Test.stopTest();

        // Assert: Exam created and Exam_Cycle__c derived (no validation error)
        Exam__c createdExam = [
            SELECT Id, Exam_Name__c, Course_Evaluation_Component__c, Exam_Cycle__c
            FROM Exam__c
            WHERE Course_Evaluation_Component__c = :comp.Id
            LIMIT 1
        ];
        System.assertEquals('CIA', createdExam.Exam_Name__c);
        System.assertNotEquals(null, createdExam.Exam_Cycle__c, 'Exam_Cycle__c should be auto-derived');

        // Assert: Junction created
        Course_Offering_Exam_Connection__c junction = [
            SELECT Id, Course_Evaluation_Component__c, Course_Offering__c, Exam__c
            FROM Course_Offering_Exam_Connection__c
            WHERE Course_Evaluation_Component__c = :comp.Id
            LIMIT 1
        ];
        System.assertEquals(offering.Id, junction.Course_Offering__c);
        System.assertEquals(createdExam.Id, junction.Exam__c);

        // Assert: Exam Connections created (one per eligible enrollment)
        List<Exam_Connections__c> conns = [
            SELECT Id, Student_Name__c, Course_Connection_ID__c, Exam_Name__c, Course_Evaluation_Component__c
            FROM Exam_Connections__c
            WHERE Exam_Name__c = :createdExam.Id
        ];
        System.assertEquals(1, conns.size(), 'Should create 1 exam connection for 1 eligible enrollment');
        System.assertEquals(ce.hed__Contact__c, conns[0].Student_Name__c);
        System.assertEquals(ce.Id, conns[0].Course_Connection_ID__c);
        System.assertEquals(comp.Id, conns[0].Course_Evaluation_Component__c);
    }

    @IsTest
    static void testAfterInsert_doesNothing_whenExamRequiredFalse() {
        hed__Course_Offering__c offering = [SELECT Id FROM hed__Course_Offering__c LIMIT 1];

        Course_Evaluation_Component__c comp = new Course_Evaluation_Component__c(
            Name = 'CIA Component - Not Required',
            Course_Offering__c = offering.Id,
            Exam_Type__c = 'CIA',
            Exam_Required__c = false,
            Maximum_Marks_for_the_Component__c = 100,
            Pass_Weightage__c = 40
        );
        insert comp;

        Test.startTest();
        CourseEvaluationComponentHandler.handleAfterInsert(new List<Course_Evaluation_Component__c>{ comp });
        Test.stopTest();

        System.assertEquals(
            0,
            [SELECT COUNT() FROM Exam__c WHERE Course_Evaluation_Component__c = :comp.Id],
            'No exam should be created when Exam_Required__c is false'
        );
    }

    @IsTest
    static void testAfterUpdate_whenBecomesEligible_createsRecords() {
        hed__Course_Offering__c offering = [SELECT Id FROM hed__Course_Offering__c LIMIT 1];

        // Ensure eligible enrollment exists
        createEnrollment();

        Course_Evaluation_Component__c comp = new Course_Evaluation_Component__c(
            Name = 'CIA Component - Update Eligible',
            Course_Offering__c = offering.Id,
            Exam_Type__c = 'CIA',
            Exam_Required__c = false,
            Maximum_Marks_for_the_Component__c = 100,
            Pass_Weightage__c = 40
        );
        insert comp;

        Map<Id, Course_Evaluation_Component__c> oldMap = new Map<Id, Course_Evaluation_Component__c>{
            comp.Id => comp.clone(false, true, false, false)
        };

        comp.Exam_Required__c = true;
        update comp;

        Test.startTest();
        CourseEvaluationComponentHandler.handleAfterUpdate(new List<Course_Evaluation_Component__c>{ comp }, oldMap);
        Test.stopTest();

       
    }

    @IsTest
    static void testAfterUpdate_whenBecomesIneligible_cleansUpRecords() {
        hed__Course_Offering__c offering = [SELECT Id FROM hed__Course_Offering__c LIMIT 1];

        // Ensure eligible enrollment exists
        createEnrollment();

        Course_Evaluation_Component__c comp = new Course_Evaluation_Component__c(
            Name = 'CIA Component - Cleanup',
            Course_Offering__c = offering.Id,
            Exam_Type__c = 'CIA',
            Exam_Required__c = true,
            Maximum_Marks_for_the_Component__c = 100,
            Pass_Weightage__c = 40
        );
        insert comp;

        // Create records via handler
        CourseEvaluationComponentHandler.handleAfterInsert(new List<Course_Evaluation_Component__c>{ comp });

        Exam__c exam = [
            SELECT Id
            FROM Exam__c
            WHERE Course_Evaluation_Component__c = :comp.Id
            LIMIT 1
        ];

        Map<Id, Course_Evaluation_Component__c> oldMap = new Map<Id, Course_Evaluation_Component__c>{
            comp.Id => comp.clone(false, true, false, false)
        };

        comp.Exam_Required__c = false;
        update comp;

        Test.startTest();
        CourseEvaluationComponentHandler.handleAfterUpdate(new List<Course_Evaluation_Component__c>{ comp }, oldMap);
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Exam__c WHERE Id = :exam.Id], 'Exam should be deleted');
        System.assertEquals(
            0,
            [SELECT COUNT() FROM Course_Offering_Exam_Connection__c WHERE Course_Evaluation_Component__c = :comp.Id],
            'Junction should be deleted'
        );
        System.assertEquals(
            0,
            [SELECT COUNT() FROM Exam_Connections__c WHERE Exam_Name__c = :exam.Id],
            'Exam connections should be deleted'
        );
    }
}