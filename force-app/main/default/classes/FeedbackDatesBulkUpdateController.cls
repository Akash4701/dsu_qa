/**
 * Backs the "Update Feedback Dates" screen: pick schedulers, then set new Start/End dates per Course
 * Offering across all of their Feedback Items. Runs with sharing and in user mode (it used to be
 * without sharing, which let a user move dates on items they cannot see).
 *
 * Scale: offerings are read with one aggregate query (not by scanning every item), and the update is
 * capped to what one transaction can safely write, with a clear message when a selection is too big.
 */
public with sharing class FeedbackDatesBulkUpdateController {

    @TestVisible private static Integer maxItemsPerUpdate = 9000;
    private static final Integer SCHEDULER_LIMIT = 1000;

    public class CourseOfferingDateWrapper {
        @AuraEnabled public String courseOfferingId;
        @AuraEnabled public String courseOfferingName;
        @AuraEnabled public Date startDate;
        @AuraEnabled public Date endDate;
    }

    @AuraEnabled(cacheable=true)
    public static List<Feedback_Scheduler__c> getFeedbackSchedulers() {
        try {
            return [
                SELECT Id, Name, Description__c, Start_Date__c, End_Date__c, Term__r.Name
                FROM Feedback_Scheduler__c
                WITH USER_MODE
                ORDER BY CreatedDate DESC
                LIMIT :SCHEDULER_LIMIT
            ];
        } catch (Exception e) {
            throw toAuraException(e);
        }
    }

    @AuraEnabled
    public static List<CourseOfferingDateWrapper> getUniqueCourseOfferings(List<Id> selectedSchedulerIds) {
        List<CourseOfferingDateWrapper> result = new List<CourseOfferingDateWrapper>();
        if (selectedSchedulerIds == null || selectedSchedulerIds.isEmpty()) {
            return result;
        }
        try {
            // One row per Course Offering however many students (items) it has. MIN/MAX give the span the
            // offering's items currently cover, which equals each item's dates when they are uniform.
            for (AggregateResult row : [
                SELECT Course_Offering__c offeringId, Course_Offering__r.Name offeringName,
                       MIN(Start_Date__c) startDate, MAX(End_Date__c) endDate
                FROM Feedback_Item__c
                WHERE Feedback_Scheduler__c IN :selectedSchedulerIds AND Course_Offering__c != NULL
                WITH USER_MODE
                GROUP BY Course_Offering__c, Course_Offering__r.Name
                ORDER BY Course_Offering__r.Name
            ]) {
                CourseOfferingDateWrapper wrapper = new CourseOfferingDateWrapper();
                wrapper.courseOfferingId = (String) row.get('offeringId');
                wrapper.courseOfferingName = (String) row.get('offeringName');
                wrapper.startDate = (Date) row.get('startDate');
                wrapper.endDate = (Date) row.get('endDate');
                result.add(wrapper);
            }
            return result;
        } catch (Exception e) {
            throw toAuraException(e);
        }
    }

    @AuraEnabled
    public static void updateFeedbackDates(String courseOfferingDatesJson, List<Id> selectedSchedulerIds) {
        // Accepts JSON and deserializes manually: Aura's typed deserializer was
        // producing all-null wrappers for this parameter when called from LWC.
        if (String.isBlank(courseOfferingDatesJson)) {
            throw new AuraHandledException('No Course Offering dates provided.');
        }
        List<CourseOfferingDateWrapper> courseOfferingDates;
        try {
            courseOfferingDates = (List<CourseOfferingDateWrapper>) JSON.deserialize(
                courseOfferingDatesJson, List<CourseOfferingDateWrapper>.class
            );
        } catch (JSONException e) {
            throw new AuraHandledException('Invalid Course Offering dates payload: ' + e.getMessage());
        }
        if (courseOfferingDates == null || courseOfferingDates.isEmpty()) {
            throw new AuraHandledException('No Course Offering dates provided.');
        }
        if (selectedSchedulerIds == null || selectedSchedulerIds.isEmpty()) {
            throw new AuraHandledException('No Feedback Schedulers selected.');
        }

        try {
            Map<Id, CourseOfferingDateWrapper> datesByOfferingId = new Map<Id, CourseOfferingDateWrapper>();
            for (CourseOfferingDateWrapper wrapper : courseOfferingDates) {
                if (String.isNotBlank(wrapper.courseOfferingId)) {
                    datesByOfferingId.put(Id.valueOf(wrapper.courseOfferingId), wrapper);
                }
            }

            Integer probe = maxItemsPerUpdate + 1;
            List<Feedback_Item__c> itemsToUpdate = [
                SELECT Id, Course_Offering__c, Start_Date__c, End_Date__c
                FROM Feedback_Item__c
                WHERE Feedback_Scheduler__c IN :selectedSchedulerIds
                  AND Course_Offering__c IN :datesByOfferingId.keySet()
                WITH USER_MODE
                LIMIT :probe
            ];
            if (itemsToUpdate.size() > maxItemsPerUpdate) {
                throw new AuraHandledException(
                    'This would change more than ' + maxItemsPerUpdate + ' Feedback Items at once. '
                    + 'Select fewer schedulers or Course Offerings and run the update again.');
            }

            List<Feedback_Item__c> changed = new List<Feedback_Item__c>();
            for (Feedback_Item__c item : itemsToUpdate) {
                CourseOfferingDateWrapper wrapper = datesByOfferingId.get(item.Course_Offering__c);
                if (item.Start_Date__c != wrapper.startDate || item.End_Date__c != wrapper.endDate) {
                    item.Start_Date__c = wrapper.startDate;
                    item.End_Date__c = wrapper.endDate;
                    changed.add(item);
                }
            }
            if (!changed.isEmpty()) {
                update as user changed;
            }
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw toAuraException(e);
        }
    }

    private static AuraHandledException toAuraException(Exception e) {
        AuraHandledException wrapped = new AuraHandledException(e.getMessage());
        wrapped.setMessage(e.getMessage());
        return wrapped;
    }
}