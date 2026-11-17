/**
 * Item generation, date sync and clean-up for Feedback Schedulers, both the in-transaction path and the
 * batch-job path used when an audience is too large for one transaction (forced here by lowering the
 * services' syncRowLimit, so the tests do not need thousands of records).
 */
@IsTest
private class FeedbackItemJobsTest {

    @TestSetup
    static void setup() {
        FeedbackTestFactory.enableIntegrationSettings();
        Account account = FeedbackTestFactory.createAccount();
        hed__Term__c term = FeedbackTestFactory.createTerm(account.Id);
        List<Contact> students = FeedbackTestFactory.createStudents(3);
        FeedbackTestFactory.createProgramEnrolments(students, term.Id);
    }

    private static hed__Term__c term() {
        return [SELECT Id FROM hed__Term__c LIMIT 1];
    }

    // ---------- generation ----------

    @IsTest
    static void termLevelTypeCreatesOneItemPerStudentSynchronously() {
        Questionnaire_Metadata__c section = FeedbackTestFactory.createSection(ConstantsControllerClass.OrientationFeedback);

        Test.startTest();
        Feedback_Scheduler__c scheduler = FeedbackTestFactory.createScheduler(
            section.Id, term().Id, Date.today(), Date.today().addDays(7));
        Test.stopTest();

        System.assertEquals(3, FeedbackTestFactory.itemCount(scheduler.Id), 'One item per enrolled student');
        for (Feedback_Item__c item : [SELECT Start_Date__c, End_Date__c, Feedback_Status__c FROM Feedback_Item__c]) {
            System.assertEquals(Date.today(), item.Start_Date__c, 'Items take the scheduler start');
            System.assertEquals(Date.today().addDays(7), item.End_Date__c, 'Items take the scheduler end');
            System.assertEquals('Pending', item.Feedback_Status__c);
        }
    }

    @IsTest
    static void largeAudienceIsHandedToTheBatchJob() {
        Questionnaire_Metadata__c section = FeedbackTestFactory.createSection(ConstantsControllerClass.EndTermFeedback);
        FeedbackItemGenerationService.syncRowLimit = 2; // 3 students > 2 -> must defer

        Feedback_Scheduler__c scheduler;
        Test.startTest();
        scheduler = FeedbackTestFactory.createScheduler(section.Id, term().Id, Date.today(), Date.today().addDays(7));
        System.assertEquals(0, FeedbackTestFactory.itemCount(scheduler.Id), 'Nothing is built inline when deferred');
        Test.stopTest();

        System.assertEquals(3, FeedbackTestFactory.itemCount(scheduler.Id), 'The batch job builds the same items');
    }

    @IsTest
    static void typesWithoutASourceCreateNoItemsFromTheTrigger() {
        Questionnaire_Metadata__c section = FeedbackTestFactory.createSection(ConstantsControllerClass.InterimFeedback);

        Feedback_Scheduler__c scheduler = FeedbackTestFactory.createScheduler(
            section.Id, term().Id, Date.today(), Date.today().addDays(7));

        System.assertEquals(0, FeedbackTestFactory.itemCount(scheduler.Id), 'Interim items come from the scheduler form');
        System.assertEquals(null, FeedbackItemSources.forType(ConstantsControllerClass.FinalFeedback));
        System.assertEquals(null, FeedbackItemSources.forType(null));
    }

    private static final List<String> TERM_TYPES = new List<String>{
        'Orientation Feedback', 'Graduation Feedback', 'End Term Feedback', 'Events and Workshop Feedback',
        'Mid Term FeedBack', 'Assistant Dean Feedback', 'Deputy Director Feedback', 'Dean Feedback',
        'Director Feedback', 'Admissions Feedback', 'Exam Feedback'
    };

    private static Feedback_Type_Setting__mdt setting(String type, String source, Boolean follows, Boolean active) {
        return new Feedback_Type_Setting__mdt(
            Feedback_Type__c = type, Item_Source__c = source,
            Follows_Scheduler_Dates__c = follows, Is_Active__c = active);
    }

    @IsTest
    static void shippedSettingsRowsGiveEveryTypeItsSource() {
        // Mirrors the shipped Feedback_Type_Setting__mdt rows (rows in the same deployment are not visible to getAll()).
        FeedbackItemSources.settings = new Map<String, Feedback_Type_Setting__mdt>();
        for (String type : TERM_TYPES) {
            FeedbackItemSources.settings.put(type, setting(type, 'Term Students', true, true));
        }
        FeedbackItemSources.settings.put('Faculty Feedback', setting('Faculty Feedback', 'Faculty Enrolments', false, true));
        FeedbackItemSources.settings.put('Interim Feedback', setting('Interim Feedback', 'Scheduler Form', false, true));
        FeedbackItemSources.settings.put('Final Feedback', setting('Final Feedback', 'Scheduler Form', false, true));
        for (String type : TERM_TYPES) {
            System.assert(FeedbackItemSources.forType(type) instanceof FeedbackItemSources.TermStudentSource, type);
            System.assertEquals(true, FeedbackItemSources.isDateDriven(type), type);
        }
        System.assert(FeedbackItemSources.forType('Faculty Feedback') instanceof FeedbackItemSources.FacultySource);
        System.assertEquals(false, FeedbackItemSources.isDateDriven('Faculty Feedback'));
        for (String type : new List<String>{ 'Interim Feedback', 'Final Feedback' }) {
            System.assertEquals(null, FeedbackItemSources.forType(type), type);
            System.assertEquals(false, FeedbackItemSources.isDateDriven(type), type);
        }
        System.assertEquals(null, FeedbackItemSources.forType('Unconfigured Type'));
        System.assertEquals(null, FeedbackItemSources.forType(null));
        FeedbackItemSources.settings = null;
    }

    @IsTest
    static void typesWithoutARowKeepTheBuiltInBehaviour() {
        FeedbackItemSources.settings = new Map<String, Feedback_Type_Setting__mdt>();
        for (String type : TERM_TYPES) {
            Boolean builtIn = type != 'Admissions Feedback' && type != 'Exam Feedback';
            System.assertEquals(builtIn, FeedbackItemSources.forType(type) != null, type);
        }
        System.assert(FeedbackItemSources.forType('Faculty Feedback') instanceof FeedbackItemSources.FacultySource);
        System.assertEquals(false, FeedbackItemSources.isDateDriven('Interim Feedback'));
        System.assertEquals(true, FeedbackItemSources.isDateDriven('Orientation Feedback'));
        FeedbackItemSources.settings = null;
    }

    @IsTest
    static void aRowOverridesTheBuiltInsAndInactiveRowsDisableTheType() {
        FeedbackItemSources.settings = new Map<String, Feedback_Type_Setting__mdt>{
            'Exam Feedback' => setting('Exam Feedback', 'Term Students', false, true),
            'Dean Feedback' => setting('Dean Feedback', 'Term Students', true, false)
        };
        System.assert(FeedbackItemSources.forType('Exam Feedback') instanceof FeedbackItemSources.TermStudentSource);
        System.assertEquals(false, FeedbackItemSources.isDateDriven('Exam Feedback'), 'Row decides the date mode');
        System.assertEquals(null, FeedbackItemSources.forType('Dean Feedback'), 'Inactive row stops generation');
        FeedbackItemSources.settings = null;
    }

    @IsTest
    static void facultyTypeBuildsItemsFromFacultyEnrolments() {
        Account account = [SELECT Id FROM Account LIMIT 1];
        hed__Term__c term = term();
        Contact faculty = FeedbackTestFactory.createFaculty();
        hed__Course__c course = FeedbackTestFactory.createCourse(account.Id);
        Date courseEnd = Date.today().addDays(30);
        hed__Course_Offering__c offering = FeedbackTestFactory.createOffering(course.Id, term.Id, faculty.Id, Date.today(), courseEnd);
        FeedbackTestFactory.createCourseEnrolment(faculty.Id, offering.Id, 'Faculty');
        Questionnaire_Metadata__c section = FeedbackTestFactory.createSection(ConstantsControllerClass.FacultyFeedback);

        Feedback_Scheduler__c scheduler = FeedbackTestFactory.createScheduler(section.Id, term.Id, Date.today(), courseEnd);

        List<Feedback_Item__c> items = [SELECT Start_Date__c, End_Date__c, Course_Offering__c FROM Feedback_Item__c WHERE Feedback_Scheduler__c = :scheduler.Id];
        System.assertEquals(1, items.size());
        System.assertEquals(courseEnd.addDays(1), items[0].Start_Date__c, 'Opens the day after the course ends');
        System.assertEquals(courseEnd.addDays(3), items[0].End_Date__c);
        System.assertEquals(offering.Id, items[0].Course_Offering__c);
    }

    @IsTest
    static void bulkInsertOfSchedulersStaysWithinLimits() {
        Questionnaire_Metadata__c section = FeedbackTestFactory.createSection(ConstantsControllerClass.OrientationFeedback);
        List<Feedback_Scheduler__c> schedulers = new List<Feedback_Scheduler__c>();
        for (Integer i = 0; i < 20; i++) {
            schedulers.add(FeedbackTestFactory.makeScheduler(section.Id, term().Id, Date.today(), Date.today().addDays(7)));
        }

        Test.startTest();
        insert schedulers;
        Test.stopTest();

        System.assertEquals(60, [SELECT COUNT() FROM Feedback_Item__c], '20 schedulers x 3 students, built in one pass');
    }

    // ---------- date sync ----------

    @IsTest
    static void changedSchedulerDatesCascadeToItemsThatDiffer() {
        Questionnaire_Metadata__c section = FeedbackTestFactory.createSection(ConstantsControllerClass.OrientationFeedback);
        Feedback_Scheduler__c scheduler = FeedbackTestFactory.createScheduler(
            section.Id, term().Id, Date.today(), Date.today().addDays(7));

        Test.startTest();
        scheduler.End_Date__c = Date.today().addDays(14);
        update scheduler;
        Test.stopTest();

        for (Feedback_Item__c item : [SELECT End_Date__c FROM Feedback_Item__c WHERE Feedback_Scheduler__c = :scheduler.Id]) {
            System.assertEquals(Date.today().addDays(14), item.End_Date__c, 'New end date reaches every item');
        }
    }

    @IsTest
    static void editingAnotherFieldDoesNotRewriteItems() {
        Questionnaire_Metadata__c section = FeedbackTestFactory.createSection(ConstantsControllerClass.OrientationFeedback);
        Feedback_Scheduler__c scheduler = FeedbackTestFactory.createScheduler(
            section.Id, term().Id, Date.today(), Date.today().addDays(7));
        DateTime before = (DateTime) [SELECT MAX(LastModifiedDate) m FROM Feedback_Item__c][0].get('m');

        Test.startTest();
        scheduler.Description__c = 'Only the description changed';
        update scheduler;
        Test.stopTest();

        DateTime after = (DateTime) [SELECT MAX(LastModifiedDate) m FROM Feedback_Item__c][0].get('m');
        System.assertEquals(before, after, 'No item should be saved when the dates did not change');
    }

    @IsTest
    static void largeSchedulerDateSyncRunsAsBatch() {
        Questionnaire_Metadata__c section = FeedbackTestFactory.createSection(ConstantsControllerClass.OrientationFeedback);
        Feedback_Scheduler__c scheduler = FeedbackTestFactory.createScheduler(
            section.Id, term().Id, Date.today(), Date.today().addDays(7));
        FeedbackItemDateSyncService.syncRowLimit = 2;

        Test.startTest();
        scheduler.Start_Date__c = Date.today().addDays(1);
        update scheduler;
        Test.stopTest();

        for (Feedback_Item__c item : [SELECT Start_Date__c FROM Feedback_Item__c WHERE Feedback_Scheduler__c = :scheduler.Id]) {
            System.assertEquals(Date.today().addDays(1), item.Start_Date__c, 'Batch applied the new start date');
        }
    }

    @IsTest
    static void ownDateTypesKeepTheirItemDates() {
        System.assertEquals(false, FeedbackItemSources.isDateDriven(ConstantsControllerClass.FacultyFeedback));
        System.assertEquals(false, FeedbackItemSources.isDateDriven(ConstantsControllerClass.InterimFeedback));
        System.assertEquals(false, FeedbackItemSources.isDateDriven(ConstantsControllerClass.FinalFeedback));
        System.assertEquals(true, FeedbackItemSources.isDateDriven(ConstantsControllerClass.OrientationFeedback));
    }

    // ---------- clean-up ----------

    @IsTest
    static void deletingASchedulerRemovesItsItems() {
        Questionnaire_Metadata__c section = FeedbackTestFactory.createSection(ConstantsControllerClass.OrientationFeedback);
        Feedback_Scheduler__c scheduler = FeedbackTestFactory.createScheduler(
            section.Id, term().Id, Date.today(), Date.today().addDays(7));
        System.assertEquals(3, [SELECT COUNT() FROM Feedback_Item__c]);

        Test.startTest();
        delete scheduler;
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Feedback_Item__c], 'No orphaned items remain');
    }

    @IsTest
    static void deletingALargeSchedulerRemovesItemsInBatches() {
        Questionnaire_Metadata__c section = FeedbackTestFactory.createSection(ConstantsControllerClass.OrientationFeedback);
        Feedback_Scheduler__c scheduler = FeedbackTestFactory.createScheduler(
            section.Id, term().Id, Date.today(), Date.today().addDays(7));
        FeedbackItemCleanupService.syncRowLimit = 2;

        Test.startTest();
        delete scheduler;
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Feedback_Item__c], 'The delete batch removed every item');
    }
}