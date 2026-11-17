@IsTest
public with sharing class ExamCycleHallTicketControllerTest {

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
        Course_Evaluation_Component__c component = new Course_Evaluation_Component__c(
            Name = 'CIA Component',
            Course_Offering__c = offering.Id,
            Exam_Type__c = 'CIA',
            Exam_Required__c = false,
            Maximum_Marks_for_the_Component__c = 100
        );
        insert component;

        // EXAM CYCLE (Publish_Hall_Ticket__c starts false/null)
        Exam_Cycle__c examCycle = new Exam_Cycle__c(
            Name = 'CIA Exam Cycle',
            Exam_Name__c = 'CIA',
            Start_Date__c = Date.today().addDays(-1),
            End_Date__c   = Date.today().addDays(30),
            Publish_Hall_Ticket__c = false
        );
        insert examCycle;

        // EXAM CYCLE TERM CONNECTION
        Exam_Cycle_Term_Connection__c ectc = new Exam_Cycle_Term_Connection__c(
            Term__c = term.Id,
            Exam_Cycle__c = examCycle.Id
        );
        insert ectc;

        // EXAM (kept from your reference)
        Exam__c exam = new Exam__c(
            Course_Evaluation_Component__c = component.Id
        );
        insert exam;
    }

    @IsTest
    static void testPublishHallTicket_setsFlagToTrue() {
        Id examCycleId = [
            SELECT Id
            FROM Exam_Cycle__c
            WHERE Name = 'CIA Exam Cycle'
            LIMIT 1
        ].Id;

        // Pre-check
        Exam_Cycle__c beforeEc = [
            SELECT Id, Publish_Hall_Ticket__c
            FROM Exam_Cycle__c
            WHERE Id = :examCycleId
            LIMIT 1
        ];
        System.assertEquals(false, beforeEc.Publish_Hall_Ticket__c, 'Publish flag should start false in test data');

        Test.startTest();
        ExamCycleHallTicketController.publishHallTicket(examCycleId);
        Test.stopTest();

        Exam_Cycle__c afterEc = [
            SELECT Id, Publish_Hall_Ticket__c
            FROM Exam_Cycle__c
            WHERE Id = :examCycleId
            LIMIT 1
        ];
        System.assertEquals(true, afterEc.Publish_Hall_Ticket__c, 'Publish flag should be set to true');
    }

    @IsTest
    static void testPublishHallTicket_throwsWhenIdNull() {
        Test.startTest();
        try {
            ExamCycleHallTicketController.publishHallTicket(null);
            System.assert(false, 'Expected AuraHandledException when examCycleId is null');
        } catch (AuraHandledException e) {
          
        }
        Test.stopTest();
    }

    @IsTest
    static void testPublishHallTicket_throwsWhenAlreadyPublished() {
        // Arrange: mark as already published
        Exam_Cycle__c ec = [
            SELECT Id, Publish_Hall_Ticket__c
            FROM Exam_Cycle__c
            WHERE Name = 'CIA Exam Cycle'
            LIMIT 1
            FOR UPDATE
        ];
        ec.Publish_Hall_Ticket__c = true;
        update ec;

        Test.startTest();
        try {
            ExamCycleHallTicketController.publishHallTicket(ec.Id);
            System.assert(false, 'Expected AuraHandledException when already published');
        } catch (AuraHandledException e) {
         
        }
        Test.stopTest();
    }
}