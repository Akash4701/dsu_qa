public class ProgramPlanController {
    // For the time shown to the user: Salesforce runs up to 5 jobs side by side, and a job of 100 students takes
    // roughly 80 seconds in the Node layer. A planning figure, not a promise.
    @TestVisible private static final Integer JOBS_AT_ONCE = 5;
    @TestVisible private static final Integer SECONDS_PER_ROUND = 80;

    // The returned text is shown to the user in the toast of the Sync Enrollment button.
    @AuraEnabled
    public static String findProgramEnrollment(id programPlanId){
        
        List<hed__Program_Enrollment__c> programEnrollment = [SELECT Id FROM hed__Program_Enrollment__c WHERE hed__Program_Plan__c =:programPlanId];
        Set<Id> programEnrollmentIds = new Set<id>();
        for(hed__Program_Enrollment__c pe:programEnrollment){
            programEnrollmentIds.add(pe.Id);
        }
        ProgramEnrollmentTriggerHandler.SyncStart started = ProgramEnrollmentTriggerHandler.handleBulkProgramEnrollment(programEnrollmentIds);
        return syncMessage(started);
    }

    @TestVisible
    private static String syncMessage(ProgramEnrollmentTriggerHandler.SyncStart started) {
        if (started.jobs == 0 && started.studentsLeftOut == 0) {
            return 'Nothing to sync. All students here are already registered in the LMS.';
        }

        String message = '';
        if (started.jobs > 0) {
            Integer minutes = estimatedMinutes(started.jobs);
            message = 'Sync started for ' + started.students + ' student(s). Estimated time: about ' + minutes
                + (minutes == 1 ? ' minute' : ' minutes') + ' (it can take longer when the LMS is busy). '
                + 'Please do not click Sync Enrollment again while it is running.';
        }
        if (started.studentsLeftOut > 0) {
            message += (message == '' ? '' : ' ') + started.studentsLeftOut + ' student(s) could not be started because '
                + 'the Salesforce batch queue is full. Click Sync Enrollment again after the running sync has finished.';
        }
        return message;
    }

    @TestVisible
    private static Integer estimatedMinutes(Integer jobs) {
        Integer rounds = Math.ceil(Decimal.valueOf(jobs) / JOBS_AT_ONCE).intValue();
        Integer minutes = Math.ceil(Decimal.valueOf(rounds * SECONDS_PER_ROUND) / 60).intValue();
        return Math.max(1, minutes);
    }

}