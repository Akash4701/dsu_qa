/**
 * AdmissionReportsController
 * ──────────────────────────
 * Backs the `admissionReports` LWC ("Admission Reports" tab). Three reports, each
 * matching a table layout the client shared:
 *
 *   1. Admission Details — State Wise (Karnataka / Non-Karnataka) & Gender Wise
 *        School | Programmes Offered | UG/PG | Karnataka M,F | Non-Karnataka M,F | Total
 *   2. Programs, Courses and Intake — Admission details, Category and Gender Wise
 *        S.N | Program Offered | UG/PG | GM M,F | OBC M,F | SC M,F | ST M,F | Total | Approved Intake
 *   3. Result Analysis — Students performance during the academic year
 *        Batch | Semester | Program | No of Students Appeared in all the subjects |
 *        No of Students Passed | Pass %
 *
 * Data model (HEDA — confirmed live against DSU Dev):
 *   Application__c            → one row per applicant per program.
 *                               ContactId__c  → Contact (gender / state / category).
 *                               AccountId__c  → Account, RecordType "Academic Program"
 *                                               = the Programme ("Bachelor of Commerce").
 *                               Program_Level__c (UG/PG), Status__c, Program_Plan__c.
 *   Account hierarchy         → Educational Institution ("Dayananda Sagar University -
 *                               Online") → University Department ("Under Graduate" /
 *                               "Post Graduate") → Academic Program → Program
 *                               Specialization. "School" on report 1 is the nearest
 *                               School/College/University Department ancestor of the
 *                               application's Account.
 *   hed__Program_Plan__c      → the batch of a Programme ("2026-JAN-BBA").
 *                               Academic_Year__c ("2025-2026"), Intake_Number__c
 *                               (= Approved Intake), hed__Account__c → Programme.
 *   hed__Term__c              → Semester. Program_Plan__c → Program Plan. Its ordinal
 *                               lives in Semesters__c ("I".."VIII") or, where that is
 *                               blank, in Term_Reference__c ("Semester 1").
 *   hed__Course_Offering__c   → hed__Term__c → the semester a course runs in.
 *   hed__Course_Enrollment__c → "Course Connection", one per student per course.
 *                               Exam_Result_Status__c is the result grade
 *                               (Pass / Fail / In Complete).
 *
 * THE CONTACT FIELDS
 *   Gender comes from `GenderIdentity` and social category from `Student_Category__c`
 *   (picklist: Karnataka, Non-Karnataka, SAARC, International, PGCET, MGT, SC, ST, OBC,
 *   General, PWD, EWS, Other) — the two fields DSU maintains.
 *
 *   They are looked up through a candidate list rather than named inline, because the DSU
 *   orgs do not carry the same Contact fields: DSU Dev has `GenderIdentity` (127 of 225
 *   Contacts filled), `Student_Category__c` (78) and `MailingState` (81), but its
 *   `hed__Gender__c` and `Mailing_State__c` are empty and `Student_State__c` does not
 *   exist at all. Hard-coding one name either fails to compile where it is missing or
 *   silently reports zeroes where it is empty, so each dimension resolves once per
 *   transaction to the first candidate that exists and is filled on a meaningful share of
 *   Contacts — see resolveContactField. `getFieldDiagnostics()` reports what was picked
 *   and the UI prints it, so an empty column is never mistaken for a missing field.
 *
 * VOLUME
 *   Reports 1 and 2 are answered with aggregate SOQL (GROUP BY), so the row count never
 *   touches the Apex heap — only the grouped buckets do. Aggregate queries return at
 *   most 2,000 grouped rows; report 1 groups by Programme × Level × Gender × State, which
 *   is the widest of the three, and `truncated` is set if that ceiling is reached.
 *   Report 3 issues one aggregate per semester (students × result statuses per query)
 *   rather than one query for the whole batch, for the same reason.
 */
public with sharing class AdmissionReportsController {

    // Statuses that count as an admission. Exposed as a filter so the registrar can
    // widen or narrow it without a code change — the client's tables say "Admission
    // Details", which in this org spans everything from "Admitted" through "Enrolled".
    private static final List<String> ADMITTED_STATUSES = new List<String>{
        'Admitted', 'Enrolled', 'Approved for USN', 'Generate Letter of Admission', 'CRM Enrolled'
    };
    private static final List<String> ENROLLED_STATUSES = new List<String>{ 'Enrolled', 'CRM Enrolled' };

    private static final String SCOPE_ADMITTED = 'ADMITTED';
    private static final String SCOPE_ENROLLED = 'ENROLLED';
    private static final String SCOPE_ALL      = 'ALL';

    // Record types treated as a "School" when walking up from the application's Account.
    private static final Set<String> SCHOOL_RECORD_TYPES = new Set<String>{
        'University Department', 'College', 'School'
    };

    private static final String NOT_SPECIFIED = 'Not Specified';
    private static final Integer AGGREGATE_CAP = 2000;

    // Category / state / gender buckets, in the column order the client's tables use.
    private static final List<String> CATEGORY_ORDER = new List<String>{ 'GM', 'OBC', 'SC', 'ST' };
    private static final List<String> STATE_ORDER    = new List<String>{ 'Karnataka', 'Non-Karnataka' };

    // ═════════════════════════════════════════════════════════════════════════
    // Contact field resolution — see the class header for why this is dynamic.
    // ═════════════════════════════════════════════════════════════════════════
    // `GenderIdentity` and `Student_Category__c` lead their lists because those are the
    // fields DSU maintains; everything after each is a fallback for an org that has not
    // been given them yet (DSU Dev, for one, carries neither).
    private static final List<String> GENDER_CANDIDATES = new List<String>{
        'GenderIdentity', 'hed__Gender__c', 'Gender_Formula__c', 'DEB_Gender__c'
    };
    // MailingState is ahead of the generic `State__c` deliberately: it is the address
    // field DSU actually fills (81 of 225 Contacts in DSU Dev, against roughly none on
    // State__c). The two purpose-built student-state fields stay ahead of both, for an
    // org that maintains them. Student_Category__c is last on purpose: it is primarily a
    // category field, but its picklist also carries Karnataka / Non-Karnataka, so it can
    // stand in for the state split where no dedicated state field is filled —
    // normalizeState only trusts the values that genuinely describe domicile.
    private static final List<String> STATE_CANDIDATES = new List<String>{
        'Student_State__c', 'Domicile_State__c', 'MailingState', 'Mailing_State__c',
        'State__c', 'OtherState', 'Student_Category__c'
    };
    private static final List<String> CATEGORY_CANDIDATES = new List<String>{
        'Student_Category__c', 'Fee_Category_of_the_Students__c', 'Caste__c', 'Community__c'
    };

    private static final Map<String, List<String>> CANDIDATES = new Map<String, List<String>>{
        'gender'   => GENDER_CANDIDATES,
        'state'    => STATE_CANDIDATES,
        'category' => CATEGORY_CANDIDATES
    };
    /** Per-transaction cache — resolution costs a probe query per candidate. */
    private static final Map<String, String> RESOLVED = new Map<String, String>();

    /** Probe ceiling — counting stops here, which keeps it bounded on a large Contact table. */
    private static final Integer DENSITY_SAMPLE = 5000;
    /** Share of Contacts a field must be filled on before it is treated as the one in use. */
    private static final Decimal MIN_COVERAGE = 0.10;

    private static Integer contactCount;

    /**
     * The first candidate that exists on Contact in this org AND is filled in on a
     * meaningful share of Contacts — declared order is the preference, the coverage floor
     * is only there to skip a field that is present in name only.
     *
     * Both halves of that rule are load-bearing, and DSU Dev demonstrates each:
     *   • Preference alone is not enough. `State__c` exists there with barely a row in it
     *     while `MailingState` carries 81 of 225; taking the first candidate holding *any*
     *     value picked `State__c` and reported almost every student as state-unknown.
     *   • Coverage alone is worse. A field with a default value looks 100% populated on
     *     freshly inserted records, so ranking purely by density let
     *     `Fee_Category_of_the_Students__c` beat `Student_Category__c` outright.
     *
     * So: walk the list in order and take the first candidate that clears the floor. If
     * none does, fall back to the best-populated one, and if nothing is populated at all
     * return the first field that exists, so the column reads "Not Specified" rather than
     * disappearing.
     */
    private static String resolveContactField(List<String> candidates) {
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Contact.fields.getMap();
        if (contactCount == null) {
            contactCount = Database.countQuery('SELECT COUNT() FROM Contact LIMIT ' + DENSITY_SAMPLE);
        }
        Integer floor = Math.max(1, (Integer) (contactCount * MIN_COVERAGE));

        String best = null;
        Integer bestCount = -1;
        for (String candidate : candidates) {
            if (!fieldMap.containsKey(candidate.toLowerCase())) { continue; }
            Integer populated;
            try {
                populated = Database.countQuery(
                    'SELECT COUNT() FROM Contact WHERE ' + candidate + ' != null LIMIT ' + DENSITY_SAMPLE
                );
            } catch (Exception e) {
                continue; // Not filterable in this org — it could not back a GROUP BY either.
            }
            if (populated >= floor) { return candidate; }
            if (populated > bestCount) { best = candidate; bestCount = populated; }
        }
        return best;
    }

    /** Resolved field for one dimension ('gender', 'state', 'category'), or null. */
    private static String fieldFor(String dimension) {
        if (!RESOLVED.containsKey(dimension)) {
            RESOLVED.put(dimension, resolveContactField(CANDIDATES.get(dimension)));
        }
        return RESOLVED.get(dimension);
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, String> getFieldDiagnostics() {
        Map<String, String> diag = new Map<String, String>();
        for (String dimension : CANDIDATES.keySet()) {
            String resolved = fieldFor(dimension);
            diag.put(dimension, resolved == null ? '' : resolved);
        }
        return diag;
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Filter options
    // ═════════════════════════════════════════════════════════════════════════
    @AuraEnabled(cacheable=true)
    public static List<Option> getAcademicYearOptions() {
        List<Option> opts = new List<Option>();
        for (AggregateResult ar : [
            SELECT Academic_Year__c acadYear
            FROM hed__Program_Plan__c
            WHERE Academic_Year__c != null
            GROUP BY Academic_Year__c
            ORDER BY Academic_Year__c DESC
            LIMIT 200
        ]) {
            String yr = (String) ar.get('acadYear');
            opts.add(new Option(yr, yr));
        }
        return opts;
    }

    @AuraEnabled(cacheable=true)
    public static List<Option> getProgramOptions() {
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
    public static List<Option> getProgramPlanOptions(String programId, String academicYear) {
        List<Option> opts = new List<Option>();
        String soql = 'SELECT Id, Name FROM hed__Program_Plan__c WHERE Id != null';
        if (String.isNotBlank(programId))    { soql += ' AND hed__Account__c = :programId'; }
        if (String.isNotBlank(academicYear)) { soql += ' AND Academic_Year__c = :academicYear'; }
        soql += ' ORDER BY Name DESC LIMIT 1000';
        for (hed__Program_Plan__c pp : (List<hed__Program_Plan__c>) Database.query(soql)) {
            opts.add(new Option(pp.Name, pp.Id));
        }
        return opts;
    }

    @AuraEnabled(cacheable=true)
    public static List<Option> getSemesterOptions(String programPlanId) {
        List<Option> opts = new List<Option>();
        if (String.isBlank(programPlanId)) { return opts; }
        for (TermRow r : orderedTerms(programPlanId)) {
            opts.add(new Option(r.label, r.id));
        }
        return opts;
    }

    // Semesters sorted in natural order. Neither Term_Number__c nor hed__Start_Date__c is
    // populated consistently in this org (checked against live data), so the ordinal is
    // taken from Semesters__c ("I".."VIII") when set and from Term_Reference__c
    // ("Semester 3") otherwise — the same fallback ExamReportCenterController relies on.
    private static List<TermRow> orderedTerms(String programPlanId) {
        List<TermRow> rows = new List<TermRow>();
        for (hed__Term__c t : [
            SELECT Id, Name, Semesters__c, Term_Reference__c
            FROM hed__Term__c
            WHERE Program_Plan__c = :programPlanId
            LIMIT 500
        ]) {
            rows.add(new TermRow(t.Id, semesterLabel(t), semesterSortKey(t)));
        }
        rows.sort();
        return rows;
    }

    private static String semesterLabel(hed__Term__c t) {
        if (String.isNotBlank(t.Semesters__c))      { return 'Semester ' + t.Semesters__c; }
        if (String.isNotBlank(t.Term_Reference__c)) { return t.Term_Reference__c; }
        return t.Name;
    }

    private static final Map<String, Integer> ROMAN = new Map<String, Integer>{
        'I' => 1, 'II' => 2, 'III' => 3, 'IV' => 4, 'V' => 5, 'VI' => 6, 'VII' => 7, 'VIII' => 8
    };

    private static Integer semesterSortKey(hed__Term__c t) {
        if (String.isNotBlank(t.Semesters__c) && ROMAN.containsKey(t.Semesters__c.toUpperCase())) {
            return ROMAN.get(t.Semesters__c.toUpperCase());
        }
        if (String.isNotBlank(t.Term_Reference__c)) {
            Matcher m = Pattern.compile('\\d+').matcher(t.Term_Reference__c);
            if (m.find()) { return Integer.valueOf(m.group()); }
        }
        return null;
    }

    private class TermRow implements Comparable {
        String id;
        String label;
        Integer sortKey;
        TermRow(String id, String label, Integer sortKey) {
            this.id = id; this.label = label; this.sortKey = sortKey;
        }
        public Integer compareTo(Object other) {
            TermRow o = (TermRow) other;
            Integer a = this.sortKey == null ? 999 : this.sortKey;
            Integer b = o.sortKey == null ? 999 : o.sortKey;
            if (a != b) { return a - b; }
            return String.isBlank(this.label) ? 0 : this.label.compareTo(o.label);
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Report 1 — Admission Details, State Wise (Karnataka / Non-Karnataka) & Gender Wise
    // ═════════════════════════════════════════════════════════════════════════
    @AuraEnabled
    public static ReportGrid getStateWiseReport(String academicYear, String programId, String statusScope) {
        try {
            return buildAdmissionGrid(academicYear, programId, statusScope, true);
        } catch (Exception e) {
            throw new AuraHandledException('Failed to load the State Wise report: ' + e.getMessage());
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Report 2 — Admission details, Category and Gender Wise
    // ═════════════════════════════════════════════════════════════════════════
    @AuraEnabled
    public static ReportGrid getCategoryWiseReport(String academicYear, String programId, String statusScope) {
        try {
            return buildAdmissionGrid(academicYear, programId, statusScope, false);
        } catch (Exception e) {
            throw new AuraHandledException('Failed to load the Category Wise report: ' + e.getMessage());
        }
    }

    /**
     * Reports 1 and 2 are the same count pivoted on a different dimension — state for
     * report 1, social category for report 2 — so they share one builder. `stateWise`
     * picks which Contact field becomes the column groups and which extra columns
     * (School, or S.N + Approved Intake) frame them.
     */
    private static ReportGrid buildAdmissionGrid(
        String academicYear, String programId, String statusScope, Boolean stateWise
    ) {
        ReportGrid grid = new ReportGrid();
        BucketSet bs = loadBuckets(academicYear, programId, statusScope, stateWise);

        String dimField = bs.dimField;
        String genderField = bs.genderField;
        grid.sourceFields.put('gender', genderField == null ? '' : genderField);
        grid.sourceFields.put(stateWise ? 'state' : 'category', dimField == null ? '' : dimField);
        grid.truncated = bs.truncated;

        Boolean anyOtherGender = bs.anyOtherGender;
        Set<String> dimsSeen = bs.dimsSeen;
        Map<Id, Account> accById = bs.accById;
        List<String> statuses = statusesFor(statusScope);

        // ── Column groups: the fixed order the client's tables use, plus any bucket the
        //    data actually needed (an unmapped category, or students with no state on
        //    file) so nothing is silently dropped from the Total.
        List<String> dimGroups = new List<String>(stateWise ? STATE_ORDER : CATEGORY_ORDER);
        for (String extra : new List<String>{ 'Other', NOT_SPECIFIED }) {
            if (dimsSeen.contains(extra)) { dimGroups.add(extra); }
        }
        List<String> genderCols = anyOtherGender
            ? new List<String>{ 'M', 'F', 'O' }
            : new List<String>{ 'M', 'F' };

        // ── Approved Intake (report 2 only) — summed per (Programme, Level).
        Map<String, Decimal> intakeByProgrammeLevel = stateWise
            ? new Map<String, Decimal>()
            : approvedIntake(academicYear, programId, statuses);

        // ── Headers.
        if (stateWise) {
            grid.title = 'Admission Details - State Wise – Karnataka / Non-Karnataka & Gender Wise';
            grid.addLeadingColumn('School');
            grid.addLeadingColumn('Programmes Offered');
        } else {
            grid.title = 'Admission details - Category and Gender Wise';
            grid.addLeadingColumn('S.N');
            grid.addLeadingColumn('Program Offered');
        }
        grid.addLeadingColumn('UG/PG');
        for (String g : dimGroups) { grid.addGroupColumn(g, genderCols); }
        grid.addTrailingColumn('Total');
        if (!stateWise) { grid.addTrailingColumn('Approved Intake'); }

        // ── Rows, ordered the way the printed table reads.
        List<Bucket> ordered = bs.buckets;
        ordered.sort();

        Integer serial = 0;
        List<Integer> columnTotals = new List<Integer>();
        Decimal intakeTotal = 0;
        for (Bucket b : ordered) {
            serial++;
            GridRow row = new GridRow(String.valueOf(b.accountId) + '-' + b.level);
            row.cells.add(stateWise ? b.school : String.valueOf(serial));
            row.cells.add(b.programme);
            row.cells.add(b.level);

            Integer offset = 3;
            Integer rowTotal = 0;
            for (String dim : dimGroups) {
                for (String g : genderCols) {
                    Integer v = b.get(dim, g);
                    rowTotal += v;
                    row.cells.add(String.valueOf(v));
                    addTo(columnTotals, offset, v);
                    offset++;
                }
            }
            row.cells.add(String.valueOf(rowTotal));
            addTo(columnTotals, offset, rowTotal);
            offset++;

            if (!stateWise) {
                Decimal intake = intakeByProgrammeLevel.get(b.accountId + '|' + b.level);
                intakeTotal += (intake == null ? 0 : intake);
                row.cells.add(intake == null ? '' : String.valueOf(intake.setScale(0)));
            }
            grid.rows.add(row);
        }

        // ── Grand total row, aligned to the same columns.
        if (!grid.rows.isEmpty()) {
            grid.totalsRow.add('Total');
            grid.totalsRow.add('');
            grid.totalsRow.add('');
            for (Integer i = 3; i < columnTotals.size(); i++) {
                grid.totalsRow.add(String.valueOf(columnTotals[i]));
            }
            if (!stateWise) { grid.totalsRow.add(String.valueOf(intakeTotal.setScale(0))); }
        }

        grid.scopeLabel = scopeLabel(academicYear, programId, statusScope, accById);
        return grid;
    }

    /**
     * The one aggregate both the admission reports and the dashboard are built from:
     * applications counted by Programme × UG/PG × gender × (state | category), already
     * bucketed and named. Sharing it is what keeps the dashboard's headline numbers and
     * the report tables from ever disagreeing with each other.
     */
    private static BucketSet loadBuckets(
        String academicYear, String programId, String statusScope, Boolean stateWise
    ) {
        BucketSet bs = new BucketSet();
        List<String> statuses = statusesFor(statusScope);
        bs.dimField = fieldFor(stateWise ? 'state' : 'category');
        bs.genderField = fieldFor('gender');
        String dimField = bs.dimField;
        String genderField = bs.genderField;

        String soql = 'SELECT COUNT(Id) recCount, AccountId__c accId, Program_Level__c progLevel';
        if (genderField != null) { soql += ', ContactId__r.' + genderField + ' genderVal'; }
        if (dimField != null)    { soql += ', ContactId__r.' + dimField + ' dimVal'; }
        soql += ' FROM Application__c WHERE ContactId__c != null';
        if (statuses != null)                { soql += ' AND Status__c IN :statuses'; }
        if (String.isNotBlank(academicYear)) { soql += ' AND Program_Plan__r.Academic_Year__c = :academicYear'; }
        if (String.isNotBlank(programId))    { soql += ' AND AccountId__c = :programId'; }
        soql += ' GROUP BY AccountId__c, Program_Level__c';
        if (genderField != null) { soql += ', ContactId__r.' + genderField; }
        if (dimField != null)    { soql += ', ContactId__r.' + dimField; }
        soql += ' LIMIT ' + AGGREGATE_CAP;

        List<AggregateResult> results = (List<AggregateResult>) Database.query(soql);
        bs.truncated = results.size() >= AGGREGATE_CAP;

        Map<String, Bucket> byKey = new Map<String, Bucket>();
        Set<Id> accountIds = new Set<Id>();
        for (AggregateResult ar : results) {
            Integer cnt = (Integer) ar.get('recCount');
            Id accId = (Id) ar.get('accId');
            String lvl = blankToNs((String) ar.get('progLevel'));
            String gen = normalizeGender(genderField == null ? null : String.valueOf(ar.get('genderVal')));
            String dim = stateWise
                ? normalizeState(dimField == null ? null : String.valueOf(ar.get('dimVal')))
                : normalizeCategory(dimField == null ? null : String.valueOf(ar.get('dimVal')));

            if (accId != null) { accountIds.add(accId); }
            if (gen == 'O') { bs.anyOtherGender = true; }
            bs.dimsSeen.add(dim);

            String key = String.valueOf(accId) + '|' + lvl;
            Bucket b = byKey.get(key);
            if (b == null) {
                b = new Bucket(accId, lvl);
                byKey.put(key, b);
            }
            b.add(dim, gen, cnt);
        }

        bs.accById = accountIds.isEmpty()
            ? new Map<Id, Account>()
            : new Map<Id, Account>([
                SELECT Id, Name, RecordType.Name,
                       Parent.Name, Parent.RecordType.Name,
                       Parent.Parent.Name, Parent.Parent.RecordType.Name
                FROM Account
                WHERE Id IN :accountIds
            ]);

        bs.buckets = byKey.values();
        for (Bucket b : bs.buckets) {
            Account a = bs.accById.get(b.accountId);
            b.programme = (a == null) ? NOT_SPECIFIED : a.Name;
            b.school = (a == null) ? NOT_SPECIFIED : schoolOf(a);
        }
        return bs;
    }

    private class BucketSet {
        List<Bucket> buckets = new List<Bucket>();
        Set<String> dimsSeen = new Set<String>();
        Map<Id, Account> accById = new Map<Id, Account>();
        Boolean anyOtherGender = false;
        Boolean truncated = false;
        String dimField;
        String genderField;
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Dashboard — the same counts as the reports, summarised
    // ═════════════════════════════════════════════════════════════════════════
    /**
     * Headline numbers and charts for the admissions in scope. Everything here is derived
     * from the very same buckets the State Wise and Category Wise tables are built from,
     * so a figure on the dashboard and the matching column total on a report can never
     * drift apart.
     */
    @AuraEnabled
    public static DashboardData getAdmissionDashboard(String academicYear, String programId, String statusScope) {
        try {
            DashboardData d = new DashboardData();
            List<String> statuses = statusesFor(statusScope);

            BucketSet stateSet = loadBuckets(academicYear, programId, statusScope, true);
            BucketSet catSet = loadBuckets(academicYear, programId, statusScope, false);

            d.sourceFields.put('gender', stateSet.genderField == null ? '' : stateSet.genderField);
            d.sourceFields.put('state', stateSet.dimField == null ? '' : stateSet.dimField);
            d.sourceFields.put('category', catSet.dimField == null ? '' : catSet.dimField);
            d.truncated = stateSet.truncated || catSet.truncated;

            // State + gender totals, and admissions per Programme / per UG-PG.
            Map<String, Integer> byState = new Map<String, Integer>();
            Map<String, Integer> byGender = new Map<String, Integer>();
            Map<String, Integer> byProgramme = new Map<String, Integer>();
            Map<String, Integer> byLevel = new Map<String, Integer>();
            Set<Id> programmes = new Set<Id>();

            for (Bucket b : stateSet.buckets) {
                if (b.accountId != null) { programmes.add(b.accountId); }
                for (String dim : b.counts.keySet()) {
                    Integer n = b.counts.get(dim);
                    List<String> parts = dim.split('\\|');
                    bump(byState, parts[0], n);
                    bump(byGender, parts[1], n);
                    bump(byProgramme, b.programme, n);
                    bump(byLevel, b.level, n);
                    d.totalAdmissions += n;
                }
            }

            Map<String, Integer> byCategory = new Map<String, Integer>();
            for (Bucket b : catSet.buckets) {
                for (String dim : b.counts.keySet()) {
                    bump(byCategory, dim.split('\\|')[0], b.counts.get(dim));
                }
            }

            d.programmeCount = programmes.size();
            d.karnataka = zero(byState.get('Karnataka'));
            d.nonKarnataka = zero(byState.get('Non-Karnataka'));
            d.stateNotSpecified = zero(byState.get(NOT_SPECIFIED));
            d.male = zero(byGender.get('M'));
            d.female = zero(byGender.get('F'));
            d.genderNotSpecified = zero(byGender.get('O'));

            // Approved Intake across the Program Plans in scope, and how much of it is taken.
            for (Decimal v : approvedIntake(academicYear, programId, statuses).values()) {
                d.approvedIntake += (v == null ? 0 : v);
            }
            d.fillRate = (d.approvedIntake > 0)
                ? ((Decimal) d.totalAdmissions / d.approvedIntake * 100).setScale(1, System.RoundingMode.HALF_UP)
                : 0;

            d.byProgramme = topChartPoints(byProgramme, 8);
            d.byCategory = orderedChartPoints(byCategory, new List<String>{ 'GM', 'OBC', 'SC', 'ST', 'Other', NOT_SPECIFIED });
            d.byState = orderedChartPoints(byState, new List<String>{ 'Karnataka', 'Non-Karnataka', NOT_SPECIFIED });
            d.byGender = orderedChartPoints(
                new Map<String, Integer>{
                    'Male' => d.male, 'Female' => d.female, 'Not Specified' => d.genderNotSpecified
                },
                new List<String>{ 'Male', 'Female', 'Not Specified' }
            );
            d.byLevel = topChartPoints(byLevel, 5);
            d.scopeLabel = scopeLabel(academicYear, programId, statusScope, stateSet.accById);
            return d;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to load the dashboard: ' + e.getMessage());
        }
    }

    private static void bump(Map<String, Integer> m, String key, Integer n) {
        m.put(key, (m.containsKey(key) ? m.get(key) : 0) + n);
    }
    private static Integer zero(Integer v) { return v == null ? 0 : v; }

    /** Chart points in a fixed order, dropping buckets that hold nothing. */
    private static List<ChartPoint> orderedChartPoints(Map<String, Integer> counts, List<String> order) {
        List<ChartPoint> points = new List<ChartPoint>();
        for (String key : order) {
            Integer n = counts.get(key);
            if (n != null && n > 0) { points.add(new ChartPoint(key, n)); }
        }
        return points;
    }

    /** Largest first, capped — a bar per Programme is unreadable past a handful. */
    private static List<ChartPoint> topChartPoints(Map<String, Integer> counts, Integer limitTo) {
        List<ChartPoint> points = new List<ChartPoint>();
        for (String key : counts.keySet()) {
            if (counts.get(key) > 0) { points.add(new ChartPoint(key, counts.get(key))); }
        }
        points.sort();
        List<ChartPoint> top = new List<ChartPoint>();
        for (ChartPoint p : points) {
            if (top.size() >= limitTo) { break; }
            top.add(p);
        }
        return top;
    }

    /**
     * Approved Intake per (Programme, Level). Intake lives on the Program Plan, which
     * carries no UG/PG of its own — so each plan inherits the level of the applications
     * that point at it (the dominant one, where a plan has been used for both).
     */
    private static Map<String, Decimal> approvedIntake(String academicYear, String programId, List<String> statuses) {
        Map<String, Decimal> byProgrammeLevel = new Map<String, Decimal>();

        String planSoql = 'SELECT Id, hed__Account__c, Intake_Number__c FROM hed__Program_Plan__c WHERE Intake_Number__c != null';
        if (String.isNotBlank(academicYear)) { planSoql += ' AND Academic_Year__c = :academicYear'; }
        if (String.isNotBlank(programId))    { planSoql += ' AND hed__Account__c = :programId'; }
        planSoql += ' LIMIT 2000';

        Map<Id, hed__Program_Plan__c> plans = new Map<Id, hed__Program_Plan__c>(
            (List<hed__Program_Plan__c>) Database.query(planSoql)
        );
        if (plans.isEmpty()) { return byProgrammeLevel; }

        Set<Id> planIds = plans.keySet();
        String levelSoql = 'SELECT COUNT(Id) recCount, Program_Plan__c planId, Program_Level__c progLevel'
            + ' FROM Application__c WHERE Program_Plan__c IN :planIds';
        if (statuses != null) { levelSoql += ' AND Status__c IN :statuses'; }
        levelSoql += ' GROUP BY Program_Plan__c, Program_Level__c LIMIT ' + AGGREGATE_CAP;

        Map<Id, String> levelByPlan = new Map<Id, String>();
        Map<Id, Integer> bestCount = new Map<Id, Integer>();
        for (AggregateResult ar : (List<AggregateResult>) Database.query(levelSoql)) {
            Id planId = (Id) ar.get('planId');
            Integer cnt = (Integer) ar.get('recCount');
            if (bestCount.containsKey(planId) && bestCount.get(planId) >= cnt) { continue; }
            bestCount.put(planId, cnt);
            levelByPlan.put(planId, blankToNs((String) ar.get('progLevel')));
        }

        for (hed__Program_Plan__c pp : plans.values()) {
            String lvl = levelByPlan.get(pp.Id);
            // A plan nobody applied to contributes no row to the table, so its intake
            // would have nowhere to sit — skip it rather than inflate another level.
            if (lvl == null || pp.hed__Account__c == null) { continue; }
            String key = pp.hed__Account__c + '|' + lvl;
            Decimal running = byProgrammeLevel.containsKey(key) ? byProgrammeLevel.get(key) : 0;
            byProgrammeLevel.put(key, running + pp.Intake_Number__c);
        }
        return byProgrammeLevel;
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Report 3 — Result Analysis, students' performance during the academic year
    // ═════════════════════════════════════════════════════════════════════════
    /**
     * One row per semester of the selected batch (Program Plan).
     *
     *   Appeared in all the subjects → students whose every Course Connection in that
     *                                  semester carries a result (Pass or Fail); a single
     *                                  "In Complete" or blank means they did not appear
     *                                  in all the subjects.
     *   Passed                       → students whose every Course Connection in that
     *                                  semester is Pass.
     *   Pass %                       → passed Course Connections ÷ all Course Connections
     *                                  in that semester, per the client's definition
     *                                  ("overall pass percentage with count of course
     *                                  connection"), so it is subject-level, not
     *                                  student-level.
     *
     * Queried one semester at a time: a single query for the whole batch would group by
     * student × result and blow through the 2,000-row aggregate ceiling on any real cohort.
     */
    @AuraEnabled
    public static ReportGrid getResultAnalysisReport(String programPlanId, String termId) {
        if (String.isBlank(programPlanId)) {
            throw new AuraHandledException('Select a Batch (Program Plan) to run the Result Analysis report.');
        }
        try {
            return buildResultAnalysis(programPlanId, termId);
        } catch (Exception e) {
            throw new AuraHandledException('Failed to load the Result Analysis report: ' + e.getMessage());
        }
    }

    private static ReportGrid buildResultAnalysis(String programPlanId, String termId) {
        ReportGrid grid = new ReportGrid();
        grid.title = 'Result Analysis - Students performance during the academic year';
        grid.addLeadingColumn('Batch');
        grid.addLeadingColumn('Semester');
        grid.addLeadingColumn('Program');
        grid.addLeadingColumn('No of Students Appeared in all the subjects');
        grid.addLeadingColumn('No of Students Passed');
        grid.addLeadingColumn('Pass %');

        hed__Program_Plan__c plan = [
            SELECT Id, Name, Academic_Year__c, hed__Account__r.Name
            FROM hed__Program_Plan__c
            WHERE Id = :programPlanId
            LIMIT 1
        ];
        String batch = plan.Name;
        String program = plan.hed__Account__r == null ? NOT_SPECIFIED : plan.hed__Account__r.Name;

        List<TermRow> terms = orderedTerms(programPlanId);
        Integer appearedTotal = 0, passedTotal = 0, connTotal = 0, passConnTotal = 0;

        for (TermRow t : terms) {
            if (String.isNotBlank(termId) && t.id != termId) { continue; }
            Id thisTermId = t.id;

            // Grouped by student × result: enough to tell "passed everything" from
            // "passed something" without pulling a single Course Connection into memory.
            List<AggregateResult> ars = [
                SELECT COUNT(Id) recCount, hed__Contact__c studentId, Exam_Result_Status__c resultVal
                FROM hed__Course_Enrollment__c
                WHERE hed__Course_Offering__r.hed__Term__c = :thisTermId
                  AND hed__Contact__c != null
                GROUP BY hed__Contact__c, Exam_Result_Status__c
                LIMIT :AGGREGATE_CAP
            ];
            if (ars.isEmpty()) { continue; }
            if (ars.size() >= AGGREGATE_CAP) { grid.truncated = true; }

            Map<Id, StudentTally> tallies = new Map<Id, StudentTally>();
            Integer semConns = 0, semPassConns = 0;
            for (AggregateResult ar : ars) {
                Id studentId = (Id) ar.get('studentId');
                Integer cnt = (Integer) ar.get('recCount');
                String res = (String) ar.get('resultVal');

                StudentTally st = tallies.get(studentId);
                if (st == null) { st = new StudentTally(); tallies.put(studentId, st); }
                st.total += cnt;
                if (res == 'Pass')      { st.passed += cnt; semPassConns += cnt; }
                else if (res == 'Fail') { st.failed += cnt; }
                semConns += cnt;
            }

            Integer appeared = 0, passed = 0;
            for (StudentTally st : tallies.values()) {
                if (st.total > 0 && st.passed + st.failed == st.total) { appeared++; }
                if (st.total > 0 && st.passed == st.total)             { passed++; }
            }

            GridRow row = new GridRow(thisTermId);
            row.cells.add(batch);
            row.cells.add(t.label);
            row.cells.add(program);
            row.cells.add(String.valueOf(appeared));
            row.cells.add(String.valueOf(passed));
            row.cells.add(percent(semPassConns, semConns));
            grid.rows.add(row);

            appearedTotal += appeared;
            passedTotal += passed;
            connTotal += semConns;
            passConnTotal += semPassConns;
        }

        if (!grid.rows.isEmpty()) {
            grid.totalsRow.add('Total');
            grid.totalsRow.add('');
            grid.totalsRow.add('');
            grid.totalsRow.add(String.valueOf(appearedTotal));
            grid.totalsRow.add(String.valueOf(passedTotal));
            grid.totalsRow.add(percent(passConnTotal, connTotal));
        }

        grid.scopeLabel = batch
            + (String.isBlank(plan.Academic_Year__c) ? '' : ' · ' + plan.Academic_Year__c)
            + ' · ' + program;
        return grid;
    }

    private class StudentTally {
        Integer total = 0;
        Integer passed = 0;
        Integer failed = 0;
    }

    private static String percent(Integer part, Integer whole) {
        if (whole == null || whole == 0) { return '0.00%'; }
        Decimal pct = ((Decimal) part / whole * 100).setScale(2, System.RoundingMode.HALF_UP);
        return String.valueOf(pct) + '%';
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Normalisation
    // ═════════════════════════════════════════════════════════════════════════
    private static String blankToNs(String v) { return String.isBlank(v) ? NOT_SPECIFIED : v; }

    private static String normalizeGender(String raw) {
        if (String.isBlank(raw) || raw == 'null') { return 'O'; }
        String v = raw.trim().toLowerCase();
        if (v.startsWith('m')) { return 'M'; }
        if (v.startsWith('f')) { return 'F'; }
        return 'O';
    }

    /**
     * Values that say nothing about where a student is domiciled. They turn up because
     * Student_Category__c doubles as the state field in orgs with no dedicated one: a
     * student recorded as "SC" or "PGCET" has a social category and an admission route
     * on file, not an address, and counting them as an out-of-state admission would be
     * a straightforward error.
     */
    private static final Set<String> NON_STATE_VALUES = new Set<String>{
        'sc', 'st', 'obc', 'general', 'gm', 'gen', 'ews', 'pwd', 'mgt', 'pgcet', 'other'
    };

    /**
     * Karnataka vs everywhere else. A blank state — or a value that is not a state at
     * all — is reported as its own bucket rather than folded into Non-Karnataka, because
     * a student with no address on file is not evidence of an out-of-state admission and
     * the client's totals have to be defensible.
     */
    private static String normalizeState(String raw) {
        if (String.isBlank(raw) || raw == 'null') { return NOT_SPECIFIED; }
        String v = raw.trim().toLowerCase();
        if (v.contains('karnataka')) {
            return (v.startsWith('non') || v.contains('non-karnataka') || v.contains('non karnataka'))
                ? 'Non-Karnataka'
                : 'Karnataka';
        }
        // 'KA' is the state code DSU's own data entry uses for Karnataka.
        if (v == 'ka' || v == 'knt') { return 'Karnataka'; }
        if (NON_STATE_VALUES.contains(v)) { return NOT_SPECIFIED; }
        // SAARC and International are Student_Category__c values that do place the
        // student outside Karnataka, so they count as Non-Karnataka like any other state.
        return 'Non-Karnataka';
    }

    /**
     * GM / OBC / SC / ST, the four buckets the client's table prints. Anything else the
     * org records (EWS, PWD, SAARC, a free-text caste) lands in "Other" so it still
     * reaches the Total instead of vanishing — that column is only rendered when it is
     * non-empty, so clean data reproduces the client's layout exactly.
     */
    private static String normalizeCategory(String raw) {
        if (String.isBlank(raw) || raw == 'null') { return NOT_SPECIFIED; }
        String v = raw.trim().toUpperCase();
        if (v == 'SC' || v.startsWith('SC-') || v.contains('SCHEDULED CASTE')) { return 'SC'; }
        if (v == 'ST' || v.startsWith('ST-') || v.contains('SCHEDULED TRIBE')) { return 'ST'; }
        if (v.startsWith('OBC') || v.startsWith('BC') || v.contains('BACKWARD')) { return 'OBC'; }
        if (v == 'GM' || v == 'GEN' || v.startsWith('GENERAL') || v == 'OPEN' || v == 'UNRESERVED') { return 'GM'; }
        return 'Other';
    }

    /** Nearest School / College / University Department above the application's Account. */
    private static String schoolOf(Account a) {
        if (a.Parent != null && a.Parent.RecordType != null
            && SCHOOL_RECORD_TYPES.contains(a.Parent.RecordType.Name)) {
            return a.Parent.Name;
        }
        if (a.Parent != null && a.Parent.Parent != null && a.Parent.Parent.RecordType != null
            && SCHOOL_RECORD_TYPES.contains(a.Parent.Parent.RecordType.Name)) {
            return a.Parent.Parent.Name;
        }
        if (a.Parent != null && String.isNotBlank(a.Parent.Name)) { return a.Parent.Name; }
        return NOT_SPECIFIED;
    }

    /** null means "no status filter at all"; anything not a named scope is a picklist value. */
    private static List<String> statusesFor(String scope) {
        if (scope == SCOPE_ALL)      { return null; }
        if (scope == SCOPE_ENROLLED) { return ENROLLED_STATUSES; }
        if (String.isBlank(scope) || scope == SCOPE_ADMITTED) { return ADMITTED_STATUSES; }
        return new List<String>{ scope };
    }

    private static String scopeLabel(
        String academicYear, String programId, String statusScope, Map<Id, Account> accById
    ) {
        List<String> parts = new List<String>();
        parts.add(String.isBlank(academicYear) ? 'All Academic Years' : academicYear);
        Id progId = String.isBlank(programId) ? null : (Id) programId;
        if (progId != null && accById.containsKey(progId)) {
            parts.add(accById.get(progId).Name);
        }
        if (statusScope == SCOPE_ALL)           { parts.add('All Applications'); }
        else if (statusScope == SCOPE_ENROLLED) { parts.add('Enrolled'); }
        else if (String.isNotBlank(statusScope) && statusScope != SCOPE_ADMITTED) { parts.add(statusScope); }
        else                                    { parts.add('Admitted & beyond'); }
        return String.join(parts, ' · ');
    }

    private static void addTo(List<Integer> totals, Integer index, Integer value) {
        while (totals.size() <= index) { totals.add(0); }
        totals[index] = totals[index] + value;
    }

    /** One (Programme, Level) row, holding its counts keyed by dimension + gender. */
    private class Bucket implements Comparable {
        Id accountId;
        String level;
        String programme = '';
        String school = '';
        Map<String, Integer> counts = new Map<String, Integer>();

        Bucket(Id accountId, String level) { this.accountId = accountId; this.level = level; }

        void add(String dim, String gender, Integer n) {
            String k = dim + '|' + gender;
            counts.put(k, (counts.containsKey(k) ? counts.get(k) : 0) + n);
        }
        Integer get(String dim, String gender) {
            String k = dim + '|' + gender;
            return counts.containsKey(k) ? counts.get(k) : 0;
        }
        public Integer compareTo(Object other) {
            Bucket o = (Bucket) other;
            Integer c = nullSafe(this.school).compareTo(nullSafe(o.school));
            if (c != 0) { return c; }
            c = nullSafe(this.programme).compareTo(nullSafe(o.programme));
            if (c != 0) { return c; }
            return nullSafe(this.level).compareTo(nullSafe(o.level));
        }
        private String nullSafe(String v) { return v == null ? '' : v; }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Wrapper types — a generic two-row-header grid so the LWC renders all three
    // reports (and exports them) through one table, exactly as the client drew them.
    // ═════════════════════════════════════════════════════════════════════════
    public class Option {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        public Option(String label, String value) { this.label = label; this.value = value; }
    }

    public class ReportGrid {
        @AuraEnabled public String title = '';
        @AuraEnabled public String scopeLabel = '';
        /** Top header row. A plain column spans both header rows (rowspan 2). */
        @AuraEnabled public List<HeaderCell> headerRow1 = new List<HeaderCell>();
        /** Second header row — the M / F / O cells beneath each grouped column. */
        @AuraEnabled public List<HeaderCell> headerRow2 = new List<HeaderCell>();
        /** Flat leaf labels ("Karnataka - M"), used for the CSV export header. */
        @AuraEnabled public List<String> columnLabels = new List<String>();
        @AuraEnabled public List<GridRow> rows = new List<GridRow>();
        @AuraEnabled public List<String> totalsRow = new List<String>();
        /** Which Contact field each dimension was actually counted from. */
        @AuraEnabled public Map<String, String> sourceFields = new Map<String, String>();
        /** True when an aggregate hit the 2,000-group ceiling and the table is partial. */
        @AuraEnabled public Boolean truncated = false;

        void addLeadingColumn(String label) {
            headerRow1.add(new HeaderCell(label, 1, 2));
            columnLabels.add(label);
        }
        void addTrailingColumn(String label) { addLeadingColumn(label); }
        void addGroupColumn(String label, List<String> subLabels) {
            headerRow1.add(new HeaderCell(label, subLabels.size(), 1));
            for (String s : subLabels) {
                headerRow2.add(new HeaderCell(s, 1, 1));
                columnLabels.add(label + ' - ' + s);
            }
        }
    }

    public class HeaderCell {
        @AuraEnabled public String label;
        @AuraEnabled public Integer colspan;
        @AuraEnabled public Integer rowspan;
        public HeaderCell(String label, Integer colspan, Integer rowspan) {
            this.label = label; this.colspan = colspan; this.rowspan = rowspan;
        }
    }

    /** Sorts largest-first, so a chart reads top-down without the caller re-ordering it. */
    public class ChartPoint implements Comparable {
        @AuraEnabled public String label;
        @AuraEnabled public Integer value;
        public ChartPoint(String label, Integer value) {
            this.label = label;
            this.value = value == null ? 0 : value;
        }
        public Integer compareTo(Object other) {
            ChartPoint o = (ChartPoint) other;
            if (this.value != o.value) { return o.value - this.value; }
            return this.label == null ? 0 : this.label.compareTo(o.label);
        }
    }

    public class DashboardData {
        @AuraEnabled public String scopeLabel = '';
        @AuraEnabled public Integer totalAdmissions = 0;
        @AuraEnabled public Integer programmeCount = 0;
        @AuraEnabled public Integer karnataka = 0;
        @AuraEnabled public Integer nonKarnataka = 0;
        @AuraEnabled public Integer stateNotSpecified = 0;
        @AuraEnabled public Integer male = 0;
        @AuraEnabled public Integer female = 0;
        @AuraEnabled public Integer genderNotSpecified = 0;
        @AuraEnabled public Decimal approvedIntake = 0;
        /** Admissions as a percentage of Approved Intake; 0 when no intake is recorded. */
        @AuraEnabled public Decimal fillRate = 0;
        @AuraEnabled public List<ChartPoint> byProgramme = new List<ChartPoint>();
        @AuraEnabled public List<ChartPoint> byCategory = new List<ChartPoint>();
        @AuraEnabled public List<ChartPoint> byState = new List<ChartPoint>();
        @AuraEnabled public List<ChartPoint> byGender = new List<ChartPoint>();
        @AuraEnabled public List<ChartPoint> byLevel = new List<ChartPoint>();
        @AuraEnabled public Map<String, String> sourceFields = new Map<String, String>();
        @AuraEnabled public Boolean truncated = false;
    }

    public class GridRow {
        @AuraEnabled public String id;
        @AuraEnabled public List<String> cells = new List<String>();
        public GridRow(String id) { this.id = id; }
    }
}