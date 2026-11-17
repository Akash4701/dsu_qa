@isTest
public class FeedbackItemTriggerHandlerTest {
    @testSetup
    static void setupData() {
        Id studentRTCon = Schema.SObjectType.Contact.getRecordTypeInfosByName().get('Student').getRecordTypeId();
        Contact studentContact = new Contact(RecordTypeId = studentRTCon, FirstName = 'Student', LastName = 'One', Email = 'student.one@test.com');
        insert studentContact;

        Account acc = new Account(Name = 'test');
        insert acc;

        hed__Term__c term = new hed__Term__c(
            Name = 'Fall 2024',
            hed__Account__c = acc.Id,
            Term_Reference__c = 'Term 1'
        );
        insert term;

        hed__Course__c course = new hed__Course__c(
            hed__Account__c = acc.Id
        );
        insert course;

        hed__Course_Offering__c offering = new hed__Course_Offering__c(
            Name = 'Course1',
            hed__Term__c = term.Id,
            hed__Start_Date__c = Date.today(),
            hed__End_Date__c = Date.today().addDays(30),
            hed__Course__c = course.Id
        );
        insert offering;

        Id RecordType = Schema.SObjectType.Questionnaire_Metadata__c.getRecordTypeInfosByName().get('Feedback').getRecordTypeId();
        Questionnaire_Metadata__c quesMaster = new Questionnaire_Metadata__c(
            RecordTypeId = RecordType,
            Feedback_Type__c = 'Faculty Feedback'
        );
        insert quesMaster;

        Feedback_Scheduler__c scheduler = new Feedback_Scheduler__c(
            Feedback_Master__c = quesMaster.Id,
            Term__c = term.Id,
            Start_Date__c = Date.today()
        );
        insert scheduler;

        Feedback_Item__c item = new Feedback_Item__c(
            Assignee__c = studentContact.Id,
            Course_Offering__c = offering.Id,
            Feedback_Scheduler__c = scheduler.Id,
            Feedback_Status__c = 'Pending',
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addDays(3)
        );
        insert item;

        // EmailTemplate rows aren't visible to test methods without SeeAllData=true -- insert our
        // own with the exact Name the handler queries by, so the real "template found, merge
        // fields resolve" path is what's actually exercised. EmailTemplate is a "setup object" in
        // Apex DML terms -- mixing it with the non-setup DML above (Contact, Account, etc.) in the
        // SAME transaction throws MIXED_DML_OPERATION regardless of ordering ("or vice versa" per
        // the platform's own error text). System.runAs opens a genuinely separate transaction,
        // which is the standard way to combine both kinds of DML in one test. Uses the same plain
        // %%TOKEN%% placeholders as the real deployed template -- {{{Feedback_Item__c.Course_
        // Offering__r.Name}}} throws EMAIL_TEMPLATE_MERGEFIELD_ERROR on this template engine
        // (relationship traversal, not a direct field).
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert new EmailTemplate(
                FolderId = UserInfo.getUserId(), // personal folder: no dependency on shared email folders
                Name = 'Feedback Extension template',
                DeveloperName = 'Test_Feedback_Extension_' + Datetime.now().getTime(),
                TemplateType = 'custom',
                Subject = 'Feedback Submission Deadline Extended',
                HtmlValue = '<p>%%COURSE_OFFERING_NAME%% %%FEEDBACK_TYPE%% {{{Feedback_Item__c.End_Date__c}}}</p>'
            );
        }
    }

    @isTest
    static void testDateChange_sendsFeedbackExtensionEmail() {
        Feedback_Item__c item = [SELECT Id, End_Date__c FROM Feedback_Item__c LIMIT 1];
        item.End_Date__c = item.End_Date__c.addDays(5);

        Test.startTest();
        update item;
        Test.stopTest();

        // Limits.getEmailInvocations() does not reliably reflect usage once checked after
        // Test.stopTest() -- asserting on the actual EmailMessage record is both more robust and
        // more meaningful: it proves the real business outcome (a logged, sent email attached to
        // the Feedback_Item__c), not just that some send API was called. Filtered by Subject, not
        // just RelatedToId -- Feedback_Item__c.workflow-meta.xml also fires its own, unrelated
        // "Feedback_Schedule_Notification" email alert against this same record, so RelatedToId
        // alone isn't a unique enough signal for this specific extension email.
        List<EmailMessage> sent = [
            SELECT Id, ToAddress, Status
            FROM EmailMessage
            WHERE RelatedToId = :item.Id AND Subject = 'Feedback Submission Deadline Extended'
        ];
        System.assertEquals(1, sent.size(), 'Extension email should actually be sent and logged, not silently fail.');
        System.assertEquals('student.one@test.com', sent[0].ToAddress);
        System.assertEquals('3', sent[0].Status, 'Status 3 = Sent.');
    }

    @isTest
    static void testDatesUnchanged_doesNotSendFeedbackExtensionEmail() {
        Feedback_Item__c item = [SELECT Id, Feedback_Status__c FROM Feedback_Item__c LIMIT 1];
        item.Feedback_Status__c = 'Completed';

        Test.startTest();
        update item;
        Test.stopTest();

        System.assertEquals(
            0,
            [SELECT COUNT() FROM EmailMessage WHERE RelatedToId = :item.Id AND Subject = 'Feedback Submission Deadline Extended'],
            'No extension email should be sent when Start_Date__c/End_Date__c did not change.'
        );
    }

    @isTest
    static void testStartDateChange_sendsFeedbackExtensionEmail() {
        Feedback_Item__c item = [SELECT Id, Start_Date__c FROM Feedback_Item__c LIMIT 1];
        item.Start_Date__c = item.Start_Date__c.addDays(1);

        Test.startTest();
        update item;
        Test.stopTest();

        System.assertEquals(
            1,
            [SELECT COUNT() FROM EmailMessage WHERE RelatedToId = :item.Id AND Subject = 'Feedback Submission Deadline Extended'],
            'Extension email should actually be sent and logged, not silently fail.'
        );
    }
}