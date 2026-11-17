trigger CourseEnrollmentManagementTrigger on Course_Enrollment_Management__c (after insert, after update) {
    if (Trigger.isAfter) {
        CourseEnrollmentManagementService.afterInsertOrTermSet(
            Trigger.new,
            Trigger.isInsert ? null : Trigger.oldMap
        );
    }
}