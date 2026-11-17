@isTest
private class EventBatchProcessTest {

    @isTest static void testBatchExecution() {
        // Create test Event_Target_Audience__c record (so batch query returns data)
        Event_Target_Audience__c eta = new Event_Target_Audience__c(
            Invite_All__c = true
        );
        insert eta;

        // Prepare list of EmailMessageWrapper for the JSON string
        List<EventBatchProcess.EmailMessageWrapper> emailWrappers = new List<EventBatchProcess.EmailMessageWrapper>();
        EventBatchProcess.EmailMessageWrapper wrapper = new EventBatchProcess.EmailMessageWrapper();
        wrapper.toAddresses = new List<String>{'test@example.com'};
        wrapper.subject = 'Test Subject';
        wrapper.plainTextBody = 'Test email body';
        emailWrappers.add(wrapper);

        // Serialize to JSON string
        String emailsToSendJson = JSON.serialize(emailWrappers);

        // Instantiate batch with JSON string
        EventBatchProcess batch = new EventBatchProcess(emailsToSendJson);

        // Execute the batch (batch size 1 for simplicity)
        Test.startTest();
        Database.executeBatch(batch, 1);
        Test.stopTest();

        // You can add asserts here if needed, but since Messaging.sendEmail is a system call, 
        // it can't be directly asserted. You can verify no exceptions occur.
    }
}