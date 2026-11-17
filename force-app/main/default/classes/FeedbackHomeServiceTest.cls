@isTest
private class FeedbackHomeServiceTest {

    @testSetup
    static void setup() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            FeedbackHomeTestData.grantFeedbackAccess(UserInfo.getUserId());
        }

        Questionnaire_Metadata__c feedbackSection = FeedbackHomeTestData.makeSection('Faculty Section', 'Feedback', true);
        Questionnaire_Metadata__c interviewSection = FeedbackHomeTestData.makeSection('Interview Section', 'Interview', true);
        Questionnaire_Metadata__c emptySection = FeedbackHomeTestData.makeSection('Empty Section', 'Feedback', true);
        insert new List<Questionnaire_Metadata__c>{ feedbackSection, interviewSection, emptySection };

        insert new List<Question_Metadata__c>{
            FeedbackHomeTestData.makeParameter('Clarity', feedbackSection.Id, true),
            FeedbackHomeTestData.makeParameter('Pace', feedbackSection.Id, true),
            FeedbackHomeTestData.makeParameter('Retired', feedbackSection.Id, false),
            FeedbackHomeTestData.makeParameter('Attitude', interviewSection.Id, true)
        };

        Date today = Date.today();
        Feedback_Scheduler__c live = FeedbackHomeTestData.makeScheduler(feedbackSection.Id, today.addDays(-2), today.addDays(1));
        Feedback_Scheduler__c upcoming = FeedbackHomeTestData.makeScheduler(feedbackSection.Id, today.addDays(10), today.addDays(20));
        Feedback_Scheduler__c finished = FeedbackHomeTestData.makeScheduler(feedbackSection.Id, today.addDays(-30), today.addDays(-20));
        insert new List<Feedback_Scheduler__c>{ live, upcoming, finished };

        // live: 2 of 4 submitted (50%, below target, ends within the alert window)
        insert FeedbackHomeTestData.makeItems(live.Id, 4, 2);
    }

    @isTest
    static void overviewRollsUpStatsAndAlerts() {
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
        Test.startTest();
        FeedbackHomeDto.Overview overview = FeedbackHomeService.overview();
        Test.stopTest();

        System.assertEquals(4, overview.stats.size(), 'Four headline stats');
        System.assertEquals('3', overview.stats[0].value, 'Three active sections');
        System.assertEquals('3', overview.stats[1].value, 'Three active parameters (the retired one is excluded)');
        System.assertEquals('1', overview.stats[2].value, 'One live schedule');
        System.assertEquals('50%', overview.stats[3].value, '2 of 4 submitted');

        Map<String, Integer> byStatus = new Map<String, Integer>();
        for (FeedbackHomeDto.StatusCount count : overview.itemStatusCounts) {
            byStatus.put(count.status, count.count);
        }
        System.assertEquals(2, byStatus.get('Submitted'));
        System.assertEquals(2, byStatus.get('Pending'));

        Boolean closesSoon = false;
        Boolean noParameters = false;
        Boolean noItems = false;
        for (FeedbackHomeDto.Alert alert : overview.alerts) {
            closesSoon = closesSoon || alert.title.contains('closes soon');
            noParameters = noParameters || alert.title.contains('Empty Section');
            noItems = noItems || alert.title.contains('no feedback items');
        }
        System.assert(closesSoon, 'Live schedule under target near its end date is flagged');
        System.assert(noParameters, 'Active section without parameters is flagged');
        System.assert(noItems, 'Upcoming schedule without items is flagged');
        System.assertEquals(FeedbackHomeSettings.targetResponseRate(), overview.targetResponseRate);
        System.assertEquals(3, overview.activeSectionCount);
        System.assertEquals(3, overview.activeParameterCount);
        System.assertEquals(3, overview.scheduleCount);
        System.assertEquals(2, overview.sectionTypeCounts.size(), 'Feedback and Interview');
            }
    }

    @isTest
    static void parameterSectionsFilterByRecordType() {
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
        List<FeedbackHomeDto.SectionRow> all = FeedbackHomeService.parameterSections(null);
        List<FeedbackHomeDto.SectionRow> interview = FeedbackHomeService.parameterSections('Interview');
        List<FeedbackHomeDto.SectionRow> feedback = FeedbackHomeService.parameterSections('Feedback');

        System.assertEquals(3, all.size());
        System.assertEquals(1, interview.size());
        System.assertEquals('Interview', interview[0].recordType);
        System.assertEquals(1, interview[0].parameterCount);
        System.assertEquals(2, feedback.size());

        Integer faculty = null;
        for (FeedbackHomeDto.SectionRow row : feedback) {
            if (row.name == 'Faculty Section') {
                faculty = row.parameterCount;
            }
        }
        System.assertEquals(2, faculty, 'Only active parameters are counted');
            }
    }

    @isTest
    static void parametersFilterBySection() {
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
        Id facultyId = [SELECT Id FROM Questionnaire_Metadata__c WHERE Name = 'Faculty Section'].Id;

        System.assertEquals(3, FeedbackHomeService.parameters(facultyId).size(), 'All parameters of the section, active or not');
        System.assertEquals(4, FeedbackHomeService.parameters(null).size(), 'No section filter returns everything');
        System.assertEquals('Faculty Section', FeedbackHomeService.parameters(facultyId)[0].sectionName);
            }
    }

    @isTest
    static void schedulesCarryStatusAndResponseCounts() {
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
        Map<String, FeedbackHomeDto.ScheduleRow> byStatus = new Map<String, FeedbackHomeDto.ScheduleRow>();
        for (FeedbackHomeDto.ScheduleRow row : FeedbackHomeService.schedules()) {
            byStatus.put(row.status, row);
        }

        System.assertEquals(3, byStatus.size(), 'One schedule per status');
        System.assertEquals(4, byStatus.get('Live').total);
        System.assertEquals(2, byStatus.get('Live').submitted);
        System.assertEquals(2, byStatus.get('Live').pending);
        System.assertEquals(50, byStatus.get('Live').rate);
        System.assertEquals(0, byStatus.get('Scheduled').total);
        System.assertEquals(0, byStatus.get('Closed').rate, 'No items means a 0% rate, not a divide-by-zero');
            }
    }

    @isTest
    static void scheduleItemsFilterByStatusAndValidateInput() {
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
        Id liveId = [SELECT Id FROM Feedback_Scheduler__c WHERE Start_Date__c < TODAY AND End_Date__c > TODAY].Id;

        System.assertEquals(4, FeedbackHomeService.scheduleItems(liveId, null).size());
        System.assertEquals(4, FeedbackHomeService.scheduleItems(liveId, 'All').size());
        System.assertEquals(2, FeedbackHomeService.scheduleItems(liveId, 'Submitted').size());
        System.assertEquals(2, FeedbackHomeService.scheduleItems(liveId, 'Pending').size());

        try {
            FeedbackHomeService.scheduleItems(liveId, 'Pending OR Id != null');
            System.assert(false, 'Unknown status must be rejected');
        } catch (FeedbackHomeService.FeedbackHomeException e) {
            System.assert(e.getMessage().contains('Unknown status'));
        }
        try {
            FeedbackHomeService.scheduleItems(null, null);
            System.assert(false, 'Missing schedule must be rejected');
        } catch (FeedbackHomeService.FeedbackHomeException e) {
            System.assert(e.getMessage().contains('Select a schedule'));
        }
            }
    }

    @isTest
    static void scheduleStatusHandlesBoundariesAndBlanks() {
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
        Date today = Date.today();
        System.assertEquals('Live', FeedbackHomeService.scheduleStatus(today, today), 'Start and end today is live');
        System.assertEquals('Live', FeedbackHomeService.scheduleStatus(today.addDays(-1), null), 'Open-ended is live');
        System.assertEquals('Scheduled', FeedbackHomeService.scheduleStatus(null, null), 'No dates yet is scheduled');
        System.assertEquals('Closed', FeedbackHomeService.scheduleStatus(null, today.addDays(-1)));
            }
    }

    @isTest
    static void controllerReturnsTheSameData() {
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
        System.assertEquals(4, FeedbackHomeController.getOverview().stats.size());
        System.assertEquals(3, FeedbackHomeController.getParameterSections(null).size());
        System.assertEquals(4, FeedbackHomeController.getParameters(null).size());
        System.assertEquals(3, FeedbackHomeController.getSchedules().size());
        Id liveId = [SELECT Id FROM Feedback_Scheduler__c WHERE Start_Date__c < TODAY AND End_Date__c > TODAY].Id;
        System.assertEquals(4, FeedbackHomeController.getScheduleItems(liveId, 'All').size());
            }
    }

    @isTest
    static void controllerWrapsErrorsInReadableMessages() {
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
        try {
            FeedbackHomeController.getScheduleItems(null, null);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Select a schedule'), 'Message survives: ' + e.getMessage());
        }
            }
    }

    @isTest
    static void userWithoutFeedbackAccessGetsAReadableError() {
        User outsider = FeedbackHomeTestData.makeStandardUser('noaccess');
        insert outsider;

        System.runAs(outsider) {
            try {
                FeedbackHomeController.getOverview();
                System.assert(false, 'USER_MODE must block a user without object access');
            } catch (AuraHandledException e) {
                System.assertNotEquals(null, e.getMessage());
            }
        }
    }

    @isTest
    static void rollUpsStayAccurateForALargeSchedule() {
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
        Questionnaire_Metadata__c section = [SELECT Id FROM Questionnaire_Metadata__c WHERE Name = 'Faculty Section'];
        Date today = Date.today();
        Feedback_Scheduler__c big = FeedbackHomeTestData.makeScheduler(section.Id, today.addDays(-1), today.addDays(5));
        insert big;
        insert FeedbackHomeTestData.makeItems(big.Id, 200, 150);

        Test.startTest();
        FeedbackHomeDto.ScheduleRow bigRow;
        for (FeedbackHomeDto.ScheduleRow row : FeedbackHomeService.schedules()) {
            if (row.id == big.Id) {
                bigRow = row;
            }
        }
        FeedbackHomeDto.Overview overview = FeedbackHomeService.overview();
        Test.stopTest();

        System.assertEquals(200, bigRow.total);
        System.assertEquals(75, bigRow.rate);
        System.assertEquals(200, FeedbackHomeService.scheduleItems(big.Id, null).size());
        System.assertEquals(4, overview.stats.size());
            }
    }
}