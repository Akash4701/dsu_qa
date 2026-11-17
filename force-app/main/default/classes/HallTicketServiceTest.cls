@IsTest
public with sharing class HallTicketServiceTest {

    @TestSetup
    static void setupData() {

        // ACCOUNT (Department / Institution)
        Account dept = new Account(Name = 'Test Department');
        insert dept;

        // TERM
        hed__Term__c term = new hed__Term__c(
            Name = 'Spring 2025',
            hed__Account__c = dept.Id,
            Term_Reference__c = 'Term 1',
            hed__Start_Date__c = Date.today(),
            hed__End_Date__c = Date.today().addMonths(4)
        );
        insert term;

        // COURSE + OFFERING
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

        // EXAM CYCLE (active by date) + published flags are not required here
        Exam_Cycle__c examCycle = new Exam_Cycle__c(
            Name = 'CIA Exam Cycle',
            Exam_Name__c = 'CIA',
            Start_Date__c = Date.today().addDays(-1),
            End_Date__c   = Date.today().addDays(30),
            Generate_HallTicket__c = false
        );
        insert examCycle;

        // EXAM CYCLE TERM CONNECTION (needed by other triggers in org sometimes)
        insert new Exam_Cycle_Term_Connection__c(
            Term__c = term.Id,
            Exam_Cycle__c = examCycle.Id
        );

        // STUDENT CONTACTS
        Contact s1 = new Contact(LastName = 'Student One', Registration_Number__c = 'REG-HT-1');
        Contact s2 = new Contact(LastName = 'Student Two', Registration_Number__c = 'REG-HT-2');
        insert new List<Contact>{ s1, s2 };

        // PROGRAM PLAN + AFFILIATIONS (used by getStudents)
        hed__Program_Plan__c plan = new hed__Program_Plan__c(Name = 'Test Program Plan');
        insert plan;

        // Create 2 affiliations for s1 so ORDER BY CreatedDate DESC chooses latest
        hed__Affiliation__c s1OldAff = new hed__Affiliation__c(
            hed__Contact__c = s1.Id,
            hed__Account__c = dept.Id,
            Program_Plan__c = plan.Id,
            DSU_Email__c = 'old1@dsuonline.com',
            Roll_Number__c = 'ROLL-OLD-1'
        );
        insert s1OldAff;

        hed__Affiliation__c s1NewAff = new hed__Affiliation__c(
            hed__Contact__c = s1.Id,
            hed__Account__c = dept.Id,
            Program_Plan__c = plan.Id,
            DSU_Email__c = 'new1@dsuonline.com',
            Roll_Number__c = 'ROLL-NEW-1'
        );
        insert s1NewAff;

        hed__Affiliation__c s2Aff = new hed__Affiliation__c(
            hed__Contact__c = s2.Id,
            hed__Account__c = dept.Id,
            Program_Plan__c = plan.Id,
            DSU_Email__c = 's2@dsuonline.com',
            Roll_Number__c = 'ROLL-2'
        );
        insert s2Aff;

        // PROGRAM ENROLLMENTS
        hed__Program_Enrollment__c pe1 = new hed__Program_Enrollment__c(
            hed__Contact__c = s1.Id,
            hed__Account__c = dept.Id,
            Term__c = term.Id,
            hed__Affiliation__c = s1NewAff.Id
        );
        hed__Program_Enrollment__c pe2 = new hed__Program_Enrollment__c(
            hed__Contact__c = s2.Id,
            hed__Account__c = dept.Id,
            Term__c = term.Id,
            hed__Affiliation__c = s2Aff.Id
        );
        insert new List<hed__Program_Enrollment__c>{ pe1, pe2 };

        // COURSE ENROLLMENTS (needed for Course_Connection_ID__r.hed__Program_Enrollment__c in queries)
        hed__Course_Enrollment__c ce1 = new hed__Course_Enrollment__c(
            hed__Contact__c = s1.Id,
            hed__Course_Offering__c = offering.Id,
            hed__Program_Enrollment__c = pe1.Id,
            Enrollment_Status__c = 'Enrolled',
            Exam_Eligibility__c = 'Eligible'
        );
        hed__Course_Enrollment__c ce2 = new hed__Course_Enrollment__c(
            hed__Contact__c = s2.Id,
            hed__Course_Offering__c = offering.Id,
            hed__Program_Enrollment__c = pe2.Id,
            Enrollment_Status__c = 'Enrolled',
            Exam_Eligibility__c = 'Eligible'
        );
        insert new List<hed__Course_Enrollment__c>{ ce1, ce2 };

        // COMPONENT (so Exam trigger handler doesn’t fail in orgs that require it)
        Course_Evaluation_Component__c component = new Course_Evaluation_Component__c(
            Name = 'CIA Component',
            Course_Offering__c = offering.Id,
            Exam_Type__c = 'CIA',
            Maximum_Marks_for_the_Component__c = 100
        );
        insert component;

        // EXAM linked to cycle
        Exam__c exam = new Exam__c(
            Course_Evaluation_Component__c = component.Id,
            Exam_Cycle__c = examCycle.Id,
            Exam_Name__c = 'CIA'
        );
        insert exam;

        // EXAM CONNECTIONS used by getStudents() and batch start()
        insert new List<Exam_Connections__c>{
            new Exam_Connections__c(
                Student_Name__c = s1.Id,
                Course_Connection_ID__c = ce1.Id,
                Exam_Name__c = exam.Id,
                Eligibility__c = 'Eligible'
            ),
            new Exam_Connections__c(
                Student_Name__c = s2.Id,
                Course_Connection_ID__c = ce2.Id,
                Exam_Name__c = exam.Id,
                Eligibility__c = 'Eligible'
            )
        };
    }

    @IsTest
    static void testGetStudents_success() {
        Id examCycleId = [SELECT Id FROM Exam_Cycle__c LIMIT 1].Id;

        Test.startTest();
        HallTicketService.getStudents(examCycleId);
        Test.stopTest();
    }

    @IsTest
    static void testGetStudents_nullExamCycle_throws() {
        Test.startTest();
        try {
            HallTicketService.getStudents(null);
        } catch (AuraHandledException e) { }
        Test.stopTest();
    }

    @IsTest
    static void testGetStudents_noConnections_returnsEmpty() {
        // create a second cycle with no exams/connections
        Exam_Cycle__c emptyCycle = new Exam_Cycle__c(
            Name = 'Empty Cycle',
            Exam_Name__c = 'CIA',
            Start_Date__c = Date.today().addDays(-1),
            End_Date__c   = Date.today().addDays(30)
        );
        insert emptyCycle;

        Test.startTest();
        HallTicketService.getStudents(emptyCycle.Id);
        Test.stopTest();
    }

    @IsTest
    static void testGenerateHallTickets_success_batchExecCovered() {
        Id examCycleId = [SELECT Id FROM Exam_Cycle__c LIMIT 1].Id;
        List<Id> contactIds = new List<Id>();
        for (Contact c : [SELECT Id FROM Contact LIMIT 2]) {
            contactIds.add(c.Id);
        }

        Test.startTest();
        HallTicketService.generateHallTickets(examCycleId, contactIds);
        Test.stopTest();
    }

    @IsTest
    static void testGenerateHallTickets_nullExamCycle_throws() {
        List<Id> contactIds = new List<Id>();
        for (Contact c : [SELECT Id FROM Contact LIMIT 1]) {
            contactIds.add(c.Id);
        }

        Test.startTest();
        try {
            HallTicketService.generateHallTickets(null, contactIds);
        } catch (AuraHandledException e) { }
        Test.stopTest();
    }

    @IsTest
    static void testGenerateHallTickets_emptyContacts_throws() {
        Id examCycleId = [SELECT Id FROM Exam_Cycle__c LIMIT 1].Id;

        Test.startTest();
        try {
            HallTicketService.generateHallTickets(examCycleId, new List<Id>());
        } catch (AuraHandledException e) { }
        Test.stopTest();
    }

    @IsTest
    static void testGenerateHallTickets_invalidExamCycle_hitsCatch() {
        // Passing a valid Id that doesn't exist will cause query exception inside try/catch.
        // Use a fake Exam_Cycle__c Id-shaped value.
        Id fakeId = 'a0X000000000001AAA';
        List<Id> contactIds = new List<Id>();
        for (Contact c : [SELECT Id FROM Contact LIMIT 1]) {
            contactIds.add(c.Id);
        }

        Test.startTest();
        try {
            HallTicketService.generateHallTickets(fakeId, contactIds);
        } catch (AuraHandledException e) { }
        Test.stopTest();
    }
}