@IsTest
public class ExamEligibilityHandlerTest {

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

        // EXAM CYCLE
        // Is_Active__c is FORMULA in your org, so set Start/End dates to make it TRUE.
        // Exam_Name__c must match the Course_Evaluation_Component__c's Exam_Type__c below ('SEE'):
        // ExamTriggerHandler looks up the Exam Cycle by the key Term|Exam_Cycle__r.Exam_Name__c.
        Exam_Cycle__c examCycle = new Exam_Cycle__c(
            Name = 'SEE Exam Cycle',
            Exam_Name__c = 'SEE',
            Start_Date__c = Date.today().addDays(-1),
            End_Date__c   = Date.today().addDays(30)
        );
        insert examCycle;

        // EXAM CYCLE TERM CONNECTION
        // Must exist BEFORE the Course_Evaluation_Component__c below is inserted: its AFTER
        // INSERT trigger (CourseEvaluationComponentHandler) auto-creates an Exam__c for SEE
        // components and validates this connection exists for the component's Term/Exam Type.
        Exam_Cycle_Term_Connection__c ectc = new Exam_Cycle_Term_Connection__c(
            Term__c = term.Id,
            Exam_Cycle__c = examCycle.Id
        );
        insert ectc;

        // COURSE EVALUATION COMPONENT (REQUIRED fields)
        // SEE, not CIA: this component gets a real Exam__c below, and
        // ExamEligibilityHandler now only creates Exam_Connections__c for
        // components where Exam_Required__c = true (CIA never needs one).
        Course_Evaluation_Component__c component = new Course_Evaluation_Component__c(
            Name = 'SEE Component',
            Course_Offering__c = offering.Id,
            Exam_Type__c = 'SEE',                       // must be valid picklist value
            Exam_Required__c = true,
            Maximum_Marks_for_the_Component__c = 100
        );
        insert component;

        // EXAM (Exam_Cycle__c auto-derived by ExamTriggerHandler)
        Exam__c exam = new Exam__c(
            Course_Evaluation_Component__c = component.Id
        );
        insert exam;
    }

    // Helper: choose a non-failing grade value from picklist (not F/IC).
    private static String getPassingLetterGrade() {
        List<Schema.PicklistEntry> entries = hed__Course_Enrollment__c.Letter_Grade__c
            .getDescribe()
            .getPicklistValues();

        for (Schema.PicklistEntry entry : entries) {
            if (!entry.isActive()) continue;
            String val = entry.getValue();
            if (val == null) continue;
            String normalized = val.trim().toUpperCase();
            if (normalized != 'F' && normalized != 'IC') {
                return val;
            }
        }

        // Defensive fallback in case metadata is very restricted.
        return null;
    }

    // Helper: create a Course Enrollment
    private static hed__Course_Enrollment__c createEnrollment(Decimal score, String letterGrade) {
        Contact student = [SELECT Id FROM Contact LIMIT 1];
        hed__Course_Offering__c offering = [SELECT Id FROM hed__Course_Offering__c LIMIT 1];

        hed__Course_Enrollment__c ce = new hed__Course_Enrollment__c(
            hed__Contact__c = student.Id,
            hed__Course_Offering__c = offering.Id,
            Enrollment_Status__c = 'Enrolled',
            Exam_Eligibility__c = 'Eligible',
            Component_Final_Score__c = score,
            Letter_Grade__c = letterGrade
        );
        insert ce;
        return ce;
    }

    @IsTest
    static void testCreditsAttemptedOnInsert() {
        Contact student = [SELECT Id FROM Contact LIMIT 1];
        hed__Course_Offering__c offering = [SELECT Id FROM hed__Course_Offering__c LIMIT 1];

        hed__Course_Enrollment__c ce = new hed__Course_Enrollment__c(
            hed__Contact__c = student.Id,
            hed__Course_Offering__c = offering.Id,
            Enrollment_Status__c = 'Enrolled',
            Exam_Eligibility__c = 'Eligible'
        );

        Test.startTest();
        insert ce;
        Test.stopTest();

        ce = [
            SELECT hed__Credits_Attempted__c
            FROM hed__Course_Enrollment__c
            WHERE Id = :ce.Id
        ];

        System.assertEquals(
            4,
            ce.hed__Credits_Attempted__c,
            'Credits Attempted should be pulled from Course.Credits__c'
        );
    }

    @IsTest
    static void testCreditsEarnedWhenGradeIsNotFailing() {
        String passingGrade = getPassingLetterGrade();
        System.assertNotEquals(
            null,
            passingGrade,
            'Need at least one active non-failing Letter_Grade__c value for this test.'
        );

        hed__Course_Enrollment__c ce;

        Test.startTest();
        ce = createEnrollment(80, passingGrade);
        Test.stopTest();

        ce = [
            SELECT hed__Credits_Attempted__c, hed__Credits_Earned__c, Final_Grade__c
            FROM hed__Course_Enrollment__c
            WHERE Id = :ce.Id
        ];

        // Rule: if Final Grade is not F/IC, earned credits = attempted credits.
        System.assertEquals(
            ce.hed__Credits_Attempted__c,
            ce.hed__Credits_Earned__c,
            'Credits Earned should equal Credits Attempted when Final Grade is not F/IC'
        );
    }

    @IsTest
    static void testCreditsEarnedIsZeroForFailingGradeF() {
        hed__Course_Enrollment__c ce;

        Test.startTest();
        ce = createEnrollment(80, 'F');
        Test.stopTest();

        ce = [
            SELECT hed__Credits_Earned__c, Final_Grade__c
            FROM hed__Course_Enrollment__c
            WHERE Id = :ce.Id
        ];

        System.assertEquals(
            'F',
            ce.Final_Grade__c,
            'Final grade should resolve to F for this scenario.'
        );
        System.assertEquals(
            0,
            ce.hed__Credits_Earned__c,
            'Credits Earned must be 0 when Final Grade is F'
        );
    }

    @IsTest
    static void testCreditsEarnedRecalculationWhenGradeChanges() {
        String passingGrade = getPassingLetterGrade();
        System.assertNotEquals(
            null,
            passingGrade,
            'Need at least one active non-failing Letter_Grade__c value for this test.'
        );

        hed__Course_Enrollment__c ce = createEnrollment(80, passingGrade);

        Test.startTest();
        ce.Letter_Grade__c = 'F';
        update ce;
        Test.stopTest();

        ce = [
            SELECT hed__Credits_Earned__c, Final_Grade__c
            FROM hed__Course_Enrollment__c
            WHERE Id = :ce.Id
        ];

        System.assertEquals(
            'F',
            ce.Final_Grade__c,
            'Final grade should be F after update.'
        );
        System.assertEquals(
            0,
            ce.hed__Credits_Earned__c,
            'Credits Earned should recalculate to 0 when grade changes to F'
        );
    }

    @IsTest
    static void testExamConnectionEligibilityFlow() {
        // Create CE initially eligible
        hed__Course_Enrollment__c ce = createEnrollment(null, null);

        Test.startTest();

        // 1) Flip to Not Eligible
        ce.Exam_Eligibility__c = 'Non-Eligible';
        update ce;

        // 2) Flip back to Eligible + Enrolled
        ce.Exam_Eligibility__c = 'Eligible';
        ce.Enrollment_Status__c = 'Enrolled';
        update ce;

        Test.stopTest();

        // Validate connections exist + are Eligible after final update
        List<Exam_Connections__c> connections = [
            SELECT Eligibility__c
            FROM Exam_Connections__c
            WHERE Course_Connection_ID__c = :ce.Id
        ];

        System.assert(
            connections.size() > 0,
            'Exam Connections should be created for eligible enrollments'
        );

        for (Exam_Connections__c ec : connections) {
            System.assertEquals(
                'Eligible',
                ec.Eligibility__c,
                'Exam Connections should be Eligible'
            );
        }
    }

    @IsTest
    static void testCiaComponentDoesNotGetExamConnection() {
        hed__Course_Offering__c offering = [SELECT Id FROM hed__Course_Offering__c LIMIT 1];
        Course_Evaluation_Component__c seeComponent = [
            SELECT Id FROM Course_Evaluation_Component__c WHERE Exam_Type__c = 'SEE' LIMIT 1
        ];

        // CIA never needs an exam - handleEligible must skip it, not create a blank connection.
        Course_Evaluation_Component__c ciaComponent = new Course_Evaluation_Component__c(
            Name = 'CIA Component',
            Course_Offering__c = offering.Id,
            Exam_Type__c = 'CIA',
            Exam_Required__c = false,
            Maximum_Marks_for_the_Component__c = 100
        );
        insert ciaComponent;

        hed__Course_Enrollment__c ce = createEnrollment(null, null);

        Test.startTest();
        ce.Exam_Eligibility__c = 'Non-Eligible';
        update ce;
        ce.Exam_Eligibility__c = 'Eligible';
        ce.Enrollment_Status__c = 'Enrolled';
        update ce;
        Test.stopTest();

        List<Exam_Connections__c> connections = [
            SELECT Course_Evaluation_Component__c
            FROM Exam_Connections__c
            WHERE Course_Connection_ID__c = :ce.Id
        ];

        System.assertEquals(
            1,
            connections.size(),
            'Only the SEE component should get an Exam_Connections__c; CIA must be skipped.'
        );
        System.assertEquals(
            seeComponent.Id,
            connections[0].Course_Evaluation_Component__c,
            'The single connection created must be for the SEE component, not CIA.'
        );
    }
}