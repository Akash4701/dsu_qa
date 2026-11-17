@IsTest
public with sharing class CalculateCgpaControllerTest {

    @TestSetup
    static void setupData() {

        // ==============================
        // Base data (from your reference)
        // ==============================

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
        Course_Evaluation_Component__c component = new Course_Evaluation_Component__c(
            Name = 'CIA Component',
            Course_Offering__c = offering.Id,
            Exam_Type__c = 'CIA',                       // must be valid picklist value
            Maximum_Marks_for_the_Component__c = 100
        );
        insert component;

        // EXAM CYCLE
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
        Exam__c exam = new Exam__c(
            Course_Evaluation_Component__c = component.Id
        );
        insert exam;

        // ==========================================
        // Additional data required for this controller
        // ==========================================

        // PROGRAM PLAN (the controller receives this Id)
        // NOTE: this assumes hed__Program_Plan__c exists in your org (common in EDA).
        hed__Program_Plan__c programPlan = new hed__Program_Plan__c(
            Name = 'Test Program Plan'
        );
        insert programPlan;

        // AFFILIATION linked to Program Plan
        // NOTE: hed__Affiliation__c typically requires Contact + Account in many orgs.
        // Also Program_Plan__c is your custom lookup used by the controller.
        hed__Affiliation__c aff = new hed__Affiliation__c(
            hed__Contact__c = student.Id,
            hed__Account__c = dept.Id,
            Program_Plan__c = programPlan.Id
        );
        insert aff;

        // PROGRAM ENROLLMENT linked to Affiliation (so CE can reach it via relationship)
        // NOTE: required fields vary by org. These are common EDA fields.
        hed__Program_Enrollment__c pe = new hed__Program_Enrollment__c(
         //   Name = 'Test Program Enrollment',
            hed__Contact__c = student.Id,
            hed__Account__c = dept.Id,
            Term__c = term.Id,
            hed__Affiliation__c = aff.Id
        );
        insert pe;

        // 2 Course Enrollments -> total credits = 4 + 4 = 8
        // total points secured = 64 => CGPA = 64/8 = 8.00
        
        hed__Course_Enrollment__c ce1 = new hed__Course_Enrollment__c(
            hed__Course_Offering__c = offering.Id,
            hed__Program_Enrollment__c = pe.Id,
            Grade_Point__c = 8,
            Letter_Grade__c = 'A' // must be a valid picklist value in your org and not F/IC
        );

        hed__Course_Enrollment__c ce2 = new hed__Course_Enrollment__c(
            hed__Course_Offering__c = offering.Id,
            hed__Program_Enrollment__c = pe.Id,
            Grade_Point__c = 8,
            Letter_Grade__c = 'A'
        );

        insert new List<hed__Course_Enrollment__c>{ ce1, ce2 };

        // Another Program Plan where affiliation exists but points secured are null/0 -> should SKIP update
        hed__Program_Plan__c programPlanNoPoints = new hed__Program_Plan__c(
            Name = 'Test Program Plan - No Points'
        );
        insert programPlanNoPoints;

        hed__Affiliation__c affNoPoints = new hed__Affiliation__c(
            hed__Contact__c = student.Id,
            hed__Account__c = dept.Id,
            Program_Plan__c = programPlanNoPoints.Id
        );
        insert affNoPoints;

        hed__Program_Enrollment__c peNoPoints = new hed__Program_Enrollment__c(
           // Name = 'Test Program Enrollment - No Points',
            hed__Contact__c = student.Id,
            hed__Account__c = dept.Id,
            Term__c = term.Id,
            hed__Affiliation__c = affNoPoints.Id
        );
        insert peNoPoints;

        // Points_Secured__c null => controller should not update CGPA__c
        hed__Course_Enrollment__c ceNoPoints = new hed__Course_Enrollment__c(
            hed__Course_Offering__c = offering.Id,
            hed__Program_Enrollment__c = peNoPoints.Id,
            Grade_Point__c = 0,
            Letter_Grade__c = 'F'
        );
        insert ceNoPoints;

        // A Program Plan with NO affiliations at all (for "early return" path)
        hed__Program_Plan__c programPlanNoAff = new hed__Program_Plan__c(
            Name = 'Test Program Plan - No Affiliations'
        );
        insert programPlanNoAff;
    }

    @IsTest
    static void testCalculateCgpa_updatesCgpaWhenValidData() {
        Id programPlanId = [
            SELECT Id
            FROM hed__Program_Plan__c
            WHERE Name = 'Test Program Plan'
            LIMIT 1
        ].Id;

        // Pre-assert (CGPA should be null before calculation)
        hed__Affiliation__c affBefore = [
            SELECT Id, CGPA__c
            FROM hed__Affiliation__c
            WHERE Program_Plan__c = :programPlanId
            LIMIT 1
        ];
        System.assertEquals(null, affBefore.CGPA__c, 'CGPA should start as null in test data');

        Test.startTest();
        CalculateCgpaController.calculateCgpaForProgramPlan(programPlanId);
        Test.stopTest();

        // Post-assert (expect 8.00)
        hed__Affiliation__c affAfter = [
            SELECT Id, CGPA__c
            FROM hed__Affiliation__c
            WHERE Id = :affBefore.Id
            LIMIT 1
        ];
        System.assertEquals(8.00, affAfter.CGPA__c, 'CGPA should be calculated as 8.00');
    }

    @IsTest
    static void testCalculateCgpa_skipsUpdateWhenNoPointsOrNoCredits() {
        Id programPlanId = [
            SELECT Id
            FROM hed__Program_Plan__c
            WHERE Name = 'Test Program Plan - No Points'
            LIMIT 1
        ].Id;

        hed__Affiliation__c affBefore = [
            SELECT Id, CGPA__c
            FROM hed__Affiliation__c
            WHERE Program_Plan__c = :programPlanId
            LIMIT 1
        ];

        Test.startTest();
        CalculateCgpaController.calculateCgpaForProgramPlan(programPlanId);
        Test.stopTest();

        hed__Affiliation__c affAfter = [
            SELECT Id, CGPA__c
            FROM hed__Affiliation__c
            WHERE Id = :affBefore.Id
            LIMIT 1
        ];

        // Should remain null because Points_Secured__c was null (and controller checks totalPointsSecured > 0)
        System.assertEquals(null, affAfter.CGPA__c, 'CGPA should not be set when points are not available');
    }

    @IsTest
    static void testCalculateCgpa_returnsGracefullyWhenNoAffiliations() {
        Id programPlanId = [
            SELECT Id
            FROM hed__Program_Plan__c
            WHERE Name = 'Test Program Plan - No Affiliations'
            LIMIT 1
        ].Id;

        Test.startTest();
        // Should not throw; should just return
        CalculateCgpaController.calculateCgpaForProgramPlan(programPlanId);
        Test.stopTest();

        // If we got here, it handled the empty affiliation case gracefully.
        System.assert(true, 'Method should return without exception when no affiliations exist');
    }
}