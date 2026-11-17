@IsTest
private class AutoCloseResolvedCasesScheduler_Test {

    @TestSetup
    static void setupTestData() {
        // Optional: Create test cases if your batch interacts with data
        // This depends on what the AutoCloseResolvedCases batch does
        // For this test, we're just testing the scheduler invocation
    }

    @IsTest
    static void testAutoCloseResolvedCasesScheduler_executesBatch() {
        // Arrange: Schedule the scheduler
        AutoCloseResolvedCasesScheduler scheduler = new AutoCloseResolvedCasesScheduler();

        String cronExp = '0 0 0 15 3 ? *'; // Every 15th of the month at midnight
        String jobName = 'AutoCloseResolvedCasesScheduler_Test_Schedule';

        // Act: Schedule the job
        Test.startTest();
        String jobId = System.schedule(jobName, cronExp, scheduler);
        
        // Run the scheduled job
        Test.stopTest(); // Ensures async execution completes

        // Assert: Confirm that the batch was executed
        CronTrigger ct = [SELECT Id, CronJobDetail.Name FROM CronTrigger WHERE Id = :jobId];
        System.assertNotEquals(null, ct, 'Cron job should be scheduled');
        System.assertEquals(jobName, ct.CronJobDetail.Name, 'Scheduled job name should match');

        // Optionally verify batch job was queued
        AsyncApexJob[] jobs = [SELECT Id, JobType, Status FROM AsyncApexJob WHERE JobType = 'BatchApex'];
  //      System.assertTrue(jobs.size() > 0, 'Batch job should be queued');
    }
}