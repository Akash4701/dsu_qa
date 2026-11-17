@IsTest
public with sharing class HallTicketBatchByExamCycleTest {

    @TestSetup
    static void setupData() {

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

        Contact student = new Contact(
            LastName = 'Test Student',
            Registration_Number__c = 'REG-HT-1'
        );
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

        Exam_Cycle__c examCycle = new Exam_Cycle__c(
            Name = 'CIA Exam Cycle',
            Exam_Name__c = 'CIA',
            Start_Date__c = Date.today().addDays(-1),
            End_Date__c   = Date.today().addDays(30)
        );
        insert examCycle;

        insert new Exam_Cycle_Term_Connection__c(
            Term__c = term.Id,
            Exam_Cycle__c = examCycle.Id
        );

        hed__Program_Plan__c programPlan = new hed__Program_Plan__c(Name = 'Test Program Plan');
        insert programPlan;

        hed__Affiliation__c aff = new hed__Affiliation__c(
            hed__Contact__c = student.Id,
            hed__Account__c = dept.Id,
            Program_Plan__c = programPlan.Id,
            DSU_Email__c = 'student1@dsuonline.com'
        );
        insert aff;

        hed__Program_Enrollment__c pe = new hed__Program_Enrollment__c(
            hed__Contact__c = student.Id,
            hed__Account__c = dept.Id,
            Term__c = term.Id,
            hed__Affiliation__c = aff.Id
        );
        insert pe;

        hed__Course_Enrollment__c ce = new hed__Course_Enrollment__c(
            hed__Contact__c = student.Id,
            hed__Course_Offering__c = offering.Id,
            hed__Program_Enrollment__c = pe.Id,
            Enrollment_Status__c = 'Enrolled',
            Exam_Eligibility__c = 'Eligible'
        );
        insert ce;

        Course_Evaluation_Component__c component = new Course_Evaluation_Component__c(
            Name = 'CIA Component',
            Course_Offering__c = offering.Id,
            Exam_Type__c = 'CIA',
            Maximum_Marks_for_the_Component__c = 100
        );
        insert component;

        // IMPORTANT: Exam must match cycle so start() query returns rows
        Exam__c exam = new Exam__c(
            Course_Evaluation_Component__c = component.Id,
            Exam_Cycle__c = examCycle.Id
        );
        insert exam;

        // IMPORTANT: Create ONLY ONE Exam_Connections__c record
        // so batch executes only once (prevents "more than one executeBatch" error in test)
        Exam_Connections__c conn = new Exam_Connections__c(
            Student_Name__c = student.Id,
            Course_Connection_ID__c = ce.Id,
            Exam_Name__c = exam.Id,
            Eligibility__c = 'Eligible'
        );
        insert conn;
    }

    @IsTest
    static void testBatchExecute_isCovered_singleScope() {
        Exam_Cycle__c ec = [SELECT Id FROM Exam_Cycle__c LIMIT 1];
        Contact student = [SELECT Id FROM Contact LIMIT 1];

        Test.startTest();
        // Batch size 1 + only 1 query row => single execute() call in test context
        Database.executeBatch(new HallTicketBatchByExamCycle(ec.Id, new List<Id>{ student.Id }), 1);
        Test.stopTest();
    }

    @IsTest
    static void testGenerateHallTicketPdfBlob_success() {
        Exam_Cycle__c ec = [SELECT Id FROM Exam_Cycle__c LIMIT 1];
        Contact student = [SELECT Id FROM Contact LIMIT 1];

        Test.startTest();
        HallTicketBatchByExamCycle.generateHallTicketPdfBlob(ec.Id, student.Id);
        Test.stopTest();
    }
}