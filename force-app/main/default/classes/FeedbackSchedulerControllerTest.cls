@IsTest
private class FeedbackSchedulerControllerTest {

    @IsTest
    static void testGetCourseOfferings() {
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Contact faculty = new Contact(LastName = 'Faculty', AccountId = acc.Id);
        insert faculty;

        hed__Term__c term = new hed__Term__c(
            Name = 'Test Term',
            hed__Account__c=acc.Id,
            Term_Reference__c ='Term 1'
        );
        insert term;

        hed__Course__c course = new hed__Course__c(
            Name = 'Test Course',
            hed__Course_ID__c = 'C-001',
            hed__Account__c=acc.Id
        );
        insert course;

        hed__Course_Offering__c co = new hed__Course_Offering__c(
            Name = 'Test Course Offering',
            hed__Course__c = course.Id,
            hed__Term__c = term.Id,
            hed__Start_Date__c = Date.today(),
            hed__End_Date__c = Date.today().addDays(30),
            hed__Faculty__c = faculty.Id
        );
        insert co;

        Test.startTest();
        List<hed__Course_Offering__c> result =
            FeedbackSchedulerController.getCourseOfferings(term.Id);
        Test.stopTest();

        System.assertEquals(1, result.size(), 'One course offering should be returned');
        System.assertEquals(co.Id, result[0].Id, 'Returned course offering should match inserted record');

        List<hed__Course_Offering__c> emptyResult =
            FeedbackSchedulerController.getCourseOfferings(null);
        System.assertEquals(0, emptyResult.size(), 'Null termId should return empty list');
            }
    }
    private static Id getEnrollmentRT(String name) {
        return [SELECT Id FROM RecordType
                WHERE SObjectType = 'hed__Course_Enrollment__c'
                AND Name = :name
                LIMIT 1].Id;
    }


    @IsTest
    static void testGetFeedbackType() {
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
        Questionnaire_Metadata__c qm = new Questionnaire_Metadata__c(
            RecordTypeId = FeedbackTestRecordTypes.questionnaire(),
            Name = 'Test QM',
            Feedback_Type__c = 'Interim Feedback'
        );
        insert qm;

        Test.startTest();
        String feedbackType =
            FeedbackSchedulerController.getFeedbackType(qm.Id);
        Test.stopTest();

        System.assertEquals('Interim Feedback', feedbackType,
            'Feedback type should match the value on the record');

        String nullResult =
            FeedbackSchedulerController.getFeedbackType(null);
        System.assertEquals(null, nullResult, 'Null Id should return null');
            }
    }
     @IsTest
    static void testAddFeedbackItems_InterimAndFinal() {
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
        Account acc = new Account(Name = 'Acc2');
        insert acc;

        Contact student = new Contact(
            LastName = 'Student2',
            AccountId = acc.Id,
            Email = 'student2@example.com'
        );
        Contact faculty = new Contact(
            LastName = 'Faculty2',
            AccountId = acc.Id,
            Email = 'faculty2@example.com'
        );
        insert new List<Contact>{ student, faculty };

         hed__Term__c term = new hed__Term__c(
            Name = 'Test Term',
            hed__Account__c=acc.Id,
            Term_Reference__c ='Term 1'
        );
        insert term;


        hed__Course__c course = new hed__Course__c(
            Name = 'C2',
            hed__Course_ID__c = 'C-002',
            hed__Account__c=acc.ID
        );
        insert course;

        hed__Course_Offering__c offering = new hed__Course_Offering__c(
            Name = 'CO2',
            hed__Course__c = course.Id,
            hed__Term__c = term.Id,
            hed__Start_Date__c = Date.today(),
            hed__End_Date__c = Date.today().addDays(20)
        );
        insert offering;

        // One session to exercise interim calculation
        Session__c session = new Session__c(
            Course_Offering__c = offering.Id
        );
        insert session;

        Id studentRTId = getEnrollmentRT('Student');
        Id facultyRTId = getEnrollmentRT('Faculty');

        insert new hed__Course_Enrollment__c(
            hed__Contact__c = student.Id,
            hed__Course_Offering__c = offering.Id,
            Enrollment_Status__c = 'Enrolled',
            RecordTypeId = studentRTId
        );
        insert new hed__Course_Enrollment__c(
            hed__Contact__c = faculty.Id,
            hed__Course_Offering__c = offering.Id,
            Enrollment_Status__c = 'Enrolled',
            RecordTypeId = facultyRTId
        );

        Questionnaire_Metadata__c qmInterim = new Questionnaire_Metadata__c(
            RecordTypeId = FeedbackTestRecordTypes.questionnaire(),
            Name = 'Interim2',
            Feedback_Type__c = FeedbackSchedulerController.INTERIM_FEEDBACK
        );
        Questionnaire_Metadata__c qmFinal = new Questionnaire_Metadata__c(
            RecordTypeId = FeedbackTestRecordTypes.questionnaire(),
            Name = 'Final2',
            Feedback_Type__c = FeedbackSchedulerController.FINAL_FEEDBACK
        );
        insert new List<Questionnaire_Metadata__c>{ qmInterim, qmFinal };

        Date startDate = Date.today();
        Date endDate   = Date.today().addDays(5);

        Feedback_Scheduler__c fsInterim = new Feedback_Scheduler__c(
            Feedback_Master__c = qmInterim.Id,
            Term__c = term.Id,
            Start_Date__c = startDate,
            End_Date__c = endDate
        );
        insert fsInterim;

        Feedback_Scheduler__c fsFinal = new Feedback_Scheduler__c(
            Feedback_Master__c = qmFinal.Id,
            Term__c = term.Id,
            Start_Date__c = startDate,
            End_Date__c = endDate
        );
        insert fsFinal;

        Test.startTest();
        FeedbackSchedulerController.addFeedbackItems(
            fsInterim.Id, new List<Id>{ offering.Id }
        );

        FeedbackSchedulerController.addFeedbackItems(
            fsFinal.Id, new List<Id>{ offering.Id }
        );
        Test.stopTest();

        Integer interimCount = [
            SELECT COUNT() FROM Feedback_Item__c
            WHERE Feedback_Scheduler__c = :fsInterim.Id
        ];
        Integer finalCount = [
            SELECT COUNT() FROM Feedback_Item__c
            WHERE Feedback_Scheduler__c = :fsFinal.Id
        ];

        System.assertEquals(1, interimCount,
            'Interim scheduler should create one student feedback item');
        System.assertEquals(1, finalCount,
            'Final scheduler should create one student feedback item');

        Feedback_Item__c finalItem = [
            SELECT Start_Date__c, End_Date__c
            FROM Feedback_Item__c
            WHERE Feedback_Scheduler__c = :fsFinal.Id
            LIMIT 1
        ];
        System.assertEquals(offering.hed__End_Date__c, finalItem.Start_Date__c,
            'Final feedback should start on the course offering end date');
        System.assertEquals(offering.hed__End_Date__c.addDays(7), finalItem.End_Date__c,
            'Final feedback should end 7 days after the course offering end date');

        try {
            FeedbackSchedulerController.addFeedbackItems(null, new List<Id>{ offering.Id });
            System.assert(false, 'Expected AuraHandledException for null schedulerId');
        } catch (AuraHandledException e) {

        }

        try {
            FeedbackSchedulerController.addFeedbackItems(fsInterim.Id, new List<Id>());
            System.assert(false, 'Expected AuraHandledException for empty list');
        } catch (AuraHandledException e) {
           
        }
            }
    }
      @IsTest
    static void testGetExistingFeedbackItems_andDelete() {
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
        Account acc = new Account(Name = 'Existing Items Account');
        insert acc;
        hed__Term__c term = new hed__Term__c(Name = 'Existing Items Term', hed__Account__c = acc.Id, Term_Reference__c = 'Term 1');
        insert term;
        hed__Course__c course = new hed__Course__c(Name = 'Existing Items Course', hed__Course_ID__c = 'C-EX1', hed__Account__c = acc.Id);
        insert course;
        hed__Course_Offering__c offering = new hed__Course_Offering__c(
            Name = 'Existing Items Offering', hed__Course__c = course.Id, hed__Term__c = term.Id,
            hed__Start_Date__c = Date.today(), hed__End_Date__c = Date.today().addDays(30));
        insert offering;

        Feedback_Scheduler__c fs = new Feedback_Scheduler__c();
        insert fs;

        // An item without a course offering is not a course-level entry, so it is not listed.
        Feedback_Item__c plainItem = new Feedback_Item__c(Feedback_Scheduler__c = fs.Id);
        insert plainItem;
        Feedback_Item__c fi = new Feedback_Item__c(Feedback_Scheduler__c = fs.Id, Course_Offering__c = offering.Id);
        insert fi;

        Test.startTest();
        List<Feedback_Item__c> items =
            FeedbackSchedulerController.getExistingFeedbackItems(fs.Id);
        Test.stopTest();

        // The service returns one read-only entry per course offering that already has an item.
        System.assertEquals(1, items.size(), 'One offering entry should be returned');
        System.assertEquals(offering.Id, items[0].Course_Offering__c, 'Entry should point at the scheduled offering');
        System.assertEquals('Existing Items Offering', items[0].Course_Offering__r.Name, 'Entry should carry the offering name for the UI');

        // getExistingFeedbackItems with null Id
        List<Feedback_Item__c> emptyResult =
            FeedbackSchedulerController.getExistingFeedbackItems(null);
        System.assertEquals(0, emptyResult.size(), 'Null schedulerId should return empty list');

        FeedbackSchedulerController.deleteFeedbackItem(fi.Id);
        System.assertEquals(0,
            [SELECT COUNT() FROM Feedback_Item__c WHERE Id = :fi.Id],
            'Feedback item should be deleted');

        try {
            FeedbackSchedulerController.deleteFeedbackItem(null);
            System.assert(false, 'Expected AuraHandledException for null Id');
        } catch (AuraHandledException e) {
            
        }
            }
    }
    // Every @AuraEnabled method turns a failure into a readable AuraHandledException (no raw stack for the LWC).
    @IsTest
    static void testFailuresAreWrappedAsReadableAuraExceptions() {
        User outsider = FeedbackHomeTestData.makeStandardUser('schedctl');
        Id anyId = UserInfo.getUserId();
        Integer wrapped = 0;

        // A user without access to the feedback objects: the user-mode reads throw and are wrapped.
        System.runAs(outsider) {
            try {
                FeedbackSchedulerController.getCourseOfferings(anyId);
            } catch (AuraHandledException e) {
                System.assert(String.isNotBlank(e.getMessage()), 'The wrapped message should be readable');
                wrapped++;
            }
            try {
                FeedbackSchedulerController.getFeedbackType(anyId);
            } catch (AuraHandledException e) {
                System.assert(String.isNotBlank(e.getMessage()), 'The wrapped message should be readable');
                wrapped++;
            }
            try {
                FeedbackSchedulerController.getExistingFeedbackItems(anyId);
            } catch (AuraHandledException e) {
                System.assert(String.isNotBlank(e.getMessage()), 'The wrapped message should be readable');
                wrapped++;
            }
        }
        System.assertEquals(3, wrapped, 'Each read should wrap the failure');

        // Creating without a Feedback Master is rejected with a clear message.
        try {
            FeedbackSchedulerController.createSchedulerWithItems(null, null, Date.today(), Date.today().addDays(3), 'No master', null);
            System.assert(false, 'Expected an AuraHandledException when the Feedback Master is missing');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Feedback Master'), 'Message should say what is missing: ' + e.getMessage());
        }
    }

    private static Id getStudentRTId() {
        return [SELECT Id FROM RecordType
                WHERE SObjectType = 'hed__Course_Enrollment__c'
                AND Name = 'Student'
                LIMIT 1].Id;
    }

    @IsTest
    static void testCreateSchedulerWithItems_WithOfferings() {
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
        // Basic data
        Account acc = new Account(Name = 'Test Acc');
        insert acc;

        Contact student = new Contact(
            LastName = 'Student',
            AccountId = acc.Id,
            Email = 'student@example.com'
        );
        insert student;

       
         hed__Term__c term = new hed__Term__c(
            Name = 'Test Term',
            hed__Account__c=acc.Id,
            Term_Reference__c ='Term 1'
        );
        insert term;

        hed__Course__c course = new hed__Course__c(
            Name = 'Course 1',
            hed__Course_ID__c = 'C-001',
            hed__Account__c=acc.Id
        );
        insert course;

        hed__Course_Offering__c offering = new hed__Course_Offering__c(
            Name = 'CO-1',
            hed__Course__c = course.Id,
            hed__Term__c   = term.Id
        );
        insert offering;

        hed__Course_Enrollment__c enrol = new hed__Course_Enrollment__c(
            hed__Contact__c        = student.Id,
            hed__Course_Offering__c = offering.Id,
            Enrollment_Status__c   = 'Enrolled',
            RecordTypeId           = getStudentRTId()
        );
        insert enrol;

        Questionnaire_Metadata__c qm = new Questionnaire_Metadata__c(
            RecordTypeId = FeedbackTestRecordTypes.questionnaire(),
            Name = 'FM 1',
            Feedback_Type__c = 'Interim Feedback'
        );
        insert qm;

        Date startDate = Date.today();
        Date dueDate   = Date.today().addDays(5);

        Test.startTest();
        Id schedulerId = FeedbackSchedulerController.createSchedulerWithItems(
            qm.Id,
            term.Id,
            startDate,
            dueDate,
            'My Scheduler',
            new List<Id>{ offering.Id }
        );
        Test.stopTest();

        Feedback_Scheduler__c fs = [
            SELECT Id, Selected_Course_Offerings__c
            FROM Feedback_Scheduler__c
            WHERE Id = :schedulerId
        ];
        System.assertNotEquals(null, fs, 'Scheduler should be created');
        System.assert(fs.Selected_Course_Offerings__c.contains('CO-1'),
                      'Rich text should contain course offering name');

        List<Feedback_Item__c> items = [
            SELECT Id, Assignee__c, Course_Offering__c, Feedback_Status__c
            FROM Feedback_Item__c
            WHERE Feedback_Scheduler__c = :schedulerId
        ];
        System.assertEquals(1, items.size(), 'One feedback item expected');
        System.assertEquals(student.Id, items[0].Assignee__c, 'Assignee should be student');
        System.assertEquals('Pending', items[0].Feedback_Status__c, 'Status should be Pending');
            }
    }

    @IsTest
    static void testCreateSchedulerWithItems_NoOfferings() {
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
        Account acc=new Account(Name='Test');
        insert acc;
         hed__Term__c term = new hed__Term__c(
            Name = 'Test Term',
            hed__Account__c=acc.Id,
            Term_Reference__c ='Term 1'
        );
        insert term;


        Questionnaire_Metadata__c qm = new Questionnaire_Metadata__c(
            RecordTypeId = FeedbackTestRecordTypes.questionnaire(),
            Name = 'FM 2',
            Feedback_Type__c = 'Final Feedback'
        );
        insert qm;

        Date startDate = Date.today();
        Date dueDate   = Date.today().addDays(3);

        Test.startTest();
        Id schedulerId = FeedbackSchedulerController.createSchedulerWithItems(
            qm.Id,
            term.Id,
            startDate,
            dueDate,
            'Scheduler No CO',
            null          
        );
        Test.stopTest();

        Feedback_Scheduler__c fs = [
            SELECT Id, Selected_Course_Offerings__c
            FROM Feedback_Scheduler__c
            WHERE Id = :schedulerId
        ];
        System.assertNotEquals(null, fs, 'Scheduler should be created');
        System.assertEquals(null, fs.Selected_Course_Offerings__c,
                            'Rich text should be empty when no offerings');

        Integer itemCount = [
            SELECT COUNT() FROM Feedback_Item__c
            WHERE Feedback_Scheduler__c = :schedulerId
        ];
        System.assertEquals(0, itemCount,
            'No feedback items should be created when courseOfferingIds is null');
            }
    }
}