/** Rating roll-up and parameter copy for Collected_Feedback_Data__c. */
@IsTest
private class FacultyCourseRatingHandlerTest {

    @IsTest
    static void emptyInputsAreIgnored() {
        FacultyCourseRatingHandler.updateFacultyRatings(null);
        FacultyCourseRatingHandler.updateFacultyRatings(new List<Collected_Feedback_Data__c>());
        FacultyCourseRatingHandler.afterSave(null, null);
        FacultyCourseRatingHandler.afterSave(new Set<Id>(), null);
        FacultyCourseRatingHandler.populateParametersFromQuestion(null, null);
        System.assert(true, 'No exception for empty input');
    }

    @IsTest
    static void parametersAreCopiedFromTheFeedbackMasterChildOnInsert() {
        Questionnaire_Metadata__c section = FeedbackTestFactory.createSection(ConstantsControllerClass.FinalFeedback);
        Question_Metadata__c parameter = FeedbackHomeTestData.makeParameter('Clarity', section.Id, true);
        insert parameter;
        Collected_Feedback_Data__c row = new Collected_Feedback_Data__c(Feedback_Master_Child__c = parameter.Id);

        FacultyCourseRatingHandler.populateParametersFromQuestion(new List<Collected_Feedback_Data__c>{ row }, null);

        System.assertEquals(parameter.Id, row.Parameters__c);
    }

    @IsTest
    static void parametersAreOnlyRecopiedWhenTheChildChangesOnUpdate() {
        Questionnaire_Metadata__c section = FeedbackTestFactory.createSection(ConstantsControllerClass.FinalFeedback);
        Question_Metadata__c first = FeedbackHomeTestData.makeParameter('A', section.Id, true);
        Question_Metadata__c second = FeedbackHomeTestData.makeParameter('B', section.Id, true);
        insert new List<Question_Metadata__c>{ first, second };

        Collected_Feedback_Data__c before = new Collected_Feedback_Data__c(Feedback_Master_Child__c = first.Id, Parameters__c = first.Id);
        Collected_Feedback_Data__c after = new Collected_Feedback_Data__c(Feedback_Master_Child__c = second.Id, Parameters__c = first.Id);
        // Id is needed to key the old map; a fake but well-formed Id is enough for an in-memory run.
        Id fakeId = Collected_Feedback_Data__c.SObjectType.getDescribe().getKeyPrefix() + '000000000001';
        after.Id = fakeId;
        before.Id = fakeId;

        FacultyCourseRatingHandler.populateParametersFromQuestion(
            new List<Collected_Feedback_Data__c>{ after }, new Map<Id, Collected_Feedback_Data__c>{ fakeId => before });

        System.assertEquals(second.Id, after.Parameters__c, 'A changed child is copied again');
    }

    @IsTest
    static void finalFeedbackRatingsRollIntoTheFacultyCourseAverage() {
        FeedbackTestFactory.enableIntegrationSettings();
        Account account = FeedbackTestFactory.createAccount();
        hed__Term__c term = FeedbackTestFactory.createTerm(account.Id);
        Contact faculty = FeedbackTestFactory.createFaculty();
        hed__Course__c course = FeedbackTestFactory.createCourse(account.Id);
        hed__Course_Offering__c offering = FeedbackTestFactory.createOffering(
            course.Id, term.Id, faculty.Id, Date.today(), Date.today().addDays(30));
        Questionnaire_Metadata__c section = FeedbackTestFactory.createSection(ConstantsControllerClass.FinalFeedback);
        Question_Metadata__c parameter = FeedbackHomeTestData.makeParameter('Overall', section.Id, true);
        parameter.Question_Type__c = 'Rating';
        insert parameter;
        Faculty_Course_Association__c association = new Faculty_Course_Association__c(Course__c = course.Id, Faculty__c = faculty.Id);
        insert association;
        Id finalType = Schema.SObjectType.Collected_Feedback_Data__c.getRecordTypeInfosByDeveloperName()
            .get('Final_Feedback').getRecordTypeId();

        Test.startTest();
        insert new Collected_Feedback_Data__c(
            RecordTypeId = finalType, Feedback_Master_Child__c = parameter.Id, Rating__c = '4',
            Course_Name__c = course.Id, Course_Offering__c = offering.Id
        );
        Test.stopTest();

        System.assertEquals(4, [SELECT Rating__c FROM Faculty_Course_Association__c WHERE Id = :association.Id].Rating__c);
    }
}