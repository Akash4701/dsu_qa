/**
 * All SOQL for the Feedback Management home. Every query runs in USER_MODE so the running user's
 * object and field access applies, and every filter is a bind variable (no string concatenation of
 * user input). Roll-ups use aggregate queries so volume does not depend on record counts in Apex.
 */
public with sharing class FeedbackHomeSelector {

    public static List<Questionnaire_Metadata__c> sections(String recordTypeDeveloperName, Integer rowLimit) {
        String soql = 'SELECT Id, Name, Feedback_Type__c, Academic__c, Face_to_Face_and_Online__c, Active__c, Order__c, '
            + 'RecordType.DeveloperName, RecordType.Name FROM Questionnaire_Metadata__c';
        Map<String, Object> binds = new Map<String, Object>{ 'rowLimit' => rowLimit };
        if (String.isNotBlank(recordTypeDeveloperName)) {
            soql += ' WHERE RecordType.DeveloperName = :recordTypeDeveloperName';
            binds.put('recordTypeDeveloperName', recordTypeDeveloperName);
        }
        soql += ' ORDER BY Order__c NULLS LAST, Name LIMIT :rowLimit';
        return (List<Questionnaire_Metadata__c>) Database.queryWithBinds(soql, binds, AccessLevel.USER_MODE);
    }

    /** Active Parameter count per Parameter Section. */
    public static Map<Id, Integer> activeParameterCounts(Set<Id> sectionIds) {
        Map<Id, Integer> counts = new Map<Id, Integer>();
        if (sectionIds == null || sectionIds.isEmpty()) {
            return counts;
        }
        for (AggregateResult row : [
            SELECT Questionnaire__c sectionId, COUNT(Id) total
            FROM Question_Metadata__c
            WHERE Questionnaire__c IN :sectionIds AND Active__c = TRUE
            WITH USER_MODE
            GROUP BY Questionnaire__c
        ]) {
            counts.put((Id) row.get('sectionId'), (Integer) row.get('total'));
        }
        return counts;
    }

    public static List<Question_Metadata__c> parameters(Id sectionId, Integer rowLimit) {
        String soql = 'SELECT Id, Name, Label__c, Question_Label__c, Questionnaire__c, Questionnaire__r.Name, '
            + 'Question_Type__c, Type__c, Mandatory__c, Active__c, Max_Grade__c, Order__c FROM Question_Metadata__c';
        Map<String, Object> binds = new Map<String, Object>{ 'rowLimit' => rowLimit };
        if (sectionId != null) {
            soql += ' WHERE Questionnaire__c = :sectionId';
            binds.put('sectionId', sectionId);
        }
        soql += ' ORDER BY Questionnaire__r.Name, Order__c NULLS LAST, Name LIMIT :rowLimit';
        return (List<Question_Metadata__c>) Database.queryWithBinds(soql, binds, AccessLevel.USER_MODE);
    }

    public static List<Feedback_Scheduler__c> schedulers(Integer rowLimit) {
        return [
            SELECT Id, Name, Start_Date__c, End_Date__c, Term__r.Name,
                   Feedback_Master__r.Name, Feedback_Master__r.Feedback_Type__c
            FROM Feedback_Scheduler__c
            WITH USER_MODE
            ORDER BY CreatedDate DESC
            LIMIT :rowLimit
        ];
    }

    /** Feedback Item counts per scheduler and status: schedulerId -> (status -> count). */
    public static Map<Id, Map<String, Integer>> itemStatusCounts(Set<Id> schedulerIds) {
        Map<Id, Map<String, Integer>> counts = new Map<Id, Map<String, Integer>>();
        if (schedulerIds == null || schedulerIds.isEmpty()) {
            return counts;
        }
        for (AggregateResult row : [
            SELECT Feedback_Scheduler__c schedulerId, Feedback_Status__c status, COUNT(Id) total
            FROM Feedback_Item__c
            WHERE Feedback_Scheduler__c IN :schedulerIds
            WITH USER_MODE
            GROUP BY Feedback_Scheduler__c, Feedback_Status__c
        ]) {
            Id schedulerId = (Id) row.get('schedulerId');
            if (!counts.containsKey(schedulerId)) {
                counts.put(schedulerId, new Map<String, Integer>());
            }
            counts.get(schedulerId).put((String) row.get('status'), (Integer) row.get('total'));
        }
        return counts;
    }

    public static List<Feedback_Item__c> items(Id schedulerId, String status, Integer rowLimit) {
        String soql = 'SELECT Id, Name, Feedback_Status__c, Assignee__r.Name, Course_Offering__r.Name, '
            + 'Start_Date__c, End_Date__c, Notification_Counter__c FROM Feedback_Item__c '
            + 'WHERE Feedback_Scheduler__c = :schedulerId';
        Map<String, Object> binds = new Map<String, Object>{ 'schedulerId' => schedulerId, 'rowLimit' => rowLimit };
        if (String.isNotBlank(status)) {
            soql += ' AND Feedback_Status__c = :status';
            binds.put('status', status);
        }
        soql += ' ORDER BY Feedback_Status__c, Name LIMIT :rowLimit';
        return (List<Feedback_Item__c>) Database.queryWithBinds(soql, binds, AccessLevel.USER_MODE);
    }

    // ---------- Paged, filtered lists (server-side, for large volumes) ----------

    /** Wraps a user search term for LIKE, escaping the LIKE wildcards so they match literally. */
    @TestVisible
    private static String likeTerm(String search) {
        if (String.isBlank(search)) {
            return null;
        }
        return '%' + search.trim().replace('\\', '\\\\').replace('%', '\\%').replace('_', '\\_') + '%';
    }

    private static String sectionFilter(String recordType, String search, Boolean activeOnly, Map<String, Object> binds) {
        List<String> clauses = new List<String>();
        if (String.isNotBlank(recordType)) {
            clauses.add('RecordType.DeveloperName = :recordType');
            binds.put('recordType', recordType);
        }
        String term = likeTerm(search);
        if (term != null) {
            clauses.add('Name LIKE :term');
            binds.put('term', term);
        }
        if (activeOnly == true) {
            clauses.add('Active__c = TRUE');
        }
        return clauses.isEmpty() ? '' : ' WHERE ' + String.join(clauses, ' AND ');
    }

    public static Integer sectionCount(String recordType, String search, Boolean activeOnly) {
        Map<String, Object> binds = new Map<String, Object>();
        String soql = 'SELECT COUNT() FROM Questionnaire_Metadata__c' + sectionFilter(recordType, search, activeOnly, binds);
        return Database.countQueryWithBinds(soql, binds, AccessLevel.USER_MODE);
    }

    public static List<Questionnaire_Metadata__c> sectionPage(
        String recordType, String search, Boolean activeOnly, Integer pageSize, Integer pageOffset
    ) {
        Map<String, Object> binds = new Map<String, Object>{ 'pageSize' => pageSize, 'pageOffset' => pageOffset };
        String soql = 'SELECT Id, Name, Feedback_Type__c, Academic__c, Face_to_Face_and_Online__c, Active__c, Order__c, '
            + 'RecordType.DeveloperName, RecordType.Name FROM Questionnaire_Metadata__c'
            + sectionFilter(recordType, search, activeOnly, binds)
            + ' ORDER BY Order__c NULLS LAST, Name, Id LIMIT :pageSize OFFSET :pageOffset';
        return (List<Questionnaire_Metadata__c>) Database.queryWithBinds(soql, binds, AccessLevel.USER_MODE);
    }

    /**
     * Schedule status is derived from the dates, so it is translated into date predicates here and the
     * database (not Apex) does the filtering. Mirrors FeedbackHomeService.scheduleStatus.
     */
    private static String scheduleFilter(String search, String status, Map<String, Object> binds) {
        List<String> clauses = new List<String>();
        String term = likeTerm(search);
        if (term != null) {
            clauses.add('(Name LIKE :term OR Feedback_Master__r.Name LIKE :term OR Term__r.Name LIKE :term)');
            binds.put('term', term);
        }
        if (status == 'Scheduled') {
            clauses.add('(Start_Date__c > :today OR (Start_Date__c = NULL AND End_Date__c = NULL))');
            binds.put('today', Date.today());
        } else if (status == 'Closed') {
            clauses.add('(End_Date__c < :today AND (Start_Date__c = NULL OR Start_Date__c <= :today))');
            binds.put('today', Date.today());
        } else if (status == 'Live') {
            clauses.add('((Start_Date__c = NULL OR Start_Date__c <= :today) AND (End_Date__c = NULL OR End_Date__c >= :today) '
                + 'AND (Start_Date__c != NULL OR End_Date__c != NULL))');
            binds.put('today', Date.today());
        }
        return clauses.isEmpty() ? '' : ' WHERE ' + String.join(clauses, ' AND ');
    }

    public static Integer scheduleCount(String search, String status) {
        Map<String, Object> binds = new Map<String, Object>();
        String soql = 'SELECT COUNT() FROM Feedback_Scheduler__c' + scheduleFilter(search, status, binds);
        return Database.countQueryWithBinds(soql, binds, AccessLevel.USER_MODE);
    }

    private static final Map<String, String> SCHEDULE_ORDER = new Map<String, String>{
        'newest' => 'CreatedDate DESC, Id',
        'closing' => 'End_Date__c ASC NULLS LAST, Name, Id',
        'name' => 'Name, Id'
    };

    public static List<Feedback_Scheduler__c> schedulePage(
        String search, String status, String sortKey, Integer pageSize, Integer pageOffset
    ) {
        Map<String, Object> binds = new Map<String, Object>{ 'pageSize' => pageSize, 'pageOffset' => pageOffset };
        String order = SCHEDULE_ORDER.containsKey(sortKey) ? SCHEDULE_ORDER.get(sortKey) : SCHEDULE_ORDER.get('newest');
        String soql = 'SELECT Id, Name, Start_Date__c, End_Date__c, Term__r.Name, Feedback_Master__r.Name, '
            + 'Feedback_Master__r.Feedback_Type__c FROM Feedback_Scheduler__c'
            + scheduleFilter(search, status, binds)
            + ' ORDER BY ' + order + ' LIMIT :pageSize OFFSET :pageOffset';
        return (List<Feedback_Scheduler__c>) Database.queryWithBinds(soql, binds, AccessLevel.USER_MODE);
    }

    /** Active Parameter Section count per record type developer name. */
    public static Map<String, Integer> activeSectionCountsByRecordType() {
        Map<String, Integer> counts = new Map<String, Integer>();
        for (AggregateResult row : [
            SELECT RecordType.DeveloperName recordType, COUNT(Id) total
            FROM Questionnaire_Metadata__c
            WHERE Active__c = TRUE
            WITH USER_MODE
            GROUP BY RecordType.DeveloperName
        ]) {
            counts.put((String) row.get('recordType'), (Integer) row.get('total'));
        }
        return counts;
    }

    public static Integer scheduleCount() {
        return [SELECT COUNT() FROM Feedback_Scheduler__c WITH USER_MODE];
    }

    public static Integer activeParameterCount() {
        return [SELECT COUNT() FROM Question_Metadata__c WHERE Active__c = TRUE WITH USER_MODE];
    }

    /** Active Parameter Sections that have no active Parameter (a template that cannot be answered). */
    public static List<Questionnaire_Metadata__c> activeSectionsWithoutParameters(Integer rowLimit) {
        return [
            SELECT Id, Name
            FROM Questionnaire_Metadata__c
            WHERE Active__c = TRUE
              AND Id NOT IN (SELECT Questionnaire__c FROM Question_Metadata__c WHERE Active__c = TRUE)
            WITH USER_MODE
            ORDER BY Name
            LIMIT :rowLimit
        ];
    }

    // ---------- Overview roll-ups (whole data set, never a sample) ----------

    /** Feedback Item counts per status across every schedule, in a single aggregate query. */
    public static Map<String, Integer> itemStatusTotals() {
        Map<String, Integer> totals = new Map<String, Integer>();
        for (AggregateResult row : [
            SELECT Feedback_Status__c status, COUNT(Id) total
            FROM Feedback_Item__c
            WITH USER_MODE
            GROUP BY Feedback_Status__c
        ]) {
            totals.put((String) row.get('status'), (Integer) row.get('total'));
        }
        return totals;
    }

    /** The newest schedules, for the overview's "recent" list. */
    public static List<Feedback_Scheduler__c> recentSchedulers(Integer rowLimit) {
        return schedulers(rowLimit);
    }

    /** Live schedules that end within the alert window, soonest first. */
    public static List<Feedback_Scheduler__c> liveSchedulersEndingBy(Date today, Date windowEnd, Integer rowLimit) {
        return [
            SELECT Id, Name, Start_Date__c, End_Date__c, Term__r.Name,
                   Feedback_Master__r.Name, Feedback_Master__r.Feedback_Type__c
            FROM Feedback_Scheduler__c
            WHERE End_Date__c >= :today AND End_Date__c <= :windowEnd
              AND (Start_Date__c = NULL OR Start_Date__c <= :today)
            WITH USER_MODE
            ORDER BY End_Date__c, Id
            LIMIT :rowLimit
        ];
    }

    /** Schedules that are not closed yet but have no Feedback Item at all (nobody assigned). */
    public static List<Feedback_Scheduler__c> openSchedulersWithoutItems(Date today, Integer rowLimit) {
        return [
            SELECT Id, Name, Start_Date__c, End_Date__c, Term__r.Name,
                   Feedback_Master__r.Name, Feedback_Master__r.Feedback_Type__c
            FROM Feedback_Scheduler__c
            WHERE Id NOT IN (SELECT Feedback_Scheduler__c FROM Feedback_Item__c WHERE Feedback_Scheduler__c != NULL)
              AND (End_Date__c = NULL OR End_Date__c >= :today OR Start_Date__c > :today)
            WITH USER_MODE
            ORDER BY CreatedDate DESC
            LIMIT :rowLimit
        ];
    }

    // ---------- Report: collected answers with student identity ----------

    private static final Integer USN_MATCH_LIMIT = 500;

    /** Contacts whose Affiliation USN matches the search, because the USN lives on Affiliation, not on the answer. */
    private static Set<Id> contactIdsByUsn(String term, Integer rowLimit) {
        Set<Id> ids = new Set<Id>();
        for (hed__Affiliation__c affiliation : [
            SELECT hed__Contact__c FROM hed__Affiliation__c
            WHERE Roll_Number__c LIKE :term AND hed__Contact__c != NULL
            WITH USER_MODE LIMIT :rowLimit
        ]) {
            ids.add(affiliation.hed__Contact__c);
        }
        return ids;
    }

    private static String reportFilter(
        String search, String feedbackType, Id termId, Date fromDate, Date toDate, Map<String, Object> binds
    ) {
        List<String> clauses = new List<String>();
        String term = likeTerm(search);
        if (term != null) {
            binds.put('term', term);
            binds.put('usnContacts', contactIdsByUsn(term, USN_MATCH_LIMIT));
            clauses.add('(Contact__r.Name LIKE :term OR Question__c LIKE :term OR Feedback_Master__r.Name LIKE :term '
                + 'OR Contact__c IN :usnContacts)');
        }
        if (String.isNotBlank(feedbackType)) {
            clauses.add('Feedback_Master__r.Feedback_Type__c = :feedbackType');
            binds.put('feedbackType', feedbackType);
        }
        if (termId != null) {
            clauses.add('Term__c = :termId');
            binds.put('termId', termId);
        }
        if (fromDate != null) {
            clauses.add('Feedback_DateTime__c >= :fromStamp');
            binds.put('fromStamp', Datetime.newInstance(fromDate, Time.newInstance(0, 0, 0, 0)));
        }
        if (toDate != null) {
            clauses.add('Feedback_DateTime__c < :toStamp');
            binds.put('toStamp', Datetime.newInstance(toDate.addDays(1), Time.newInstance(0, 0, 0, 0)));
        }
        return clauses.isEmpty() ? '' : ' WHERE ' + String.join(clauses, ' AND ');
    }

    public static Integer reportCount(
        String search, String feedbackType, Id termId, Date fromDate, Date toDate
    ) {
        Map<String, Object> binds = new Map<String, Object>();
        String soql = 'SELECT COUNT() FROM Collected_Feedback_Data__c'
            + reportFilter(search, feedbackType, termId, fromDate, toDate, binds);
        return Database.countQueryWithBinds(soql, binds, AccessLevel.USER_MODE);
    }

    public static List<Collected_Feedback_Data__c> reportPage(
        String search, String feedbackType, Id termId, Date fromDate, Date toDate, Integer pageSize, Integer pageOffset
    ) {
        Map<String, Object> binds = new Map<String, Object>{ 'pageSize' => pageSize, 'pageOffset' => pageOffset };
        String soql = 'SELECT Id, Contact__c, Contact__r.Name, Term__c, Term__r.Name, Term__r.Program_Plan__c, '
            + 'Term__r.Program_Plan__r.Name, Feedback_Master__r.Name, Feedback_Master__r.Feedback_Type__c, '
            + 'Feedback_Master__r.Program__r.Name, Feedback_Master_Child__r.Order__c, Question__c, Question_Type__c, '
            + 'Answer__c, Rating__c, Feedback_DateTime__c, Feedback_Item__r.Feedback_Status__c '
            + 'FROM Collected_Feedback_Data__c'
            + reportFilter(search, feedbackType, termId, fromDate, toDate, binds)
            + ' ORDER BY Feedback_DateTime__c DESC NULLS LAST, Contact__c, Feedback_Master_Child__r.Order__c NULLS LAST, Id'
            + ' LIMIT :pageSize OFFSET :pageOffset';
        return (List<Collected_Feedback_Data__c>) Database.queryWithBinds(soql, binds, AccessLevel.USER_MODE);
    }

    /** USN-bearing affiliations for the students on one page (never more than one page of contacts). */
    public static List<hed__Affiliation__c> affiliationsWithUsn(Set<Id> contactIds) {
        return [
            SELECT hed__Contact__c, Roll_Number__c, Program_Plan__c
            FROM hed__Affiliation__c
            WHERE hed__Contact__c IN :contactIds AND Roll_Number__c != NULL
            WITH USER_MODE
            ORDER BY CreatedDate DESC
            LIMIT 2000
        ];
    }

    /** Terms that actually have collected answers, for the Semester filter. */
    public static List<AggregateResult> termsWithAnswers(Integer rowLimit) {
        return [
            SELECT Term__c termId, Term__r.Name termName
            FROM Collected_Feedback_Data__c
            WHERE Term__c != NULL
            WITH USER_MODE
            GROUP BY Term__c, Term__r.Name
            ORDER BY Term__r.Name
            LIMIT :rowLimit
        ];
    }
}