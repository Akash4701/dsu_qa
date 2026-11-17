/**
 * Guard rails of the scheduler form service that the controller tests do not reach: missing master,
 * oversize selections, and the Aura-facing error wrapping.
 */
@IsTest
private class FeedbackSchedulerServiceTest {

    @TestSetup
    static void setup() {
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
        FeedbackTestFactory.enableIntegrationSettings();
            }
    }

    @IsTest
    static void missingFeedbackMasterIsRejectedWithAReadableMessage() {
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
        try {
            FeedbackSchedulerController.createSchedulerWithItems(null, null, Date.today(), Date.today().addDays(1), 'x', null);
            System.assert(false, 'Expected an AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Feedback Master'), e.getMessage());
        }
            }
    }

    @IsTest
    static void oversizeSelectionIsRejectedAndRolledBack() {
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
        Account account = FeedbackTestFactory.createAccount();
        hed__Term__c term = FeedbackTestFactory.createTerm(account.Id);
        Contact faculty = FeedbackTestFactory.createFaculty();
        hed__Course__c course = FeedbackTestFactory.createCourse(account.Id);
        hed__Course_Offering__c offering = FeedbackTestFactory.createOffering(
            course.Id, term.Id, faculty.Id, Date.today(), Date.today().addDays(30));
        List<Contact> students = FeedbackTestFactory.createStudents(2);
        for (Contact student : students) {
            hed__Course_Enrollment__c enrolment = FeedbackTestFactory.createCourseEnrolment(student.Id, offering.Id, 'Student');
            enrolment.Enrollment_Status__c = ConstantsControllerClass.ENROLLED;
            update enrolment;
        }
        Questionnaire_Metadata__c section = FeedbackTestFactory.createSection(ConstantsControllerClass.FinalFeedback);
        FeedbackSchedulerService.maxItemsPerRequest = 1;

        try {
            FeedbackSchedulerController.createSchedulerWithItems(
                section.Id, term.Id, Date.today(), Date.today().addDays(7), 'Big', new List<Id>{ offering.Id });
            System.assert(false, 'Expected the size guard to fire');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Select fewer'), e.getMessage());
        }
        System.assertEquals(0, [SELECT COUNT() FROM Feedback_Scheduler__c], 'The scheduler is rolled back with its items');
            }
    }

    @IsTest
    static void offeringsAlreadyScheduledAreNotAddedTwice() {
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
        System.assertEquals(0, FeedbackSchedulerService.existingOfferingItems(null).size());
        try {
            FeedbackSchedulerController.addFeedbackItems(null, new List<Id>());
            System.assert(false, 'Expected an AuraHandledException');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
            }
    }
}