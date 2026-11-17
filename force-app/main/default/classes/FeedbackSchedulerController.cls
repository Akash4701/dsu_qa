/**
 * Thin @AuraEnabled facade for the Feedback Scheduler form. No logic: it delegates to
 * FeedbackSchedulerService and turns any failure into a readable AuraHandledException so the LWC
 * can show it (see c/errorUtils) instead of a raw stack.
 */
public with sharing class FeedbackSchedulerController {
    public static final String INTERIM_FEEDBACK = FeedbackSchedulerService.INTERIM_FEEDBACK;
    public static final String FINAL_FEEDBACK = FeedbackSchedulerService.FINAL_FEEDBACK;

    @AuraEnabled(cacheable=true)
    public static List<hed__Course_Offering__c> getCourseOfferings(Id termId) {
        try {
            return FeedbackSchedulerService.courseOfferings(termId);
        } catch (Exception e) {
            throw toAuraException(e);
        }
    }

    @AuraEnabled(cacheable=true)
    public static String getFeedbackType(Id feedbackMasterId) {
        try {
            return FeedbackSchedulerService.feedbackType(feedbackMasterId);
        } catch (Exception e) {
            throw toAuraException(e);
        }
    }

    @AuraEnabled
    public static Id createSchedulerWithItems(
        Id feedbackMasterId, Id termId, Date startDate, Date dueDate, String feedbackName, List<Id> courseOfferingIds
    ) {
        try {
            return FeedbackSchedulerService.createSchedulerWithItems(
                feedbackMasterId, termId, startDate, dueDate, feedbackName, courseOfferingIds);
        } catch (Exception e) {
            throw toAuraException(e);
        }
    }

    @AuraEnabled
    public static void addFeedbackItems(Id schedulerId, List<Id> courseOfferingIds) {
        try {
            FeedbackSchedulerService.addFeedbackItems(schedulerId, courseOfferingIds);
        } catch (Exception e) {
            throw toAuraException(e);
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Feedback_Item__c> getExistingFeedbackItems(Id schedulerId) {
        try {
            return FeedbackSchedulerService.existingOfferingItems(schedulerId);
        } catch (Exception e) {
            throw toAuraException(e);
        }
    }

    @AuraEnabled
    public static void deleteFeedbackItem(Id feedbackItemId) {
        try {
            FeedbackSchedulerService.deleteFeedbackItem(feedbackItemId);
        } catch (Exception e) {
            throw toAuraException(e);
        }
    }

    /** Aura only shows the message of an AuraHandledException; setMessage makes getMessage() match in Apex too. */
    private static AuraHandledException toAuraException(Exception e) {
        AuraHandledException wrapped = new AuraHandledException(e.getMessage());
        wrapped.setMessage(e.getMessage());
        return wrapped;
    }
}