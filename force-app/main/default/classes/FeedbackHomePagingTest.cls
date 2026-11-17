@isTest
private class FeedbackHomePagingTest {

    @testSetup
    static void setup() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            FeedbackHomeTestData.grantFeedbackAccess(UserInfo.getUserId());
        }
        Questionnaire_Metadata__c faculty = FeedbackHomeTestData.makeSection('Faculty Section', 'Feedback', true);
        Questionnaire_Metadata__c interview = FeedbackHomeTestData.makeSection('Interview Section', 'Interview', true);
        insert new List<Questionnaire_Metadata__c>{ faculty, interview };

        Date today = Date.today();
        Feedback_Scheduler__c live = FeedbackHomeTestData.makeScheduler(faculty.Id, today.addDays(-2), today.addDays(1));
        Feedback_Scheduler__c upcoming = FeedbackHomeTestData.makeScheduler(faculty.Id, today.addDays(10), today.addDays(20));
        Feedback_Scheduler__c finished = FeedbackHomeTestData.makeScheduler(faculty.Id, today.addDays(-30), today.addDays(-20));
        Feedback_Scheduler__c undated = FeedbackHomeTestData.makeScheduler(faculty.Id, null, null);
        insert new List<Feedback_Scheduler__c>{ live, upcoming, finished, undated };
        insert FeedbackHomeTestData.makeItems(live.Id, 4, 2);
    }

    private static void addBulkSections(Integer count, Integer inactive) {
        List<Questionnaire_Metadata__c> bulkRows = new List<Questionnaire_Metadata__c>();
        for (Integer i = 0; i < count; i++) {
            bulkRows.add(FeedbackHomeTestData.makeSection('Bulk Section ' + i, 'Feedback', i >= inactive));
        }
        insert bulkRows;
    }

    @isTest
    static void sectionsArePagedOnTheServer() {
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
        addBulkSections(60, 0);

        FeedbackHomeDto.SectionPage first = FeedbackHomeService.sectionPage(null, null, false, 25, 1);
        System.assertEquals(62, first.total);
        System.assertEquals(25, first.rows.size());
        System.assertEquals(3, first.totalPages);
        System.assertEquals(false, first.truncated);

        FeedbackHomeDto.SectionPage last = FeedbackHomeService.sectionPage(null, null, false, 25, 3);
        System.assertEquals(12, last.rows.size());

        FeedbackHomeDto.SectionPage clamped = FeedbackHomeService.sectionPage(null, null, false, 25, 99);
        System.assertEquals(3, clamped.pageNumber, 'An out-of-range page is clamped, not an error');
        System.assertEquals(12, clamped.rows.size());
            }
    }

    @isTest
    static void sectionSearchAndFiltersRunInTheDatabase() {
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
        addBulkSections(10, 4);

        System.assertEquals(10, FeedbackHomeService.sectionPage(null, 'Bulk', false, 25, 1).total);
        System.assertEquals(0, FeedbackHomeService.sectionPage(null, '%', false, 25, 1).total, 'LIKE wildcards match literally');
        System.assertEquals(0, FeedbackHomeService.sectionPage(null, '_ulk', false, 25, 1).total);
        System.assertEquals(1, FeedbackHomeService.sectionPage('Interview', null, false, 25, 1).total);
        System.assertEquals(8, FeedbackHomeService.sectionPage(null, null, true, 25, 1).total, '2 base + 6 active bulkRows');
        FeedbackHomeDto.SectionPage empty = FeedbackHomeService.sectionPage(null, 'nothing-matches', false, 25, 1);
        System.assertEquals(0, empty.rows.size());
        System.assertEquals(1, empty.totalPages);
            }
    }

    @isTest
    static void pageSizeIsClamped() {
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
        System.assertEquals(25, FeedbackHomeService.clampPageSize(null));
        System.assertEquals(25, FeedbackHomeService.clampPageSize(0));
        System.assertEquals(100, FeedbackHomeService.clampPageSize(100000));
        System.assertEquals(10, FeedbackHomeService.clampPageSize(10));
            }
    }

    @isTest
    static void scheduleStatusFiltersMatchTheDerivedStatus() {
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
        FeedbackHomeDto.SchedulePage all = FeedbackHomeService.schedulePage(null, 'All', null, 25, 1);
        System.assertEquals(4, all.total);
        Map<String, Integer> counts = new Map<String, Integer>();
        for (FeedbackHomeDto.StatusCount c : all.statusCounts) {
            counts.put(c.status, c.count);
        }
        System.assertEquals(4, counts.get('All'));
        System.assertEquals(1, counts.get('Live'));
        System.assertEquals(2, counts.get('Scheduled'), 'Upcoming plus the undated one');
        System.assertEquals(1, counts.get('Closed'));

        for (String status : new List<String>{ 'Live', 'Scheduled', 'Closed' }) {
            FeedbackHomeDto.SchedulePage page = FeedbackHomeService.schedulePage(null, status, null, 25, 1);
            System.assertEquals(counts.get(status), page.total, status);
            for (FeedbackHomeDto.ScheduleRow row : page.rows) {
                System.assertEquals(status, row.status, 'SOQL filter agrees with scheduleStatus()');
            }
        }
        FeedbackHomeDto.SchedulePage live = FeedbackHomeService.schedulePage(null, 'Live', null, 25, 1);
        System.assertEquals(4, live.rows[0].total);
        System.assertEquals(2, live.rows[0].submitted);
            }
    }

    @isTest
    static void scheduleSearchSortAndValidation() {
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
        System.assertEquals(4, FeedbackHomeService.schedulePage('Faculty', null, null, 25, 1).total, 'Matches the template name');
        FeedbackHomeDto.SchedulePage none = FeedbackHomeService.schedulePage('zzz-none', null, null, 25, 1);
        System.assertEquals(0, none.total);
        System.assertEquals(0, none.statusCounts[0].count);

        FeedbackHomeDto.SchedulePage closing = FeedbackHomeService.schedulePage(null, null, 'closing', 25, 1);
        System.assertEquals('Closed', closing.rows[0].status, 'Earliest end date first');
        System.assertEquals(4, FeedbackHomeService.schedulePage(null, null, 'bogus', 25, 1).rows.size(), 'Unknown sort falls back');

        try {
            FeedbackHomeService.schedulePage(null, 'Bogus', null, 25, 1);
            System.assert(false, 'Expected FeedbackHomeException');
        } catch (FeedbackHomeService.FeedbackHomeException e) {
            System.assert(e.getMessage().contains('Unknown schedule status'));
        }
            }
    }

    @isTest
    static void largeScheduleListPagesAndRollsUpOnlyThePage() {
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
        Questionnaire_Metadata__c section = [SELECT Id FROM Questionnaire_Metadata__c WHERE Name = 'Faculty Section'];
        List<Feedback_Scheduler__c> bulkRows = new List<Feedback_Scheduler__c>();
        for (Integer i = 0; i < 40; i++) {
            bulkRows.add(FeedbackHomeTestData.makeScheduler(section.Id, Date.today().addDays(-1), Date.today().addDays(5)));
        }
        insert bulkRows;

        Test.startTest();
        FeedbackHomeDto.SchedulePage page = FeedbackHomeService.schedulePage(null, 'Live', null, 15, 2);
        Test.stopTest();
        System.assertEquals(41, page.total);
        System.assertEquals(15, page.rows.size());
        System.assertEquals(3, page.totalPages);
            }
    }

    @isTest
    static void paginationPastTheOffsetLimitIsFlaggedNotBroken() {
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
        addBulkSections(2100, 0);
        FeedbackHomeDto.SectionPage page = FeedbackHomeService.sectionPage(null, null, false, 100, 999);
        System.assertEquals(2102, page.total);
        System.assertEquals(true, page.truncated, 'More matches than SOQL OFFSET can reach');
        System.assertEquals(21, page.pageNumber, 'Clamped to the last reachable page');
        System.assert(page.rows.size() > 0);
            }
    }

    @isTest
    static void controllerEndpointsReturnPagesAndWrapErrors() {
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
        System.assertEquals(2, FeedbackHomeController.getSectionPage(null, null, false, 25, 1).total);
        System.assertEquals(4, FeedbackHomeController.getSchedulePage(null, null, 'newest', 25, 1).total);
        try {
            FeedbackHomeController.getSchedulePage(null, 'Bogus', null, 25, 1);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Unknown schedule status'), e.getMessage());
        }
            }
    }

    @isTest
    static void userWithoutAccessIsBlockedOnPagedEndpoints() {
        User outsider = FeedbackHomeTestData.makeStandardUser('pagingnoaccess');
        insert outsider;
        System.runAs(outsider) {
            try {
                FeedbackHomeController.getSectionPage(null, null, false, 25, 1);
                System.assert(false, 'USER_MODE must block this user');
            } catch (AuraHandledException e) {
                System.assertNotEquals(null, e.getMessage());
            }
        }
    }
}