/**
 * AdmissionReportsControllerTest
 * ──────────────────────────────
 * Covers the three Admission Reports end to end against a small, fully-known cohort,
 * so every count in the assertions can be checked by hand against the setup below.
 *
 * DSU records gender on `GenderIdentity` and social category on `Student_Category__c`,
 * but neither field exists in every DSU org — DSU Dev has neither. So the setup writes
 * whichever of them the org actually has (picking a real, active picklist value out of
 * the field's own describe rather than assuming one) and the assertions that depend on
 * them adapt, rather than hard-failing the whole suite in an org that has not been given
 * the field yet. The counts themselves are asserted strictly in every case, because
 * `hed__Gender__c` is always populated as the fallback the controller would land on.
 */
@isTest
private class AdmissionReportsControllerTest {

    private static final String ACADEMIC_YEAR = '2025-2026';

    /** The category field this org actually has, or null — see the class header. */
    private static String categoryFieldInOrg() {
        Map<String, Schema.SObjectField> f = Schema.SObjectType.Contact.fields.getMap();
        // Only these two are safe to write a raw 'SC' / 'General' into: the others are a
        // restricted picklist whose values differ per org.
        for (String candidate : new List<String>{ 'Student_Category__c', 'Caste__c' }) {
            if (f.containsKey(candidate.toLowerCase())) { return candidate; }
        }
        return null;
    }

    /**
     * An active picklist value on Contact.<fieldName> that starts with `letter`, or null
     * if the field is absent or has no such value. GenderIdentity is a standard picklist
     * whose entries are configured per org, so the test reads a real value out of the
     * describe instead of assuming 'Male' / 'Female' and risking a DML failure on a
     * restricted picklist.
     */
    private static String activePicklistValue(String fieldName, String letter) {
        Map<String, Schema.SObjectField> f = Schema.SObjectType.Contact.fields.getMap();
        if (!f.containsKey(fieldName.toLowerCase())) { return null; }
        Schema.DescribeFieldResult dfr = f.get(fieldName.toLowerCase()).getDescribe();
        if (dfr.getType() != Schema.DisplayType.PICKLIST) { return null; }
        for (Schema.PicklistEntry entry : dfr.getPicklistValues()) {
            if (entry.isActive() && entry.getValue().toLowerCase().startsWith(letter)) {
                return entry.getValue();
            }
        }
        return null;
    }

    /**
     * The GenderIdentity value for a Male/Female student, or null when this org's
     * GenderIdentity cannot express both — filling only half of it would leave the other
     * half blank and quietly turn those students into the "Other" gender bucket.
     */
    private static String genderIdentityValue(String gender) {
        String male = activePicklistValue('GenderIdentity', 'm');
        String female = activePicklistValue('GenderIdentity', 'f');
        if (male == null || female == null) { return null; }
        return gender == 'Male' ? male : female;
    }

    /** The gender field the controller will land on, given what this org has and what the setup fills. */
    private static String expectedGenderField() {
        return genderIdentityValue('Male') != null ? 'GenderIdentity' : 'hed__Gender__c';
    }

    @TestSetup
    static void setup() {
        Id academicProgramRt = [
            SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND Name = 'Academic Program' LIMIT 1
        ].Id;
        Id departmentRt = [
            SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND Name = 'University Department' LIMIT 1
        ].Id;

        Account school = new Account(Name = 'Under Graduate', RecordTypeId = departmentRt);
        insert school;

        Account program = new Account(
            Name = 'Bachelor of Business Administration',
            RecordTypeId = academicProgramRt,
            ParentId = school.Id
        );
        insert program;

        hed__Program_Plan__c plan = new hed__Program_Plan__c(
            Name = '2025-JUL-BBA',
            hed__Account__c = program.Id,
            Academic_Year__c = ACADEMIC_YEAR,
            Intake_Number__c = 60
        );
        insert plan;

        hed__Term__c term = new hed__Term__c(
            Name = '2025-JUL-BBA-Sem 1-Online',
            hed__Account__c = program.Id,
            Term_Reference__c = 'Semester 1',
            Program_Plan__c = plan.Id
        );
        insert term;

        // ── Four applicants: Karnataka M, Karnataka F, Kerala M, and one with no state.
        String catField = categoryFieldInOrg();
        List<Contact> students = new List<Contact>{
            newStudent('Kiran', 'Male', 'Karnataka', catField, 'SC'),
            newStudent('Asha', 'Female', 'Karnataka', catField, 'General'),
            newStudent('Rahul', 'Male', 'Kerala', catField, 'General'),
            newStudent('Meera', 'Female', null, catField, null)
        };
        insert students;

        // External_Application_Number__c is required and unique on this object, so each
        // application needs its own value even though the reports never read it.
        List<Application__c> apps = new List<Application__c>();
        Integer seq = 0;
        for (Contact c : students) {
            apps.add(application(c.Id, program.Id, plan.Id, 'Admitted', 'TEST-APP-' + (++seq)));
        }
        // A fifth application that the default "Admitted & beyond" scope must exclude.
        apps.add(application(students[0].Id, program.Id, plan.Id, 'Application rejected', 'TEST-APP-' + (++seq)));
        insert apps;

        // ── Two courses in Semester 1, three students sitting them.
        Account courseProvider = new Account(Name = 'BBA Department');
        insert courseProvider;

        List<hed__Course__c> courses = new List<hed__Course__c>{
            new hed__Course__c(Name = 'English - 1', hed__Account__c = courseProvider.Id),
            new hed__Course__c(Name = 'Business Law', hed__Account__c = courseProvider.Id)
        };
        insert courses;

        List<hed__Course_Offering__c> offerings = new List<hed__Course_Offering__c>();
        for (hed__Course__c c : courses) {
            offerings.add(new hed__Course_Offering__c(
                Name = c.Name + ' Offering', hed__Course__c = c.Id, hed__Term__c = term.Id
            ));
        }
        insert offerings;

        // Kiran passes both, Asha passes one and fails one, Rahul has one still open.
        insert new List<hed__Course_Enrollment__c>{
            connection(students[0].Id, offerings[0].Id, 'Pass'),
            connection(students[0].Id, offerings[1].Id, 'Pass'),
            connection(students[1].Id, offerings[0].Id, 'Pass'),
            connection(students[1].Id, offerings[1].Id, 'Fail'),
            connection(students[2].Id, offerings[0].Id, 'Pass'),
            connection(students[2].Id, offerings[1].Id, 'In Complete')
        };
    }

    private static Contact newStudent(String firstName, String gender, String state, String catField, String category) {
        // hed__Gender__c is always set: it exists in every HEDA org and is the fallback
        // the controller lands on wherever GenderIdentity is absent or unusable.
        Contact c = new Contact(
            FirstName = firstName,
            LastName = 'Student',
            hed__Gender__c = gender,
            MailingState = state
        );
        String genderIdentity = genderIdentityValue(gender);
        if (genderIdentity != null) { c.put('GenderIdentity', genderIdentity); }
        if (catField != null && category != null) { c.put(catField, category); }
        return c;
    }

    private static Application__c application(
        Id contactId, Id programId, Id planId, String status, String externalNumber
    ) {
        return new Application__c(
            ContactId__c = contactId,
            AccountId__c = programId,
            Program_Plan__c = planId,
            Program_Level__c = 'UG',
            Status__c = status,
            External_Application_Number__c = externalNumber
        );
    }

    private static hed__Course_Enrollment__c connection(Id contactId, Id offeringId, String result) {
        return new hed__Course_Enrollment__c(
            hed__Contact__c = contactId,
            hed__Course_Offering__c = offeringId,
            Exam_Result_Status__c = result
        );
    }

    /** Index of a leaf column by its flat export label ("Karnataka - M"). */
    private static Integer columnIndex(AdmissionReportsController.ReportGrid grid, String label) {
        for (Integer i = 0; i < grid.columnLabels.size(); i++) {
            if (grid.columnLabels[i] == label) { return i; }
        }
        return -1;
    }

    private static String cell(AdmissionReportsController.ReportGrid grid, Integer rowIndex, String label) {
        Integer col = columnIndex(grid, label);
        System.assertNotEquals(-1, col,
            'Expected a "' + label + '" column. Columns: ' + String.join(grid.columnLabels, ', '));
        return grid.rows[rowIndex].cells[col];
    }

    // ═════════════════════════════════════════════════════════════════════════
    @isTest
    static void testFilterOptionCascade() {
        Test.startTest();
        List<AdmissionReportsController.Option> years = AdmissionReportsController.getAcademicYearOptions();
        List<AdmissionReportsController.Option> programs = AdmissionReportsController.getProgramOptions();
        Test.stopTest();

        System.assertEquals(1, years.size(), 'Expected the one Academic Year used by the test Program Plan.');
        System.assertEquals(ACADEMIC_YEAR, years[0].value);
        System.assert(!programs.isEmpty(), 'Expected at least one Academic Program option.');

        List<AdmissionReportsController.Option> plans =
            AdmissionReportsController.getProgramPlanOptions(programs[0].value, ACADEMIC_YEAR);
        System.assertEquals(1, plans.size(), 'Expected the one Program Plan for that Program and year.');
        System.assertEquals('2025-JUL-BBA', plans[0].label);

        List<AdmissionReportsController.Option> semesters =
            AdmissionReportsController.getSemesterOptions(plans[0].value);
        System.assertEquals(1, semesters.size(), 'Expected the one Semester on that Program Plan.');
        System.assertEquals('Semester 1', semesters[0].label,
            'Semester should read from Term_Reference__c when Semesters__c is blank.');

        System.assert(AdmissionReportsController.getSemesterOptions(null).isEmpty(),
            'A blank Program Plan should return no Semester options.');
        System.assert(!AdmissionReportsController.getProgramPlanOptions(null, null).isEmpty(),
            'Unfiltered Program Plan options should still return the test plan.');
    }

    @isTest
    static void testFieldDiagnosticsNameTheFieldsActuallyCounted() {
        String expectedCategoryField = categoryFieldInOrg();

        Test.startTest();
        Map<String, String> diag = AdmissionReportsController.getFieldDiagnostics();
        Test.stopTest();

        System.assertEquals(expectedGenderField(), diag.get('gender'),
            'Gender should prefer GenderIdentity and fall back to hed__Gender__c only where GenderIdentity is unusable.');
        System.assertEquals('MailingState', diag.get('state'),
            'State should resolve past any empty custom state field to the populated MailingState.');
        if (expectedCategoryField != null) {
            System.assertEquals(expectedCategoryField, diag.get('category'),
                'Category should resolve to Student_Category__c wherever the org has it and the setup filled it.');
        } else {
            // The org may still carry a different, empty candidate — all that matters is
            // that the dimension is reported so the UI can say where the column came from.
            System.assert(diag.containsKey('category'), 'The category dimension should always be reported.');
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Report 1 — State Wise
    // ═════════════════════════════════════════════════════════════════════════
    @isTest
    static void testStateWiseReport() {
        Test.startTest();
        AdmissionReportsController.ReportGrid grid =
            AdmissionReportsController.getStateWiseReport(ACADEMIC_YEAR, null, 'ADMITTED');
        Test.stopTest();

        System.assertEquals(1, grid.rows.size(), 'All four admitted applicants share one Programme + Level row.');
        System.assertEquals('Under Graduate', grid.rows[0].cells[0], 'School comes from the Programme\'s parent Account.');
        System.assertEquals('Bachelor of Business Administration', grid.rows[0].cells[1]);
        System.assertEquals('UG', grid.rows[0].cells[2]);

        System.assertEquals('1', cell(grid, 0, 'Karnataka - M'));
        System.assertEquals('1', cell(grid, 0, 'Karnataka - F'));
        System.assertEquals('1', cell(grid, 0, 'Non-Karnataka - M'), 'Kerala counts as Non-Karnataka.');
        System.assertEquals('0', cell(grid, 0, 'Non-Karnataka - F'));
        System.assertEquals('0', cell(grid, 0, 'Not Specified - M'));
        System.assertEquals('1', cell(grid, 0, 'Not Specified - F'),
            'A student with no state on file must not be counted as an out-of-state admission.');
        System.assertEquals('4', cell(grid, 0, 'Total'),
            'The rejected application must be excluded by the default Admitted scope.');

        System.assertEquals('Total', grid.totalsRow[0], 'A grand total row should be present.');
        System.assertEquals(grid.columnLabels.size(), grid.totalsRow.size(),
            'The totals row must line up with the columns.');
        System.assertEquals(false, grid.truncated);
        System.assertEquals('MailingState', grid.sourceFields.get('state'));
    }

    @isTest
    static void testStateWiseReportHonoursStatusScope() {
        Test.startTest();
        AdmissionReportsController.ReportGrid all =
            AdmissionReportsController.getStateWiseReport(null, null, 'ALL');
        AdmissionReportsController.ReportGrid enrolled =
            AdmissionReportsController.getStateWiseReport(null, null, 'ENROLLED');
        AdmissionReportsController.ReportGrid single =
            AdmissionReportsController.getStateWiseReport(null, null, 'Application rejected');
        Test.stopTest();

        System.assertEquals('5', cell(all, 0, 'Total'), '"All applications" should include the rejected one.');
        System.assert(enrolled.rows.isEmpty(), 'No application is Enrolled, so that scope should be empty.');
        System.assertEquals(1, single.rows.size(), 'A single picklist value should be usable as the scope.');
        System.assertEquals('1', cell(single, 0, 'Total'));
    }

    @isTest
    static void testStateWiseReportFiltersByProgram() {
        Account program = [SELECT Id FROM Account WHERE Name = 'Bachelor of Business Administration' LIMIT 1];
        Test.startTest();
        AdmissionReportsController.ReportGrid matched =
            AdmissionReportsController.getStateWiseReport(ACADEMIC_YEAR, program.Id, 'ADMITTED');
        Test.stopTest();

        System.assertEquals(1, matched.rows.size());
        System.assert(matched.scopeLabel.contains('Bachelor of Business Administration'),
            'The scope label should name the selected Program: ' + matched.scopeLabel);
        System.assert(matched.scopeLabel.contains(ACADEMIC_YEAR));
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Report 2 — Category Wise
    // ═════════════════════════════════════════════════════════════════════════
    @isTest
    static void testCategoryWiseReport() {
        String catField = categoryFieldInOrg();

        Test.startTest();
        AdmissionReportsController.ReportGrid grid =
            AdmissionReportsController.getCategoryWiseReport(ACADEMIC_YEAR, null, 'ADMITTED');
        Test.stopTest();

        System.assertEquals(1, grid.rows.size());
        System.assertEquals('1', grid.rows[0].cells[0], 'The first column is the serial number.');
        System.assertEquals('Bachelor of Business Administration', grid.rows[0].cells[1]);
        System.assertEquals('UG', grid.rows[0].cells[2]);
        System.assertEquals('4', cell(grid, 0, 'Total'));
        System.assertEquals('60', cell(grid, 0, 'Approved Intake'),
            'Approved Intake is the Program Plan Intake_Number__c, summed for this Programme and Level.');

        // The four printed buckets are always present, whatever the data holds.
        for (String bucket : new List<String>{ 'GM', 'OBC', 'SC', 'ST' }) {
            System.assertNotEquals(-1, columnIndex(grid, bucket + ' - M'),
                'The client\'s table always prints a ' + bucket + ' column.');
        }

        if (catField != null) {
            System.assertEquals('1', cell(grid, 0, 'SC - M'), 'Kiran is recorded as SC.');
            System.assertEquals('1', cell(grid, 0, 'GM - F'), 'Asha is recorded as General.');
            System.assertEquals('1', cell(grid, 0, 'GM - M'), 'Rahul is recorded as General.');
            System.assertEquals('1', cell(grid, 0, 'Not Specified - F'),
                'Meera has no category on file and must still reach the Total.');
        } else {
            System.assertEquals('2', cell(grid, 0, 'Not Specified - F'),
                'With no category field in this org every student falls into Not Specified.');
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Report 3 — Result Analysis
    // ═════════════════════════════════════════════════════════════════════════
    @isTest
    static void testResultAnalysisReport() {
        hed__Program_Plan__c plan = [SELECT Id FROM hed__Program_Plan__c LIMIT 1];

        Test.startTest();
        AdmissionReportsController.ReportGrid grid =
            AdmissionReportsController.getResultAnalysisReport(plan.Id, null);
        Test.stopTest();

        System.assertEquals(1, grid.rows.size(), 'One row per semester that has Course Connections.');
        List<String> row = grid.rows[0].cells;
        System.assertEquals('2025-JUL-BBA', row[0], 'Batch is the Program Plan.');
        System.assertEquals('Semester 1', row[1]);
        System.assertEquals('Bachelor of Business Administration', row[2]);
        System.assertEquals('2', row[3],
            'Kiran and Asha have a result in every subject; Rahul still has one In Complete.');
        System.assertEquals('1', row[4], 'Only Kiran passed every subject.');
        System.assertEquals('66.67%', row[5],
            'Pass % is 4 passed Course Connections out of 6, per the client\'s definition.');

        System.assertEquals('Total', grid.totalsRow[0]);
        System.assertEquals('66.67%', grid.totalsRow[5]);
        System.assert(grid.scopeLabel.contains(ACADEMIC_YEAR), 'Scope label: ' + grid.scopeLabel);
    }

    @isTest
    static void testResultAnalysisScopedToOneSemester() {
        hed__Program_Plan__c plan = [SELECT Id FROM hed__Program_Plan__c LIMIT 1];
        hed__Term__c term = [SELECT Id FROM hed__Term__c LIMIT 1];

        Test.startTest();
        AdmissionReportsController.ReportGrid grid =
            AdmissionReportsController.getResultAnalysisReport(plan.Id, term.Id);
        Test.stopTest();

        System.assertEquals(1, grid.rows.size());
        System.assertEquals('Semester 1', grid.rows[0].cells[1]);
    }

    @isTest
    static void testResultAnalysisRequiresABatch() {
        Boolean threw = false;
        try {
            AdmissionReportsController.getResultAnalysisReport(null, null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'Result Analysis should refuse to run without a Program Plan.');
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Dashboard
    // ═════════════════════════════════════════════════════════════════════════
    @isTest
    static void testDashboardAgreesWithTheReports() {
        Test.startTest();
        AdmissionReportsController.DashboardData d =
            AdmissionReportsController.getAdmissionDashboard(ACADEMIC_YEAR, null, 'ADMITTED');
        AdmissionReportsController.ReportGrid stateGrid =
            AdmissionReportsController.getStateWiseReport(ACADEMIC_YEAR, null, 'ADMITTED');
        Test.stopTest();

        System.assertEquals(4, d.totalAdmissions, 'The four admitted applicants, excluding the rejected one.');
        System.assertEquals(1, d.programmeCount, 'All four applied to the one Programme.');
        System.assertEquals(2, d.karnataka, 'Kiran and Asha are Karnataka.');
        System.assertEquals(1, d.nonKarnataka, 'Rahul is Kerala.');
        System.assertEquals(1, d.stateNotSpecified, 'Meera has no state on file.');
        System.assertEquals(2, d.male);
        System.assertEquals(2, d.female);
        System.assertEquals(60, d.approvedIntake, 'Approved Intake is the Program Plan Intake_Number__c.');
        System.assertEquals(6.7, d.fillRate, '4 of 60 places taken.');

        // The headline must never disagree with the table underneath it.
        System.assertEquals(
            cell(stateGrid, 0, 'Total'),
            String.valueOf(d.totalAdmissions),
            'Dashboard total and the State Wise row total are built from the same buckets.'
        );

        System.assert(!d.byProgramme.isEmpty(), 'Expected a bar per Programme.');
        System.assertEquals('Bachelor of Business Administration', d.byProgramme[0].label);
        System.assertEquals(4, d.byProgramme[0].value);
        System.assertEquals('UG', d.byLevel[0].label);
        System.assertEquals('Karnataka', d.byState[0].label, 'State chart keeps the printed order.');
        System.assertEquals('Male', d.byGender[0].label, 'Gender chart keeps the printed order.');
        System.assert(d.scopeLabel.contains(ACADEMIC_YEAR), 'Scope label: ' + d.scopeLabel);
        System.assertEquals(false, d.truncated);
    }

    @isTest
    static void testDashboardWithNoMatchingData() {
        Test.startTest();
        AdmissionReportsController.DashboardData d =
            AdmissionReportsController.getAdmissionDashboard('2030-2031', null, 'ADMITTED');
        Test.stopTest();

        System.assertEquals(0, d.totalAdmissions);
        System.assertEquals(0, d.fillRate, 'No intake in scope means no fill rate to report, not a division by zero.');
        System.assert(d.byProgramme.isEmpty());
        System.assert(d.byState.isEmpty(), 'Empty buckets are dropped rather than charted as zero bars.');
    }

    @isTest
    static void testReportsWithNoMatchingData() {
        Test.startTest();
        AdmissionReportsController.ReportGrid grid =
            AdmissionReportsController.getStateWiseReport('2030-2031', null, 'ADMITTED');
        Test.stopTest();

        System.assert(grid.rows.isEmpty(), 'An Academic Year with no Program Plans should return no rows.');
        System.assert(grid.totalsRow.isEmpty(), 'No rows means no totals row.');
    }
}