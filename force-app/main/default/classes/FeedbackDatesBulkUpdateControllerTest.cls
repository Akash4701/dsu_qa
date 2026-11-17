@IsTest
private class FeedbackDatesBulkUpdateControllerTest {

    // Tests run as a dedicated admin user so WITH SECURITY_ENFORCED in the
    // controller does not fail when the deploying/test-running user's profile
    // lacks FLS on the feedback fields.
    private static User createAdminUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        String uniq = String.valueOf(Datetime.now().getTime()) + String.valueOf(Math.round(Math.random() * 10000));
        User u = new User(
            Alias = 'fbtest',
            Email = 'fbtest@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'FeedbackTest',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            UserName = 'fbtest' + uniq + '@example.com.dsu'
        );
        insert u;
        // New fields carry no profile FLS; access comes from the Feedback Management permission set.
        Id permSetId = [SELECT Id FROM PermissionSet WHERE Name = 'Feedback_Management' LIMIT 1].Id;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = permSetId);
        }
        return u;
    }

    private static Map<String, Object> setupData() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        hed__Term__c term = new hed__Term__c(
            Name = 'Test Term',
            hed__Account__c = acc.Id,
            Term_Reference__c = 'Term 1'
        );
        insert term;

        hed__Course__c course = new hed__Course__c(
            Name = 'Test Course',
            hed__Course_ID__c = 'C-001',
            hed__Account__c = acc.Id
        );
        insert course;

        hed__Course_Offering__c co1 = new hed__Course_Offering__c(
            Name = 'CO-1',
            hed__Course__c = course.Id,
            hed__Term__c = term.Id
        );
        hed__Course_Offering__c co2 = new hed__Course_Offering__c(
            Name = 'CO-2',
            hed__Course__c = course.Id,
            hed__Term__c = term.Id
        );
        insert new List<hed__Course_Offering__c>{ co1, co2 };

        Feedback_Scheduler__c fsA = new Feedback_Scheduler__c(Term__c = term.Id);
        Feedback_Scheduler__c fsB = new Feedback_Scheduler__c(Term__c = term.Id);
        insert new List<Feedback_Scheduler__c>{ fsA, fsB };

        Date startDate = Date.today();
        Date endDate = Date.today().addDays(5);

        List<Feedback_Item__c> items = new List<Feedback_Item__c>{
            new Feedback_Item__c(Feedback_Scheduler__c = fsA.Id, Course_Offering__c = co1.Id, Start_Date__c = startDate, End_Date__c = endDate),
            new Feedback_Item__c(Feedback_Scheduler__c = fsB.Id, Course_Offering__c = co1.Id, Start_Date__c = startDate, End_Date__c = endDate),
            new Feedback_Item__c(Feedback_Scheduler__c = fsA.Id, Course_Offering__c = co2.Id, Start_Date__c = startDate, End_Date__c = endDate)
        };
        insert items;

        return new Map<String, Object>{
            'fsA' => fsA, 'fsB' => fsB, 'co1' => co1, 'co2' => co2
        };
    }

    @IsTest
    static void testGetFeedbackSchedulers() {
        User admin = createAdminUser();
        System.runAs(admin) {
            Map<String, Object> data = setupData();

            Test.startTest();
            List<Feedback_Scheduler__c> result = FeedbackDatesBulkUpdateController.getFeedbackSchedulers();
            Test.stopTest();

            System.assertEquals(2, result.size(), 'Both schedulers should be returned');
        }
    }

    @IsTest
    static void testGetUniqueCourseOfferings() {
        User admin = createAdminUser();
        System.runAs(admin) {
            Map<String, Object> data = setupData();
            Feedback_Scheduler__c fsA = (Feedback_Scheduler__c) data.get('fsA');
            Feedback_Scheduler__c fsB = (Feedback_Scheduler__c) data.get('fsB');

            Test.startTest();
            List<FeedbackDatesBulkUpdateController.CourseOfferingDateWrapper> result =
                FeedbackDatesBulkUpdateController.getUniqueCourseOfferings(
                    new List<Id>{ fsA.Id, fsB.Id }
                );
            Test.stopTest();

            System.assertEquals(2, result.size(), 'CO-1 should appear once despite two schedulers using it');

            List<FeedbackDatesBulkUpdateController.CourseOfferingDateWrapper> emptyResult =
                FeedbackDatesBulkUpdateController.getUniqueCourseOfferings(null);
            System.assertEquals(0, emptyResult.size(), 'Null selection should return empty list');
        }
    }

    @IsTest
    static void testUpdateFeedbackDates_onlyUpdatesSelectedSchedulerAndOffering() {
        User admin = createAdminUser();
        System.runAs(admin) {
        Map<String, Object> data = setupData();
        Feedback_Scheduler__c fsA = (Feedback_Scheduler__c) data.get('fsA');
        Feedback_Scheduler__c fsB = (Feedback_Scheduler__c) data.get('fsB');
        hed__Course_Offering__c co1 = (hed__Course_Offering__c) data.get('co1');
        hed__Course_Offering__c co2 = (hed__Course_Offering__c) data.get('co2');

        Date newStart = Date.today().addDays(10);
        Date newEnd = Date.today().addDays(20);

        FeedbackDatesBulkUpdateController.CourseOfferingDateWrapper wrapper =
            new FeedbackDatesBulkUpdateController.CourseOfferingDateWrapper();
        wrapper.courseOfferingId = co1.Id;
        wrapper.startDate = newStart;
        wrapper.endDate = newEnd;

        Test.startTest();
        FeedbackDatesBulkUpdateController.updateFeedbackDates(
            JSON.serialize(new List<FeedbackDatesBulkUpdateController.CourseOfferingDateWrapper>{ wrapper }),
            new List<Id>{ fsA.Id }
        );
        Test.stopTest();

        Map<Id, Feedback_Item__c> itemsBySchedulerAndOffering = new Map<Id, Feedback_Item__c>();
        for (Feedback_Item__c fi : [
            SELECT Feedback_Scheduler__c, Course_Offering__c, Start_Date__c, End_Date__c
            FROM Feedback_Item__c
        ]) {
            itemsBySchedulerAndOffering.put(fi.Feedback_Scheduler__c, fi);
        }

        for (Feedback_Item__c fi : [
            SELECT Start_Date__c, End_Date__c
            FROM Feedback_Item__c
            WHERE Feedback_Scheduler__c = :fsA.Id AND Course_Offering__c = :co1.Id
        ]) {
            System.assertEquals(newStart, fi.Start_Date__c, 'Selected scheduler + offering should be updated');
            System.assertEquals(newEnd, fi.End_Date__c, 'Selected scheduler + offering should be updated');
        }

        for (Feedback_Item__c fi : [
            SELECT Start_Date__c, End_Date__c
            FROM Feedback_Item__c
            WHERE Feedback_Scheduler__c = :fsB.Id AND Course_Offering__c = :co1.Id
        ]) {
            System.assertNotEquals(newStart, fi.Start_Date__c, 'Unselected scheduler should not be updated');
        }

        for (Feedback_Item__c fi : [
            SELECT Start_Date__c, End_Date__c
            FROM Feedback_Item__c
            WHERE Feedback_Scheduler__c = :fsA.Id AND Course_Offering__c = :co2.Id
        ]) {
            System.assertNotEquals(newStart, fi.Start_Date__c, 'Unselected course offering should not be updated');
        }
        }
    }

    @IsTest
    static void testUpdateFeedbackDates_validation() {
        try {
            FeedbackDatesBulkUpdateController.updateFeedbackDates(null, new List<Id>{ '000000000000000AAA' });
            System.assert(false, 'Expected AuraHandledException for empty dates');
        } catch (AuraHandledException e) {
        }

        try {
            FeedbackDatesBulkUpdateController.updateFeedbackDates('not-valid-json', new List<Id>{ '000000000000000AAA' });
            System.assert(false, 'Expected AuraHandledException for malformed JSON');
        } catch (AuraHandledException e) {
        }

        FeedbackDatesBulkUpdateController.CourseOfferingDateWrapper wrapper =
            new FeedbackDatesBulkUpdateController.CourseOfferingDateWrapper();
        try {
            FeedbackDatesBulkUpdateController.updateFeedbackDates(
                JSON.serialize(new List<FeedbackDatesBulkUpdateController.CourseOfferingDateWrapper>{ wrapper }),
                null
            );
            System.assert(false, 'Expected AuraHandledException for empty scheduler list');
        } catch (AuraHandledException e) {
        }
    }
}