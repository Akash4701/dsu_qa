@isTest
private class ProgramPlanControllerTest {

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
            hed__End_Date__c = Date.today().addMonths(6)
        );
        insert progPlan;

        // Create Program Enrollment linked to Program Plan
        hed__Program_Enrollment__c enrollment = new hed__Program_Enrollment__c(
            hed__Contact__c = con.Id,
            hed__Program_Plan__c = progPlan.Id
        );
        insert enrollment;
    }

    @isTest
    static void testFindProgramEnrollment() {
        // Get the inserted Program Plan
        hed__Program_Plan__c plan = [SELECT Id FROM hed__Program_Plan__c LIMIT 1];
        try{
              Test.startTest();
        ProgramPlanController.findProgramEnrollment(plan.Id);
        Test.stopTest();
}
        catch(Exception e){
            
        }
      

        // Basic assertion just to confirm the test ran to completion
    }

    private static ProgramEnrollmentTriggerHandler.SyncStart startOf(Integer students, Integer jobs, Integer leftOut) {
        ProgramEnrollmentTriggerHandler.SyncStart started = new ProgramEnrollmentTriggerHandler.SyncStart();
        started.students = students;
        started.jobs = jobs;
        started.studentsLeftOut = leftOut;
        return started;
    }

    @isTest
    static void testEstimatedMinutes() {
        System.assertEquals(2, ProgramPlanController.estimatedMinutes(1));   // one round of 80 s
        System.assertEquals(2, ProgramPlanController.estimatedMinutes(5));   // still one round
        System.assertEquals(3, ProgramPlanController.estimatedMinutes(10));  // 1,000 students: 2 rounds, 160 s
        System.assertEquals(14, ProgramPlanController.estimatedMinutes(50)); // 5,000 students: 10 rounds, 800 s
        System.assertEquals(27, ProgramPlanController.estimatedMinutes(100)); // 10,000 students: 20 rounds, 1,600 s
    }

    @isTest
    static void testSyncMessageWhenStudentsAreQueued() {
        String message = ProgramPlanController.syncMessage(startOf(1000, 10, 0));
        System.assert(message.contains('Sync started for 1000 student(s)'), message);
        System.assert(message.contains('about 3 minutes'), message);
        System.assert(message.contains('do not click Sync Enrollment again'), message);
        System.assert(!message.contains('queue is full'), message);
    }

    @isTest
    static void testSyncMessageWhenNothingIsPending() {
        String message = ProgramPlanController.syncMessage(startOf(0, 0, 0));
        System.assert(message.startsWith('Nothing to sync'), message);
    }

    @isTest
    static void testSyncMessageWhenTheBatchQueueIsFull() {
        String partly = ProgramPlanController.syncMessage(startOf(500, 5, 250));
        System.assert(partly.contains('Sync started for 500 student(s)'), partly);
        System.assert(partly.contains('250 student(s) could not be started'), partly);

        String notAtAll = ProgramPlanController.syncMessage(startOf(0, 0, 300));
        System.assert(!notAtAll.contains('Sync started'), notAtAll);
        System.assert(notAtAll.contains('300 student(s) could not be started'), notAtAll);
    }

    @isTest
    static void testFindProgramEnrollmentReturnsAMessage() {
        // The test data has no course enrollment, so no student is pending and no job (or callout) is started.
        hed__Program_Plan__c plan = [SELECT Id FROM hed__Program_Plan__c LIMIT 1];
        Test.startTest();
        String message = ProgramPlanController.findProgramEnrollment(plan.Id);
        Test.stopTest();
        System.assert(message.startsWith('Nothing to sync'), message);
    }
}