@IsTest
private class FeedbackItemEmailActivityActionTest {
    @IsTest
    static void sendEmailsUsesFeedbackItemAssigneeAndTemplate() {
        Contact student = new Contact(
            FirstName = 'Feedback',
            LastName = 'Student',
            Email = 'feedback.student@example.com'
        );
        insert student;

        Feedback_Item__c feedbackItem = new Feedback_Item__c(
            Assignee__c = student.Id,
            Start_Date__c = Date.today()
        );
        insert feedbackItem;

        EmailTemplate template = createTestTemplate(
            'Test_Feedback_Schedule_Email_Notification',
            'Test Feedback Schedule Email Notification'
        );

        FeedbackItemEmailActivityAction.Request req = new FeedbackItemEmailActivityAction.Request();
        req.feedbackItemId = feedbackItem.Id;
        req.templateDeveloperName = template.DeveloperName;

        Test.startTest();
        List<FeedbackItemEmailActivityAction.Response> responses =
            FeedbackItemEmailActivityAction.sendEmails(new List<FeedbackItemEmailActivityAction.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'One response should be returned.');
        System.assertEquals(feedbackItem.Id, responses[0].feedbackItemId, 'Response should map to the feedback item.');
        System.assertEquals(true, responses[0].success,
            'Email should send once Start Date has arrived: ' + responses[0].message);
    }

    @IsTest
    static void sendEmailsReturnsErrorForMissingAssignee() {
        Feedback_Item__c feedbackItem = new Feedback_Item__c(Start_Date__c = Date.today());
        insert feedbackItem;

        FeedbackItemEmailActivityAction.Request req = new FeedbackItemEmailActivityAction.Request();
        req.feedbackItemId = feedbackItem.Id;

        Test.startTest();
        List<FeedbackItemEmailActivityAction.Response> responses =
            FeedbackItemEmailActivityAction.sendEmails(new List<FeedbackItemEmailActivityAction.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'One response should be returned.');
        System.assertEquals(false, responses[0].success, 'Missing assignee should fail before sending.');
        System.assertEquals('Feedback Item Assignee is required.', responses[0].message);
    }

    @IsTest
    static void sendEmailsBlocksWhenStartDateNotYetArrived() {
        Contact student = new Contact(
            FirstName = 'Feedback',
            LastName = 'Future',
            Email = 'feedback.future@example.com'
        );
        insert student;

        Feedback_Item__c feedbackItem = new Feedback_Item__c(
            Assignee__c = student.Id,
            Start_Date__c = Date.today().addDays(3)
        );
        insert feedbackItem;

        FeedbackItemEmailActivityAction.Request req = new FeedbackItemEmailActivityAction.Request();
        req.feedbackItemId = feedbackItem.Id;

        Test.startTest();
        List<FeedbackItemEmailActivityAction.Response> responses =
            FeedbackItemEmailActivityAction.sendEmails(new List<FeedbackItemEmailActivityAction.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'One response should be returned.');
        System.assertEquals(false, responses[0].success, 'A future Start Date should block the send.');
        System.assertEquals('Feedback Item Start Date has not arrived yet — email not sent.', responses[0].message);
    }

    @IsTest
    static void sendEmailsBlocksWhenStartDateIsBlank() {
        Contact student = new Contact(
            FirstName = 'Feedback',
            LastName = 'Blank',
            Email = 'feedback.blank@example.com'
        );
        insert student;

        Feedback_Item__c feedbackItem = new Feedback_Item__c(Assignee__c = student.Id);
        insert feedbackItem;

        FeedbackItemEmailActivityAction.Request req = new FeedbackItemEmailActivityAction.Request();
        req.feedbackItemId = feedbackItem.Id;

        Test.startTest();
        List<FeedbackItemEmailActivityAction.Response> responses =
            FeedbackItemEmailActivityAction.sendEmails(new List<FeedbackItemEmailActivityAction.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'One response should be returned.');
        System.assertEquals(false, responses[0].success, 'A blank Start Date should block the send.');
        System.assertEquals('Feedback Item Start Date has not arrived yet — email not sent.', responses[0].message);
    }

    private static EmailTemplate createTestTemplate(String developerNamePrefix, String name) {
        String uniqueSuffix = String.valueOf(Datetime.now().getTime());

        EmailTemplate template = new EmailTemplate(
            DeveloperName = developerNamePrefix + '_' + uniqueSuffix,
            Name = name,
            FolderId = UserInfo.getUserId(), // personal folder: no dependency on shared email folders
            TemplateType = 'text',
            Subject = 'Feedback notification',
            Body = 'Please submit feedback.',
            IsActive = true
        );
        // EmailTemplate is a setup object: insert it in its own transaction (avoids MIXED_DML_OPERATION)
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert template;
        }
        return template;
    }
}