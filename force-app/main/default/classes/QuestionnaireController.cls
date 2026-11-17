public with sharing class QuestionnaireController {
    @AuraEnabled(cacheable=true)
    public static List<Alm_Questionnaire__c> getQuestionnaireResponses(Id caseId) {
        // Query to fetch the service offering, questionnaire, and related responses based on the case Id
        Id conId = [SELECT ContactId FROM Case WHERE Id =: caseId].ContactId;
        Id serviceOfferingId = [SELECT Service_Offering__c FROM Case WHERE Id = :caseId].Service_Offering__c;
        return [
            SELECT Id, Name,Questions_JSON__c,
            (SELECT Id, Name, Question_Label__c,
             (SELECT Id, Response__c, Respondent__r.Name
              FROM Alm_Questionnaire_Parameter_Responses__r WHERE Respondent__c =: conId)
             FROM Alm_Questionnaire_Parameters__r)
            FROM Alm_Questionnaire__c
            WHERE Id IN (
                SELECT Questionnaire__c 
                FROM Alm_Service_Offering__c 
                WHERE Id =: serviceOfferingId
            )
        ];
    }
}