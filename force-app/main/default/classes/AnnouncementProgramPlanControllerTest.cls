@isTest
private class AnnouncementProgramPlanControllerTest {

    private static final String ADMIN_USERNAME = 'announcement.admin.pkdsu199@test.example.com';

    @testSetup
    static void setup() {
        insert new Announcement__c(Title__c = 'Exam schedule', Description__c = 'Test', IsActive__c = true);
        insert new List<hed__Program_Plan__c>{
            new hed__Program_Plan__c(Name = '2026-AUG-MBA'),
            new hed__Program_Plan__c(Name = '2026-AUG-MCA')
        };

        // The controller enforces field-level security, so run as an admin with the permission set.
        // Setup objects go in their own runAs block to avoid a mixed DML error.
        System.runAs(new User(Id = UserInfo.getUserId())) {
            User admin = new User(
                Username = ADMIN_USERNAME, LastName = 'Announcement Admin', Email = ADMIN_USERNAME, Alias = 'annadm',
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

    private static List<String> planIds() {
        List<String> ids = new List<String>();
        for (hed__Program_Plan__c plan : [SELECT Id FROM hed__Program_Plan__c WHERE Name LIKE '2026-AUG-%' ORDER BY Name]) {
            ids.add(plan.Id);
        }
        return ids;
    }

    @isTest
    static void newAnnouncementIsVisibleToAll() {
        Id annId = announcementId();
        System.runAs(admin()) {
            AnnouncementProgramPlanController.Config config = AnnouncementProgramPlanController.getConfig(annId);

            System.assertEquals(true, config.allProgramPlans);
            System.assert(config.selectedProgramPlanIds.isEmpty());
            System.assert(config.programPlans.size() >= 2, 'Program Plans should be offered');
            System.assertEquals(10, config.semesters.size(), 'Semester 1 to 10 should be offered');
        }
    }

    @isTest
    static void optionsForNewAnnouncement() {
        System.runAs(admin()) {
            AnnouncementProgramPlanController.Config options = AnnouncementProgramPlanController.getOptions();
            System.assert(options.programPlans.size() >= 2, 'Program Plans should be offered');
            System.assertEquals(10, options.semesters.size(), 'Semester 1 to 10 should be offered');
            System.assert(options.selectedProgramPlanIds.isEmpty());
        }
    }

    @isTest
    static void savesPlansAndSemesters() {
        Id annId = announcementId();
        List<String> plans = planIds();
        System.runAs(admin()) {
            Test.startTest();
            AnnouncementProgramPlanController.saveMappings(annId, plans, new List<String>{ 'Semester 1', 'Semester 2' });
            Test.stopTest();

            AnnouncementProgramPlanController.Config config = AnnouncementProgramPlanController.getConfig(annId);
            System.assertEquals(2, config.selectedProgramPlanIds.size());
            System.assertEquals(2, config.selectedSemesters.size());
            System.assertEquals(false, config.allProgramPlans);
        }
        System.assertEquals(4, [SELECT COUNT() FROM Announcement_Program_Plan__c WHERE Announcement__c = :annId],
            'One row per Program Plan and semester');
        System.assertEquals(false, [SELECT All_Program_Plans__c FROM Announcement__c WHERE Id = :annId].All_Program_Plans__c);
    }

    @isTest
    static void savesPlansForAllSemesters() {
        Id annId = announcementId();
        List<String> plans = planIds();
        System.runAs(admin()) {
            AnnouncementProgramPlanController.saveMappings(annId, plans, new List<String>());
        }

        List<Announcement_Program_Plan__c> mappings = [SELECT Semester__c FROM Announcement_Program_Plan__c WHERE Announcement__c = :annId];
        System.assertEquals(2, mappings.size(), 'One row per Program Plan');
        for (Announcement_Program_Plan__c mapping : mappings) {
            System.assertEquals(null, mapping.Semester__c, 'Blank semester means every semester');
        }
    }

    @isTest
    static void clearingPlansMakesItVisibleToAllAgain() {
        Id annId = announcementId();
        List<String> plans = planIds();
        System.runAs(admin()) {
            AnnouncementProgramPlanController.saveMappings(annId, plans, new List<String>{ 'Semester 1' });
            AnnouncementProgramPlanController.saveMappings(annId, new List<String>(), new List<String>());
        }

        System.assertEquals(0, [SELECT COUNT() FROM Announcement_Program_Plan__c WHERE Announcement__c = :annId]);
        System.assertEquals(true, [SELECT All_Program_Plans__c FROM Announcement__c WHERE Id = :annId].All_Program_Plans__c);
    }

    @isTest
    static void invalidProgramPlanIsReported() {
        Id annId = announcementId();
        Boolean failed = false;
        System.runAs(admin()) {
            try {
                AnnouncementProgramPlanController.saveMappings(annId, new List<String>{ 'not-an-id' }, null);
            } catch (AuraHandledException e) {
                failed = true;
            }
        }
        System.assert(failed, 'An invalid Program Plan should fail');
        System.assertEquals(0, [SELECT COUNT() FROM Announcement_Program_Plan__c WHERE Announcement__c = :annId]);
    }
}