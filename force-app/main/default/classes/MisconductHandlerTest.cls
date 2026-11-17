@IsTest
public with sharing class MisconductHandlerTest {

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

        hed__Course_Enrollment__c ce = new hed__Course_Enrollment__c(
            hed__Contact__c = student.Id,
            hed__Course_Offering__c = offering.Id,
            Enrollment_Status__c = 'Enrolled',
            Exam_Eligibility__c = 'Eligible'
        );
        insert ce;

        Exam_Cycle__c cycle = new Exam_Cycle__c(
            Name = 'CIA Cycle',
            Exam_Name__c = 'CIA',
            Start_Date__c = Date.today().addDays(-1),
            End_Date__c = Date.today().addDays(10)
        );
        insert cycle;

        Exam_Cycle_Term_Connection__c ectc = new Exam_Cycle_Term_Connection__c(
            Term__c = term.Id,
            Exam_Cycle__c = cycle.Id
        );
        insert ectc;

        Exam__c exam = new Exam__c(
            Course_Evaluation_Component__c = component.Id,
            Exam_Name__c = 'CIA'
        );
        insert exam;

        Exam_Connections__c ec1 = new Exam_Connections__c(
            Student_Name__c = student.Id,
            Course_Connection_ID__c = ce.Id,
            Exam_Name__c = exam.Id,
            Course_Evaluation_Component__c = component.Id
        );
        insert ec1;

        Exam_Connections__c ec2 = new Exam_Connections__c(
            Student_Name__c = student.Id,
            Course_Connection_ID__c = ce.Id,
            Exam_Name__c = exam.Id,
            Course_Evaluation_Component__c = component.Id
        );
        insert ec2;
    }

    // -----------------------------
    // INSERT path (oldMap = null)
    // -----------------------------
    @IsTest
    static void testInsertPath() {
        Id examConnId = [SELECT Id FROM Exam_Connections__c LIMIT 1].Id;

        Misconduct__c m = new Misconduct__c(
            Exam_Connection__c = examConnId
        );

        Test.startTest();
        MisconductHandler.populateFromExamConnection(
            new List<Misconduct__c>{ m },
            null
        );
        Test.stopTest();
    }

    // -------------------------------------
    // UPDATE path (Exam Connection changed)
    // -------------------------------------
    @IsTest
    static void testUpdatePath_examConnectionChanged() {

        List<Exam_Connections__c> conns =
            [SELECT Id FROM Exam_Connections__c ORDER BY CreatedDate LIMIT 2];

        // REAL record inserted
        Misconduct__c existing = new Misconduct__c(
            Exam_Connection__c = conns[0].Id
        );
        insert existing;

        Misconduct__c newRec = new Misconduct__c(
            Id = existing.Id,
            Exam_Connection__c = conns[1].Id
        );

        Map<Id, Misconduct__c> oldMap =
            new Map<Id, Misconduct__c>{ existing.Id => existing };

        Test.startTest();
        MisconductHandler.populateFromExamConnection(
            new List<Misconduct__c>{ newRec },
            oldMap
        );
        Test.stopTest();
    }

    // -------------------------------------
    // UPDATE path (Exam Connection unchanged)
    // -------------------------------------
    @IsTest
    static void testUpdatePath_examConnectionUnchanged() {

        Id examConnId = [SELECT Id FROM Exam_Connections__c LIMIT 1].Id;

        Misconduct__c existing = new Misconduct__c(
            Exam_Connection__c = examConnId
        );
        insert existing;

        Misconduct__c newRec = new Misconduct__c(
            Id = existing.Id,
            Exam_Connection__c = examConnId
        );

        Map<Id, Misconduct__c> oldMap =
            new Map<Id, Misconduct__c>{ existing.Id => existing };

        Test.startTest();
        MisconductHandler.populateFromExamConnection(
            new List<Misconduct__c>{ newRec },
            oldMap
        );
        Test.stopTest();
    }

    // -----------------------------
    // NULL Exam_Connection__c path
    // -----------------------------
    @IsTest
    static void testNullExamConnection() {
        Misconduct__c m = new Misconduct__c();

        Test.startTest();
        MisconductHandler.populateFromExamConnection(
            new List<Misconduct__c>{ m },
            null
        );
        Test.stopTest();
    }
}