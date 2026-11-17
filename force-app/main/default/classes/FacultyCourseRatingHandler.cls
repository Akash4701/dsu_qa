/**
 * Collected_Feedback_Data__c trigger logic:
 *  - before save: copy the Feedback Master Child onto Parameters__c (populateParametersFromQuestion)
 *  - after save:  roll Final Feedback ratings into the matching Faculty_Course_Association__c average
 *                 (updateFacultyRatings, entered through afterSave so the trigger stays logic-free)
 */
public with sharing class FacultyCourseRatingHandler {

    private static final String FINAL_FEEDBACK_RECORD_TYPE = 'Final_Feedback';
    private static final String RATING_QUESTION_TYPE = 'Rating';

    /** After-save entry point: re-reads the saved rows (formula fields and parents are only available after save). */
    public static void afterSave(Set<Id> savedIds, Map<Id, Collected_Feedback_Data__c> oldById) {
        if (savedIds == null || savedIds.isEmpty()) {
            return;
        }
        List<Collected_Feedback_Data__c> candidates = new List<Collected_Feedback_Data__c>();
        for (Collected_Feedback_Data__c row : [
            SELECT Id, Question_Type__c, Course_Name__c, Course_Offering__c, Rating__c, Rating_F__c, RecordTypeId,
                   Course_Offering__r.hed__Faculty__c
            FROM Collected_Feedback_Data__c
            WHERE Id IN :savedIds AND Question_Type__c = :RATING_QUESTION_TYPE
        ]) {
            // On update, only a changed rating should be rolled in again; otherwise every unrelated edit
            // would add the same rating to the average a second time.
            Collected_Feedback_Data__c before = oldById?.get(row.Id);
            if (before == null || before.Rating__c != row.Rating__c) {
                candidates.add(row);
            }
        }
        updateFacultyRatings(candidates);
    }

    public static void updateFacultyRatings(List<Collected_Feedback_Data__c> feedbackList) {
        Schema.RecordTypeInfo ratingType = Schema.SObjectType.Collected_Feedback_Data__c
            .getRecordTypeInfosByDeveloperName().get(FINAL_FEEDBACK_RECORD_TYPE);
        if (ratingType == null || feedbackList == null || feedbackList.isEmpty()) {
            return;
        }

        Map<String, List<Decimal>> ratingsByKey = new Map<String, List<Decimal>>();
        Set<Id> courseIds = new Set<Id>();
        Set<Id> facultyIds = new Set<Id>();
        for (Collected_Feedback_Data__c feedback : feedbackList) {
            Id facultyId = feedback.Course_Offering__r?.hed__Faculty__c;
            if (feedback.Question_Type__c == RATING_QUESTION_TYPE
                && feedback.Course_Name__c != null
                && feedback.Course_Offering__c != null
                && feedback.Rating_F__c != null
                && feedback.RecordTypeId == ratingType.getRecordTypeId()
                && facultyId != null) {
                String key = feedback.Course_Name__c + '-' + facultyId;
                if (!ratingsByKey.containsKey(key)) {
                    ratingsByKey.put(key, new List<Decimal>());
                }
                ratingsByKey.get(key).add(feedback.Rating_F__c);
                courseIds.add(feedback.Course_Name__c);
                facultyIds.add(facultyId);
            }
        }
        if (ratingsByKey.isEmpty()) {
            return;
        }

        // Only the associations that can match, never the whole table.
        List<Faculty_Course_Association__c> toUpdate = new List<Faculty_Course_Association__c>();
        for (Faculty_Course_Association__c association : [
            SELECT Id, Course__c, Faculty__c, Rating__c
            FROM Faculty_Course_Association__c
            WHERE Course__c IN :courseIds AND Faculty__c IN :facultyIds
        ]) {
            List<Decimal> ratings = ratingsByKey.get(association.Course__c + '-' + association.Faculty__c);
            if (ratings == null) {
                continue;
            }
            if (association.Rating__c != null) {
                ratings.add(association.Rating__c);
            }
            Decimal total = 0;
            for (Decimal rating : ratings) {
                total += rating;
            }
            association.Rating__c = (total / ratings.size()).setScale(2, RoundingMode.HALF_UP);
            toUpdate.add(association);
        }
        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }

    public static void populateParametersFromQuestion(
        List<Collected_Feedback_Data__c> newList,
        Map<Id, Collected_Feedback_Data__c> oldMap
    ) {
        if (newList == null || newList.isEmpty()) {
            return;
        }

        Boolean isInsert = (oldMap == null);

        for (Collected_Feedback_Data__c rec : newList) {
            if (rec == null || rec.Feedback_Master_Child__c == null) {
                continue;
            }

            Boolean shouldPopulate = false;

            if (isInsert) {
                shouldPopulate = (rec.Parameters__c == null);
            } else {
                Collected_Feedback_Data__c oldRec = oldMap.get(rec.Id);

                shouldPopulate =
                    oldRec == null ||
                    oldRec.Feedback_Master_Child__c != rec.Feedback_Master_Child__c ||
                    rec.Parameters__c == null;
            }

            if (shouldPopulate) {
                rec.Parameters__c = rec.Feedback_Master_Child__c;
            }
        }
    }
}