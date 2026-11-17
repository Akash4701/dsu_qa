/**
 * Factory for FeedbackItemSource strategies, keyed by the Feedback Type of the Parameter Section
 * (Feedback_Master__c). Behaviour per type comes from Feedback_Type_Setting__mdt. Types whose Item Source is
 * 'Scheduler Form' (Interim, Final) return null here: their items are created per selected Course Offering
 * by FeedbackSchedulerService, not from the trigger.
 */
public with sharing class FeedbackItemSources {

    /** Built-in fallback, used only when a type has no Feedback_Type_Setting__mdt row. */
    private static final Set<String> TERM_STUDENT_TYPES = new Set<String>{
        ConstantsControllerClass.GraduationFeedback,
        ConstantsControllerClass.EndTermFeedback,
        ConstantsControllerClass.OrientationFeedback,
        ConstantsControllerClass.EventAndWorkshopFeedback,
        ConstantsControllerClass.MidTermFeedBack,
        ConstantsControllerClass.ASSISTANTDEANFEEDBACK,
        ConstantsControllerClass.DEPUTYDIRECTORFEEDBACK,
        ConstantsControllerClass.DEANFEEDBACK,
        ConstantsControllerClass.DIRECTORFEEDBACK
    };

    /** Types whose items keep their own dates (computed per course), so scheduler date edits do not cascade. */
    private static final Set<String> OWN_DATE_TYPES = new Set<String>{
        ConstantsControllerClass.InterimFeedback,
        ConstantsControllerClass.FacultyFeedback,
        ConstantsControllerClass.FinalFeedback
    };

    public static final String SOURCE_TERM_STUDENTS = 'Term Students';
    public static final String SOURCE_FACULTY = 'Faculty Enrolments';
    public static final String SOURCE_SCHEDULER_FORM = 'Scheduler Form';

    /**
     * Per-type behaviour from Feedback_Type_Setting__mdt, read once per transaction (getAll() costs no SOQL).
     * A type with a row follows the row; a type without one keeps the built-in behaviour above, so a missing
     * row never changes how an existing type works.
     */
    @TestVisible private static Map<String, Feedback_Type_Setting__mdt> settings;

    private static Feedback_Type_Setting__mdt settingFor(String feedbackType) {
        if (settings == null) {
            settings = new Map<String, Feedback_Type_Setting__mdt>();
            for (Feedback_Type_Setting__mdt row : Feedback_Type_Setting__mdt.getAll().values()) {
                if (String.isNotBlank(row.Feedback_Type__c)) {
                    settings.put(row.Feedback_Type__c, row);
                }
            }
        }
        return feedbackType == null ? null : settings.get(feedbackType);
    }

    /** @return the source for a feedback type, or null when items are not generated from the trigger. */
    public static FeedbackItemSource forType(String feedbackType) {
        Feedback_Type_Setting__mdt setting = settingFor(feedbackType);
        if (setting != null) {
            if (setting.Is_Active__c != true) {
                return null;
            }
            if (setting.Item_Source__c == SOURCE_FACULTY) {
                return new FacultySource();
            }
            return setting.Item_Source__c == SOURCE_TERM_STUDENTS ? (FeedbackItemSource) new TermStudentSource() : null;
        }
        if (feedbackType == ConstantsControllerClass.FacultyFeedback) {
            return new FacultySource();
        }
        if (feedbackType != null && TERM_STUDENT_TYPES.contains(feedbackType)) {
            return new TermStudentSource();
        }
        return null;
    }

    /** True when the scheduler's Start/End dates are copied onto its items. */
    public static Boolean isDateDriven(String feedbackType) {
        Feedback_Type_Setting__mdt setting = settingFor(feedbackType);
        if (setting != null) {
            return setting.Follows_Scheduler_Dates__c == true;
        }
        return feedbackType == null || !OWN_DATE_TYPES.contains(feedbackType);
    }

    /** One item per faculty course enrolment in the term; opens the day after the course ends, for 3 days. */
    public class FacultySource implements FeedbackItemSource {
        public String query() {
            return 'SELECT Id, hed__Contact__c, hed__Course_Offering__c, hed__Course_Offering__r.hed__End_Date__c '
                + 'FROM hed__Course_Enrollment__c '
                + 'WHERE hed__Course_Offering__r.hed__Term__c = :termId AND RecordType.Name = \'Faculty\'';
        }

        public Map<String, Object> binds(Feedback_Scheduler__c scheduler) {
            return new Map<String, Object>{ 'termId' => scheduler.Term__c };
        }

        public AccessLevel accessLevel() {
            return AccessLevel.USER_MODE;
        }

        public List<Feedback_Item__c> toItems(Feedback_Scheduler__c scheduler, List<SObject> rows) {
            List<Feedback_Item__c> items = new List<Feedback_Item__c>();
            for (SObject row : rows) {
                hed__Course_Enrollment__c enrolment = (hed__Course_Enrollment__c) row;
                Date courseEnd = enrolment.hed__Course_Offering__r?.hed__End_Date__c;
                items.add(new Feedback_Item__c(
                    Feedback_Scheduler__c = scheduler.Id,
                    Course_Offering__c = enrolment.hed__Course_Offering__c,
                    Feedback_Status__c = ConstantsControllerClass.PENDING,
                    Assignee__c = enrolment.hed__Contact__c,
                    Start_Date__c = courseEnd?.addDays(1),
                    End_Date__c = courseEnd?.addDays(3)
                ));
            }
            return items;
        }
    }

    /** One item per Student enrolled in the term's program; dates come from the scheduler. */
    public class TermStudentSource implements FeedbackItemSource {
        public String query() {
            return 'SELECT Id, hed__Contact__c FROM hed__Program_Enrollment__c '
                + 'WHERE Term__c = :termId AND hed__Contact__r.RecordType.Name = \'Student\'';
        }

        public Map<String, Object> binds(Feedback_Scheduler__c scheduler) {
            return new Map<String, Object>{ 'termId' => scheduler.Term__c };
        }

        public AccessLevel accessLevel() {
            // The scheduler's creator may not hold field access on every enrolment field; the generated
            // items are system data derived from the term, so they are read in system mode.
            return AccessLevel.SYSTEM_MODE;
        }

        public List<Feedback_Item__c> toItems(Feedback_Scheduler__c scheduler, List<SObject> rows) {
            List<Feedback_Item__c> items = new List<Feedback_Item__c>();
            for (SObject row : rows) {
                items.add(new Feedback_Item__c(
                    Feedback_Scheduler__c = scheduler.Id,
                    Feedback_Status__c = ConstantsControllerClass.PENDING,
                    Assignee__c = ((hed__Program_Enrollment__c) row).hed__Contact__c,
                    Start_Date__c = scheduler.Start_Date__c,
                    End_Date__c = scheduler.End_Date__c
                ));
            }
            return items;
        }
    }
}