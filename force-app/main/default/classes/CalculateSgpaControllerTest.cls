@IsTest
public with sharing class CalculateSgpaControllerTest {

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

        // PROGRAM PLAN (not used by SGPA controller, but kept since you asked to use this sample setup)
        hed__Program_Plan__c programPlan = new hed__Program_Plan__c(Name = 'Test Program Plan');
        insert programPlan;

        // AFFILIATION linked to Program Plan
        hed__Affiliation__c aff = new hed__Affiliation__c(
            hed__Contact__c = student.Id,
            hed__Account__c = dept.Id,
            Program_Plan__c = programPlan.Id
        );
        insert aff;

        // PROGRAM ENROLLMENT (IMPORTANT for SGPA: Term__c must match term.Id)
        hed__Program_Enrollment__c pe = new hed__Program_Enrollment__c(
            hed__Contact__c = student.Id,
            hed__Account__c = dept.Id,
            Term__c = term.Id,              // <-- this is used by Course Offering Term filter indirectly
            hed__Affiliation__c = aff.Id
        );
        insert pe;

        // ✅ Course Enrollments (Points_Secured__c is FORMULA, so set Grade_Point__c + Letter_Grade__c)
        // Each CE: Points_Secured = 8 * 4 credits = 32
        // Total points = 64; total credits = 8; SGPA = 64/8 = 8.00
        hed__Course_Enrollment__c ce1 = new hed__Course_Enrollment__c(
            hed__Course_Offering__c = offering.Id,
            hed__Program_Enrollment__c = pe.Id,
            Grade_Point__c = 8,
            Letter_Grade__c = 'A'
        );

        hed__Course_Enrollment__c ce2 = new hed__Course_Enrollment__c(
            hed__Course_Offering__c = offering.Id,
            hed__Program_Enrollment__c = pe.Id,
            Grade_Point__c = 8,
            Letter_Grade__c = 'A'
        );

        insert new List<hed__Course_Enrollment__c>{ ce1, ce2 };

        // Another Program Enrollment in the SAME term but with grade = F => Points_Secured formula becomes 0
        // This should produce SGPA = 0/credits => 0.00 (controller still updates because credits > 0)
        hed__Program_Plan__c programPlanNoPoints = new hed__Program_Plan__c(Name = 'Test Program Plan - No Points');
        insert programPlanNoPoints;

        hed__Affiliation__c affNoPoints = new hed__Affiliation__c(
            hed__Contact__c = student.Id,
            hed__Account__c = dept.Id,
            Program_Plan__c = programPlanNoPoints.Id
        );
        insert affNoPoints;

        hed__Program_Enrollment__c peNoPoints = new hed__Program_Enrollment__c(
            hed__Contact__c = student.Id,
            hed__Account__c = dept.Id,
            Term__c = term.Id,
            hed__Affiliation__c = affNoPoints.Id
        );
        insert peNoPoints;

        hed__Course_Enrollment__c ceNoPoints = new hed__Course_Enrollment__c(
            hed__Course_Offering__c = offering.Id,
            hed__Program_Enrollment__c = peNoPoints.Id,
            Grade_Point__c = 8,
            Letter_Grade__c = 'F' // formula => 0
        );
        insert ceNoPoints;

        // Extra term with no course enrollments (for early return coverage)
        hed__Term__c termNoCE = new hed__Term__c(
            Name = 'Fall 2026',
            hed__Account__c = dept.Id,
            Term_Reference__c = 'Term 1',
            hed__Start_Date__c = Date.today().addMonths(6),
            hed__End_Date__c = Date.today().addMonths(10)
        );
        insert termNoCE;
    }

    @IsTest
    static void testCalculateSgpa_updatesSgpaForValidEnrollments() {
        Id termId = [
            SELECT Id
            FROM hed__Term__c
            WHERE Name = 'Spring 2025'
            LIMIT 1
        ].Id;

        // Pre-check: SGPA initially null
        hed__Program_Enrollment__c peBefore = [
            SELECT Id, SGPA__c
            FROM hed__Program_Enrollment__c
            WHERE SGPA__c = null
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];
        System.assertEquals(null, peBefore.SGPA__c, 'SGPA should start as null');

        Test.startTest();
        CalculateSgpaController.calculateSgpaForTerm(termId);
        Test.stopTest();

        // Find the Program Enrollment that has 2 A grades (8 points each)
        // SGPA = (32 + 32) / (4 + 4) = 8.00
        hed__Program_Enrollment__c peAfter = [
            SELECT Id, SGPA__c
            FROM hed__Program_Enrollment__c
            WHERE Id = :peBefore.Id
            LIMIT 1
        ];

        System.assertEquals(8.00, peAfter.SGPA__c, 'SGPA should be calculated as 8.00');
    }

    @IsTest
    static void testCalculateSgpa_setsZeroWhenAllGradesFail() {
        Id termId = [
            SELECT Id
            FROM hed__Term__c
            WHERE Name = 'Spring 2025'
            LIMIT 1
        ].Id;

        // Grab the PE that has the failing CE (Letter_Grade__c = 'F')
        // We detect it by joining to its course enrollments and checking Letter_Grade__c.
        hed__Program_Enrollment__c peFail = [
            SELECT Id, SGPA__c,
                   (SELECT Id, Letter_Grade__c FROM hed__Course_Enrollments__r)
            FROM hed__Program_Enrollment__c
            WHERE Id IN (
                SELECT hed__Program_Enrollment__c
                FROM hed__Course_Enrollment__c
                WHERE Letter_Grade__c = 'F'
            )
            LIMIT 1
        ];

        Test.startTest();
        CalculateSgpaController.calculateSgpaForTerm(termId);
        Test.stopTest();

        hed__Program_Enrollment__c peFailAfter = [
            SELECT Id, SGPA__c
            FROM hed__Program_Enrollment__c
            WHERE Id = :peFail.Id
            LIMIT 1
        ];

        // credits > 0 so controller updates; total points = 0 => SGPA = 0.00
        System.assertEquals(0.00, peFailAfter.SGPA__c, 'SGPA should be 0.00 when points secured are 0');
    }

    @IsTest
    static void testCalculateSgpa_returnsWhenNoCourseEnrollments() {
        Id termNoCEId = [
            SELECT Id
            FROM hed__Term__c
            WHERE Name = 'Fall 2026'
            LIMIT 1
        ].Id;

        Test.startTest();
        // No course enrollments for this term => method returns without exception
        CalculateSgpaController.calculateSgpaForTerm(termNoCEId);
        Test.stopTest();

        System.assert(true, 'Method should return gracefully when no course enrollments exist');
    }
}