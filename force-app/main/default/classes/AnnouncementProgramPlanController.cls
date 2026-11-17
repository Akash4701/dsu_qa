/**
 * PKDSU-199: backs the "Program Plans" action on Announcement. Lets admins limit an announcement
 * to selected Program Plans and, optionally, to selected semesters of them.
 *
 * Mapping rows: one Announcement_Program_Plan__c per Program Plan x semester. When no semester is
 * selected, one row per Program Plan with a blank Semester__c (= every semester).
 * No Program Plans selected = visible to all (Announcement__c.All_Program_Plans__c = true).
 */
public with sharing class AnnouncementProgramPlanController {

    public class Option {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        Option(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    public class Config {
        @AuraEnabled public List<Option> programPlans = new List<Option>();
        @AuraEnabled public List<Option> semesters = new List<Option>();
        @AuraEnabled public List<String> selectedProgramPlanIds = new List<String>();
        @AuraEnabled public List<String> selectedSemesters = new List<String>();
        @AuraEnabled public Boolean allProgramPlans = true;
    }

    /** Program Plan and semester choices, for the New Announcement form (no record yet). */
    @AuraEnabled(cacheable=true)
    public static Config getOptions() {
        Config config = new Config();
        for (hed__Program_Plan__c plan : [SELECT Id, Name FROM hed__Program_Plan__c WITH SECURITY_ENFORCED ORDER BY Name]) {
            config.programPlans.add(new Option(plan.Name, plan.Id));
        }
        for (Schema.PicklistEntry entry : Announcement_Program_Plan__c.Semester__c.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                config.semesters.add(new Option(entry.getLabel(), entry.getValue()));
            }
        }
        return config;
    }

    @AuraEnabled
    public static Config getConfig(Id announcementId) {
        Config config = getOptions();

        Announcement__c announcement = [
            SELECT All_Program_Plans__c,
                (SELECT Program_Plan__c, Semester__c FROM Announcement_Program_Plans__r)
            FROM Announcement__c
            WHERE Id = :announcementId
            WITH SECURITY_ENFORCED
        ];
        config.allProgramPlans = announcement.All_Program_Plans__c;

        Set<String> planIds = new Set<String>();
        Set<String> semesters = new Set<String>();
        for (Announcement_Program_Plan__c mapping : announcement.Announcement_Program_Plans__r) {
            planIds.add(mapping.Program_Plan__c);
            if (String.isNotBlank(mapping.Semester__c)) {
                semesters.add(mapping.Semester__c);
            }
        }
        config.selectedProgramPlanIds.addAll(planIds);
        config.selectedSemesters.addAll(semesters);
        return config;
    }

    /**
     * Replaces the announcement's Program Plan mappings with the given selection.
     * An empty programPlanIds makes the announcement visible to all Program Plans again.
     */
    @AuraEnabled
    public static void saveMappings(Id announcementId, List<String> programPlanIds, List<String> semesters) {
        List<String> planIds = programPlanIds == null ? new List<String>() : programPlanIds;
        List<String> semesterValues = semesters == null ? new List<String>() : semesters;

        Savepoint sp = Database.setSavepoint();
        try {
            delete [SELECT Id FROM Announcement_Program_Plan__c WHERE Announcement__c = :announcementId];

            List<Announcement_Program_Plan__c> mappings = new List<Announcement_Program_Plan__c>();
            for (String planId : planIds) {
                if (semesterValues.isEmpty()) {
                    mappings.add(new Announcement_Program_Plan__c(Announcement__c = announcementId, Program_Plan__c = planId));
                }
                for (String semester : semesterValues) {
                    mappings.add(new Announcement_Program_Plan__c(
                        Announcement__c = announcementId, Program_Plan__c = planId, Semester__c = semester));
                }
            }
            insert mappings;

            update new Announcement__c(Id = announcementId, All_Program_Plans__c = planIds.isEmpty());
        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException('Could not save the Program Plans: ' + e.getMessage());
        }
    }
}