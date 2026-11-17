@isTest
private class ExamReportCenterControllerTest {

    @TestSetup
    static void setup() {
        Id academicProgramRtId = [
            SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND Name = 'Academic Program' LIMIT 1
        ].Id;

        Account program = new Account(Name = 'MBA', RecordTypeId = academicProgramRtId);
        insert program;

        hed__Program_Plan__c plan = new hed__Program_Plan__c(
            Name = '2025-JUL-MBA', hed__Account__c = program.Id
        );
        insert plan;

        hed__Term__c term = new hed__Term__c(
            Name = '2025-JUL-MBA-Sem 1-Online',
            hed__Account__c = program.Id,
            Term_Reference__c = 'Semester 1',
            Program_Plan__c = plan.Id
        );
        insert term;

        Contact student = new Contact(FirstName = 'Test', LastName = 'Student');
        insert student;

        hed__Affiliation__c affiliation = new hed__Affiliation__c(
            hed__Contact__c = student.Id,
            Roll_Number__c = 'DSUOE251MBA0004',
            Student_Name__c = 'Test Student'
        );
        insert affiliation;

        hed__Program_Enrollment__c pe = new hed__Program_Enrollment__c(
            hed__Contact__c = student.Id,
            hed__Account__c = program.Id,
            hed__Program_Plan__c = plan.Id,
            hed__Affiliation__c = affiliation.Id,
            Term__c = term.Id,
            SGPA__c = 8.5
        );
        insert pe;

        Account courseProvider = new Account(Name = 'MBA Department');
        insert courseProvider;

        hed__Course__c course = new hed__Course__c(
            Name = 'Marketing Management',
            hed__Account__c = courseProvider.Id,
            hed__Course_ID__c = 'MBAOL101'
        );
        insert course;

        hed__Course_Offering__c offering = new hed__Course_Offering__c(
            Name = 'MBAOL101 Offering',
            hed__Course__c = course.Id,
            hed__Term__c = term.Id
        );
        insert offering;

        hed__Course_Enrollment__c ce = new hed__Course_Enrollment__c(
            hed__Contact__c = student.Id,
            hed__Course_Offering__c = offering.Id,
            hed__Program_Enrollment__c = pe.Id,
            Component_Final_Score__c = 81,
            Letter_Grade__c = 'A+',
            Grade_Point__c = 9,
            Exam_Result_Status__c = 'Pass'
        );
        insert ce;

        Exam_Cycle__c cycle = new Exam_Cycle__c(Name = 'Sem 1 Cycle', Term__c = term.Id, Exam_Type__c = 'End Term');
        insert cycle;
    }

    @isTest
    static void testProgramProgramPlanAndSemesterCascade() {
        Test.startTest();
        List<ExamReportCenterController.Option> programs = ExamReportCenterController.getAcademicProgramOptions();
        Test.stopTest();

        System.assert(!programs.isEmpty(), 'Expected at least one Academic Program option.');

        List<ExamReportCenterController.Option> plans =
            ExamReportCenterController.getProgramPlanOptions(programs[0].value);
        System.assert(!plans.isEmpty(), 'Expected at least one Program Plan option for the selected Program.');

        List<ExamReportCenterController.Option> semesters =
            ExamReportCenterController.getSemesterOptions(plans[0].value);
        System.assert(!semesters.isEmpty(), 'Expected at least one Semester option for the selected Program Plan.');
        System.assertEquals('2025-JUL-MBA-Sem 1-Online', semesters[0].label,
            'Semester option should show the Term Name — not Term_Reference__c or the Parent Term name.');
    }

    @isTest
    static void testProgramPlanAndSemesterOptionsBlankInputs() {
        System.assert(ExamReportCenterController.getProgramPlanOptions(null).isEmpty(),
            'Blank Program should return no Program Plan options.');
        System.assert(ExamReportCenterController.getSemesterOptions(null).isEmpty(),
            'Blank Program Plan should return no Semester options.');
    }

    @isTest
    static void testStudentResultReportRequiresProgramPlanAndTerm() {
        Boolean threw = false;
        try {
            ExamReportCenterController.getStudentResultReport(null, null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'Expected an AuraHandledException when Program Plan/Semester are blank.');
    }

    @isTest
    static void testStudentResultReportAndDashboard() {
        hed__Term__c term = [SELECT Id FROM hed__Term__c WHERE Term_Reference__c = 'Semester 1' LIMIT 1];
        hed__Program_Plan__c plan = [SELECT Id FROM hed__Program_Plan__c LIMIT 1];

        Test.startTest();
        ExamReportCenterController.StudentResultReport report =
            ExamReportCenterController.getStudentResultReport(plan.Id, term.Id);
        ExamReportCenterController.DashboardData dashboard =
            ExamReportCenterController.getDashboardSummary(plan.Id, term.Id);
        Test.stopTest();

        System.assertEquals(1, report.rows.size(), 'Expected one student row.');
        System.assertEquals(1, report.courseCodes.size(), 'Expected one course column.');
        System.assertEquals('MBAOL101', report.courseCodes[0]);
        System.assertEquals('DSUOE251MBA0004', report.rows[0].usn);
        System.assertEquals('Test Student', report.rows[0].studentName);
        System.assertEquals(81, Decimal.valueOf(report.rows[0].cells[0].total), 'Total Marks should reflect Component_Final_Score__c.');
        System.assertEquals('A+', report.rows[0].cells[0].grade);

        System.assertEquals(1, dashboard.totalStudents);
        System.assertEquals(1, dashboard.totalResults);
        System.assertEquals(1, dashboard.passCount);
    }

    @isTest
    static void testDashboardWithNoScope() {
        ExamReportCenterController.DashboardData dashboard = ExamReportCenterController.getDashboardSummary(null, null);
        System.assertNotEquals(null, dashboard);
    }
}