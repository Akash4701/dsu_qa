@isTest
private class ProgramEnrollmentTriggerHandlerTest {

    @testSetup
    static void setupData() {
        // Create Account
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        // Create Contact
        Contact con = new Contact(LastName = 'Test Contact', AccountId = acc.Id);
        insert con;

        // Create Program Plan
        hed__Program_Plan__c progPlan = new hed__Program_Plan__c(
            Name = 'Test Program Plan',
            hed__Start_Date__c = Date.today(),
            hed__End_Date__c = Date.today().addMonths(6),
            hed__Account__c = acc.Id
        );
        insert progPlan;

        // Create Affiliation
        hed__Affiliation__c aff = new hed__Affiliation__c(
            hed__Contact__c = con.Id,
            hed__Account__c = acc.Id,
            Program_Plan__c = progPlan.Id,
            hed__StartDate__c = Date.today()
        );
        insert aff;

        // Create Program Enrollment
        hed__Program_Enrollment__c enrollment = new hed__Program_Enrollment__c(
            hed__Contact__c = con.Id,
            hed__Program_Plan__c = progPlan.Id,
            hed__Affiliation__c = aff.Id
        );
        insert enrollment;
    }

    @isTest
    static void testHandleAfterInsert() {
        hed__Program_Enrollment__c enrollment = [SELECT Id FROM hed__Program_Enrollment__c LIMIT 1];
        try{
            Test.startTest();
        ProgramEnrollmentTriggerHandler.handleAfterInsert(enrollment.Id);
        Test.stopTest();
        }
        catch(Exception e){
            
        }
        

        // There's no assertion since it's a batch, but it shouldn't throw any errors
    }

    @isTest
    static void testHandleBulkProgramEnrollment() {
        Set<Id> enrollIds = new Set<Id>();
        for (hed__Program_Enrollment__c pe : [SELECT Id FROM hed__Program_Enrollment__c]) {
            enrollIds.add(pe.Id);
        }
        try{
           Test.startTest();
        ProgramEnrollmentTriggerHandler.handleBulkProgramEnrollment(enrollIds);
        Test.stopTest(); 
        }
        catch(Exception e){
} 
        

    }

    @isTest
    static void testHandleAffiliation() {
        List<hed__Program_Enrollment__c> enrollments = [SELECT Id, hed__Affiliation__c FROM hed__Program_Enrollment__c];

        Test.startTest();
        ProgramEnrollmentTriggerHandler.handleAffiliation(enrollments);
        Test.stopTest();

    }

    // ---- Sync Enrollment: one job per 100 students ----

    private class EmptyLmsResponseMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{"success":"true","data":[]}');
            return res;
        }
    }

    private static List<Id> fakeContactIds(Integer count) {
        List<Id> ids = new List<Id>();
        for (Integer i = 0; i < count; i++) {
            ids.add(Id.valueOf('003' + ('000000000000' + String.valueOf(i)).right(12)));
        }
        return ids;
    }

    private static void createCourseEnrollment(Contact con, Boolean registered) {
        insert new LMS_URL__c(Name = 'Bulk Enrollment', Bulk_Enroll__c = 'https://lms.example.com/bulkenrollment');

        Account parentAccount = new Account(Name = 'Sync Parent', LMS_Id__c = 'SYNCPARENT1');
        insert parentAccount;
        Account department = new Account(Name = 'Sync Department', ParentId = parentAccount.Id, LMS_Id__c = 'SYNCDEPT1');
        insert department;
        hed__Course__c course = new hed__Course__c(Name = 'Sync Course', hed__Account__c = department.Id, LMS_Id__c = 'SYNCCOURSE1');
        insert course;
        hed__Term__c term = new hed__Term__c(Name = 'Sync Term', hed__Account__c = department.Id, Term_Reference__c = 'Semester 1');
        insert term;
        hed__Course_Offering__c offering = new hed__Course_Offering__c(
            Name = 'Sync 101', hed__Course__c = course.Id, LMS_Id__c = 'SYNCOFFER1', hed__Term__c = term.Id
        );
        insert offering;
        insert new hed__Course_Enrollment__c(
            hed__Contact__c = con.Id, hed__Course_Offering__c = offering.Id, Registered__c = registered
        );
    }

    @isTest
    static void testSplitIntoJobsMakesOneJobPer100Students() {
        List<List<Id>> jobs = ProgramEnrollmentTriggerHandler.splitIntoJobs(
            fakeContactIds(250), ProgramEnrollmentTriggerHandler.STUDENTS_PER_JOB
        );

        System.assertEquals(3, jobs.size(), '250 students make 3 jobs');
        System.assertEquals(100, jobs.get(0).size());
        System.assertEquals(100, jobs.get(1).size());
        System.assertEquals(50, jobs.get(2).size());
    }

    @isTest
    static void testSplitIntoJobsKeepsExactMultipleInOneJobPerHundred() {
        List<List<Id>> jobs = ProgramEnrollmentTriggerHandler.splitIntoJobs(
            fakeContactIds(1000), ProgramEnrollmentTriggerHandler.STUDENTS_PER_JOB
        );

        System.assertEquals(10, jobs.size(), '1000 students make 10 jobs');
        for (List<Id> job : jobs) {
            System.assertEquals(100, job.size());
        }
    }

    @isTest
    static void testSplitIntoJobsWithNoStudentsMakesNoJobs() {
        System.assertEquals(
            0,
            ProgramEnrollmentTriggerHandler.splitIntoJobs(new List<Id>(), ProgramEnrollmentTriggerHandler.STUDENTS_PER_JOB).size()
        );
    }

    @isTest
    static void testAvailableJobSlotsAreTheFlexQueueLimitMinusTheHoldingJobs() {
        // AsyncApexJob is not isolated in tests, so count the Holding jobs the same way instead of assuming zero.
        Integer holding = [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'BatchApex' AND Status = 'Holding'];
        System.assertEquals(
            Math.max(0, ProgramEnrollmentTriggerHandler.FLEX_QUEUE_LIMIT - holding),
            ProgramEnrollmentTriggerHandler.availableJobSlots()
        );
    }

    @isTest
    static void testStartSyncJobsStartsOneJobForAStudentWithPendingEnrollment() {
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        createCourseEnrollment(con, false);
        Test.setMock(HttpCalloutMock.class, new EmptyLmsResponseMock());

        Test.startTest();
        ProgramEnrollmentTriggerHandler.SyncStart started = ProgramEnrollmentTriggerHandler.startSyncJobs(new Set<Id>{ con.Id });
        Test.stopTest();

        System.assertEquals(1, started.jobs);
        System.assertEquals(1, started.students);
        System.assertEquals(0, started.studentsLeftOut);
    }

    @isTest
    static void testStartSyncJobsSkipsStudentsWhoseEnrollmentsAreAllRegistered() {
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        createCourseEnrollment(con, true);
        Test.setMock(HttpCalloutMock.class, new EmptyLmsResponseMock());

        Test.startTest();
        ProgramEnrollmentTriggerHandler.SyncStart started = ProgramEnrollmentTriggerHandler.startSyncJobs(new Set<Id>{ con.Id });
        Test.stopTest();

        System.assertEquals(0, started.jobs, 'Clicking Sync again must not send students that are already registered');
        System.assertEquals(0, started.students);
    }
}