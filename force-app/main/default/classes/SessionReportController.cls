public with sharing class SessionReportController {

    // ─── Private Helpers ──────────────────────────────────────────────────────

    private static DateTime toStartOfDay(String ds) {
        if (String.isBlank(ds)) return null;
        try {
            Date d = Date.valueOf(ds);
            return DateTime.newInstance(d, Time.newInstance(0, 0, 0, 0));
        } catch (Exception e) { return null; }
    }

    private static DateTime toEndOfDay(String ds) {
        if (String.isBlank(ds)) return null;
        try {
            Date d = Date.valueOf(ds);
            return DateTime.newInstance(d, Time.newInstance(23, 59, 59, 999));
        } catch (Exception e) { return null; }
    }

    // ─── Used by sessionReportDashboard ──────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static List<Map<String,Object>> getAllSessions() {
        List<Portal_Session__c> sessions = [
            SELECT Id, Name,
                   Contact__c,
                   Contact__r.Name,
                   Contact__r.Email,
                   Login_Time__c,
                   Logout_Time__c,
                   Session_Duration_Minutes__c,
                   Session_Status__c,
                   CreatedDate
            FROM Portal_Session__c
            ORDER BY Login_Time__c DESC
            LIMIT 1000
        ];

        Set<Id> contactIds = new Set<Id>();
        for (Portal_Session__c s : sessions) {
            if (s.Contact__c != null) contactIds.add(s.Contact__c);
        }

        Map<Id, hed__Affiliation__c> affMap = new Map<Id, hed__Affiliation__c>();
        if (!contactIds.isEmpty()) {
            for (hed__Affiliation__c a : [
                SELECT hed__Contact__c,
                       Roll_Number__c,
                       DSU_Email__c,
                       hed__Account__r.Name,
                       Program_Plan__r.Name
                FROM hed__Affiliation__c
                WHERE hed__Contact__c IN :contactIds
                  AND hed__Status__c = 'Current'
                ORDER BY CreatedDate DESC
            ]) {
                if (!affMap.containsKey(a.hed__Contact__c)) {
                    affMap.put(a.hed__Contact__c, a);
                }
            }
        }

        Map<Id, String> semesterMap = new Map<Id, String>();
        if (!contactIds.isEmpty()) {
            for (hed__Program_Enrollment__c pe : [
                SELECT hed__Contact__c, Term__r.Term_Reference__c
                FROM hed__Program_Enrollment__c
                WHERE hed__Contact__c IN :contactIds
                  AND Term__r.Term_Status__c = 'Ongoing'
                LIMIT 1000
            ]) {
                if (!semesterMap.containsKey(pe.hed__Contact__c) && pe.Term__r != null) {
                    semesterMap.put(pe.hed__Contact__c, pe.Term__r.Term_Reference__c);
                }
            }
        }

        List<Map<String,Object>> result = new List<Map<String,Object>>();
        for (Portal_Session__c s : sessions) {
            hed__Affiliation__c aff = affMap.get(s.Contact__c);
            result.add(new Map<String,Object>{
                'Id'                          => s.Id,
                'Name'                        => s.Name,
                'Contact__c'                  => s.Contact__c,
                'contactName'                 => s.Contact__r != null ? s.Contact__r.Name  : '',
                'contactEmail'                => s.Contact__r != null ? s.Contact__r.Email : '',
                'Login_Time__c'               => s.Login_Time__c,
                'Logout_Time__c'              => s.Logout_Time__c,
                'Session_Duration_Minutes__c' => s.Session_Duration_Minutes__c,
                'Session_Status__c'           => s.Session_Status__c,
                'rollNumber'                  => aff != null ? aff.Roll_Number__c : null,
                'dsuEmail'                    => aff != null ? aff.DSU_Email__c   : null,
                'programName'                 => aff != null && aff.hed__Account__r != null ? aff.hed__Account__r.Name : null,
                'programPlan'                 => aff != null && aff.Program_Plan__r != null ? aff.Program_Plan__r.Name : null,
                'currentSemester'             => semesterMap.get(s.Contact__c)
            });
        }
        return result;
    }

    // ─── Paginated list with optional search ─────────────────────────────────
    @AuraEnabled
    public static Map<String, Object> getPagedSessions(
        String  searchName,
        Integer pageNumber,
        Integer pageSize
    ) {
        if (pageNumber == null || pageNumber < 1) pageNumber = 1;
        if (pageSize   == null || pageSize   < 1) pageSize   = 20;

        String  likeFilter = String.isBlank(searchName)
                           ? '%'
                           : '%' + String.escapeSingleQuotes(searchName.trim()) + '%';
        Integer offsetVal  = (pageNumber - 1) * pageSize;

        List<Portal_Session__c> sessions = [
            SELECT Id, Name,
                   Contact__c,
                   Contact__r.Name,
                   Contact__r.Email,
                   Login_Time__c,
                   Logout_Time__c,
                   Session_Duration_Minutes__c,
                   Session_Status__c
            FROM Portal_Session__c
            WHERE Contact__r.Name LIKE :likeFilter
            ORDER BY Login_Time__c DESC
            LIMIT :pageSize
            OFFSET :offsetVal
        ];

        Integer totalCount = [
            SELECT COUNT()
            FROM Portal_Session__c
            WHERE Contact__r.Name LIKE :likeFilter
        ];

        Integer totalPages = totalCount == 0
                           ? 1
                           : (Integer) Math.ceil((Double) totalCount / pageSize);

        return new Map<String, Object>{
            'sessions'   => sessions,
            'totalCount' => totalCount,
            'totalPages' => totalPages,
            'pageNumber' => pageNumber,
            'pageSize'   => pageSize
        };
    }

    // ─── All sessions for one contact (detail view) ───────────────────────────
    @AuraEnabled(cacheable=true)
    public static List<Portal_Session__c> getContactSessions(Id contactId) {
        return [
            SELECT Id, Name,
                   Contact__c,
                   Contact__r.Name,
                   Contact__r.Email,
                   Login_Time__c,
                   Logout_Time__c,
                   Session_Duration_Minutes__c,
                   Session_Status__c
            FROM Portal_Session__c
            WHERE Contact__c = :contactId
            ORDER BY Login_Time__c DESC
        ];
    }

    // ─── Filter options for dropdowns ────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getFilterOptions() {
        List<Map<String,Object>> batches = new List<Map<String,Object>>();
        for (hed__Program_Plan__c pp : [
            SELECT Id, Name FROM hed__Program_Plan__c ORDER BY Name LIMIT 200
        ]) {
            batches.add(new Map<String,Object>{ 'label' => pp.Name, 'value' => pp.Id });
        }
        return new Map<String,Object>{ 'batches' => batches };
    }

    // ─── KPI dashboard stats ─────────────────────────────────────────────────
    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getDashboardStats(String dateFrom, String dateTo) {
        DateTime dtFrom = toStartOfDay(dateFrom);
        DateTime dtTo   = toEndOfDay(dateTo);
        if (dtFrom == null) dtFrom = DateTime.now().addDays(-30);
        if (dtTo   == null) dtTo   = DateTime.now();

        // Period aggregates
        List<AggregateResult> periodAgg = [
            SELECT COUNT_DISTINCT(Contact__c) uniqueStudents,
                   COUNT(Id) totalSessions,
                   AVG(Session_Duration_Minutes__c) avgMinutes
            FROM Portal_Session__c
            WHERE Login_Time__c >= :dtFrom AND Login_Time__c <= :dtTo
        ];

        // Total distinct students ever
        List<AggregateResult> totalAgg = [
            SELECT COUNT_DISTINCT(Contact__c) total
            FROM Portal_Session__c
        ];

        // Currently active
        Integer currentlyOnline = [
            SELECT COUNT() FROM Portal_Session__c WHERE Session_Status__c = 'Active'
        ];

        AggregateResult pa = periodAgg[0];
        Integer uniqueStudents = pa.get('uniqueStudents') == null ? 0 : Integer.valueOf(pa.get('uniqueStudents'));
        Integer totalSessions  = pa.get('totalSessions')  == null ? 0 : Integer.valueOf(pa.get('totalSessions'));
        Decimal avgMinutes     = pa.get('avgMinutes')     == null ? 0 : (Decimal)pa.get('avgMinutes');
        Integer totalStudents  = totalAgg[0].get('total') == null ? 0 : Integer.valueOf(totalAgg[0].get('total'));

        return new Map<String,Object>{
            'totalStudents'     => totalStudents,
            'studentsLoggedIn'  => uniqueStudents,
            'currentlyOnline'   => currentlyOnline,
            'totalSessions'     => totalSessions,
            'avgSessionMinutes' => avgMinutes.setScale(0)
        };
    }

    // ─── Paginated student session summary (grouped per student) ─────────────
    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getStudentSummaryReport(
        String  dateFrom,
        String  dateTo,
        String  programPlanId,
        String  studentSearch,
        String  statusFilter,
        Integer pageNumber,
        Integer pageSize
    ) {
        if (pageNumber == null || pageNumber < 1) pageNumber = 1;
        if (pageSize   == null || pageSize   < 1) pageSize   = 10;

        DateTime dtFrom = toStartOfDay(dateFrom);
        DateTime dtTo   = toEndOfDay(dateTo);
        if (dtFrom == null) dtFrom = DateTime.now().addDays(-30);
        if (dtTo   == null) dtTo   = DateTime.now();

        String nameLike = String.isBlank(studentSearch)
            ? '%'
            : '%' + String.escapeSingleQuotes(studentSearch.trim()) + '%';

        // Optional: filter by program plan
        Set<Id> planContactIds = null;
        if (!String.isBlank(programPlanId)) {
            planContactIds = new Set<Id>();
            for (hed__Affiliation__c a : [
                SELECT hed__Contact__c FROM hed__Affiliation__c
                WHERE Program_Plan__c = :programPlanId AND hed__Status__c = 'Current'
            ]) {
                if (a.hed__Contact__c != null) planContactIds.add(a.hed__Contact__c);
            }
            if (planContactIds.isEmpty()) {
                return new Map<String,Object>{
                    'rows' => new List<Object>(), 'total' => 0,
                    'totalPages' => 1, 'pageNumber' => 1, 'pageSize' => pageSize
                };
            }
        }

        // Aggregate sessions per student
        List<AggregateResult> allAgg = buildAggregateQuery(
            dtFrom, dtTo, nameLike, planContactIds, statusFilter
        );

        Integer total      = allAgg.size();
        Integer totalPages = total == 0 ? 1 : (Integer)Math.ceil((Double)total / pageSize);
        pageNumber = Math.min(pageNumber, totalPages);
        Integer startIdx = (pageNumber - 1) * pageSize;
        Integer endIdx   = Math.min(startIdx + pageSize, total);

        // Collect contact IDs for this page
        Set<Id> pageContactIds = new Set<Id>();
        for (Integer i = startIdx; i < endIdx; i++) {
            pageContactIds.add((Id)allAgg[i].get('cId'));
        }

        // Fetch affiliation data for this page
        Map<Id, hed__Affiliation__c> affMap = new Map<Id, hed__Affiliation__c>();
        if (!pageContactIds.isEmpty()) {
            for (hed__Affiliation__c a : [
                SELECT hed__Contact__c, Roll_Number__c
                FROM hed__Affiliation__c
                WHERE hed__Contact__c IN :pageContactIds AND hed__Status__c = 'Current'
                ORDER BY CreatedDate DESC
            ]) {
                if (!affMap.containsKey(a.hed__Contact__c)) affMap.put(a.hed__Contact__c, a);
            }
        }

        // Identify which page contacts have active sessions
        Set<Id> activeContactIds = new Set<Id>();
        if (!pageContactIds.isEmpty()) {
            for (Portal_Session__c s : [
                SELECT Contact__c FROM Portal_Session__c
                WHERE Contact__c IN :pageContactIds AND Session_Status__c = 'Active'
            ]) {
                activeContactIds.add(s.Contact__c);
            }
        }

        List<Map<String,Object>> rows = new List<Map<String,Object>>();
        for (Integer i = startIdx; i < endIdx; i++) {
            AggregateResult ar  = allAgg[i];
            Id              cId = (Id)ar.get('cId');
            hed__Affiliation__c aff = affMap.get(cId);
            Integer cnt       = (Integer)ar.get('cnt');
            Decimal totalMins = (Decimal)ar.get('totalMins');
            Decimal avgMins   = (cnt != null && cnt > 0 && totalMins != null)
                                ? (totalMins / cnt).setScale(1) : 0;

            rows.add(new Map<String,Object>{
                'contactId'    => cId,
                'studentName'  => ar.get('cName'),
                'rollNumber'   => aff != null ? aff.Roll_Number__c : '',
                'firstLogin'   => ar.get('firstLogin'),
                'lastLogout'   => ar.get('lastLogout'),
                'sessionCount' => cnt != null ? cnt : 0,
                'totalMinutes' => totalMins != null ? totalMins : 0,
                'avgMinutes'   => avgMins,
                'status'       => activeContactIds.contains(cId) ? 'Online' : 'Completed'
            });
        }

        return new Map<String,Object>{
            'rows'       => rows,
            'total'      => total,
            'totalPages' => totalPages,
            'pageNumber' => pageNumber,
            'pageSize'   => pageSize
        };
    }

    private static List<AggregateResult> buildAggregateQuery(
        DateTime dtFrom, DateTime dtTo,
        String nameLike, Set<Id> planContactIds, String statusFilter
    ) {
        Boolean hasPlan   = planContactIds != null;
        Boolean hasStatus = !String.isBlank(statusFilter);

        if (hasPlan && hasStatus) {
            return [
                SELECT Contact__c cId, Contact__r.Name cName,
                       MIN(Login_Time__c) firstLogin, MAX(Logout_Time__c) lastLogout,
                       COUNT(Id) cnt, SUM(Session_Duration_Minutes__c) totalMins
                FROM Portal_Session__c
                WHERE Login_Time__c >= :dtFrom AND Login_Time__c <= :dtTo
                  AND Contact__c IN :planContactIds
                  AND Contact__r.Name LIKE :nameLike
                  AND Session_Status__c = :statusFilter
                GROUP BY Contact__c, Contact__r.Name
                ORDER BY MAX(Logout_Time__c) DESC NULLS LAST
                LIMIT 2000
            ];
        } else if (hasPlan) {
            return [
                SELECT Contact__c cId, Contact__r.Name cName,
                       MIN(Login_Time__c) firstLogin, MAX(Logout_Time__c) lastLogout,
                       COUNT(Id) cnt, SUM(Session_Duration_Minutes__c) totalMins
                FROM Portal_Session__c
                WHERE Login_Time__c >= :dtFrom AND Login_Time__c <= :dtTo
                  AND Contact__c IN :planContactIds
                  AND Contact__r.Name LIKE :nameLike
                GROUP BY Contact__c, Contact__r.Name
                ORDER BY MAX(Logout_Time__c) DESC NULLS LAST
                LIMIT 2000
            ];
        } else if (hasStatus) {
            return [
                SELECT Contact__c cId, Contact__r.Name cName,
                       MIN(Login_Time__c) firstLogin, MAX(Logout_Time__c) lastLogout,
                       COUNT(Id) cnt, SUM(Session_Duration_Minutes__c) totalMins
                FROM Portal_Session__c
                WHERE Login_Time__c >= :dtFrom AND Login_Time__c <= :dtTo
                  AND Contact__r.Name LIKE :nameLike
                  AND Session_Status__c = :statusFilter
                GROUP BY Contact__c, Contact__r.Name
                ORDER BY MAX(Logout_Time__c) DESC NULLS LAST
                LIMIT 2000
            ];
        } else {
            return [
                SELECT Contact__c cId, Contact__r.Name cName,
                       MIN(Login_Time__c) firstLogin, MAX(Logout_Time__c) lastLogout,
                       COUNT(Id) cnt, SUM(Session_Duration_Minutes__c) totalMins
                FROM Portal_Session__c
                WHERE Login_Time__c >= :dtFrom AND Login_Time__c <= :dtTo
                  AND Contact__r.Name LIKE :nameLike
                GROUP BY Contact__c, Contact__r.Name
                ORDER BY MAX(Logout_Time__c) DESC NULLS LAST
                LIMIT 2000
            ];
        }
    }

    // ─── Full export: all students with complete fields ──────────────────────
    @AuraEnabled(cacheable=false)
    public static List<Map<String,Object>> exportAllStudentsReport(
        String dateFrom, String dateTo, String statusFilter
    ) {
        DateTime dtFrom = toStartOfDay(dateFrom);
        DateTime dtTo   = toEndOfDay(dateTo);
        if (dtFrom == null) dtFrom = DateTime.now().addDays(-30);
        if (dtTo   == null) dtTo   = DateTime.now();

        // Aggregate sessions per student in date range
        List<AggregateResult> allAgg;
        Boolean hasStatus = !String.isBlank(statusFilter);
        if (hasStatus) {
            allAgg = [
                SELECT Contact__c cId, Contact__r.Name cName, Contact__r.Email cEmail,
                       MIN(Login_Time__c) firstLogin, MAX(Login_Time__c) lastLogin,
                       COUNT(Id) cnt, SUM(Session_Duration_Minutes__c) totalMins
                FROM Portal_Session__c
                WHERE Login_Time__c >= :dtFrom AND Login_Time__c <= :dtTo
                  AND Session_Status__c = :statusFilter
                GROUP BY Contact__c, Contact__r.Name, Contact__r.Email
                ORDER BY MAX(Login_Time__c) DESC NULLS LAST
                LIMIT 2000
            ];
        } else {
            allAgg = [
                SELECT Contact__c cId, Contact__r.Name cName, Contact__r.Email cEmail,
                       MIN(Login_Time__c) firstLogin, MAX(Login_Time__c) lastLogin,
                       COUNT(Id) cnt, SUM(Session_Duration_Minutes__c) totalMins
                FROM Portal_Session__c
                WHERE Login_Time__c >= :dtFrom AND Login_Time__c <= :dtTo
                GROUP BY Contact__c, Contact__r.Name, Contact__r.Email
                ORDER BY MAX(Login_Time__c) DESC NULLS LAST
                LIMIT 2000
            ];
        }

        // Collect contact IDs
        Set<Id> contactIds = new Set<Id>();
        for (AggregateResult ar : allAgg) {
            if (ar.get('cId') != null) contactIds.add((Id)ar.get('cId'));
        }

        // Affiliation: roll, DSU email, program, batch
        Map<Id, hed__Affiliation__c> affMap = new Map<Id, hed__Affiliation__c>();
        if (!contactIds.isEmpty()) {
            for (hed__Affiliation__c a : [
                SELECT hed__Contact__c, Roll_Number__c, DSU_Email__c,
                       hed__Account__r.Name, Program_Plan__r.Name
                FROM hed__Affiliation__c
                WHERE hed__Contact__c IN :contactIds AND hed__Status__c = 'Current'
                ORDER BY CreatedDate DESC
            ]) {
                if (!affMap.containsKey(a.hed__Contact__c)) affMap.put(a.hed__Contact__c, a);
            }
        }

        // Current semester
        Map<Id, String> semMap = new Map<Id, String>();
        if (!contactIds.isEmpty()) {
            for (hed__Program_Enrollment__c pe : [
                SELECT hed__Contact__c, Term__r.Term_Reference__c
                FROM hed__Program_Enrollment__c
                WHERE hed__Contact__c IN :contactIds AND Term__r.Term_Status__c = 'Ongoing'
                LIMIT 1000
            ]) {
                if (!semMap.containsKey(pe.hed__Contact__c) && pe.Term__r != null)
                    semMap.put(pe.hed__Contact__c, pe.Term__r.Term_Reference__c);
            }
        }

        List<Map<String,Object>> result = new List<Map<String,Object>>();
        for (AggregateResult ar : allAgg) {
            Id   cId      = (Id)ar.get('cId');
            hed__Affiliation__c aff = affMap.get(cId);
            result.add(new Map<String,Object>{
                'studentName'    => ar.get('cName'),
                'email'          => ar.get('cEmail'),
                'usn'            => aff != null ? aff.Roll_Number__c : '',
                'universityEmail'=> aff != null ? aff.DSU_Email__c   : '',
                'programName'    => aff != null && aff.hed__Account__r != null ? aff.hed__Account__r.Name : '',
                'batch'          => aff != null && aff.Program_Plan__r != null ? aff.Program_Plan__r.Name : '',
                'semester'       => semMap.get(cId),
                'totalSessions'  => ar.get('cnt'),
                'totalMinutes'   => ar.get('totalMins'),
                'lastLogin'      => ar.get('lastLogin')
            });
        }
        return result;
    }

    // ─── Student detail: timeline + summary ──────────────────────────────────
    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getStudentDetail(Id contactId, String dateFrom, String dateTo) {
        DateTime dtFrom = toStartOfDay(dateFrom);
        DateTime dtTo   = toEndOfDay(dateTo);

        List<Portal_Session__c> sessions;
        if (dtFrom != null && dtTo != null) {
            sessions = [
                SELECT Id, Login_Time__c, Logout_Time__c,
                       Session_Duration_Minutes__c, Session_Status__c
                FROM Portal_Session__c
                WHERE Contact__c = :contactId
                  AND Login_Time__c >= :dtFrom AND Login_Time__c <= :dtTo
                ORDER BY Login_Time__c DESC
                LIMIT 500
            ];
        } else {
            sessions = [
                SELECT Id, Login_Time__c, Logout_Time__c,
                       Session_Duration_Minutes__c, Session_Status__c
                FROM Portal_Session__c
                WHERE Contact__c = :contactId
                ORDER BY Login_Time__c DESC
                LIMIT 500
            ];
        }

        Contact c = [SELECT Name, Email FROM Contact WHERE Id = :contactId LIMIT 1];

        List<hed__Affiliation__c> affs = [
            SELECT Roll_Number__c, DSU_Email__c, hed__Account__r.Name, Program_Plan__r.Name
            FROM hed__Affiliation__c
            WHERE hed__Contact__c = :contactId AND hed__Status__c = 'Current'
            ORDER BY CreatedDate DESC LIMIT 1
        ];
        hed__Affiliation__c aff = affs.isEmpty() ? null : affs[0];

        Decimal totalMinutes = 0;
        DateTime firstLogin  = null;
        DateTime lastLogout  = null;
        Boolean  isOnline    = false;

        List<Map<String,Object>> timeline = new List<Map<String,Object>>();
        for (Portal_Session__c s : sessions) {
            totalMinutes += s.Session_Duration_Minutes__c != null ? s.Session_Duration_Minutes__c : 0;
            if (firstLogin == null || (s.Login_Time__c != null && s.Login_Time__c < firstLogin))
                firstLogin = s.Login_Time__c;
            if (s.Logout_Time__c != null && (lastLogout == null || s.Logout_Time__c > lastLogout))
                lastLogout = s.Logout_Time__c;
            if (s.Session_Status__c == 'Active') isOnline = true;

            timeline.add(new Map<String,Object>{
                'Id'            => s.Id,
                'loginTime'     => s.Login_Time__c,
                'logoutTime'    => s.Logout_Time__c,
                'durationMins'  => s.Session_Duration_Minutes__c,
                'status'        => s.Session_Status__c
            });
        }

        return new Map<String,Object>{
            'contactName'  => c.Name,
            'contactEmail' => c.Email,
            'rollNumber'   => aff != null ? aff.Roll_Number__c  : '',
            'dsuEmail'     => aff != null ? aff.DSU_Email__c    : '',
            'programName'  => aff != null && aff.hed__Account__r != null  ? aff.hed__Account__r.Name  : '',
            'batchName'    => aff != null && aff.Program_Plan__r != null  ? aff.Program_Plan__r.Name  : '',
            'firstLogin'   => firstLogin,
            'lastLogout'   => lastLogout,
            'totalSessions'=> sessions.size(),
            'totalMinutes' => totalMinutes,
            'isOnline'     => isOnline,
            'timeline'     => timeline
        };
    }

    // ─── 7-day daily activity + summary for the detail page ──────────────────
    // Returns { days: [7 buckets], summary: { real aggregates over the window } }.
    // The summary is computed from the session records themselves — deriving it from
    // the daily buckets (as the UI used to) can only ever count days, not sessions.
    @AuraEnabled(cacheable=true)
    public static Map<String,Object> getStudentWeeklyActivity(Id contactId) {
        Date     today     = Date.today();
        Date     startDate = today.addDays(-6);
        DateTime dtFrom    = DateTime.newInstance(startDate,        Time.newInstance(0, 0, 0, 0));
        DateTime dtTo      = DateTime.newInstance(today.addDays(1), Time.newInstance(0, 0, 0, 0));

        List<Portal_Session__c> sessions = [
            SELECT Login_Time__c, Logout_Time__c, Session_Duration_Minutes__c
            FROM Portal_Session__c
            WHERE Contact__c = :contactId
              AND Login_Time__c >= :dtFrom
              AND Login_Time__c <  :dtTo
            ORDER BY Login_Time__c ASC
        ];

        Map<Date, Decimal> dayMins  = new Map<Date, Decimal>();
        Map<Date, Integer> dayCount = new Map<Date, Integer>();
        for (Integer i = 0; i < 7; i++) {
            Date d = startDate.addDays(i);
            dayMins.put(d, 0);
            dayCount.put(d, 0);
        }

        Decimal  totalMinutes    = 0;
        Decimal  longestSession  = 0;
        Integer  sessionCount    = 0;
        DateTime mostRecentLogin = null;

        for (Portal_Session__c s : sessions) {
            if (s.Login_Time__c == null) continue;
            Date d = s.Login_Time__c.date();
            if (!dayMins.containsKey(d)) continue;

            Decimal mins = s.Session_Duration_Minutes__c != null ? s.Session_Duration_Minutes__c : 0;
            dayMins.put(d, dayMins.get(d) + mins);
            dayCount.put(d, dayCount.get(d) + 1);

            totalMinutes += mins;
            sessionCount++;
            if (mins > longestSession) longestSession = mins;
            if (mostRecentLogin == null || s.Login_Time__c > mostRecentLogin) {
                mostRecentLogin = s.Login_Time__c;
            }
        }

        List<Date> dates = new List<Date>(dayMins.keySet());
        dates.sort();

        Decimal maxMins = 0;
        for (Date d : dates) {
            if (dayMins.get(d) > maxMins) maxMins = dayMins.get(d);
        }

        Integer activeDays = 0;
        List<Map<String,Object>> days = new List<Map<String,Object>>();
        for (Date d : dates) {
            Decimal mins = dayMins.get(d);
            if (mins > 0) activeDays++;
            DateTime dt = DateTime.newInstance(d, Time.newInstance(12, 0, 0, 0));
            days.add(new Map<String,Object>{
                'dayLabel'   => dt.format('EEE, d MMM'),
                'shortDay'   => dt.format('EEE'),
                'dateLabel'  => dt.format('d MMM'),
                'minutes'    => mins,
                'sessions'   => dayCount.get(d),
                'percentage' => maxMins > 0 ? (mins / maxMins * 100).setScale(1) : 0
            });
        }

        // When the window is empty, the UI needs the student's last activity of any
        // age so it can say "no activity in the last 7 days" with something concrete.
        DateTime lastSeen = null;
        for (Portal_Session__c s : [
            SELECT Login_Time__c
            FROM Portal_Session__c
            WHERE Contact__c = :contactId AND Login_Time__c != null
            ORDER BY Login_Time__c DESC
            LIMIT 1
        ]) {
            lastSeen = s.Login_Time__c;
        }

        return new Map<String,Object>{
            'days' => days,
            'summary' => new Map<String,Object>{
                'totalMinutes'          => totalMinutes,
                'activeDays'            => activeDays,
                'totalSessions'         => sessionCount,
                'totalLogins'           => sessionCount,
                'longestSessionMinutes' => longestSession,
                'mostRecentLogin'       => mostRecentLogin,
                'lastSeen'              => lastSeen,
                'windowStart'           => startDate,
                'windowEnd'             => today
            }
        };
    }
}