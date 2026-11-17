/**
 * Business logic behind the Feedback Scheduler form: creating a scheduler (with its per-course items
 * for Interim/Final feedback) and adding or removing items later. Called by FeedbackSchedulerController,
 * which stays a thin @AuraEnabled facade. Term-level feedback types are handled by the trigger path
 * (FeedbackItemGenerationService), not here.
 */
public with sharing class FeedbackSchedulerService {
    public class FeedbackSchedulerException extends Exception {}

    public static final String INTERIM_FEEDBACK = ConstantsControllerClass.InterimFeedback;
    public static final String FINAL_FEEDBACK = ConstantsControllerClass.FinalFeedback;

    /** Course-level feedback inserts one item per enrolled student; keep one request inside DML limits. */
    @TestVisible private static Integer maxItemsPerRequest = 9000;
    @TestVisible private static final Integer COURSE_OFFERING_LIMIT = 2000;
    private static final Decimal INTERIM_SESSION_FRACTION = 0.20;
    private static final Integer INTERIM_WINDOW_DAYS = 3;
    private static final Integer FINAL_WINDOW_DAYS = 7;

    // ---------- Reads for the form ----------

    public static List<hed__Course_Offering__c> courseOfferings(Id termId) {
        if (termId == null) {
            return new List<hed__Course_Offering__c>();
        }
        return FeedbackSchedulerSelector.courseOfferingsForTerm(termId, COURSE_OFFERING_LIMIT);
    }

    public static String feedbackType(Id feedbackMasterId) {
        if (feedbackMasterId == null) {
            return null;
        }
        Questionnaire_Metadata__c section = FeedbackSchedulerSelector.section(feedbackMasterId);
        return section?.Feedback_Type__c;
    }

    // ---------- Create ----------

    public static Id createSchedulerWithItems(
        Id feedbackMasterId, Id termId, Date startDate, Date dueDate, String feedbackName, List<Id> courseOfferingIds
    ) {
        Questionnaire_Metadata__c section = feedbackMasterId == null ? null : FeedbackSchedulerSelector.section(feedbackMasterId);
        if (section == null) {
            throw new FeedbackSchedulerException('Select a Feedback Master you have access to.');
        }
        Boolean courseLevel = isCourseLevel(section.Feedback_Type__c);
        Boolean hasOfferings = courseOfferingIds != null && !courseOfferingIds.isEmpty();

        Savepoint beforeCreate = Database.setSavepoint();
        try {
            Feedback_Scheduler__c scheduler = new Feedback_Scheduler__c(
                Feedback_Master__c = feedbackMasterId,
                Term__c = termId,
                Start_Date__c = startDate,
                End_Date__c = dueDate,
                Description__c = feedbackName,
                Selected_Course_Offerings__c = courseLevel && hasOfferings ? offeringsRichText(courseOfferingIds) : ''
            );
            insert as user scheduler;

            if (courseLevel && hasOfferings) {
                insertItems(buildCourseItems(scheduler.Id, section.Feedback_Type__c, courseOfferingIds));
            }
            return scheduler.Id;
        } catch (Exception e) {
            // A scheduler without the items the user asked for would be misleading: undo the whole create.
            Database.rollback(beforeCreate);
            throw e;
        }
    }

    // ---------- Add / remove items on an existing scheduler ----------

    public static void addFeedbackItems(Id schedulerId, List<Id> courseOfferingIds) {
        if (schedulerId == null) {
            throw new FeedbackSchedulerException('Scheduler Id missing.');
        }
        if (courseOfferingIds == null || courseOfferingIds.isEmpty()) {
            throw new FeedbackSchedulerException('Select at least one Course Offering.');
        }
        Feedback_Scheduler__c scheduler = FeedbackSchedulerSelector.byId(schedulerId);
        if (scheduler == null) {
            throw new FeedbackSchedulerException('Feedback Scheduler not found.');
        }

        Set<Id> alreadyScheduled = FeedbackSchedulerSelector.offeringIdsAlreadyScheduled(schedulerId);
        List<Id> newOfferingIds = new List<Id>();
        Set<Id> requestedIds = new Set<Id>(courseOfferingIds);
        for (Id offeringId : requestedIds) {
            if (!alreadyScheduled.contains(offeringId)) {
                newOfferingIds.add(offeringId);
            }
        }
        if (!newOfferingIds.isEmpty()) {
            insertItems(buildCourseItems(schedulerId, scheduler.Feedback_Master__r?.Feedback_Type__c, newOfferingIds));
        }
    }

    public static List<Feedback_Item__c> existingOfferingItems(Id schedulerId) {
        List<Feedback_Item__c> result = new List<Feedback_Item__c>();
        if (schedulerId == null) {
            return result;
        }
        // One row per Course Offering (not per student): the list is for choosing offerings.
        List<Id> scheduledOfferingIds = new List<Id>(FeedbackSchedulerSelector.offeringIdsAlreadyScheduled(schedulerId));
        List<hed__Course_Offering__c> offerings = FeedbackSchedulerSelector.offeringNames(scheduledOfferingIds);
        for (hed__Course_Offering__c offering : offerings) {
            // Read-only shape for the UI (Course_Offering__r.Name); never inserted.
            result.add(new Feedback_Item__c(Course_Offering__c = offering.Id, Course_Offering__r = offering));
        }
        return result;
    }

    public static void deleteFeedbackItem(Id feedbackItemId) {
        if (feedbackItemId == null) {
            throw new FeedbackSchedulerException('Feedback Item Id is required.');
        }
        List<Feedback_Item__c> doomed = [SELECT Id FROM Feedback_Item__c WHERE Id = :feedbackItemId WITH USER_MODE];
        if (!doomed.isEmpty()) {
            delete as user doomed;
        }
    }

    // ---------- Item building (pure + one bounded query) ----------

    @TestVisible
    private static Boolean isCourseLevel(String feedbackType) {
        return feedbackType == INTERIM_FEEDBACK || feedbackType == FINAL_FEEDBACK;
    }

    private static List<Feedback_Item__c> buildCourseItems(Id schedulerId, String feedbackType, List<Id> offeringIds) {
        List<Feedback_Item__c> items = new List<Feedback_Item__c>();
        if (!isCourseLevel(feedbackType)) {
            return items;
        }
        // One extra row tells us the selection is too large without loading it all.
        List<hed__Course_Enrollment__c> enrolments = FeedbackSchedulerSelector.studentEnrolments(offeringIds, maxItemsPerRequest + 1);
        if (enrolments.size() > maxItemsPerRequest) {
            throw new FeedbackSchedulerException(
                'This selection covers more than ' + maxItemsPerRequest + ' enrolled students. '
                + 'Select fewer Course Offerings and create another schedule for the rest.');
        }
        Map<Id, hed__Course_Offering__c> offeringsWithSessions = feedbackType == INTERIM_FEEDBACK
            ? FeedbackSchedulerSelector.offeringsWithSessions(offeringIds)
            : new Map<Id, hed__Course_Offering__c>();

        for (hed__Course_Enrollment__c enrolment : enrolments) {
            Date startDate;
            Date endDate;
            if (feedbackType == INTERIM_FEEDBACK) {
                startDate = interimStart(enrolment, offeringsWithSessions);
                endDate = startDate?.addDays(INTERIM_WINDOW_DAYS);
            } else {
                Date courseEnd = enrolment.hed__Course_Offering__r?.hed__End_Date__c;
                startDate = courseEnd;
                endDate = courseEnd?.addDays(FINAL_WINDOW_DAYS);
            }
            items.add(new Feedback_Item__c(
                Feedback_Scheduler__c = schedulerId,
                Course_Offering__c = enrolment.hed__Course_Offering__c,
                Feedback_Status__c = ConstantsControllerClass.PENDING,
                Assignee__c = enrolment.hed__Contact__c,
                Start_Date__c = startDate,
                End_Date__c = endDate
            ));
        }
        return items;
    }

    /** Interim feedback opens once ~20% of the course's sessions have run; falls back to the course start. */
    private static Date interimStart(hed__Course_Enrollment__c enrolment, Map<Id, hed__Course_Offering__c> offeringsWithSessions) {
        List<Session__c> sessions = offeringsWithSessions.get(enrolment.hed__Course_Offering__c)?.Sessions__r;
        if (sessions != null && !sessions.isEmpty()) {
            Integer index = Math.max(Math.floor(sessions.size() * INTERIM_SESSION_FRACTION).intValue(), 0);
            return sessions[index].Start_Date__c;
        }
        return enrolment.hed__Course_Offering__r?.hed__Start_Date__c;
    }

    private static String offeringsRichText(List<Id> offeringIds) {
        List<hed__Course_Offering__c> offerings = FeedbackSchedulerSelector.offeringNames(offeringIds);
        if (offerings.isEmpty()) {
            return '';
        }
        String html = '<ul>';
        for (hed__Course_Offering__c offering : offerings) {
            html += '<li>' + offering.Name.escapeHtml4() + '</li>';
        }
        return html + '</ul>';
    }

    private static void insertItems(List<Feedback_Item__c> items) {
        if (!items.isEmpty()) {
            insert items;
        }
    }
}