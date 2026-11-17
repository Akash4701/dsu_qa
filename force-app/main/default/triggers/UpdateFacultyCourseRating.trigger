trigger UpdateFacultyCourseRating on Collected_Feedback_Data__c (
    before insert, before update,
    after insert, after update
) {
    if (Trigger.isBefore) {
        FacultyCourseRatingHandler.populateParametersFromQuestion(
            Trigger.new,
            Trigger.isUpdate ? Trigger.oldMap : null
        );
    } else {
        FacultyCourseRatingHandler.afterSave(
            Trigger.newMap.keySet(),
            Trigger.isUpdate ? Trigger.oldMap : null
        );
    }
}