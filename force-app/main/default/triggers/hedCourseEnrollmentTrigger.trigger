trigger hedCourseEnrollmentTrigger on hed__Course_Enrollment__c (
    before insert, before update,
    after update
) {
    // BEFORE: update fields on the same Course Enrollment record (no extra DML needed)
    if (Trigger.isBefore) {
        ExamEligibilityHandler.handleCourseEnrollmentBefore(
            Trigger.new,
            Trigger.isInsert ? null : Trigger.oldMap
        );
    }

    // AFTER UPDATE: existing eligibility logic
    if (Trigger.isAfter && Trigger.isUpdate) {
        ExamEligibilityHandler.handleCourseEnrollmentUpdate(Trigger.newMap, Trigger.oldMap);
    }
}