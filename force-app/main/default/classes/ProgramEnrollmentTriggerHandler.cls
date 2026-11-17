public class ProgramEnrollmentTriggerHandler {
    // Students (contacts) sent to the Node layer by one batch job, i.e. by one /bulkenrollment call.
    @TestVisible private static final Integer STUDENTS_PER_JOB = 100;
    // Salesforce lets at most 100 batch jobs wait in the Flex Queue (status Holding); the 5 running ones are extra.
    @TestVisible private static final Integer FLEX_QUEUE_LIMIT = 100;

    // What one click on Sync Enrollment started (shown to the user by ProgramPlanController).
    public class SyncStart {
        public Integer students = 0;         // students sent to the jobs that were started
        public Integer jobs = 0;             // jobs started
        public Integer studentsLeftOut = 0;  // pending students not started because the Flex Queue is full
    }

    @AuraEnabled
    public static void handleAfterInsert(id newEnrollments) {
        Set<Id> contactIds = new Set<Id>();
        hed__Program_Enrollment__c pe = [SELECT Id,hed__Contact__c FROM hed__Program_Enrollment__c WHERE id = :newEnrollments];
            if (pe.hed__Contact__c != null) {
                contactIds.add(pe.hed__Contact__c);
            }
        

        if (!contactIds.isEmpty()) {
            Database.executeBatch(new SendContactIdsBatch(new List<Id>(contactIds)), 10);        }
    }
    
    public static SyncStart handleBulkProgramEnrollment(Set<Id> newEnrollments) {
    Set<Id> contactIds = new Set<Id>();

    List<hed__Program_Enrollment__c> programEnrollments = [
        SELECT Id, hed__Contact__c
        FROM hed__Program_Enrollment__c
        WHERE Id IN :newEnrollments
    ];

    for (hed__Program_Enrollment__c pe : programEnrollments) {
        if (pe.hed__Contact__c != null) {
            contactIds.add(pe.hed__Contact__c);
        }
    }

    if (contactIds.isEmpty()) {
        return new SyncStart();
    }
    return startSyncJobs(contactIds);
}

    /**
     * Starts one SendContactIdsBatch job for every STUDENTS_PER_JOB students (1,000 students = 10 jobs). Each job
     * runs a single scope, so it makes one call to the Node layer with its 100 students, and Salesforce runs up to
     * 5 jobs side by side. Students without any pending (Registered__c = false) course enrollment are left out, so
     * clicking Sync again only retries what is still pending. Returns what was started.
     */
    @TestVisible
    private static SyncStart startSyncJobs(Set<Id> contactIds) {
        List<List<Id>> jobs = splitIntoJobs(findStudentsWithPendingEnrollments(contactIds), STUDENTS_PER_JOB);
        Integer jobsToStart = Math.min(jobs.size(), availableJobSlots());

        SyncStart started = new SyncStart();
        for (Integer i = 0; i < jobs.size(); i++) {
            if (i < jobsToStart) {
                Database.executeBatch(new SendContactIdsBatch(jobs.get(i)), STUDENTS_PER_JOB);
                started.jobs++;
                started.students += jobs.get(i).size();
            } else {
                started.studentsLeftOut += jobs.get(i).size();
            }
        }

        if (jobsToStart < jobs.size()) {
            // The Flex Queue is full. The students left out stay unregistered, so another click picks them up.
            System.debug(LoggingLevel.WARN, 'LMS sync: started ' + jobsToStart + ' of ' + jobs.size()
                + ' jobs because the Flex Queue is full. Click Sync Enrollment again once jobs have finished.');
        }
        System.debug('LMS sync: ' + jobsToStart + ' job(s) started for ' + contactIds.size() + ' student(s) selected.');
        return started;
    }

    private static List<Id> findStudentsWithPendingEnrollments(Set<Id> contactIds) {
        List<Id> pending = new List<Id>();
        for (Contact c : [
            SELECT Id
            FROM Contact
            WHERE Id IN :contactIds
            AND Id IN (SELECT hed__Contact__c FROM hed__Course_Enrollment__c WHERE Registered__c = false)
            ORDER BY Id
        ]) {
            pending.add(c.Id);
        }
        return pending;
    }

    @TestVisible
    private static List<List<Id>> splitIntoJobs(List<Id> contactIds, Integer studentsPerJob) {
        List<List<Id>> jobs = new List<List<Id>>();
        List<Id> current = new List<Id>();
        for (Id contactId : contactIds) {
            current.add(contactId);
            if (current.size() == studentsPerJob) {
                jobs.add(current);
                current = new List<Id>();
            }
        }
        if (!current.isEmpty()) {
            jobs.add(current);
        }
        return jobs;
    }

    @TestVisible
    private static Integer availableJobSlots() {
        Integer holding = [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'BatchApex' AND Status = 'Holding'];
        return Math.max(0, FLEX_QUEUE_LIMIT - holding);
    }

    public static void handleAffiliation(List<hed__Program_Enrollment__c> newEnrollments){
        Set<Id> affiliationIds = new Set<id>();
        for(hed__Program_Enrollment__c pe : newEnrollments ){
            if (pe.hed__Affiliation__c != null) {
                //pe.hed__Affiliation__r.Is_Program_Enrollment__c = True;
                affiliationIds.add(pe.hed__Affiliation__c);
            }
        }
        if (affiliationIds.isEmpty()) {
            return;
        }

        List<hed__Affiliation__c> affiliations = [SELECT Id  FROM hed__Affiliation__c WHERE Id in :affiliationIds];
        for(hed__Affiliation__c aff : affiliations ){
            aff.Is_Program_Enrollment__c = True;
        }
        update affiliations;
    }
public static void handleEndDateStatusUpdate(List<hed__Program_Enrollment__c> enrollments) {
    Date today = Date.today();
    for (hed__Program_Enrollment__c pe : enrollments) {
        if (pe.hed__End_Date__c != null && 
            pe.hed__End_Date__c < today && 
            pe.hed__Enrollment_Status__c != 'In active') {
            pe.hed__Enrollment_Status__c = 'In active';
        }
        else if(pe.hed__End_Date__c > today && 
                 pe.hed__Enrollment_Status__c != 'Active' )
                {
                 pe.hed__Enrollment_Status__c = 'Active';
                }
    }
}
}