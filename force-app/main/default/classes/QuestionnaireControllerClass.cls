public with sharing class QuestionnaireControllerClass {
    @AuraEnabled
    public static Id saveQuestionnaireWithQuestions(Alm_Questionnaire__c questionnaire, List<Alm_Questionnaire_Parameter__c> questions, String relatedRecordId,String relatedObjectType) {
        try {
            // Insert the questionnaire record to get the new ID
            insert questionnaire;
            
            // Set the Questionnaire__c field on each question to the new questionnaire ID
            for (Alm_Questionnaire_Parameter__c question : questions) {
                question.Questionnaire__c = questionnaire.Id;
            }
            
            // Insert the questions to get their IDs
            insert questions;
            
            SObject relatedRecord;

            if(relatedObjectType == 'Alm_Service_Offering__c'){
                relatedRecord = new Alm_Service_Offering__c(Id=relatedRecordId, Questionnaire__c = questionnaire.Id);
            }else if(relatedObjectType == 'Schedule_Sessions__c'){
                relatedRecord = new Schedule_Sessions__c(Id=relatedRecordId, Questionnaire__c = questionnaire.Id);
            }else if(relatedObjectType == 'Alm_Survey__c'){
                relatedRecord = new Alm_Survey__c(Id=relatedRecordId, Alm_Questionnaire__c = questionnaire.Id);
            }
            
            if(relatedRecord!=null){
                update relatedRecord;
            }

            // Return the new questionnaire ID
            return questionnaire.Id;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static Alm_Questionnaire__c getQuestionnaireWithQuestions(Id questionnaireId) {
        try {
            return [SELECT Id, Section_Name__c, Descripation__c, Target_Audience__c,
                    (SELECT Id, Question_Label__c, Question_Type__c, Is_Required__c, MCQ_Options__c,Section_Name__c,Section_Header__c
                     FROM Alm_Questionnaire_Parameters__r)
                    FROM Alm_Questionnaire__c
                    WHERE Id = :questionnaireId];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static Id saveQuestionnaireWithQuestions2(Alm_Questionnaire__c questionnaire, List<Alm_Questionnaire_Parameter__c> questions) {
        try {
            
            // Serialize the questions list to JSON and save to the questionnaire
            String questionsJson = JSON.serialize(questions);
            questionnaire.Questions_JSON__c = questionsJson;
            
            // Upsert the questionnaire record
            upsert questionnaire;
            
            // Retrieve existing questions from the database
            List<Alm_Questionnaire_Parameter__c> existingQuestions = [
                SELECT Id FROM Alm_Questionnaire_Parameter__c 
                WHERE Questionnaire__c = :questionnaire.Id
            ];
            
            // Get the IDs of the questions sent from the LWC component
            Set<Id> incomingQuestionIds = new Set<Id>();
            for (Alm_Questionnaire_Parameter__c question : questions) {
                if (question.Id != null) {
                    incomingQuestionIds.add(question.Id);
                }
            }
            
            // Identify the questions to delete
            List<Alm_Questionnaire_Parameter__c> questionsToDelete = new List<Alm_Questionnaire_Parameter__c>();
            for (Alm_Questionnaire_Parameter__c existingQuestion : existingQuestions) {
                if (!incomingQuestionIds.contains(existingQuestion.Id)) {
                    questionsToDelete.add(existingQuestion);
                }
            }
            
            // Delete the identified questions
            if (!questionsToDelete.isEmpty()) {
                delete questionsToDelete;
            }
            
            // Handle new or updated questions
            for (Alm_Questionnaire_Parameter__c question : questions) {
                if (question.Id == null) {
                    question.Questionnaire__c = questionnaire.Id;
                }
            }
            upsert questions;
            
            // Return the questionnaire Id
            return questionnaire.Id;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}