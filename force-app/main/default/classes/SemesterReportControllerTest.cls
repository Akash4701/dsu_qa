@IsTest
private class SemesterReportControllerTest {

    private static Account testAccount;
    private static hed__Program_Plan__c testPlan;
    private static hed__Term__c semester1;
    private static hed__Term__c semester2;
    private static List<hed__Course_Offering__c> offerings;

    @TestSetup
    static void setupTestData() {
        Account acc = new Account(
            Name = 'Test University'
        );
        insert acc;

        hed__Program_Plan__c plan = new hed__Program_Plan__c(
            Name = 'TEST-BBA-PLAN',
            hed__Account__c = acc.Id
        );
        insert plan;

        List<hed__Term__c> terms = new List<hed__Term__c>{
            new hed__Term__c(
                Name = 'Semester 1',
                Program_Plan__c = plan.Id,
                hed__Account__c = acc.Id,
                Term_Reference__c = 'Semester 1',
                Term_Number__c = 1
            ),
            new hed__Term__c(
                Name = 'Semester 2',
                Program_Plan__c = plan.Id,
                hed__Account__c = acc.Id,
                Term_Reference__c = 'Semester 2',
                Term_Number__c = 2
            )
        };
        insert terms;

        List<hed__Course__c> courses = new List<hed__Course__c>{
            new hed__Course__c(
                Name = 'Test Course 1',
                hed__Course_ID__c = 'TC001',
                hed__Account__c = acc.Id
            ),
            new hed__Course__c(
                Name = 'Test Course 2',
                hed__Course_ID__c = 'TC002',
                hed__Account__c = acc.Id
            ),
            new hed__Course__c(
                Name = 'Test Course 3',
                hed__Course_ID__c = 'TC003',
                hed__Account__c = acc.Id
            )
        };
        insert courses;

        List<hed__Course_Offering__c> courseOfferings =
    new List<hed__Course_Offering__c>{
        new hed__Course_Offering__c(
            Name = 'Offering 1',
            hed__Term__c = terms[0].Id,
            hed__Course__c = courses[0].Id
        ),
        new hed__Course_Offering__c(
            Name = 'Offering 2',
            hed__Term__c = terms[0].Id,
            hed__Course__c = courses[1].Id
        ),
        new hed__Course_Offering__c(
            Name = 'Offering 3',
            hed__Term__c = terms[1].Id,
            hed__Course__c = courses[2].Id
        )
    };

insert courseOfferings;

        List<hed__Course_Enrollment__c> enrollments =
            new List<hed__Course_Enrollment__c>{
                // Course 1: override grade O
                new hed__Course_Enrollment__c(
                    hed__Course_Offering__c = courseOfferings[0].Id,
                    Letter_Grade__c = 'A',
                    Override_Grade__c = 'O'
                ),

                // Course 1: grade A
                new hed__Course_Enrollment__c(
                    hed__Course_Offering__c = courseOfferings[0].Id,
                    Letter_Grade__c = 'A'
                ),

                // Course 1: override grade F
                new hed__Course_Enrollment__c(
                    hed__Course_Offering__c = courseOfferings[0].Id,
                    Letter_Grade__c = 'P',
                    Override_Grade__c = 'F'
                ),

                // Course 2: override grade B+
                new hed__Course_Enrollment__c(
                    hed__Course_Offering__c = courseOfferings[1].Id,
                    Letter_Grade__c = 'A',
                    Override_Grade__c = 'B+'
                ),

                // Course 3: grade C
                new hed__Course_Enrollment__c(
                    hed__Course_Offering__c = courseOfferings[2].Id,
                    Letter_Grade__c = 'C'
                ),

                // Course 3: grade IC
                new hed__Course_Enrollment__c(
                    hed__Course_Offering__c = courseOfferings[2].Id,
                    Letter_Grade__c = 'IC'
                )
            };

        insert enrollments;
    }

    @IsTest
    static void testGetProgramPlans() {
        Test.startTest();
        List<SemesterReportController.ProgramPlanOption> results =
            SemesterReportController.getProgramPlans();
        Test.stopTest();

        System.assertNotEquals(null, results);
        System.assert(!results.isEmpty(), 'Expected a program plan.');

        Boolean foundPlan = false;
        for (SemesterReportController.ProgramPlanOption option : results) {
            if (option.name == 'TEST-BBA-PLAN') {
                foundPlan = true;
                break;
            }
        }

        System.assertEquals(true, foundPlan);
    }

    @IsTest
    static void testGradeCountsAndPercentage() {
        hed__Program_Plan__c plan = [
            SELECT Id
            FROM hed__Program_Plan__c
            WHERE Name = 'TEST-BBA-PLAN'
            LIMIT 1
        ];

        Test.startTest();
        SemesterReportController.SemesterReport report =
            SemesterReportController.getSemesterSubjectReport(
                String.valueOf(plan.Id)
            );
        Test.stopTest();

        System.assertNotEquals(null, report);
        System.assertEquals('TEST-BBA-PLAN', report.programPlanName);
        System.assertEquals(2, report.totalSemesters);
        System.assertEquals(2, report.semesters.size());

        SemesterReportController.SemesterReportSection firstSemester =
            report.semesters[0];

        System.assertEquals('Semester 1', firstSemester.semesterName);
        System.assertEquals(2, firstSemester.totalCourses);

        SemesterReportController.CourseReportRow firstCourse =
            firstSemester.courses[0];

        System.assertEquals(1, firstCourse.gradeO);
        System.assertEquals(1, firstCourse.gradeA);
        System.assertEquals(1, firstCourse.gradeF);
        System.assertEquals(3, firstCourse.appeared);
        System.assertEquals(2, firstCourse.passed);
        System.assertEquals(
            Decimal.valueOf('66.67'),
            firstCourse.percentage
        );

        SemesterReportController.CourseReportRow secondCourse =
            firstSemester.courses[1];

        System.assertEquals(1, secondCourse.gradeBPlus);
        System.assertEquals(1, secondCourse.appeared);
        System.assertEquals(1, secondCourse.passed);
        System.assertEquals(
            Decimal.valueOf('100.00'),
            secondCourse.percentage
        );

        SemesterReportController.SemesterReportSection secondSemester =
            report.semesters[1];

        System.assertEquals('Semester 2', secondSemester.semesterName);
        System.assertEquals(1, secondSemester.totalCourses);

        SemesterReportController.CourseReportRow thirdCourse =
            secondSemester.courses[0];

        System.assertEquals(1, thirdCourse.gradeC);
        System.assertEquals(1, thirdCourse.appeared);
        System.assertEquals(1, thirdCourse.passed);
        System.assertEquals(
            Decimal.valueOf('100.00'),
            thirdCourse.percentage
        );
    }

    @IsTest
    static void testBlankProgramPlanId() {
        try {
            SemesterReportController.getSemesterSubjectReport('');
            System.assert(false, 'Expected an exception for a blank ID.');
        } catch (Exception ex) {
            System.assert(
                ex.getMessage().contains('Please select a Program Plan.')
                || ex instanceof AuraHandledException
            );
        }
    }

    @IsTest
    static void testInvalidProgramPlanId() {
        try {
            SemesterReportController.getSemesterSubjectReport('invalid-id');
            System.assert(false, 'Expected an exception for an invalid ID.');
        } catch (Exception ex) {
            System.assert(
                ex instanceof AuraHandledException
                || ex.getMessage() != null
            );
        }
    }

    @IsTest
    static void testWrongObjectId() {
        Account acc = [
            SELECT Id
            FROM Account
            WHERE Name = 'Test University'
            LIMIT 1
        ];

        try {
            SemesterReportController.getSemesterSubjectReport(
                String.valueOf(acc.Id)
            );
            System.assert(
                false,
                'Expected an exception when an Account ID is supplied.'
            );
        } catch (Exception ex) {
            System.assert(ex instanceof AuraHandledException);
        }
    }
}