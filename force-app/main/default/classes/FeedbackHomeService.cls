/**
 * Business logic for the Feedback Management home: turns selector output into the DTOs the LWCs
 * render. No SOQL here (see FeedbackHomeSelector) and no UI concerns (see FeedbackHomeController).
 */
public with sharing class FeedbackHomeService {
    public class FeedbackHomeException extends Exception {}

    public static final String STATUS_PENDING = 'Pending';
    public static final String STATUS_SUBMITTED = 'Submitted';
    public static final String SCHEDULE_SCHEDULED = 'Scheduled';
    public static final String SCHEDULE_LIVE = 'Live';
    public static final String SCHEDULE_CLOSED = 'Closed';

    private static final Integer ALERT_CANDIDATE_LIMIT = 25;
    private static final Integer RECENT_SCHEDULE_LIMIT = 6;
    private static final Integer LIST_LIMIT = 200;
    private static final Integer ITEM_LIMIT = 500;
    private static final Integer ALERT_LIMIT = 5;

    // ---------- Overview ----------

    /**
     * Every figure is computed over the whole data set with aggregate/COUNT queries (never a sample of the
     * newest schedules), so the numbers stay correct as schedules and items grow into the hundreds of
     * thousands. Only the small lists (recent schedules, alerts) are capped.
     */
    public static FeedbackHomeDto.Overview overview() {
        FeedbackHomeDto.Overview result = new FeedbackHomeDto.Overview();
        Integer target = FeedbackHomeSettings.targetResponseRate();
        Integer alertWindow = FeedbackHomeSettings.alertWindowDays();
        result.targetResponseRate = target;

        Integer live = FeedbackHomeSelector.scheduleCount(null, SCHEDULE_LIVE);
        Integer scheduled = FeedbackHomeSelector.scheduleCount(null, SCHEDULE_SCHEDULED);
        Integer closed = FeedbackHomeSelector.scheduleCount(null, SCHEDULE_CLOSED);

        Map<String, Integer> itemTotals = FeedbackHomeSelector.itemStatusTotals();
        Integer total = 0;
        for (Integer count : itemTotals.values()) {
            total += count;
        }
        Integer submitted = itemTotals.containsKey(STATUS_SUBMITTED) ? itemTotals.get(STATUS_SUBMITTED) : 0;
        Integer pending = total - submitted;
        Integer overallRate = percent(submitted, total);

        Map<String, Integer> sectionCounts = FeedbackHomeSelector.activeSectionCountsByRecordType();
        List<String> typeNames = new List<String>(sectionCounts.keySet());
        typeNames.sort();
        Integer activeSections = 0;
        List<String> sectionBreakdown = new List<String>();
        for (String typeName : typeNames) {
            Integer count = sectionCounts.get(typeName);
            activeSections += count;
            sectionBreakdown.add(typeName + ' ' + count);
            result.sectionTypeCounts.add(new FeedbackHomeDto.StatusCount(typeName, count));
        }
        Integer activeParameters = FeedbackHomeSelector.activeParameterCount();
        result.activeSectionCount = activeSections;
        result.activeParameterCount = activeParameters;
        result.scheduleCount = live + scheduled + closed;

        result.stats.add(new FeedbackHomeDto.Stat('Active Parameter Sections', String.valueOf(activeSections),
            sectionBreakdown.isEmpty() ? 'None yet' : String.join(sectionBreakdown, ' · '), 'info'));
        result.stats.add(new FeedbackHomeDto.Stat('Active Parameters', String.valueOf(activeParameters),
            'Questions across all sections', 'info'));
        result.stats.add(new FeedbackHomeDto.Stat('Live Schedules', String.valueOf(live),
            scheduled + ' scheduled · ' + closed + ' closed', live > 0 ? 'success' : 'info'));
        result.stats.add(new FeedbackHomeDto.Stat('Response Rate', overallRate + '%',
            submitted + ' of ' + total + ' submitted · target ' + target + '%', rateTone(overallRate, total, target)));

        result.itemStatusCounts.add(new FeedbackHomeDto.StatusCount(STATUS_SUBMITTED, submitted));
        result.itemStatusCounts.add(new FeedbackHomeDto.StatusCount(STATUS_PENDING, pending));

        addAlerts(result, target, alertWindow);
        result.recentSchedules = scheduleRows(FeedbackHomeSelector.recentSchedulers(RECENT_SCHEDULE_LIMIT));
        return result;
    }

    /** Most urgent first: live schedules about to close under target, then empty schedules, then empty sections. */
    private static void addAlerts(FeedbackHomeDto.Overview result, Integer target, Integer alertWindow) {
        Date today = Date.today();

        List<FeedbackHomeDto.ScheduleRow> closing = scheduleRows(
            FeedbackHomeSelector.liveSchedulersEndingBy(today, today.addDays(alertWindow), ALERT_CANDIDATE_LIMIT));
        for (FeedbackHomeDto.ScheduleRow row : closing) {
            if (result.alerts.size() >= ALERT_LIMIT) {
                return;
            }
            if (row.total > 0 && row.rate < target) {
                result.alerts.add(new FeedbackHomeDto.Alert(row.name + ' closes soon',
                    row.rate + '% responded, target ' + target + '% · ends ' + row.endDate.format(), 'error', row.id));
            }
        }
        for (Feedback_Scheduler__c schedule : FeedbackHomeSelector.openSchedulersWithoutItems(today, ALERT_LIMIT)) {
            if (result.alerts.size() >= ALERT_LIMIT) {
                return;
            }
            result.alerts.add(new FeedbackHomeDto.Alert(schedule.Name + ' has no feedback items',
                'Nobody has been assigned yet', 'warning', schedule.Id));
        }
        for (Questionnaire_Metadata__c section : FeedbackHomeSelector.activeSectionsWithoutParameters(ALERT_LIMIT)) {
            if (result.alerts.size() >= ALERT_LIMIT) {
                return;
            }
            result.alerts.add(new FeedbackHomeDto.Alert(section.Name + ' has no active parameters',
                'Add parameters before scheduling this section', 'warning', section.Id));
        }
    }

    // ---------- Parameter Sections ----------

    public static List<FeedbackHomeDto.SectionRow> parameterSections(String recordTypeDeveloperName) {
        return sectionRows(FeedbackHomeSelector.sections(recordTypeDeveloperName, LIST_LIMIT));
    }

    /** Server-side paged, searchable, filterable list: safe for thousands of sections. */
    public static FeedbackHomeDto.SectionPage sectionPage(
        String recordTypeDeveloperName, String search, Boolean activeOnly, Integer pageSize, Integer pageNumber
    ) {
        FeedbackHomeDto.SectionPage result = new FeedbackHomeDto.SectionPage();
        Integer size = clampPageSize(pageSize);
        result.pageSize = size;
        result.total = FeedbackHomeSelector.sectionCount(recordTypeDeveloperName, search, activeOnly);
        applyPaging(result.total, size, pageNumber, result);
        if (result.total > 0) {
            result.rows = sectionRows(FeedbackHomeSelector.sectionPage(
                recordTypeDeveloperName, search, activeOnly, size, (result.pageNumber - 1) * size));
        }
        return result;
    }

    private static List<FeedbackHomeDto.SectionRow> sectionRows(List<Questionnaire_Metadata__c> records) {
        Set<Id> ids = new Set<Id>();
        for (Questionnaire_Metadata__c record : records) {
            ids.add(record.Id);
        }
        Map<Id, Integer> counts = FeedbackHomeSelector.activeParameterCounts(ids);

        List<FeedbackHomeDto.SectionRow> rows = new List<FeedbackHomeDto.SectionRow>();
        for (Questionnaire_Metadata__c record : records) {
            FeedbackHomeDto.SectionRow row = new FeedbackHomeDto.SectionRow();
            row.id = record.Id;
            row.name = record.Name;
            row.recordType = record.RecordType?.DeveloperName;
            row.recordTypeLabel = record.RecordType?.Name;
            row.feedbackType = record.Feedback_Type__c;
            row.academic = record.Academic__c;
            row.mode = record.Face_to_Face_and_Online__c;
            row.active = record.Active__c;
            row.sortOrder = record.Order__c;
            row.parameterCount = counts.containsKey(record.Id) ? counts.get(record.Id) : 0;
            rows.add(row);
        }
        return rows;
    }

    // ---------- Parameters ----------

    public static List<FeedbackHomeDto.ParameterRow> parameters(Id sectionId) {
        List<FeedbackHomeDto.ParameterRow> rows = new List<FeedbackHomeDto.ParameterRow>();
        for (Question_Metadata__c record : FeedbackHomeSelector.parameters(sectionId, LIST_LIMIT)) {
            FeedbackHomeDto.ParameterRow row = new FeedbackHomeDto.ParameterRow();
            row.id = record.Id;
            row.name = record.Name;
            row.label = record.Label__c;
            row.question = record.Question_Label__c;
            row.sectionId = record.Questionnaire__c;
            row.sectionName = record.Questionnaire__r?.Name;
            row.questionType = record.Question_Type__c;
            row.type = record.Type__c;
            row.mandatory = record.Mandatory__c;
            row.active = record.Active__c;
            row.maxGrade = record.Max_Grade__c;
            row.sortOrder = record.Order__c;
            rows.add(row);
        }
        return rows;
    }

    // ---------- Scheduling ----------

    public static List<FeedbackHomeDto.ScheduleRow> schedules() {
        return scheduleRows(FeedbackHomeSelector.schedulers(LIST_LIMIT));
    }

    /** Server-side paged, searchable list with a status filter (derived from dates) and per-status counts. */
    public static FeedbackHomeDto.SchedulePage schedulePage(
        String search, String status, String sortKey, Integer pageSize, Integer pageNumber
    ) {
        String statusFilter = normaliseScheduleStatus(status);
        FeedbackHomeDto.SchedulePage result = new FeedbackHomeDto.SchedulePage();
        Integer size = clampPageSize(pageSize);
        result.pageSize = size;

        Integer all = FeedbackHomeSelector.scheduleCount(search, null);
        Integer live = FeedbackHomeSelector.scheduleCount(search, SCHEDULE_LIVE);
        Integer scheduled = FeedbackHomeSelector.scheduleCount(search, SCHEDULE_SCHEDULED);
        Integer closed = FeedbackHomeSelector.scheduleCount(search, SCHEDULE_CLOSED);
        result.statusCounts.add(new FeedbackHomeDto.StatusCount('All', all));
        result.statusCounts.add(new FeedbackHomeDto.StatusCount(SCHEDULE_LIVE, live));
        result.statusCounts.add(new FeedbackHomeDto.StatusCount(SCHEDULE_SCHEDULED, scheduled));
        result.statusCounts.add(new FeedbackHomeDto.StatusCount(SCHEDULE_CLOSED, closed));

        result.total = statusFilter == null ? all
            : statusFilter == SCHEDULE_LIVE ? live
            : statusFilter == SCHEDULE_SCHEDULED ? scheduled : closed;
        applyPaging(result.total, size, pageNumber, result);
        if (result.total > 0) {
            result.rows = scheduleRows(FeedbackHomeSelector.schedulePage(
                search, statusFilter, sortKey, size, (result.pageNumber - 1) * size));
        }
        return result;
    }

    // ---------- Responses ----------

    public static List<FeedbackHomeDto.ItemRow> scheduleItems(Id schedulerId, String status) {
        if (schedulerId == null) {
            throw new FeedbackHomeException('Select a schedule first.');
        }
        String statusFilter = normaliseStatus(status);
        List<FeedbackHomeDto.ItemRow> rows = new List<FeedbackHomeDto.ItemRow>();
        for (Feedback_Item__c record : FeedbackHomeSelector.items(schedulerId, statusFilter, ITEM_LIMIT)) {
            FeedbackHomeDto.ItemRow row = new FeedbackHomeDto.ItemRow();
            row.id = record.Id;
            row.name = record.Name;
            row.status = record.Feedback_Status__c;
            row.assignee = record.Assignee__r?.Name;
            row.courseOffering = record.Course_Offering__r?.Name;
            row.startDate = record.Start_Date__c;
            row.endDate = record.End_Date__c;
            row.reminders = record.Notification_Counter__c;
            rows.add(row);
        }
        return rows;
    }

    // ---------- Helpers ----------

    @TestVisible
    private static List<FeedbackHomeDto.ScheduleRow> scheduleRows(List<Feedback_Scheduler__c> records) {
        Set<Id> ids = new Set<Id>();
        for (Feedback_Scheduler__c record : records) {
            ids.add(record.Id);
        }
        Map<Id, Map<String, Integer>> counts = FeedbackHomeSelector.itemStatusCounts(ids);

        List<FeedbackHomeDto.ScheduleRow> rows = new List<FeedbackHomeDto.ScheduleRow>();
        for (Feedback_Scheduler__c record : records) {
            FeedbackHomeDto.ScheduleRow row = new FeedbackHomeDto.ScheduleRow();
            row.id = record.Id;
            row.name = record.Name;
            row.term = record.Term__r?.Name;
            row.template = record.Feedback_Master__r?.Name;
            row.feedbackType = record.Feedback_Master__r?.Feedback_Type__c;
            row.startDate = record.Start_Date__c;
            row.endDate = record.End_Date__c;
            row.status = scheduleStatus(record.Start_Date__c, record.End_Date__c);

            Map<String, Integer> byStatus = counts.containsKey(record.Id) ? counts.get(record.Id) : new Map<String, Integer>();
            for (String status : byStatus.keySet()) {
                row.total += byStatus.get(status);
            }
            row.submitted = byStatus.containsKey(STATUS_SUBMITTED) ? byStatus.get(STATUS_SUBMITTED) : 0;
            row.pending = row.total - row.submitted;
            row.rate = percent(row.submitted, row.total);
            rows.add(row);
        }
        return rows;
    }

    @TestVisible
    private static String scheduleStatus(Date startDate, Date endDate) {
        Date today = Date.today();
        if (startDate != null && startDate > today) {
            return SCHEDULE_SCHEDULED;
        }
        if (endDate != null && endDate < today) {
            return SCHEDULE_CLOSED;
        }
        return startDate == null && endDate == null ? SCHEDULE_SCHEDULED : SCHEDULE_LIVE;
    }

    // ----- paging helpers -----

    private static final Integer DEFAULT_PAGE_SIZE = 25;
    private static final Integer MAX_PAGE_SIZE = 100;
    // SOQL OFFSET cannot exceed 2,000, so deeper pages are not reachable; the UI asks the user to refine instead.
    @TestVisible private static final Integer MAX_OFFSET = 2000;

    @TestVisible
    private static Integer clampPageSize(Integer pageSize) {
        if (pageSize == null || pageSize < 1) {
            return DEFAULT_PAGE_SIZE;
        }
        return Math.min(pageSize, MAX_PAGE_SIZE);
    }

    /** Fills pageNumber, totalPages and truncated, clamping an out-of-range page (e.g. after a filter shrinks the list). */
    private static void applyPaging(Integer total, Integer size, Integer requestedPage, Object target) {
        Integer lastReachable = (MAX_OFFSET / size) + 1;
        Integer totalPages = Math.max(1, Math.min((total + size - 1) / size, lastReachable));
        Integer page = Math.min(Math.max(requestedPage == null ? 1 : requestedPage, 1), totalPages);
        Boolean truncated = total > totalPages * size;
        if (target instanceof FeedbackHomeDto.SectionPage) {
            FeedbackHomeDto.SectionPage sp = (FeedbackHomeDto.SectionPage) target;
            sp.totalPages = totalPages;
            sp.pageNumber = page;
            sp.truncated = truncated;
        } else if (target instanceof FeedbackHomeDto.SchedulePage) {
            FeedbackHomeDto.SchedulePage sc = (FeedbackHomeDto.SchedulePage) target;
            sc.totalPages = totalPages;
            sc.pageNumber = page;
            sc.truncated = truncated;
        } else if (target instanceof FeedbackHomeDto.ReportPage) {
            FeedbackHomeDto.ReportPage rp = (FeedbackHomeDto.ReportPage) target;
            rp.totalPages = totalPages;
            rp.pageNumber = page;
            rp.truncated = truncated;
        }
    }

    private static String normaliseScheduleStatus(String status) {
        if (String.isBlank(status) || status == 'All') {
            return null;
        }
        if (status != SCHEDULE_LIVE && status != SCHEDULE_SCHEDULED && status != SCHEDULE_CLOSED) {
            throw new FeedbackHomeException('Unknown schedule status filter: ' + status);
        }
        return status;
    }

    private static String normaliseStatus(String status) {
        if (String.isBlank(status) || status == 'All') {
            return null;
        }
        if (status != STATUS_PENDING && status != STATUS_SUBMITTED) {
            throw new FeedbackHomeException('Unknown status filter: ' + status);
        }
        return status;
    }

    private static Integer percent(Integer part, Integer whole) {
        return whole > 0 ? Math.round(part * 100.0 / whole) : 0;
    }

    private static String rateTone(Integer rate, Integer total, Integer target) {
        if (total == 0) {
            return 'info';
        }
        if (rate >= target) {
            return 'success';
        }
        return rate >= target - 15 ? 'warning' : 'error';
    }

    // ---------- Report: answers joined with the student's USN ----------

    private static final Integer TERM_OPTION_LIMIT = 200;

    public static FeedbackHomeDto.ReportPage reportPage(
        String search, String feedbackType, Id termId, Date fromDate, Date toDate, Integer pageSize, Integer pageNumber
    ) {
        if (fromDate != null && toDate != null && fromDate > toDate) {
            throw new FeedbackHomeException('The From date must be on or before the To date.');
        }
        FeedbackHomeDto.ReportPage result = new FeedbackHomeDto.ReportPage();
        Integer size = clampPageSize(pageSize);
        result.pageSize = size;
        result.total = FeedbackHomeSelector.reportCount(search, feedbackType, termId, fromDate, toDate);
        applyPaging(result.total, size, pageNumber, result);
        if (result.total > 0) {
            result.rows = reportRows(FeedbackHomeSelector.reportPage(
                search, feedbackType, termId, fromDate, toDate, size, (result.pageNumber - 1) * size));
        }
        return result;
    }

    @TestVisible
    private static List<FeedbackHomeDto.ReportRow> reportRows(List<Collected_Feedback_Data__c> records) {
        Set<Id> contactIds = new Set<Id>();
        for (Collected_Feedback_Data__c record : records) {
            if (record.Contact__c != null) {
                contactIds.add(record.Contact__c);
            }
        }
        Map<Id, List<hed__Affiliation__c>> affiliations = new Map<Id, List<hed__Affiliation__c>>();
        if (!contactIds.isEmpty()) {
            for (hed__Affiliation__c affiliation : FeedbackHomeSelector.affiliationsWithUsn(contactIds)) {
                if (!affiliations.containsKey(affiliation.hed__Contact__c)) {
                    affiliations.put(affiliation.hed__Contact__c, new List<hed__Affiliation__c>());
                }
                affiliations.get(affiliation.hed__Contact__c).add(affiliation);
            }
        }

        List<FeedbackHomeDto.ReportRow> rows = new List<FeedbackHomeDto.ReportRow>();
        for (Collected_Feedback_Data__c record : records) {
            FeedbackHomeDto.ReportRow row = new FeedbackHomeDto.ReportRow();
            row.id = record.Id;
            row.contactId = record.Contact__c;
            row.student = record.Contact__r?.Name;
            row.usn = pickUsn(affiliations.get(record.Contact__c), record.Term__r?.Program_Plan__c);
            row.program = record.Feedback_Master__r?.Program__r?.Name;
            row.programPlan = record.Term__r?.Program_Plan__r?.Name;
            row.term = record.Term__r?.Name;
            row.section = record.Feedback_Master__r?.Name;
            row.feedbackType = record.Feedback_Master__r?.Feedback_Type__c;
            row.questionNo = record.Feedback_Master_Child__r?.Order__c;
            row.question = record.Question__c;
            row.questionType = record.Question_Type__c;
            row.answer = String.isNotBlank(record.Answer__c) ? record.Answer__c : record.Rating__c;
            row.submittedOn = record.Feedback_DateTime__c;
            row.status = record.Feedback_Item__r?.Feedback_Status__c;
            rows.add(row);
        }
        return rows;
    }

    /** The USN of the affiliation in the answer's program plan; otherwise the student's most recent USN. */
    @TestVisible
    private static String pickUsn(List<hed__Affiliation__c> candidates, Id programPlanId) {
        if (candidates == null || candidates.isEmpty()) {
            return null;
        }
        if (programPlanId != null) {
            for (hed__Affiliation__c candidate : candidates) {
                if (candidate.Program_Plan__c == programPlanId) {
                    return candidate.Roll_Number__c;
                }
            }
        }
        return candidates[0].Roll_Number__c;
    }

    public static FeedbackHomeDto.ReportFilters reportFilters() {
        FeedbackHomeDto.ReportFilters filters = new FeedbackHomeDto.ReportFilters();
        for (Schema.PicklistEntry entry : Questionnaire_Metadata__c.Feedback_Type__c.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                filters.feedbackTypes.add(new FeedbackHomeDto.FilterOption(entry.getValue(), entry.getLabel()));
            }
        }
        for (AggregateResult term : FeedbackHomeSelector.termsWithAnswers(TERM_OPTION_LIMIT)) {
            filters.terms.add(new FeedbackHomeDto.FilterOption((String) term.get('termId'), (String) term.get('termName')));
        }
        return filters;
    }
}