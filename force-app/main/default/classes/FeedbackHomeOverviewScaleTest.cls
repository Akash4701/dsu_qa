/**
 * The overview must reflect the WHOLE data set, not just the newest schedules. 60 live schedules are
 * created (more than any sample window) and the only items sit on the OLDEST one: a sampled overview
 * would miss them.
 */
@IsTest
private class FeedbackHomeOverviewScaleTest {

    @TestSetup
    static void setup() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            FeedbackHomeTestData.grantFeedbackAccess(UserInfo.getUserId());
        }
        Questionnaire_Metadata__c section = FeedbackTestFactory.createSection('Faculty Feedback');
        List<Feedback_Scheduler__c> schedulers = new List<Feedback_Scheduler__c>();
        for (Integer i = 0; i < 60; i++) {
            schedulers.add(FeedbackHomeTestData.makeScheduler(section.Id, Date.today().addDays(-5), Date.today().addDays(20)));
        }
        insert schedulers;
        insert FeedbackHomeTestData.makeItems(schedulers[0].Id, 4, 2);
    }

    @IsTest
    static void liveCountAndResponseRateCoverEverySchedule() {
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
        FeedbackHomeDto.Overview overview = FeedbackHomeService.overview();

        System.assertEquals('60', overview.stats[2].value, 'All 60 live schedules are counted');
        System.assertEquals('50%', overview.stats[3].value, 'Items on the oldest schedule are included');
        System.assertEquals(60, overview.scheduleCount);
        System.assertEquals(6, overview.recentSchedules.size(), 'The recent list stays small');
            }
    }

    @IsTest
    static void emptySchedulesAreFlaggedWithoutLoadingEverySchedule() {
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
        FeedbackHomeDto.Overview overview = FeedbackHomeService.overview();

        System.assert(overview.alerts.size() <= 5, 'Alerts are capped');
        Boolean flagged = false;
        for (FeedbackHomeDto.Alert alert : overview.alerts) {
            flagged = flagged || alert.title.contains('no feedback items');
        }
        System.assert(flagged, 'A schedule with nobody assigned is flagged');
            }
    }
}