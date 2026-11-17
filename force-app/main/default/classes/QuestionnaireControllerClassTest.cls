@IsTest
public class QuestionnaireControllerClassTest {
    @TestSetup
    static void setupTestData() {
        // Create test Questionnaire
        Alm_Questionnaire__c testQuestionnaire = new Alm_Questionnaire__c(
            //Name = 'Test Questionnaire',
            Section_Name__c = 'Section 1',
            Descripation__c = 'Test Description',
            Target_Audience__c = 'Test Audience'
        );
        insert testQuestionnaire;
        
        // Create test Questionnaire Parameters
        List<Alm_Questionnaire_Parameter__c> testQuestions = new List<Alm_Questionnaire_Parameter__c>();
        for (Integer i = 1; i <= 3; i++) {
            testQuestions.add(new Alm_Questionnaire_Parameter__c(
                Questionnaire__c = testQuestionnaire.Id,
                Question_Label__c = 'Question ' + i,
                Question_Type__c = 'Linear Scale',
                Is_Required__c = true
            ));
        }
        insert testQuestions;
        
        // Create a Service Offering
        Alm_Service_Offering__c testServiceOffering = new Alm_Service_Offering__c(
            Name = 'Test Service Offering'
        );
        insert testServiceOffering;
    }
    
    @IsTest
    static void testSaveQuestionnaireWithQuestions() {
        // Create new Questionnaire and Questions
        Alm_Questionnaire__c newQuestionnaire = new Alm_Questionnaire__c(
            //Name = 'New Test Questionnaire',
            Section_Name__c = 'Section 2',
            Descripation__c = 'New Test Description',
            Target_Audience__c = 'New Test Audience'
        );
        
        List<Alm_Questionnaire_Parameter__c> newQuestions = new List<Alm_Questionnaire_Parameter__c>();
        for (Integer i = 1; i <= 2; i++) {
            newQuestions.add(new Alm_Questionnaire_Parameter__c(
                Question_Label__c = 'New Question ' + i,
                Question_Type__c = 'Linear Scale',
                Is_Required__c = false,
                MCQ_Options__c = 'Option 1,Option 2'
            ));
        }
        
        // Call the method
        //String serviceOfferingId = [SELECT Id FROM Service_Offering__c LIMIT 1].Id;
        Alm_Service_Offering__c so = new Alm_Service_Offering__c(Name = 'Test');
        insert so;
        
        Test.startTest();
        Id questionnaireId = QuestionnaireControllerClass.saveQuestionnaireWithQuestions(newQuestionnaire, newQuestions, so.Id,'Service_Offering__c');
        Test.stopTest();
        
        // Validate results
           }
    
    @IsTest
    static void testGetQuestionnaireWithQuestions() {
        // Retrieve existing Questionnaire
        Id questionnaireId = [SELECT Id FROM Alm_Questionnaire__c LIMIT 1].Id;
        
        // Call the method
        Test.startTest();
        Alm_Questionnaire__c retrievedQuestionnaire = QuestionnaireControllerClass.getQuestionnaireWithQuestions(questionnaireId);
        Test.stopTest();
        
        // Validate results
        System.assertNotEquals(null, retrievedQuestionnaire, 'Retrieved questionnaire should not be null');
        System.assertEquals(3, retrievedQuestionnaire.Alm_Questionnaire_Parameters__r.size(), 'There should be 3 associated questions');
    }
    
    @IsTest
    static void testSaveQuestionnaireWithQuestions2() {
        // Retrieve an existing Questionnaire
        Alm_Questionnaire__c existingQuestionnaire = [SELECT Id FROM Alm_Questionnaire__c LIMIT 1];
        List<Alm_Questionnaire_Parameter__c> questions = [SELECT Id, Questionnaire__c FROM Alm_Questionnaire_Parameter__c WHERE Questionnaire__c = :existingQuestionnaire.Id];
        
        // Modify existing questions and add a new question
        questions[0].Question_Label__c = 'Updated Question Label';
        questions.add(new Alm_Questionnaire_Parameter__c(
            Question_Label__c = 'Newly Added Question',
            Question_Type__c = 'Dropdown',
            Is_Required__c = true
        ));
        
        // Call the method
        Test.startTest();
        Id updatedQuestionnaireId = QuestionnaireControllerClass.saveQuestionnaireWithQuestions2(existingQuestionnaire, questions);
        Test.stopTest();
        
        // Validate results
        System.assertEquals(existingQuestionnaire.Id, updatedQuestionnaireId, 'Returned questionnaire ID should match the existing questionnaire ID');
        
        List<Alm_Questionnaire_Parameter__c> updatedQuestions = [SELECT Id FROM Alm_Questionnaire_Parameter__c WHERE Questionnaire__c = :existingQuestionnaire.Id];
        System.assertEquals(4, updatedQuestions.size(), 'There should now be 4 questions');
    }
    
    @IsTest
    static void testSaveQuestionnaireWithQuestions1() {
        // Create new Questionnaire and Questions
        Alm_Questionnaire__c newQuestionnaire = new Alm_Questionnaire__c(
            //Name = 'New Test Questionnaire',
            Section_Name__c = 'Section 2',
            Descripation__c = 'New Test Description',
            Target_Audience__c = 'New Test Audience'
        );
        
        List<Alm_Questionnaire_Parameter__c> newQuestions = new List<Alm_Questionnaire_Parameter__c>();
        for (Integer i = 1; i <= 2; i++) {
            newQuestions.add(new Alm_Questionnaire_Parameter__c(
                Question_Label__c = 'New Question ' + i,
                Question_Type__c = 'Linear Scale',
                Is_Required__c = false,
                MCQ_Options__c = 'Option 1,Option 2'
            ));
        }
        
        // Call the method
        //String serviceOfferingId = [SELECT Id FROM Service_Offering__c LIMIT 1].Id;
        Alm_Service_Offering__c so = new Alm_Service_Offering__c(Name = 'Test');
        insert so;
        
        Test.startTest();
        Id questionnaireId = QuestionnaireControllerClass.saveQuestionnaireWithQuestions(newQuestionnaire, newQuestions, so.Id,'Alm_Service_Offering__c');
        Test.stopTest();
        
        
    }
    
    @IsTest
    static void testSaveQuestionnaireWithQuestions8() {
        // Create new Questionnaire and Questions
        Alm_Questionnaire__c newQuestionnaire = new Alm_Questionnaire__c(
            //Name = 'New Test Questionnaire',
            Section_Name__c = 'Section 2',
            Descripation__c = 'New Test Description',
            Target_Audience__c = 'New Test Audience'
        );
        
        List<Alm_Questionnaire_Parameter__c> newQuestions = new List<Alm_Questionnaire_Parameter__c>();
        for (Integer i = 1; i <= 2; i++) {
            newQuestions.add(new Alm_Questionnaire_Parameter__c(
                Question_Label__c = 'New Question ' + i,
                Question_Type__c = 'Linear Scale',
                Is_Required__c = false,
                MCQ_Options__c = 'Option 1,Option 2'
            ));
        }
        
        // Call the method
        //String serviceOfferingId = [SELECT Id FROM Service_Offering__c LIMIT 1].Id;
        Alm_Service_Offering__c so = new Alm_Service_Offering__c(Name = 'Test');
        insert so;
        
        Test.startTest();
        try{
            Id questionnaireId = QuestionnaireControllerClass.saveQuestionnaireWithQuestions(newQuestionnaire, newQuestions, so.Id,'Event_Master__c');}
        catch(exception e){
            
        }
        Test.stopTest();
        
        // Validate results
        
    }
    
    @IsTest
    static void testSaveQuestionnaireWithQuestions9() {
        // Create new Questionnaire and Questions
        Alm_Questionnaire__c newQuestionnaire = new Alm_Questionnaire__c(
            //Name = 'New Test Questionnaire',
            Section_Name__c = 'Section 2',
            Descripation__c = 'New Test Description',
            Target_Audience__c = 'New Test Audience'
        );
        
        List<Alm_Questionnaire_Parameter__c> newQuestions = new List<Alm_Questionnaire_Parameter__c>();
        for (Integer i = 1; i <= 2; i++) {
            newQuestions.add(new Alm_Questionnaire_Parameter__c(
                Question_Label__c = 'New Question ' + i,
                Question_Type__c = 'Linear Scale',
                Is_Required__c = false,
                MCQ_Options__c = 'Option 1,Option 2'
            ));
        }
        
        // Call the method
        //String serviceOfferingId = [SELECT Id FROM Service_Offering__c LIMIT 1].Id;
        Alm_Service_Offering__c so = new Alm_Service_Offering__c(Name = 'Test');
        insert so;
        
        Test.startTest();
        try{
            Id questionnaireId = QuestionnaireControllerClass.saveQuestionnaireWithQuestions(newQuestionnaire, newQuestions, so.Id,'Schedule_Sessions__c');}
        catch(exception e){
            
        }
        Test.stopTest();
        
        // Validate results
        
    }
    
    @IsTest
    static void testExceptionHandling() {
        // Test with null questionnaire
        try {
            Test.startTest();
            QuestionnaireControllerClass.saveQuestionnaireWithQuestions(null, new List<Alm_Questionnaire_Parameter__c>(), null,null);
            Test.stopTest();
            System.assert(false, 'Exception was not thrown for null questionnaire');
        } catch (AuraHandledException e) {
            System.assertEquals('Script-thrown exception', e.getMessage(), 'Unexpected exception message');
        }
    }
}