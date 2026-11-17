@isTest
private class AnnouncementAudienceControllerTest {

    private static final String ADMIN_USERNAME = 'announcement.audience.pkdsu199@test.example.com';

    @testSetup
    static void setup() {
        Account mba = new Account(Name = 'Master of Business Administration Test');
        Account mca = new Account(Name = 'Master of Computer Applications Test');
        insert new List<Account>{ mba, mca };
        insert new Announcement__c(Title__c = 'Exam schedule', Description__c = 'Test', IsActive__c = true);
        insert new List<hed__Program_Plan__c>{
            new hed__Program_Plan__c(Name = '2026-AUG-MBA', hed__Account__c = mba.Id),
            new hed__Program_Plan__c(Name = '2026-AUG-MCA', hed__Account__c = mca.Id)
        };

        // The controller enforces field-level security, so run as an admin with the permission set.
        // Setup objects go in their own runAs block to avoid a mixed DML error.
        System.runAs(new User(Id = UserInfo.getUserId())) {
            User admin = new User(
                Username = ADMIN_USERNAME, LastName = 'Announcement Admin', Email = ADMIN_USERNAME, Alias = 'annaud',
                ProfileId = [SELECT Id FROM Profile WHERE Name = 'System Administrator'].Id,
                TimeZoneSidKey = 'Asia/Kolkata', LocaleSidKey = 'en_US', EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US');
            insert admin;
            insert new PermissionSetAssignment(AssigneeId = admin.Id,
                PermissionSetId = [SELECT Id FROM PermissionSet WHERE Name = 'Announcement_Program_Plans'].Id);
        }
    }

    private static User admin() {
        return [SELECT Id FROM User WHERE Username = :ADMIN_USERNAME];
    }

    private static Id announcementId() {
        return [SELECT Id FROM Announcement__c LIMIT 1].Id;
    }

    private static Id accountId(String name) {
        return [SELECT Id FROM Account WHERE Name = :name].Id;
    }

    private static Id planId(String name) {
        return [SELECT Id FROM hed__Program_Plan__c WHERE Name = :name].Id;
    }

    @isTest
    static void optionsListPlanAccountsAndPlans() {
        AnnouncementAudienceController.Options options;
        System.runAs(admin()) {
            Test.startTest();
            options = AnnouncementAudienceController.getOptions();
            Test.stopTest();
        }

        Set<String> accountLabels = new Set<String>();
        for (AnnouncementAudienceController.Option option : options.accounts) {
            accountLabels.add(option.label);
        }
        System.assert(accountLabels.contains('Master of Business Administration Test'), 'Plan owner Account listed');
        System.assert(accountLabels.contains('Master of Computer Applications Test'), 'Plan owner Account listed');

        Boolean mbaPlanFound = false;
        for (AnnouncementAudienceController.Option option : options.programPlans) {
            if (option.label == '2026-AUG-MBA') {
                mbaPlanFound = true;
                System.assertEquals(accountId('Master of Business Administration Test'), option.accountId, 'Plan carries its Account');
            }
        }
        System.assert(mbaPlanFound, 'Program Plan listed');
    }

    @isTest
    static void saveCreatesOneRowPerAccountAndPerPlan() {
        Id annId = announcementId();
        System.runAs(admin()) {
            Test.startTest();
            AnnouncementAudienceController.saveAudience(annId,
                new List<String>{ accountId('Master of Business Administration Test') },
                new List<String>{ planId('2026-AUG-MBA'), planId('2026-AUG-MCA') });
            Test.stopTest();
        }

        List<Announcement_Audience__c> rows = [
            SELECT Account__c, Program_Plan__c FROM Announcement_Audience__c WHERE Announcement__c = :annId
        ];
        System.assertEquals(3, rows.size(), '1 Account row + 2 Program Plan rows');
        Integer accountRows = 0;
        for (Announcement_Audience__c row : rows) {
            if (row.Account__c != null) {
                accountRows++;
                System.assertEquals(null, row.Program_Plan__c, 'An Account row has no Program Plan');
            }
        }
        System.assertEquals(1, accountRows, 'One Account row');
        System.assertEquals(false, [SELECT All_Program_Plans__c FROM Announcement__c WHERE Id = :annId].All_Program_Plans__c,
            'An announcement with an audience is no longer visible to all');
    }

    @isTest
    static void saveReplacesAndEmptyClearsTheAudience() {
        Id annId = announcementId();
        System.runAs(admin()) {
            Test.startTest();
            AnnouncementAudienceController.saveAudience(annId, null, new List<String>{ planId('2026-AUG-MBA') });
            AnnouncementAudienceController.saveAudience(annId, null, new List<String>{ planId('2026-AUG-MCA') });
            System.assertEquals(planId('2026-AUG-MCA'),
                [SELECT Program_Plan__c FROM Announcement_Audience__c WHERE Announcement__c = :annId].Program_Plan__c,
                'Save replaces the earlier selection');

            AnnouncementAudienceController.saveAudience(annId, new List<String>(), new List<String>());
            Test.stopTest();
        }
        System.assertEquals(0, [SELECT COUNT() FROM Announcement_Audience__c WHERE Announcement__c = :annId],
            'Nothing selected = no rows = for everyone');
        System.assertEquals(true, [SELECT All_Program_Plans__c FROM Announcement__c WHERE Id = :annId].All_Program_Plans__c,
            'Clearing the audience makes it visible to all again');
    }

    @isTest
    static void saveFailureRollsBackAndReportsError() {
        Id annId = announcementId();
        System.runAs(admin()) {
            AnnouncementAudienceController.saveAudience(annId, null, new List<String>{ planId('2026-AUG-MBA') });
            Test.startTest();
            try {
                AnnouncementAudienceController.saveAudience(annId, new List<String>{ 'not-an-id' }, null);
                System.assert(false, 'Expected an error for an invalid Account id');
            } catch (AuraHandledException e) {
                System.assert(true, 'Error surfaced to the form');
            }
            Test.stopTest();
        }
        System.assertEquals(1, [SELECT COUNT() FROM Announcement_Audience__c WHERE Announcement__c = :annId],
            'The earlier audience is kept when a save fails');
    }
}