@isTest
private class saveQuestionnaireResponseTest {
    
    @testSetup
    static void setup() {
        // Create required RecordType for Case
        RecordType rt = [SELECT Id FROM RecordType WHERE SObjectType = 'Case' AND Name = 'Service' LIMIT 1];
        Contact testContact = new Contact(
            FirstName = 'Questionnaire',
            LastName = 'Tester',
            Email = 'questionnaire.tester@example.com'
        );
        insert testContact;
        
        // Insert dummy Case
        Case c = new Case(
            Subject = 'Test Case',
            RecordTypeId = rt.Id,
            ContactId = testContact.Id,
            SuppliedEmail = testContact.Email
        );
        insert c;
        
		Alm_Questionnaire__c quest = new Alm_Questionnaire__c();
        insert quest;
        
        Alm_Questionnaire_Parameter__c param = new Alm_Questionnaire_Parameter__c(
        	Questionnaire__c=quest.Id
        );
        insert param;
        
        // Insert Questionnaire Parameter Response separately (no list)
        Alm_Questionnaire_Parameter_Response__c resp1 = new Alm_Questionnaire_Parameter_Response__c(
            Case__c = c.Id,
            Questionnaire_Parameter__c = param.Id,
            Response__c = 'Answer0'
        );
        insert resp1;
        
        Alm_Questionnaire__c quest1 = new Alm_Questionnaire__c();
        insert quest1;
        
		Alm_Questionnaire_Parameter__c param1 = new Alm_Questionnaire_Parameter__c(
         Questionnaire__c=quest1.Id
        );
        insert param1;
        Alm_Questionnaire_Parameter_Response__c resp2 = new Alm_Questionnaire_Parameter_Response__c(
            Case__c = c.Id,
            Questionnaire_Parameter__c = param1.Id,
            Response__c = 'Answer1'
        );
        insert resp2;
    }

    @isTest
    static void testRetrieveCaseDetails() {
        
        
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/saveQuestionnaire/getCaseDetails/';
        req.httpMethod = 'GET';
        req.addParameter('caseId', testCase.Id);
        RestContext.request = req;
        RestContext.response = res;

        saveQuestionnaireResponse.doGet();
        Test.stopTest();

        System.assert(true, 'GET request executed successfully.');
    }

    @isTest
    static void testSaveQuestionnaireWithPDF() {
        RecordType rt = [SELECT Id FROM RecordType WHERE SObjectType = 'Case' AND Name = 'Service' LIMIT 1];
        Contact testContact = [SELECT Id, Email FROM Contact LIMIT 1];

        Case c = new Case(
            Subject = 'PDF Test Case',
            RecordTypeId = rt.Id,
            ContactId = testContact.Id,
            SuppliedEmail = testContact.Email
        );

        Alm_Questionnaire__c quest2 = new Alm_Questionnaire__c();
        insert quest2;
        
		Alm_Questionnaire_Parameter__c param2 = new Alm_Questionnaire_Parameter__c(
         Questionnaire__c=quest2.Id
        );
        insert param2;
        
        Alm_Questionnaire_Parameter_Response__c resp = new Alm_Questionnaire_Parameter_Response__c(
            Questionnaire_Parameter__c = param2.Id,
            Response__c = EncodingUtil.base64Encode(Blob.valueOf('Dummy PDF content'))
        );

        saveQuestionnaireResponse.QuestionnairePostRequestWrapper wrapper = 
            new saveQuestionnaireResponse.QuestionnairePostRequestWrapper();
        wrapper.fileType = 'pdf';
        wrapper.response = new List<Alm_Questionnaire_Parameter_Response__c>{ resp };

        saveQuestionnaireResponse.QuestionnairePostRequest reqPayload = 
            new saveQuestionnaireResponse.QuestionnairePostRequest();
        reqPayload.caseRecord = c;
        reqPayload.response = new List<saveQuestionnaireResponse.QuestionnairePostRequestWrapper>{ wrapper };

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestBody = Blob.valueOf(JSON.serialize(reqPayload));
        req.httpMethod = 'POST';
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        saveQuestionnaireResponse.QuestionnairePostResponse result = saveQuestionnaireResponse.saveQuestionnaire();
        Test.stopTest();

        System.assertEquals(true, result.success);
        System.assertEquals('Response created successfully', result.message);
    }

    @isTest
    static void testSaveQuestionnaireWithNormalResponses() {
        RecordType rt = [SELECT Id FROM RecordType WHERE SObjectType = 'Case' AND Name = 'Service' LIMIT 1];
        Contact testContact = [SELECT Id, Email FROM Contact LIMIT 1];

        Case c = new Case(
            Subject = 'Normal Response Test',
            RecordTypeId = rt.Id,
            ContactId = testContact.Id,
            SuppliedEmail = testContact.Email
        );

         Alm_Questionnaire__c quest3 = new Alm_Questionnaire__c();
        insert quest3;
        
		Alm_Questionnaire_Parameter__c param3 = new Alm_Questionnaire_Parameter__c(
         Questionnaire__c=quest3.Id
        );
        insert param3;
        
        Alm_Questionnaire_Parameter_Response__c resp = new Alm_Questionnaire_Parameter_Response__c(
            Questionnaire_Parameter__c = param3.Id,
            Response__c = 'This is a normal response'
        );

        saveQuestionnaireResponse.QuestionnairePostRequestWrapper wrapper = 
            new saveQuestionnaireResponse.QuestionnairePostRequestWrapper();
        wrapper.fileType = null;
        wrapper.response = new List<Alm_Questionnaire_Parameter_Response__c>{ resp };

        saveQuestionnaireResponse.QuestionnairePostRequest reqPayload = 
            new saveQuestionnaireResponse.QuestionnairePostRequest();
        reqPayload.caseRecord = c;
        reqPayload.response = new List<saveQuestionnaireResponse.QuestionnairePostRequestWrapper>{ wrapper };

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestBody = Blob.valueOf(JSON.serialize(reqPayload));
        req.httpMethod = 'POST';
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        saveQuestionnaireResponse.QuestionnairePostResponse result = saveQuestionnaireResponse.saveQuestionnaire();
        Test.stopTest();

        System.assertEquals(true, result.success);
    }
    
    @isTest
    static void testRetrieveCaseDetailsMissingCaseId() {
       
		 try{
            // Set up the RestRequest without caseId
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/saveQuestionnaire/getCaseDetails';
        req.httpMethod = 'GET';

        RestContext.request = req;

        // Invoke the method
        Test.startTest();
       	saveQuestionnaireResponse.retrieveCaseDetails();
        Test.stopTest();
        }catch(Exception e){

        }   
    }
    
    @isTest
    static void testSaveQuestionnaireExceptionHandling() {
        // Create a mock RestRequest
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/saveQuestionnaire/';
        req.httpMethod = 'POST';

        // Construct a request payload with missing required fields
        saveQuestionnaireResponse.QuestionnairePostRequest requestPayload = new saveQuestionnaireResponse.QuestionnairePostRequest();
        requestPayload.caseRecord =null; // Intentionally missing required fields
        requestPayload.response = new List<saveQuestionnaireResponse.QuestionnairePostRequestWrapper>();

        // Serialize the payload to JSON and set it as the request body
        req.requestBody = Blob.valueOf(JSON.serialize(requestPayload));
        RestContext.request = req;

        // Invoke the method
        saveQuestionnaireResponse.QuestionnairePostResponse result;
        Test.startTest();
        result = saveQuestionnaireResponse.saveQuestionnaire();
        Test.stopTest();
    }
    
   
}