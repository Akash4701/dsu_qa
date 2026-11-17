/**
 * ExamReportCenterController
 * ───────────────────────────
 * Backs the `examReportCenter` LWC (Dashboard tab + Reports tab).
 *
 * Data model (HEDA - this org, confirmed live against DSU Dev — see the field-level
 * notes below and ExamReportCenterControllerTest for a worked example):
 *   Account (RecordType "Academic Program") → Program.
 *   hed__Program_Plan__c       → Program Plan ("batch" of a Program, e.g. "2026-JUL-MBA").
 *                               hed__Account__c → Program.
 *   hed__Term__c               → Semester. Program_Plan__c → Program Plan. The *display*
 *                               name is the Term's own Name (e.g. "2026-JUL-MBA-Sem 1-
 *                               Online") — NOT Term_Reference__c ("Semester 1", a bare
 *                               ordinal repeated across every Program Plan) and NOT
 *                               hed__Parent_Term__r.Name (a coarser grouping term, e.g.
 *                               "MBA-Master Term 1"), per client direction. Term_Reference__c
 *                               is still read server-side (never shown) purely to sort
 *                               semesters in natural order (Sem 1, 2, 3…) since neither
 *                               Term_Number__c nor hed__Start_Date__c is populated
 *                               consistently enough to sort on (checked against live data).
 *   hed__Program_Enrollment__c→ one row per student per (Program Plan, Term) — "PE" in the
 *                               DSU Prod joined report. hed__Program_Plan__c, Term__c,
 *                               hed__Contact__c, hed__Account__c (Program), SGPA__c.
 *   hed__Affiliation__c       → per-Contact record holding Roll_Number__c, which this
 *                               org's own code (StudentIdCardController) documents as
 *                               "USN = Roll_Number__c".
 *   hed__Course_Enrollment__c → "Course Connection" — one row per student per course.
 *                               Letter_Grade__c, Grade_Point__c, Component_Final_Score__c
 *                               (Total Marks), Exam_Result_Status__c (Pass/Fail/In Complete).
 *
 * ASSUMPTIONS (flagged for client sign-off — the object also carries a couple of
 * same-shaped alternates that were not chosen):
 *   • "Total Marks"  = Component_Final_Score__c ("Composite Score") — matches the field
 *     the DSU Prod joined report itself sums under that name. `Points_Secured__c` is a
 *     second, unconfirmed candidate on the same object.
 *   • "Grade Letter" = Letter_Grade__c (picklist O/A+/A/B+/B/C/P/F/IC — matches the grade
 *     letters in the client's sample CSV exactly). `Final_Grade__c`, `Grade__c` and
 *     `hed__Display_Grade__c` are other grade-shaped fields on the same object that were
 *     not chosen.
 *   Component_Scores__c       → CIA / SEE marks per Course Connection (Exam_Type__c,
 *                               Marks_Obtained__c, Is_Active__c — one active row per
 *                               (Course Connection, Exam Type), matches
 *                               ComponentScoresHandler's own dedupe rule).
 *   Exam_Cycle__c              → Mid Term / End Term / Special, scoped to a Term.
 *
 * This is the same model behind the DSU Prod "Student Wise Final Scores" joined report
 * (00Ofv00000GJsZwEAL) that could not be fully reproduced with a standard report —
 * here it is queried directly and pivoted into the exact column layout the client
 * shared (USN, Student Name, then CIA / SEE / Total Marks / Result / Grade / Grade
 * Point repeated per course code).
 */
public with sharing class ExamReportCenterController {

    private static final List<String> EXAM_TYPES = new List<String>{ 'CIA', 'SEE' };
    // Column labels match the client-shared report exactly (ERP_examination report-MBA Sem 1 Result.csv).
    private static final List<String> SUB_COLUMNS =
        new List<String>{ 'CIA', 'SEE', 'Total Marks', 'Results', 'Grade Letter', 'Grade Point' };
    private static final Integer PE_LIMIT = 2000;
    private static final Integer CE_LIMIT = 10000;

    // ═════════════════════════════════════════════════════════════════════════
    // Filter options — cascade is Program → Program Plan → Semester
    // ═════════════════════════════════════════════════════════════════════════
    @AuraEnabled(cacheable=true)
    public static List<Option> getAcademicProgramOptions() {
        List<Option> opts = new List<Option>();
        for (Account a : [
            SELECT Id, Name
            FROM Account
            WHERE RecordType.Name = 'Academic Program'
            ORDER BY Name
            LIMIT 500
        ]) {
            opts.add(new Option(a.Name, a.Id));
        }
        return opts;
    }

    @AuraEnabled(cacheable=true)
    public static List<Option> getProgramPlanOptions(String programId) {
        List<Option> opts = new List<Option>();
        if (String.isBlank(programId)) { return opts; }
        for (hed__Program_Plan__c pp : [
            SELECT Id, Name
            FROM hed__Program_Plan__c
            WHERE hed__Account__c = :programId
            ORDER BY Name DESC
            LIMIT 500
        ]) {
            opts.add(new Option(pp.Name, pp.Id));
        }
        return opts;
    }

    @AuraEnabled(cacheable=true)
    public static List<Option> getSemesterOptions(String programPlanId) {
        List<Option> opts = new List<Option>();
        if (String.isBlank(programPlanId)) { return opts; }
        List<TermRow> rows = new List<TermRow>();
        for (hed__Term__c t : [
            SELECT Id, Name, Term_Reference__c
            FROM hed__Term__c
            WHERE Program_Plan__c = :programPlanId
            LIMIT 500
        ]) {
            rows.add(new TermRow(t.Id, t.Name, semesterSortKey(t.Term_Reference__c)));
        }
        rows.sort();
        for (TermRow r : rows) { opts.add(new Option(r.name, r.id)); }
        return opts;
    }

    // Term_Reference__c ("Semester 6") is read only to sort naturally — Term_Number__c
    // and hed__Start_Date__c are both unpopulated on most Terms in this org (checked
    // against live data), so the ordinal buried in Term_Reference__c is the only
    // reliable sort key. It is never shown to the user.
    private static Integer semesterSortKey(String termReference) {
        if (String.isBlank(termReference)) { return null; }
        Matcher m = Pattern.compile('\\d+').matcher(termReference);
        return m.find() ? Integer.valueOf(m.group()) : null;
    }

    private class TermRow implements Comparable {
        String id;
        String name;
        Integer sortKey;
        TermRow(String id, String name, Integer sortKey) {
            this.id = id;
            this.name = name;
            this.sortKey = sortKey;
        }
        public Integer compareTo(Object other) {
            TermRow o = (TermRow) other;
            Integer a = this.sortKey == null ? 999 : this.sortKey;
            Integer b = o.sortKey == null ? 999 : o.sortKey;
            if (a != b) { return a - b; }
            return String.isBlank(this.name) ? 0 : this.name.compareTo(o.name);
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Report — Student Semester Result Sheet (the one format the client shared)
    // ═════════════════════════════════════════════════════════════════════════
    @AuraEnabled(cacheable=true)
    public static StudentResultReport getStudentResultReport(String programPlanId, String termId) {
        if (String.isBlank(programPlanId) || String.isBlank(termId)) {
            throw new AuraHandledException('Please select a Program, Program Plan and Semester to run this report.');
        }
        try {
            return buildReport(programPlanId, termId);
        } catch (Exception e) {
            throw new AuraHandledException('Failed to load report: ' + e.getMessage());
        }
    }

    private static StudentResultReport buildReport(String programPlanId, String termId) {
        StudentResultReport rpt = new StudentResultReport();

        // 1) Program Enrollments ("PE") for the selected Program Plan + Semester.
        //    USN + Student Name come straight off the linked hed__Affiliation__c — this is
        //    the same Affiliation → Program Enrollment → Course Enrollment → Component Scores
        //    chain the DSU Prod "Student Wise Final Scores" joined report (00Ofv00000GJsZwEAL)
        //    itself is built on, confirmed by retrieving that report's metadata.
        List<hed__Program_Enrollment__c> peList = [
            SELECT Id, hed__Contact__c, hed__Contact__r.Name, hed__Account__r.Name, SGPA__c,
                   hed__Affiliation__c, hed__Affiliation__r.Roll_Number__c, hed__Affiliation__r.Student_Name__c
            FROM hed__Program_Enrollment__c
            WHERE hed__Program_Plan__c = :programPlanId AND Term__c = :termId
            ORDER BY hed__Contact__r.Name
            LIMIT :PE_LIMIT
        ];
        if (peList.isEmpty()) { return rpt; }

        Set<Id> peIds = new Set<Id>();
        Set<Id> contactIds = new Set<Id>();
        for (hed__Program_Enrollment__c pe : peList) {
            peIds.add(pe.Id);
            // Fallback path for PEs with no Affiliation linked directly.
            if (pe.hed__Affiliation__c == null && pe.hed__Contact__c != null) { contactIds.add(pe.hed__Contact__c); }
        }

        // Fallback USN lookup (by Contact) only for PEs missing a direct Affiliation link.
        Map<Id, String> usnByContact = new Map<Id, String>();
        if (!contactIds.isEmpty()) {
            for (hed__Affiliation__c af : [
                SELECT hed__Contact__c, Roll_Number__c
                FROM hed__Affiliation__c
                WHERE hed__Contact__c IN :contactIds AND Roll_Number__c != null
            ]) {
                if (!usnByContact.containsKey(af.hed__Contact__c)) {
                    usnByContact.put(af.hed__Contact__c, af.Roll_Number__c);
                }
            }
        }

        // 3) Course Enrollments ("Course Connection") for these students.
        List<hed__Course_Enrollment__c> ceList = [
            SELECT Id, hed__Program_Enrollment__c,
                   hed__Course_Offering__r.hed__Course__r.hed__Course_ID__c,
                   hed__Course_Offering__r.hed__Course__r.Name,
                   Letter_Grade__c, Grade_Point__c, Component_Final_Score__c, Exam_Result_Status__c
            FROM hed__Course_Enrollment__c
            WHERE hed__Program_Enrollment__c IN :peIds
              AND hed__Course_Offering__r.hed__Course__r.Exclude_From_Official_Records__c = false
            ORDER BY hed__Course_Offering__r.hed__Course__r.hed__Course_ID__c
            LIMIT :CE_LIMIT
        ];

        Set<Id> ceIds = new Set<Id>();
        for (hed__Course_Enrollment__c ce : ceList) { ceIds.add(ce.Id); }

        // 4) Component Scores (CIA / SEE) — one active row per (Course Connection, Exam Type),
        //    latest wins (mirrors ComponentScoresHandler's own de-dupe rule).
        Map<Id, Decimal> ciaMarks = new Map<Id, Decimal>();
        Map<Id, Decimal> seeMarks = new Map<Id, Decimal>();
        if (!ceIds.isEmpty()) {
            for (Component_Scores__c sc : [
                SELECT Course_Connection__c, Exam_Type__c, Marks_Obtained__c
                FROM Component_Scores__c
                WHERE Is_Active__c = true
                  AND Course_Connection__c IN :ceIds
                  AND Exam_Type__c IN :EXAM_TYPES
                ORDER BY CreatedDate DESC
            ]) {
                Map<Id, Decimal> target = (sc.Exam_Type__c == 'CIA') ? ciaMarks : seeMarks;
                if (!target.containsKey(sc.Course_Connection__c)) {
                    target.put(sc.Course_Connection__c, sc.Marks_Obtained__c);
                }
            }
        }

        // 5) Distinct, ordered course codes across the cohort → the dynamic column set.
        List<String> courseCodes = new List<String>();
        Set<String> seenCodes = new Set<String>();
        Map<String, String> titleByCode = new Map<String, String>();
        for (hed__Course_Enrollment__c ce : ceList) {
            String code = courseCodeOf(ce);
            if (String.isBlank(code) || seenCodes.contains(code)) { continue; }
            seenCodes.add(code);
            courseCodes.add(code);
            titleByCode.put(code, courseTitleOf(ce));
        }
        courseCodes.sort();

        // 6) Index course enrollments by (Program Enrollment, course code).
        Map<Id, Map<String, hed__Course_Enrollment__c>> ceByPeAndCode =
            new Map<Id, Map<String, hed__Course_Enrollment__c>>();
        for (hed__Course_Enrollment__c ce : ceList) {
            String code = courseCodeOf(ce);
            if (String.isBlank(code)) { continue; }
            Id peId = ce.hed__Program_Enrollment__c;
            if (!ceByPeAndCode.containsKey(peId)) {
                ceByPeAndCode.put(peId, new Map<String, hed__Course_Enrollment__c>());
            }
            ceByPeAndCode.get(peId).put(code, ce);
        }

        // 7) Assemble the pivoted rows.
        rpt.courseCodes = courseCodes;
        for (String code : courseCodes) { rpt.courseTitles.add(titleByCode.get(code)); }
        rpt.subColumns = SUB_COLUMNS;

        for (hed__Program_Enrollment__c pe : peList) {
            StudentRow row = new StudentRow();
            row.id = pe.Id;
            // Prefer the linked Affiliation (matches the DSU Prod report); fall back to the
            // Contact-keyed lookup, then to the Contact record itself, so a row is never blank.
            String affUsn = (pe.hed__Affiliation__r != null) ? pe.hed__Affiliation__r.Roll_Number__c : null;
            row.usn = String.isNotBlank(affUsn) ? affUsn
                : (usnByContact.containsKey(pe.hed__Contact__c) ? usnByContact.get(pe.hed__Contact__c) : '');
            String affName = (pe.hed__Affiliation__r != null) ? pe.hed__Affiliation__r.Student_Name__c : null;
            row.studentName = String.isNotBlank(affName) ? affName
                : ((pe.hed__Contact__r != null) ? pe.hed__Contact__r.Name : '');
            row.program = (pe.hed__Account__r != null) ? pe.hed__Account__r.Name : '';
            row.sgpa = pe.SGPA__c;

            Map<String, hed__Course_Enrollment__c> byCode = ceByPeAndCode.containsKey(pe.Id)
                ? ceByPeAndCode.get(pe.Id)
                : new Map<String, hed__Course_Enrollment__c>();

            for (String code : courseCodes) {
                hed__Course_Enrollment__c ce = byCode.get(code);
                CourseCell cell = new CourseCell();
                if (ce != null) {
                    cell.cia = numStr(ciaMarks.get(ce.Id));
                    cell.see = numStr(seeMarks.get(ce.Id));
                    cell.total = numStr(ce.Component_Final_Score__c);
                    cell.result = str(ce.Exam_Result_Status__c);
                    cell.grade = str(ce.Letter_Grade__c);
                    cell.gradePoint = numStr(ce.Grade_Point__c);
                }
                row.cells.add(cell);
            }
            rpt.rows.add(row);
        }
        rpt.totalRows = rpt.rows.size();
        return rpt;
    }

    private static String courseCodeOf(hed__Course_Enrollment__c ce) {
        return (ce.hed__Course_Offering__r != null && ce.hed__Course_Offering__r.hed__Course__r != null)
            ? ce.hed__Course_Offering__r.hed__Course__r.hed__Course_ID__c
            : null;
    }
    private static String courseTitleOf(hed__Course_Enrollment__c ce) {
        return (ce.hed__Course_Offering__r != null && ce.hed__Course_Offering__r.hed__Course__r != null)
            ? ce.hed__Course_Offering__r.hed__Course__r.Name
            : '';
    }
    private static String str(Object v) { return v == null ? '' : String.valueOf(v); }
    private static String numStr(Decimal v) { return v == null ? '' : String.valueOf(v); }

    // ═════════════════════════════════════════════════════════════════════════
    // Dashboard
    // ═════════════════════════════════════════════════════════════════════════
    @AuraEnabled(cacheable=true)
    public static DashboardData getDashboardSummary(String programPlanId, String termId) {
        DashboardData d = new DashboardData();
        try {
            // Program Enrollments in scope: (Program Plan + Term), Term only, or all.
            List<hed__Program_Enrollment__c> peList;
            if (String.isNotBlank(programPlanId) && String.isNotBlank(termId)) {
                peList = [
                    SELECT Id, SGPA__c FROM hed__Program_Enrollment__c
                    WHERE hed__Program_Plan__c = :programPlanId AND Term__c = :termId
                    LIMIT :PE_LIMIT
                ];
            } else if (String.isNotBlank(termId)) {
                peList = [SELECT Id, SGPA__c FROM hed__Program_Enrollment__c WHERE Term__c = :termId LIMIT :PE_LIMIT];
            } else {
                peList = [SELECT Id, SGPA__c FROM hed__Program_Enrollment__c LIMIT :PE_LIMIT];
            }
            Set<Id> peIds = new Set<Id>();
            Decimal sgpaSum = 0; Integer sgpaCount = 0;
            for (hed__Program_Enrollment__c pe : peList) {
                peIds.add(pe.Id);
                if (pe.SGPA__c != null) { sgpaSum += pe.SGPA__c; sgpaCount++; }
            }
            d.totalStudents = peList.size();
            d.averageSgpa = sgpaCount > 0 ? (sgpaSum / sgpaCount).setScale(2, System.RoundingMode.HALF_UP) : 0;

            // Course Enrollments ("results") in scope.
            List<hed__Course_Enrollment__c> ceList = peIds.isEmpty()
                ? new List<hed__Course_Enrollment__c>()
                : [
                    SELECT Id, Exam_Result_Status__c, Letter_Grade__c, Component_Final_Score__c
                    FROM hed__Course_Enrollment__c
                    WHERE hed__Program_Enrollment__c IN :peIds
                      AND hed__Course_Offering__r.hed__Course__r.Exclude_From_Official_Records__c = false
                    LIMIT :CE_LIMIT
                  ];

            Integer pass = 0, fail = 0, incomplete = 0;
            Decimal marksSum = 0; Integer marksCount = 0;
            Map<String, Integer> gradeCounts = new Map<String, Integer>();
            Set<Id> ceIds = new Set<Id>();
            for (hed__Course_Enrollment__c ce : ceList) {
                ceIds.add(ce.Id);
                if (ce.Exam_Result_Status__c == 'Pass') { pass++; }
                else if (ce.Exam_Result_Status__c == 'Fail') { fail++; }
                else { incomplete++; }
                if (ce.Component_Final_Score__c != null) { marksSum += ce.Component_Final_Score__c; marksCount++; }
                String grade = String.isBlank(ce.Letter_Grade__c) ? 'Not Set' : ce.Letter_Grade__c;
                gradeCounts.put(grade, (gradeCounts.containsKey(grade) ? gradeCounts.get(grade) : 0) + 1);
            }
            d.totalResults = ceList.size();
            d.passCount = pass;
            d.failCount = fail;
            d.inCompleteCount = incomplete;
            d.passPercentage = ceList.isEmpty() ? 0
                : ((Decimal) pass / ceList.size() * 100).setScale(1, System.RoundingMode.HALF_UP);
            d.averageMarks = marksCount > 0 ? (marksSum / marksCount).setScale(2, System.RoundingMode.HALF_UP) : 0;

            // CIA / SEE upload progress across those Course Connections.
            if (!ceIds.isEmpty()) {
                Set<Id> ciaDone = new Set<Id>();
                Set<Id> seeDone = new Set<Id>();
                for (Component_Scores__c sc : [
                    SELECT Course_Connection__c, Exam_Type__c
                    FROM Component_Scores__c
                    WHERE Is_Active__c = true
                      AND Course_Connection__c IN :ceIds
                      AND Exam_Type__c IN :EXAM_TYPES
                      AND Marks_Obtained__c != null
                ]) {
                    if (sc.Exam_Type__c == 'CIA') { ciaDone.add(sc.Course_Connection__c); }
                    else { seeDone.add(sc.Course_Connection__c); }
                }
                d.ciaUploadPercentage = (((Decimal) ciaDone.size()) / ceIds.size() * 100).setScale(1, System.RoundingMode.HALF_UP);
                d.seeUploadPercentage = (((Decimal) seeDone.size()) / ceIds.size() * 100).setScale(1, System.RoundingMode.HALF_UP);
            }

            // Grade distribution chart.
            for (String grade : gradeCounts.keySet()) {
                d.gradeDistribution.add(new ChartPoint(grade, gradeCounts.get(grade)));
            }

            // Pass / Fail / Incomplete chart.
            if (pass > 0) { d.passFail.add(new ChartPoint('Pass', pass)); }
            if (fail > 0) { d.passFail.add(new ChartPoint('Fail', fail)); }
            if (incomplete > 0) { d.passFail.add(new ChartPoint('In Complete', incomplete)); }

            // Exam Cycles by type (Mid Term / End Term / Special), scoped to the Term.
            String cycleSoql = 'SELECT Exam_Type__c grp, COUNT(Id) total FROM Exam_Cycle__c WHERE Exam_Type__c != null';
            if (String.isNotBlank(termId)) { cycleSoql += ' AND Term__c = :termId'; }
            cycleSoql += ' GROUP BY Exam_Type__c';
            for (AggregateResult ar : Database.query(cycleSoql)) {
                d.examCyclesByType.add(new ChartPoint((String) ar.get('grp'), (Integer) ar.get('total')));
            }

            d.totalExamCycles = String.isNotBlank(termId)
                ? Database.countQuery('SELECT COUNT() FROM Exam_Cycle__c WHERE Term__c = :termId')
                : Database.countQuery('SELECT COUNT() FROM Exam_Cycle__c');
            d.activeExamCycles = String.isNotBlank(termId)
                ? Database.countQuery('SELECT COUNT() FROM Exam_Cycle__c WHERE Term__c = :termId AND Is_Active__c = true')
                : Database.countQuery('SELECT COUNT() FROM Exam_Cycle__c WHERE Is_Active__c = true');
        } catch (Exception e) {
            throw new AuraHandledException('Failed to load dashboard: ' + e.getMessage());
        }
        return d;
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Wrapper types
    // ═════════════════════════════════════════════════════════════════════════
    public class Option {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        public Option(String label, String value) { this.label = label; this.value = value; }
    }

    public class StudentResultReport {
        @AuraEnabled public List<String> courseCodes = new List<String>();
        @AuraEnabled public List<String> courseTitles = new List<String>();
        @AuraEnabled public List<String> subColumns = new List<String>();
        @AuraEnabled public List<StudentRow> rows = new List<StudentRow>();
        @AuraEnabled public Integer totalRows = 0;
    }

    public class StudentRow {
        @AuraEnabled public String id;
        @AuraEnabled public String usn;
        @AuraEnabled public String studentName;
        @AuraEnabled public String program;
        @AuraEnabled public Decimal sgpa;
        @AuraEnabled public List<CourseCell> cells = new List<CourseCell>();
    }

    public class CourseCell {
        @AuraEnabled public String cia = '';
        @AuraEnabled public String see = '';
        @AuraEnabled public String total = '';
        @AuraEnabled public String result = '';
        @AuraEnabled public String grade = '';
        @AuraEnabled public String gradePoint = '';
    }

    public class DashboardData {
        @AuraEnabled public Integer totalStudents = 0;
        @AuraEnabled public Integer totalResults = 0;
        @AuraEnabled public Integer passCount = 0;
        @AuraEnabled public Integer failCount = 0;
        @AuraEnabled public Integer inCompleteCount = 0;
        @AuraEnabled public Decimal passPercentage = 0;
        @AuraEnabled public Decimal averageMarks = 0;
        @AuraEnabled public Decimal averageSgpa = 0;
        @AuraEnabled public Decimal ciaUploadPercentage = 0;
        @AuraEnabled public Decimal seeUploadPercentage = 0;
        @AuraEnabled public Integer totalExamCycles = 0;
        @AuraEnabled public Integer activeExamCycles = 0;
        @AuraEnabled public List<ChartPoint> gradeDistribution = new List<ChartPoint>();
        @AuraEnabled public List<ChartPoint> passFail = new List<ChartPoint>();
        @AuraEnabled public List<ChartPoint> examCyclesByType = new List<ChartPoint>();
    }

    public class ChartPoint {
        @AuraEnabled public String label;
        @AuraEnabled public Decimal value;
        public ChartPoint(String label, Decimal value) { this.label = label; this.value = value == null ? 0 : value; }
    }
}