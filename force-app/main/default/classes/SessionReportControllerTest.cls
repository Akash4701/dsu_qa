/**
 * SessionReportControllerTest
 * ---------------------------
 * Covers every SessionReportController API: session lists (all / paged /
 * per contact), filter options, KPI stats, the per-student summary report
 * (each plan / status filter combination and paging), the full export, the
 * student detail view and the 7-day weekly activity summary.
 */
@isTest
private class SessionReportControllerTest {

    @testSetup
    static void setupData() {
        Account acc = new Account(Name = 'Test Program Account');
        insert acc;

        Contact student = new Contact(FirstName = 'Sam', LastName = 'Session', Email = 'sam.session@example.com');
        insert student;

        hed__Program_Plan__c plan = new hed__Program_Plan__c(Name = 'MBA', hed__Account__c = acc.Id);
        insert plan;

        // Term_Status__c is a formula ('Ongoing' when today is within the term
        // window), so drive it via the start/end dates rather than setting it.
        hed__Term__c term = new hed__Term__c(
            Name = 'Sem 1',
            Term_Reference__c = 'Semester 1',
            hed__Start_Date__c = Date.today().addDays(-10),
            hed__End_Date__c   = Date.today().addDays(10),
            hed__Account__c = acc.Id
        );
        insert term;

        hed__Affiliation__c aff = new hed__Affiliation__c(
            hed__Contact__c = student.Id,
            hed__Account__c = acc.Id,
            hed__Status__c  = 'Current',
            Program_Plan__c = plan.Id,
            Roll_Number__c  = 'R-1001',
            DSU_Email__c    = 'sam.session@dsu.edu.in'
        );
        insert aff;

        hed__Program_Enrollment__c pe = new hed__Program_Enrollment__c(
            hed__Contact__c = student.Id,
            Term__c         = term.Id
        );
        insert pe;

        // Two sessions for the contact.
        List<Portal_Session__c> sessions = new List<Portal_Session__c>{
            new Portal_Session__c(
                Contact__c       = student.Id,
                Login_Time__c    = Datetime.now().addHours(-2),
                Logout_Time__c   = Datetime.now().addHours(-1),
                Session_Status__c = 'Completed'
            ),
            new Portal_Session__c(
                Contact__c       = student.Id,
                Login_Time__c    = Datetime.now().addMinutes(-30),
                Session_Status__c = 'Active'
            )
        };
        insert sessions;
    }

    @isTest
    static void testGetAllSessions() {
        Test.startTest();
        List<Map<String, Object>> rows = SessionReportController.getAllSessions();
        Test.stopTest();

        System.assertEquals(2, rows.size(), 'Both sessions returned');

        Map<String, Object> row = rows[0];
        System.assertEquals('Sam Session', row.get('contactName'), 'Contact name resolved');
        System.assertEquals('sam.session@example.com', row.get('contactEmail'), 'Contact email resolved');
        System.assertEquals('R-1001', row.get('rollNumber'), 'Roll number from affiliation');
        System.assertEquals('sam.session@dsu.edu.in', row.get('dsuEmail'), 'DSU email from affiliation');
        System.assertEquals('MBA', row.get('programPlan'), 'Program plan name enriched');
        System.assertEquals('Test Program Account', row.get('programName'), 'Program (account) name enriched');
        System.assertEquals('Semester 1', row.get('currentSemester'), 'Ongoing term reference enriched');
    }

    @isTest
    static void testGetPagedSessionsDefaults() {
        Test.startTest();
        Map<String, Object> result = SessionReportController.getPagedSessions(null, null, null);
        Test.stopTest();

        System.assertEquals(2, (Integer) result.get('totalCount'), 'Both sessions counted');
        System.assertEquals(1, result.get('pageNumber'), 'Defaults to page 1');
        System.assertEquals(20, result.get('pageSize'), 'Defaults to page size 20');
        System.assertEquals(1, result.get('totalPages'), 'Single page for two records');
        System.assertEquals(2, ((List<Portal_Session__c>) result.get('sessions')).size(), 'Sessions returned');
    }

    @isTest
    static void testGetPagedSessionsWithSearch() {
        Test.startTest();
        Map<String, Object> match  = SessionReportController.getPagedSessions('Session', 1, 10);
        Map<String, Object> noHit  = SessionReportController.getPagedSessions('NoSuchName', 1, 10);
        Test.stopTest();

        System.assertEquals(2, (Integer) match.get('totalCount'), 'Name search matches the student');
        System.assertEquals(0, (Integer) noHit.get('totalCount'), 'Unmatched search returns none');
        System.assertEquals(1, noHit.get('totalPages'), 'Zero results still reports one page');
    }

    // ─── getStudentWeeklyActivity ────────────────────────────────────────────
    // Session_Duration_Minutes__c is a formula over Login/Logout, so durations are
    // driven by the timestamps rather than assigned.
    private static Portal_Session__c session(Id contactId, Integer daysAgo, Integer atHour, Integer lengthMins) {
        Datetime login = Datetime.newInstance(
            Date.today().addDays(-daysAgo), Time.newInstance(atHour, 0, 0, 0)
        );
        return new Portal_Session__c(
            Contact__c        = contactId,
            Login_Time__c     = login,
            Logout_Time__c    = login.addMinutes(lengthMins),
            Session_Status__c = 'Completed'
        );
    }

    @isTest
    static void testWeeklyActivityAggregatesRealSessions() {
        Contact ct = new Contact(FirstName = 'Week', LastName = 'Window');
        insert ct;

        insert new List<Portal_Session__c>{
            session(ct.Id, 1,  10, 30),   // in window
            session(ct.Id, 1,  14, 20),   // in window, same day  → 2 sessions / 1 active day
            session(ct.Id, 5,  11, 45),   // in window, longest
            session(ct.Id, 20, 11, 60)    // outside the 7-day window → must be ignored
        };

        Test.startTest();
        Map<String, Object> res = SessionReportController.getStudentWeeklyActivity(ct.Id);
        Test.stopTest();

        List<Object>        days    = (List<Object>) res.get('days');
        Map<String, Object> summary = (Map<String, Object>) res.get('summary');

        System.assertEquals(7, days.size(), 'Always seven day buckets');
        System.assertEquals(3, summary.get('totalSessions'), 'Only in-window sessions counted');
        System.assertEquals(3, summary.get('totalLogins'), 'Logins match session records');
        System.assertEquals(2, summary.get('activeDays'), 'Two distinct days had activity');
        System.assertEquals(95, ((Decimal) summary.get('totalMinutes')).setScale(0),
            'Sums in-window durations only (30 + 20 + 45)');
        System.assertEquals(45, ((Decimal) summary.get('longestSessionMinutes')).setScale(0),
            'Longest single session, not the largest daily total');

        Datetime expectedRecent = Datetime.newInstance(
            Date.today().addDays(-1), Time.newInstance(14, 0, 0, 0)
        );
        System.assertEquals(expectedRecent, (Datetime) summary.get('mostRecentLogin'),
            'Most recent login inside the window');
        System.assertEquals(Date.today().addDays(-6), summary.get('windowStart'), 'Window starts six days back');
        System.assertEquals(Date.today(), summary.get('windowEnd'), 'Window ends today');
    }

    @isTest
    static void testWeeklyActivityEmptyWindowStillReportsLastSeen() {
        Contact ct = new Contact(FirstName = 'Stale', LastName = 'Window');
        insert ct;
        insert new List<Portal_Session__c>{ session(ct.Id, 30, 9, 25) };

        Test.startTest();
        Map<String, Object> res = SessionReportController.getStudentWeeklyActivity(ct.Id);
        Test.stopTest();

        Map<String, Object> summary = (Map<String, Object>) res.get('summary');

        System.assertEquals(7, ((List<Object>) res.get('days')).size(), 'Seven buckets even with no activity');
        System.assertEquals(0, summary.get('totalSessions'), 'Nothing inside the window');
        System.assertEquals(0, summary.get('activeDays'), 'No active days');
        System.assertEquals(null, summary.get('mostRecentLogin'), 'No in-window login to report');
        System.assertEquals(
            Datetime.newInstance(Date.today().addDays(-30), Time.newInstance(9, 0, 0, 0)),
            (Datetime) summary.get('lastSeen'),
            'Falls back to the student\'s last login of any age'
        );
    }

    @isTest
    static void testWeeklyActivityNeverLoggedIn() {
        Contact ct = new Contact(FirstName = 'Never', LastName = 'LoggedIn');
        insert ct;

        Test.startTest();
        Map<String, Object> res = SessionReportController.getStudentWeeklyActivity(ct.Id);
        Test.stopTest();

        Map<String, Object> summary = (Map<String, Object>) res.get('summary');
        System.assertEquals(0, summary.get('totalSessions'), 'No sessions at all');
        System.assertEquals(null, summary.get('lastSeen'), 'No last-seen for a student who never logged in');
    }

    @isTest
    static void testGetContactSessions() {
        Contact ct = [SELECT Id FROM Contact WHERE Email = 'sam.session@example.com' LIMIT 1];

        Test.startTest();
        List<Portal_Session__c> sessions = SessionReportController.getContactSessions(ct.Id);
        Test.stopTest();

        System.assertEquals(2, sessions.size(), 'Both sessions for the contact returned');
    }

    // ─── helpers for the report tests ────────────────────────────────────────
    // Sam's two setup sessions are at most 2 hours old, so a window from yesterday
    // to today always contains them, even just after midnight.
    private static String yesterday() { return String.valueOf(Date.today().addDays(-1)); }
    private static String today()     { return String.valueOf(Date.today()); }

    private static Contact sam() {
        return [SELECT Id FROM Contact WHERE Email = 'sam.session@example.com' LIMIT 1];
    }

    private static Id mbaPlanId() {
        return [SELECT Id FROM hed__Program_Plan__c WHERE Name = 'MBA' LIMIT 1].Id;
    }

    // A student with one completed session and no affiliation at all.
    private static Contact studentWithoutAffiliation() {
        Contact ct = new Contact(FirstName = 'Nora', LastName = 'NoAff', Email = 'nora@example.com');
        insert ct;
        insert session(ct.Id, 0, 0, 15);
        return ct;
    }

    // ─── getFilterOptions ────────────────────────────────────────────────────

    @isTest
    static void testGetFilterOptionsListsBatches() {
        Test.startTest();
        Map<String, Object> res = SessionReportController.getFilterOptions();
        Test.stopTest();

        List<Map<String, Object>> batches = (List<Map<String, Object>>) res.get('batches');
        System.assertEquals(1, batches.size(), 'One program plan in setup');
        System.assertEquals('MBA', batches[0].get('label'), 'Label is the plan name');
        System.assertEquals(mbaPlanId(), batches[0].get('value'), 'Value is the plan Id');
    }

    // ─── getDashboardStats ───────────────────────────────────────────────────

    @isTest
    static void testDashboardStatsForDateRange() {
        Test.startTest();
        Map<String, Object> res = SessionReportController.getDashboardStats(yesterday(), today());
        Test.stopTest();

        System.assertEquals(1, res.get('totalStudents'), 'One distinct student ever');
        System.assertEquals(1, res.get('studentsLoggedIn'), 'One distinct student in range');
        System.assertEquals(2, res.get('totalSessions'), 'Both sessions in range');
        System.assertEquals(1, res.get('currentlyOnline'), 'One Active session');
        System.assertNotEquals(null, res.get('avgSessionMinutes'), 'Average is always populated');
    }

    @isTest
    static void testDashboardStatsDefaultsAndInvalidDates() {
        Test.startTest();
        Map<String, Object> defaults = SessionReportController.getDashboardStats(null, null);
        Map<String, Object> invalid  = SessionReportController.getDashboardStats('not-a-date', 'bad');
        Test.stopTest();

        System.assertEquals(2, defaults.get('totalSessions'), 'Blank dates default to the last 30 days');
        System.assertEquals(2, invalid.get('totalSessions'), 'Unparseable dates fall back to the default window');
    }

    @isTest
    static void testDashboardStatsEmptyRange() {
        String from2000 = '2000-01-01';
        String to2000   = '2000-01-31';

        Test.startTest();
        Map<String, Object> res = SessionReportController.getDashboardStats(from2000, to2000);
        Test.stopTest();

        System.assertEquals(0, res.get('studentsLoggedIn'), 'No students in an empty range');
        System.assertEquals(0, res.get('totalSessions'), 'No sessions in an empty range');
        System.assertEquals(0, res.get('avgSessionMinutes'), 'Null average reported as 0');
        System.assertEquals(1, res.get('totalStudents'), 'Lifetime total ignores the range');
    }

    // ─── getStudentSummaryReport ─────────────────────────────────────────────

    @isTest
    static void testSummaryReportNoFilters() {
        Test.startTest();
        Map<String, Object> res = SessionReportController.getStudentSummaryReport(
            yesterday(), today(), null, null, null, null, null);
        Test.stopTest();

        System.assertEquals(1, res.get('total'), 'One student row');
        System.assertEquals(1, res.get('pageNumber'), 'Defaults to page 1');
        System.assertEquals(10, res.get('pageSize'), 'Defaults to page size 10');

        Map<String, Object> row = ((List<Map<String, Object>>) res.get('rows'))[0];
        System.assertEquals(sam().Id, row.get('contactId'));
        System.assertEquals('Sam Session', row.get('studentName'));
        System.assertEquals('R-1001', row.get('rollNumber'), 'Roll number from current affiliation');
        System.assertEquals(2, row.get('sessionCount'), 'Sessions grouped per student');
        System.assertEquals('Online', row.get('status'), 'Student with an Active session is Online');
        System.assertNotEquals(null, row.get('firstLogin'));
    }

    @isTest
    static void testSummaryReportByPlan() {
        Test.startTest();
        Map<String, Object> res = SessionReportController.getStudentSummaryReport(
            yesterday(), today(), mbaPlanId(), null, null, 1, 10);
        Test.stopTest();

        System.assertEquals(1, res.get('total'), 'Student in the MBA plan is included');
        Map<String, Object> row = ((List<Map<String, Object>>) res.get('rows'))[0];
        System.assertEquals(2, row.get('sessionCount'));
    }

    @isTest
    static void testSummaryReportByPlanAndStatus() {
        Test.startTest();
        Map<String, Object> res = SessionReportController.getStudentSummaryReport(
            yesterday(), today(), mbaPlanId(), null, 'Completed', 1, 10);
        Test.stopTest();

        Map<String, Object> row = ((List<Map<String, Object>>) res.get('rows'))[0];
        System.assertEquals(1, row.get('sessionCount'), 'Only the Completed session is counted');
        System.assertEquals(60, ((Decimal) row.get('totalMinutes')).setScale(0), 'Completed session lasted 60 minutes');
        System.assertEquals(60, ((Decimal) row.get('avgMinutes')).setScale(0), 'Average of a single session');
    }

    @isTest
    static void testSummaryReportByStatusOnly() {
        Test.startTest();
        Map<String, Object> res = SessionReportController.getStudentSummaryReport(
            yesterday(), today(), null, 'Sam', 'Active', 1, 10);
        Test.stopTest();

        System.assertEquals(1, res.get('total'));
        Map<String, Object> row = ((List<Map<String, Object>>) res.get('rows'))[0];
        System.assertEquals(1, row.get('sessionCount'), 'Only the Active session is counted');
        System.assertEquals('Online', row.get('status'));
    }

    @isTest
    static void testSummaryReportPlanWithNoStudentsReturnsEmpty() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        hed__Program_Plan__c emptyPlan = new hed__Program_Plan__c(Name = 'Empty Plan', hed__Account__c = acc.Id);
        insert emptyPlan;

        Test.startTest();
        Map<String, Object> res = SessionReportController.getStudentSummaryReport(
            yesterday(), today(), emptyPlan.Id, null, null, 1, 25);
        Test.stopTest();

        System.assertEquals(0, res.get('total'), 'No current affiliations on the plan');
        System.assertEquals(1, res.get('totalPages'));
        System.assertEquals(25, res.get('pageSize'), 'Requested page size is echoed back');
        System.assertEquals(0, ((List<Object>) res.get('rows')).size());
    }

    @isTest
    static void testSummaryReportSearchMissAndPageClamp() {
        studentWithoutAffiliation();

        Test.startTest();
        Map<String, Object> miss    = SessionReportController.getStudentSummaryReport(
            yesterday(), today(), null, 'NoSuchStudent', null, 1, 10);
        Map<String, Object> clamped = SessionReportController.getStudentSummaryReport(
            yesterday(), today(), null, null, null, 9, 1);
        Test.stopTest();

        System.assertEquals(0, miss.get('total'), 'Unmatched search returns no rows');
        System.assertEquals(1, miss.get('totalPages'), 'Zero rows still reports one page');

        System.assertEquals(2, clamped.get('total'), 'Sam and Nora');
        System.assertEquals(2, clamped.get('totalPages'), 'Page size 1 → two pages');
        System.assertEquals(2, clamped.get('pageNumber'), 'Page 9 is clamped to the last page');
        System.assertEquals(1, ((List<Object>) clamped.get('rows')).size(), 'One row per page');
    }

    @isTest
    static void testSummaryReportStudentWithoutAffiliation() {
        studentWithoutAffiliation();

        Test.startTest();
        Map<String, Object> res = SessionReportController.getStudentSummaryReport(
            null, null, null, 'Nora', null, 1, 10);
        Test.stopTest();

        Map<String, Object> row = ((List<Map<String, Object>>) res.get('rows'))[0];
        System.assertEquals('Nora NoAff', row.get('studentName'));
        System.assertEquals('', row.get('rollNumber'), 'No affiliation → blank roll number');
        System.assertEquals('Completed', row.get('status'), 'No Active session → Completed');
    }

    // ─── exportAllStudentsReport ─────────────────────────────────────────────

    @isTest
    static void testExportAllStudentsEnrichesRows() {
        Test.startTest();
        List<Map<String, Object>> rows = SessionReportController.exportAllStudentsReport(yesterday(), today(), null);
        Test.stopTest();

        System.assertEquals(1, rows.size(), 'One row per student');
        Map<String, Object> row = rows[0];
        System.assertEquals('Sam Session', row.get('studentName'));
        System.assertEquals('sam.session@example.com', row.get('email'));
        System.assertEquals('R-1001', row.get('usn'));
        System.assertEquals('sam.session@dsu.edu.in', row.get('universityEmail'));
        System.assertEquals('Test Program Account', row.get('programName'));
        System.assertEquals('MBA', row.get('batch'));
        System.assertEquals('Semester 1', row.get('semester'), 'Ongoing term reference');
        System.assertEquals(2, row.get('totalSessions'));
        System.assertNotEquals(null, row.get('lastLogin'));
    }

    @isTest
    static void testExportAllStudentsByStatus() {
        Test.startTest();
        List<Map<String, Object>> rows = SessionReportController.exportAllStudentsReport(yesterday(), today(), 'Completed');
        Test.stopTest();

        System.assertEquals(1, rows.size());
        System.assertEquals(1, rows[0].get('totalSessions'), 'Only Completed sessions are counted');
    }

    @isTest
    static void testExportStudentWithoutAffiliationUsesBlanks() {
        studentWithoutAffiliation();

        Test.startTest();
        List<Map<String, Object>> rows = SessionReportController.exportAllStudentsReport(null, null, 'Completed');
        Test.stopTest();

        Map<String, Object> nora = null;
        for (Map<String, Object> r : rows) {
            if ('Nora NoAff'.equals(r.get('studentName'))) nora = r;
        }
        System.assertNotEquals(null, nora, 'Student without an affiliation is still exported');
        System.assertEquals('', nora.get('usn'));
        System.assertEquals('', nora.get('universityEmail'));
        System.assertEquals('', nora.get('programName'));
        System.assertEquals('', nora.get('batch'));
        System.assertEquals(null, nora.get('semester'), 'No enrollment → no semester');
    }

    // ─── getStudentDetail ────────────────────────────────────────────────────

    @isTest
    static void testStudentDetailWithDateRange() {
        Test.startTest();
        Map<String, Object> res = SessionReportController.getStudentDetail(sam().Id, yesterday(), today());
        Test.stopTest();

        System.assertEquals('Sam Session', res.get('contactName'));
        System.assertEquals('sam.session@example.com', res.get('contactEmail'));
        System.assertEquals('R-1001', res.get('rollNumber'));
        System.assertEquals('sam.session@dsu.edu.in', res.get('dsuEmail'));
        System.assertEquals('Test Program Account', res.get('programName'));
        System.assertEquals('MBA', res.get('batchName'));
        System.assertEquals(2, res.get('totalSessions'));
        System.assertEquals(2, ((List<Object>) res.get('timeline')).size(), 'One timeline entry per session');
        System.assertEquals(true, res.get('isOnline'), 'Has an Active session');
        System.assertNotEquals(null, res.get('firstLogin'));
        System.assertNotEquals(null, res.get('lastLogout'), 'Completed session has a logout time');
    }

    @isTest
    static void testStudentDetailAllTimeWithoutAffiliation() {
        Id noraId = studentWithoutAffiliation().Id;

        Test.startTest();
        Map<String, Object> res = SessionReportController.getStudentDetail(noraId, null, null);
        Test.stopTest();

        System.assertEquals('Nora NoAff', res.get('contactName'));
        System.assertEquals('', res.get('rollNumber'), 'No affiliation → blank fields');
        System.assertEquals('', res.get('batchName'));
        System.assertEquals(1, res.get('totalSessions'), 'Blank dates → all sessions');
        System.assertEquals(false, res.get('isOnline'), 'Only a Completed session');
        System.assertEquals(15, ((Decimal) res.get('totalMinutes')).setScale(0));
    }
}