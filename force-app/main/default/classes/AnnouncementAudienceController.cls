/**
 * PKDSU-199: backs the New Announcement form. Lets admins pick the Accounts and Program Plans an
 * announcement is for, saved as Announcement_Audience__c rows (as in the product org).
 *
 * One row per selected Account and one row per selected Program Plan.
 * No Accounts and no Program Plans selected = no rows = the announcement is for everyone.
 */
public with sharing class AnnouncementAudienceController {

    public class Option {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public String accountId;
        Option(String label, String value, String accountId) {
            this.label = label;
            this.value = value;
            this.accountId = accountId;
        }
    }

    public class Options {
        @AuraEnabled public List<Option> accounts = new List<Option>();
        @AuraEnabled public List<Option> programPlans = new List<Option>();
    }

    /** The Accounts that own Program Plans, and every Program Plan with its Account. */
    @AuraEnabled(cacheable=true)
    public static Options getOptions() {
        Options options = new Options();
        Map<Id, String> accountNames = new Map<Id, String>();
        for (hed__Program_Plan__c plan : [
            SELECT Id, Name, hed__Account__c, hed__Account__r.Name
            FROM hed__Program_Plan__c
            WITH SECURITY_ENFORCED
            ORDER BY Name
        ]) {
            options.programPlans.add(new Option(plan.Name, plan.Id, plan.hed__Account__c));
            if (plan.hed__Account__c != null) {
                accountNames.put(plan.hed__Account__c, plan.hed__Account__r.Name);
            }
        }
        List<Option> accounts = new List<Option>();
        for (Id accountId : accountNames.keySet()) {
            accounts.add(new Option(accountNames.get(accountId), accountId, accountId));
        }
        options.accounts = sortByLabel(accounts);
        return options;
    }

    /** Replaces the announcement's audience with the given Accounts and Program Plans. */
    @AuraEnabled
    public static void saveAudience(Id announcementId, List<String> accountIds, List<String> programPlanIds) {
        Savepoint sp = Database.setSavepoint();
        try {
            delete [SELECT Id FROM Announcement_Audience__c WHERE Announcement__c = :announcementId];

            List<Announcement_Audience__c> rows = new List<Announcement_Audience__c>();
            for (String accountId : accountIds == null ? new List<String>() : accountIds) {
                rows.add(new Announcement_Audience__c(Announcement__c = announcementId, Account__c = accountId));
            }
            for (String planId : programPlanIds == null ? new List<String>() : programPlanIds) {
                rows.add(new Announcement_Audience__c(Announcement__c = announcementId, Program_Plan__c = planId));
            }
            insert rows;

            // Visible to all students only when no audience is selected (the portal API checks this flag)
            update new Announcement__c(Id = announcementId, All_Program_Plans__c = rows.isEmpty());
        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException('Could not save the audience: ' + e.getMessage());
        }
    }

    private static List<Option> sortByLabel(List<Option> options) {
        Map<String, Option> byKey = new Map<String, Option>();
        for (Option option : options) {
            byKey.put(option.label + '|' + option.value, option);
        }
        List<String> keys = new List<String>(byKey.keySet());
        keys.sort();
        List<Option> sorted = new List<Option>();
        for (String key : keys) {
            sorted.add(byKey.get(key));
        }
        return sorted;
    }
}