/**
 * Read-only data shapes returned to the Feedback Management home LWCs. Plain DTOs: no queries,
 * no logic, so the UI never depends on SObject field names.
 */
public with sharing class FeedbackHomeDto {

    /** One headline number on the overview. tone: success | warning | error | info. */
    public class Stat {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public String sub;
        @AuraEnabled public String tone;

        public Stat(String label, String value, String sub, String tone) {
            this.label = label;
            this.value = value;
            this.sub = sub;
            this.tone = tone;
        }
    }

    public class Alert {
        @AuraEnabled public String title;
        @AuraEnabled public String detail;
        @AuraEnabled public String tone;
        @AuraEnabled public Id recordId;

        public Alert(String title, String detail, String tone, Id recordId) {
            this.title = title;
            this.detail = detail;
            this.tone = tone;
            this.recordId = recordId;
        }
    }

    public class StatusCount {
        @AuraEnabled public String status;
        @AuraEnabled public Integer count;

        public StatusCount(String status, Integer count) {
            this.status = status;
            this.count = count;
        }
    }

    public class Overview {
        @AuraEnabled public List<Stat> stats = new List<Stat>();
        @AuraEnabled public List<Alert> alerts = new List<Alert>();
        @AuraEnabled public List<StatusCount> itemStatusCounts = new List<StatusCount>();
        @AuraEnabled public List<ScheduleRow> recentSchedules = new List<ScheduleRow>();
        @AuraEnabled public Integer targetResponseRate;
        @AuraEnabled public Integer activeSectionCount = 0;
        @AuraEnabled public Integer activeParameterCount = 0;
        @AuraEnabled public Integer scheduleCount = 0;
        // Active Parameter Sections per record type (status = record type developer name).
        @AuraEnabled public List<StatusCount> sectionTypeCounts = new List<StatusCount>();
    }

    /** A Parameter Section (Questionnaire_Metadata__c). */
    public class SectionRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String recordType;
        @AuraEnabled public String recordTypeLabel;
        @AuraEnabled public String feedbackType;
        @AuraEnabled public String academic;
        @AuraEnabled public String mode;
        @AuraEnabled public Boolean active;
        @AuraEnabled public Integer parameterCount;
        @AuraEnabled public Decimal sortOrder;
    }

    /** One page of Parameter Sections plus the paging facts the UI needs. */
    public class SectionPage {
        @AuraEnabled public List<SectionRow> rows = new List<SectionRow>();
        @AuraEnabled public Integer total = 0;
        @AuraEnabled public Integer pageNumber = 1;
        @AuraEnabled public Integer pageSize = 25;
        @AuraEnabled public Integer totalPages = 1;
        // True when more records match than can be paged to (SOQL OFFSET limit): ask the user to refine.
        @AuraEnabled public Boolean truncated = false;
    }

    /** One page of schedules; statusCounts are per status under the current search (status = label). */
    public class SchedulePage {
        @AuraEnabled public List<ScheduleRow> rows = new List<ScheduleRow>();
        @AuraEnabled public Integer total = 0;
        @AuraEnabled public Integer pageNumber = 1;
        @AuraEnabled public Integer pageSize = 25;
        @AuraEnabled public Integer totalPages = 1;
        @AuraEnabled public Boolean truncated = false;
        @AuraEnabled public List<StatusCount> statusCounts = new List<StatusCount>();
    }

    /** A Parameter (Question_Metadata__c). */
    public class ParameterRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String label;
        @AuraEnabled public String question;
        @AuraEnabled public Id sectionId;
        @AuraEnabled public String sectionName;
        @AuraEnabled public String questionType;
        @AuraEnabled public String type;
        @AuraEnabled public Boolean mandatory;
        @AuraEnabled public Boolean active;
        @AuraEnabled public Decimal maxGrade;
        @AuraEnabled public Decimal sortOrder;
    }

    /** A Feedback Scheduler with its rolled-up item counts. status: Scheduled | Live | Closed. */
    public class ScheduleRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String term;
        @AuraEnabled public String template;
        @AuraEnabled public String feedbackType;
        @AuraEnabled public Date startDate;
        @AuraEnabled public Date endDate;
        @AuraEnabled public String status;
        @AuraEnabled public Integer total = 0;
        @AuraEnabled public Integer submitted = 0;
        @AuraEnabled public Integer pending = 0;
        @AuraEnabled public Integer rate = 0;
    }

    /** A Feedback Item (one respondent / course offering of a schedule). */
    public class ItemRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public String assignee;
        @AuraEnabled public String courseOffering;
        @AuraEnabled public Date startDate;
        @AuraEnabled public Date endDate;
        @AuraEnabled public Decimal reminders;
    }

    /** One collected answer with the student's identity (USN comes from their Affiliation). */
    public class ReportRow {
        @AuraEnabled public Id id;
        @AuraEnabled public Id contactId;
        @AuraEnabled public String student;
        @AuraEnabled public String usn;
        @AuraEnabled public String program;
        @AuraEnabled public String programPlan;
        @AuraEnabled public String term;
        @AuraEnabled public String section;
        @AuraEnabled public String feedbackType;
        @AuraEnabled public Decimal questionNo;
        @AuraEnabled public String question;
        @AuraEnabled public String questionType;
        @AuraEnabled public String answer;
        @AuraEnabled public Datetime submittedOn;
        @AuraEnabled public String status;
    }

    public class ReportPage {
        @AuraEnabled public List<ReportRow> rows = new List<ReportRow>();
        @AuraEnabled public Integer total = 0;
        @AuraEnabled public Integer pageNumber = 1;
        @AuraEnabled public Integer pageSize = 25;
        @AuraEnabled public Integer totalPages = 1;
        @AuraEnabled public Boolean truncated = false;
    }

    public class FilterOption {
        @AuraEnabled public String value;
        @AuraEnabled public String label;

        public FilterOption(String value, String label) {
            this.value = value;
            this.label = label;
        }
    }

    public class ReportFilters {
        @AuraEnabled public List<FilterOption> feedbackTypes = new List<FilterOption>();
        @AuraEnabled public List<FilterOption> terms = new List<FilterOption>();
    }
}