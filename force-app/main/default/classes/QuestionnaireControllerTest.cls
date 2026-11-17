@isTest
public class QuestionnaireControllerTest {
    @testSetup
    static void setup() {
        // Create test data for the Case, Contact, Service Offering, Questionnaire, and related objects
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            Email = 'questionnaire.controller@example.com'
        );
        insert testContact;
        
        Alm_Service_Offering__c testServiceOffering = new Alm_Service_Offering__c(Name = 'Test Service Offering');
        insert testServiceOffering;
        
        Case testCase = new Case(
            Subject = 'Test Case',
            ContactId = testContact.Id,
            Service_Offering__c = testServiceOffering.Id,
            SuppliedEmail = testContact.Email
        );
        insert testCase;
        
        Alm_Questionnaire__c testQuestionnaire = new Alm_Questionnaire__c(
            Section_Name__c = 'Test Questionnaire',
            Questions_JSON__c = '{"questions": []}'
        );
        insert testQuestionnaire;
        
        // Link Questionnaire with Service Offering
        Alm_Service_Offering__c serviceOfferingWithQuestionnaire = new Alm_Service_Offering__c(
            Id = testServiceOffering.Id,
            Questionnaire__c = testQuestionnaire.Id
        );
        update serviceOfferingWithQuestionnaire;
        
        Alm_Questionnaire_Parameter__c testParameter = new Alm_Questionnaire_Parameter__c(
            //Name = 'Test Parameter',
            Question_Label__c = 'Test Question',
            Questionnaire__c = testQuestionnaire.Id
        );
        insert testParameter;
        
        Alm_Questionnaire_Parameter_Response__c testResponse = new Alm_Questionnaire_Parameter_Response__c(
            Questionnaire_Parameter__c = testParameter.Id,
            Response__c = 'Test Response',
            Respondent__c = testContact.Id
        );
        insert testResponse;
    }
    
    @isTest
    static void testGetQuestionnaireResponses() {
        // Retrieve the Case Id for testing
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        
        Test.startTest();
        // Call the method in the controller
        List<Alm_Questionnaire__c> result = QuestionnaireController.getQuestionnaireResponses(testCase.Id);
        Test.stopTest();
        
        // Verify the result is not null and contains the expected data
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(1, result.size(), 'There should be one questionnaire returned');
        //System.assertEquals('Test Questionnaire', result[0].Name, 'Questionnaire name should match');
        System.assertEquals(1, result[0].Alm_Questionnaire_Parameters__r.size(), 'There should be one parameter');
        System.assertEquals('Test Question', result[0].Alm_Questionnaire_Parameters__r[0].Question_Label__c, 'Question label should match');
        System.assertEquals(1, result[0].Alm_Questionnaire_Parameters__r[0].Alm_Questionnaire_Parameter_Responses__r.size(), 'There should be one response');
        System.assertEquals('Test Response', result[0].Alm_Questionnaire_Parameters__r[0].Alm_Questionnaire_Parameter_Responses__r[0].Response__c, 'Response should match');
    }
}