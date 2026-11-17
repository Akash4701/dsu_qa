@IsTest
private class FeedbackItemBacklogEmailBulkActionTest {

    // Deliberately no Assignee__c and no EmailTemplate setup here. This class's own job is only to
    // turn a List<Id> into one Request per Id (isReminder=false) and delegate once to
    // FeedbackItemEmailActivityAction.sendEmails -- that delegation's own success/failure handling,
    // including which template it resolves to, is already covered by
    // FeedbackItemEmailActivityActionTest. Reusing FIRST_TEMPLATE's literal DeveloperName here would
    // collide with the real, already-existing production EmailTemplate of that same name --
    // DUPLICATE_DEVELOPER_NAME is enforced even inside a test's rollback transaction -- so a missing
    // Assignee is used instead as a controllable, template-independent way to exercise the full
    // per-Id loop in sendBacklogEmails without touching EmailTemplate at all.
    @IsTest
    static void sendBacklogEmailsSendsOneRequestPerIdInASingleDelegatedCall() {
        List<Feedback_Item__c> feedbackItems = new List<Feedback_Item__c>();
        for (Integer i = 0; i < 3; i++) {
            feedbackItems.add(new Feedback_Item__c(Start_Date__c = Date.today()));
        }
        insert feedbackItems;

        List<Id> feedbackItemIds = new List<Id>();
        for (Feedback_Item__c item : feedbackItems) {
            feedbackItemIds.add(item.Id);
        }

        FeedbackItemBacklogEmailBulkAction.BulkRequest bulkRequest = new FeedbackItemBacklogEmailBulkAction.BulkRequest();
        bulkRequest.feedbackItemIds = feedbackItemIds;

        Test.startTest();
        List<FeedbackItemEmailActivityAction.Response> responses =
            FeedbackItemBacklogEmailBulkAction.sendBacklogEmails(
                new List<FeedbackItemBacklogEmailBulkAction.BulkRequest>{ bulkRequest }
            );
        Test.stopTest();

        System.assertEquals(3, responses.size(), 'One response should come back per Id submitted.');
        Set<Id> respondedIds = new Set<Id>();
        for (FeedbackItemEmailActivityAction.Response res : responses) {
            respondedIds.add(res.feedbackItemId);
            System.assertEquals(false, res.success, 'Missing Assignee should fail before sending.');
            System.assertEquals('Feedback Item Assignee is required.', res.message);
        }
        System.assertEquals(new Set<Id>(feedbackItemIds), respondedIds,
            'Every submitted Id should map to exactly one response.');
    }

    @IsTest
    static void sendBacklogEmailsHandlesNullAndEmptyInput() {
        FeedbackItemBacklogEmailBulkAction.BulkRequest emptyBulkRequest = new FeedbackItemBacklogEmailBulkAction.BulkRequest();
        emptyBulkRequest.feedbackItemIds = new List<Id>();
        FeedbackItemBacklogEmailBulkAction.BulkRequest nullFieldBulkRequest = new FeedbackItemBacklogEmailBulkAction.BulkRequest();

        Test.startTest();
        List<FeedbackItemEmailActivityAction.Response> nullResult =
            FeedbackItemBacklogEmailBulkAction.sendBacklogEmails(null);
        List<FeedbackItemEmailActivityAction.Response> emptyResult =
            FeedbackItemBacklogEmailBulkAction.sendBacklogEmails(
                new List<FeedbackItemBacklogEmailBulkAction.BulkRequest>{ emptyBulkRequest, nullFieldBulkRequest }
            );
        Test.stopTest();

        System.assertEquals(0, nullResult.size(), 'A null request list should produce no responses.');
        System.assertEquals(0, emptyResult.size(), 'An empty/null Id field should produce no responses.');
    }
}