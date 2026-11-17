/**
 * Test-only lookups for the "Feedback" record types, so tests do not depend on the running
 * user's default record type (the Feedback_Master__c lookup filter requires RT "Feedback").
 */
@isTest
public class FeedbackTestRecordTypes {
    public static Id questionnaire() {
        return Schema.SObjectType.Questionnaire_Metadata__c.getRecordTypeInfosByDeveloperName().get('Feedback').getRecordTypeId();
    }

    public static Id question() {
        return Schema.SObjectType.Question_Metadata__c.getRecordTypeInfosByDeveloperName().get('Feedback').getRecordTypeId();
    }
}