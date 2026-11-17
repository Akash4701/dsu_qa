/**
 * Test data factory for the Feedback Management home. One place to change when the Parameter
 * Section / Parameter / Scheduler / Item schema changes.
 */
@isTest
public class FeedbackHomeTestData {

    public static Id sectionRecordType(String developerName) {
        return Schema.SObjectType.Questionnaire_Metadata__c.getRecordTypeInfosByDeveloperName().get(developerName).getRecordTypeId();
    }

    public static Questionnaire_Metadata__c makeSection(String name, String recordTypeDeveloperName, Boolean active) {
        return new Questionnaire_Metadata__c(
            Name = name,
            RecordTypeId = sectionRecordType(recordTypeDeveloperName),
            Feedback_Type__c = 'Faculty Feedback',
            Active__c = active
        );
    }

    public static Question_Metadata__c makeParameter(String name, Id sectionId, Boolean active) {
        // Name is an auto-number on Parameter; the label carries the readable name.
        return new Question_Metadata__c(
            Label__c = name,
            RecordTypeId = FeedbackTestRecordTypes.question(),
            Questionnaire__c = sectionId,
            Question_Label__c = 'How was ' + name + '?',
            Active__c = active,
            Mandatory__c = true
        );
    }

    public static Feedback_Scheduler__c makeScheduler(Id sectionId, Date startDate, Date endDate) {
        return new Feedback_Scheduler__c(
            Feedback_Master__c = sectionId,
            Start_Date__c = startDate,
            End_Date__c = endDate
        );
    }

    /** Creates `total` items, the first `submitted` of them with status Submitted. */
    public static List<Feedback_Item__c> makeItems(Id schedulerId, Integer total, Integer submitted) {
        List<Feedback_Item__c> items = new List<Feedback_Item__c>();
        for (Integer i = 0; i < total; i++) {
            items.add(new Feedback_Item__c(
                Feedback_Scheduler__c = schedulerId,
                Feedback_Status__c = i < submitted ? FeedbackHomeService.STATUS_SUBMITTED : FeedbackHomeService.STATUS_PENDING
            ));
        }
        return items;
    }

    /** Gives the running user the Feedback_Management permission set (idempotent). */
    public static void grantFeedbackAccess(Id userId) {
        Id permissionSetId = [SELECT Id FROM PermissionSet WHERE Name = 'Feedback_Management' LIMIT 1].Id;
        if ([SELECT COUNT() FROM PermissionSetAssignment WHERE AssigneeId = :userId AND PermissionSetId = :permissionSetId] == 0) {
            insert new PermissionSetAssignment(AssigneeId = userId, PermissionSetId = permissionSetId);
        }
    }

    /**
     * The running user with Feedback_Management granted, for use as `System.runAs(asFeedbackUser()) { ... }`.
     * A permission set assigned in the same transaction (or in @TestSetup) does not change what the running
     * user can see until a fresh System.runAs context starts, so tests that exercise user-mode code or write
     * the feedback fields wrap their body in this. Orgs where the user already holds the permission set (the
     * assignment is idempotent) behave the same, so the tests pass in every org.
     */
    public static User asFeedbackUser() {
        Id me = UserInfo.getUserId();
        System.runAs(new User(Id = me)) {
            grantFeedbackAccess(me);
        }
        return new User(Id = me);
    }

    public static User makeStandardUser(String uniqueSuffix) {
        Profile profile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        return new User(
            Alias = 'fbh' + uniqueSuffix.left(4),
            Email = 'fbh' + uniqueSuffix + '@example.com',
            Username = 'fbh' + uniqueSuffix + '@example.com.dsu',
            LastName = 'FeedbackHome',
            ProfileId = profile.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_IN',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
    }
}