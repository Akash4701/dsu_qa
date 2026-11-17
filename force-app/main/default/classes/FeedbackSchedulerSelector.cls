/**
 * All SOQL for scheduler-side logic (item generation, date sync, clean-up, and the scheduler form).
 * Home-screen reads live in FeedbackHomeSelector. Methods that feed user-facing screens run in
 * USER_MODE; the internal trigger helpers (withType, byId, itemsForScheduler, itemLocatorForScheduler,
 * itemIdsForSchedulers) are deliberately not field-filtered so every item of a scheduler stays
 * consistent regardless of who edits it.
 */
public with sharing class FeedbackSchedulerSelector {

    public static List<Feedback_Scheduler__c> withType(Set<Id> schedulerIds) {
        return [
            SELECT Id, Term__c, Start_Date__c, End_Date__c, Feedback_Master__r.Feedback_Type__c
            FROM Feedback_Scheduler__c
            WHERE Id IN :schedulerIds
            WITH SYSTEM_MODE
        ];
    }

    public static Feedback_Scheduler__c byId(Id schedulerId) {
        List<Feedback_Scheduler__c> rows = withType(new Set<Id>{ schedulerId });
        return rows.isEmpty() ? null : rows[0];
    }

    /** Items of one scheduler, capped: callers pass cap + 1 to detect "too many for this transaction". */
    public static List<Feedback_Item__c> itemsForScheduler(Id schedulerId, Integer rowLimit) {
        return [
            SELECT Id, Start_Date__c, End_Date__c
            FROM Feedback_Item__c
            WHERE Feedback_Scheduler__c = :schedulerId
            LIMIT :rowLimit
        ];
    }

    public static Database.QueryLocator itemLocatorForScheduler(Id schedulerId) {
        return Database.getQueryLocator([
            SELECT Id, Start_Date__c, End_Date__c
            FROM Feedback_Item__c
            WHERE Feedback_Scheduler__c = :schedulerId
        ]);
    }

    public static List<Id> itemIdsForSchedulers(Set<Id> schedulerIds, Integer rowLimit) {
        List<Id> ids = new List<Id>();
        for (Feedback_Item__c item : [
            SELECT Id FROM Feedback_Item__c WHERE Feedback_Scheduler__c IN :schedulerIds LIMIT :rowLimit
        ]) {
            ids.add(item.Id);
        }
        return ids;
    }

    // ---------- Scheduler form (course-level feedback) ----------

    public static List<hed__Course_Offering__c> courseOfferingsForTerm(Id termId, Integer rowLimit) {
        return [
            SELECT Id, Name, hed__Course__r.Name, hed__Course__r.hed__Course_ID__c,
                   hed__Start_Date__c, hed__End_Date__c, hed__Faculty__r.Name
            FROM hed__Course_Offering__c
            WHERE hed__Term__c = :termId
            WITH USER_MODE
            ORDER BY Name
            LIMIT :rowLimit
        ];
    }

    public static List<hed__Course_Offering__c> offeringNames(List<Id> offeringIds) {
        return [
            SELECT Id, Name FROM hed__Course_Offering__c WHERE Id IN :offeringIds WITH USER_MODE ORDER BY Name
        ];
    }

    public static Questionnaire_Metadata__c section(Id sectionId) {
        List<Questionnaire_Metadata__c> rows = [
            SELECT Id, Feedback_Type__c FROM Questionnaire_Metadata__c WHERE Id = :sectionId WITH USER_MODE LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    /** Student enrolments of the offerings; callers pass cap + 1 to detect oversize selections. */
    public static List<hed__Course_Enrollment__c> studentEnrolments(List<Id> offeringIds, Integer rowLimit) {
        return [
            SELECT Id, hed__Contact__c, hed__Course_Offering__c,
                   hed__Course_Offering__r.hed__Start_Date__c, hed__Course_Offering__r.hed__End_Date__c
            FROM hed__Course_Enrollment__c
            WHERE hed__Course_Offering__c IN :offeringIds
              AND RecordType.Name = :ConstantsControllerClass.STUDENT
              AND Enrollment_Status__c = :ConstantsControllerClass.ENROLLED
            WITH USER_MODE
            LIMIT :rowLimit
        ];
    }

    public static Map<Id, hed__Course_Offering__c> offeringsWithSessions(List<Id> offeringIds) {
        return new Map<Id, hed__Course_Offering__c>([
            SELECT Id, (SELECT Start_Date__c FROM Sessions__r ORDER BY Start_Date__c)
            FROM hed__Course_Offering__c
            WHERE Id IN :offeringIds
            WITH USER_MODE
        ]);
    }

    public static Set<Id> offeringIdsAlreadyScheduled(Id schedulerId) {
        Set<Id> ids = new Set<Id>();
        String soql = 'SELECT Course_Offering__c offeringId FROM Feedback_Item__c '
            + 'WHERE Feedback_Scheduler__c = :schedulerId AND Course_Offering__c != NULL GROUP BY Course_Offering__c';
        Map<String, Object> binds = new Map<String, Object>{ 'schedulerId' => schedulerId };
        for (SObject row : Database.queryWithBinds(soql, binds, AccessLevel.USER_MODE)) {
            ids.add((Id) row.get('offeringId'));
        }
        return ids;
    }
}