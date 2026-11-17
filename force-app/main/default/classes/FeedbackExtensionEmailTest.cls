/**
 * Date-change emails respect the org's daily email allowance: what fits is sent now, the rest is flagged
 * and drained by FeedbackExtensionEmailBatch. Capacity is simulated with capacityOverride so no test
 * needs thousands of emails.
 */
@IsTest
private class FeedbackExtensionEmailTest {

    @TestSetup
    static void setup() {
        FeedbackTestFactory.enableIntegrationSettings();
        Account account = FeedbackTestFactory.createAccount();
        hed__Term__c term = FeedbackTestFactory.createTerm(account.Id);
        Contact student = FeedbackTestFactory.createStudents(1)[0];
        student.Email = 'feedback.student@example.com';
        update student;
        Questionnaire_Metadata__c section = FeedbackTestFactory.createSection(ConstantsControllerClass.FinalFeedback);
        Feedback_Scheduler__c scheduler = FeedbackTestFactory.createScheduler(
            section.Id, term.Id, Date.today(), Date.today().addDays(7));
        insert new Feedback_Item__c(
            Feedback_Scheduler__c = scheduler.Id, Assignee__c = student.Id, Feedback_Status__c = 'Pending',
            Start_Date__c = Date.today(), End_Date__c = Date.today().addDays(3));
        // EmailTemplate is a setup object: its own transaction avoids MIXED_DML_OPERATION.
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert new EmailTemplate(
                FolderId = UserInfo.getUserId(), Name = FeedbackExtensionEmailService.TEMPLATE_NAME,
                DeveloperName = 'Test_Extension_' + Datetime.now().getTime(), TemplateType = 'custom',
                Subject = 'Feedback Submission Deadline Extended',
                HtmlValue = '<p>%%COURSE_OFFERING_NAME%% %%FEEDBACK_TYPE%%</p>');
        }
    }

    private static Feedback_Item__c item() {
        return [SELECT Id, End_Date__c, Extension_Email_Pending__c FROM Feedback_Item__c LIMIT 1];
    }

    private static Integer jobCount() {
        return [SELECT COUNT() FROM CronTrigger WHERE CronJobDetail.Name = :FeedbackExtensionEmailBatch.JOB_NAME];
    }

    @IsTest
    static void whenTheDailyAllowanceIsUsedUpTheEmailIsDeferredAndAJobIsScheduled() {
        FeedbackExtensionEmailService.capacityOverride = 0;
        Feedback_Item__c item = item();
        item.End_Date__c = item.End_Date__c.addDays(5);

        Test.startTest();
        update item;
        Test.stopTest();

        System.assertEquals(true, item().Extension_Email_Pending__c, 'Flagged instead of lost');
        System.assertEquals(1, jobCount(), 'The catch-up job exists exactly once (created now, or already scheduled)');
    }

    @IsTest
    static void theCatchUpJobSendsDeferredEmailsOnceCapacityReturns() {
        FeedbackExtensionEmailService.capacityOverride = 0;
        Feedback_Item__c item = item();
        item.End_Date__c = item.End_Date__c.addDays(5);
        update item;
        System.assertEquals(true, item().Extension_Email_Pending__c);

        FeedbackExtensionEmailService.capacityOverride = 1000;
        Test.startTest();
        Database.executeBatch(new FeedbackExtensionEmailBatch(), FeedbackExtensionEmailBatch.SCOPE);
        Test.stopTest();

        System.assertEquals(false, item().Extension_Email_Pending__c, 'Cleared after the email is processed');
    }

    @IsTest
    static void theBatchLeavesItemsFlaggedWhileThereIsNoCapacity() {
        FeedbackExtensionEmailService.capacityOverride = 0;
        Feedback_Item__c item = item();
        item.End_Date__c = item.End_Date__c.addDays(2);
        update item;

        Test.startTest();
        Database.executeBatch(new FeedbackExtensionEmailBatch(), FeedbackExtensionEmailBatch.SCOPE);
        Test.stopTest();

        System.assertEquals(true, item().Extension_Email_Pending__c, 'Still waiting for tomorrow');
    }

    @IsTest
    static void ensureScheduledIsIdempotent() {
        Test.startTest();
        FeedbackExtensionEmailBatch.ensureScheduled();
        FeedbackExtensionEmailBatch.ensureScheduled();
        Test.stopTest();

        System.assertEquals(1, jobCount());
    }

    @IsTest
    static void capacityKeepsAReserveForTheRestOfTheOrg() {
        FeedbackExtensionEmailService.dailyReserve = 200;
        FeedbackExtensionEmailService.capacityOverride = 250;
        System.assertEquals(50, FeedbackExtensionEmailService.availableCapacity());

        FeedbackExtensionEmailService.capacityOverride = 150;
        System.assertEquals(0, FeedbackExtensionEmailService.availableCapacity(), 'Never dips into the reserve');

        FeedbackExtensionEmailService.capacityOverride = 100000;
        System.assertEquals(FeedbackExtensionEmailService.perTransactionLimit, FeedbackExtensionEmailService.availableCapacity(),
            'Capped per transaction');
    }

    @IsTest
    static void unchangedDatesNeverQueueAnEmail() {
        Feedback_Item__c item = item();
        item.Feedback_Status__c = 'Submitted';
        // CronTrigger is org-wide: production already runs the real catch-up job, so compare against the
        // count before the update instead of assuming there is none.
        Integer jobsBefore = jobCount();

        Test.startTest();
        update item;
        Test.stopTest();

        System.assertEquals(false, item().Extension_Email_Pending__c);
        System.assertEquals(jobsBefore, jobCount(), 'No job is scheduled when nothing was deferred');
        System.assertEquals(0, FeedbackItemTriggerHandler.changedDateItemIds(new List<Feedback_Item__c>{ item }, null).size());
    }
}