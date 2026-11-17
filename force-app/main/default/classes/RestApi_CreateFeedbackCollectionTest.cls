@isTest
private class RestApi_CreateFeedbackCollectionTest {
    @isTest
    static void testCreateFeedbackCollection() {
        Blackboard_Integration__c bbSettings = new Blackboard_Integration__c(
            SetupOwnerId = UserInfo.getOrganizationId(), // Organization level
            Username__c = 'testUser',
            Password__c = 'testPass'
        );
        insert bbSettings;
        Test.setMock(HttpCalloutMock.class, new MockCallout());
        Datetime before = System.now();
        setupTestDataAndExecuteRequest();
        Datetime after = System.now();

        // Feedback_DateTime__c is the server-side submission time, never the (stale) feedbackDate from the
        // request, and every answer row of one submission carries the same value.
        List<Collected_Feedback_Data__c> saved = [
            SELECT Id, Feedback_DateTime__c FROM Collected_Feedback_Data__c
        ];
        System.assertEquals(2, saved.size(), 'Both answer rows should be saved');
        Datetime dueDate = Datetime.newInstanceGmt(STALE_DUE_DATE, Time.newInstance(0, 0, 0, 0));
        for (Collected_Feedback_Data__c row : saved) {
            System.assertNotEquals(null, row.Feedback_DateTime__c, 'Feedback_DateTime__c should be populated');
            System.assertNotEquals(dueDate, row.Feedback_DateTime__c, 'The request feedbackDate must be ignored');
            System.assert(row.Feedback_DateTime__c >= before && row.Feedback_DateTime__c <= after,
                'Feedback_DateTime__c should be the submission time, was ' + row.Feedback_DateTime__c);
        }
        System.assertEquals(saved[0].Feedback_DateTime__c, saved[1].Feedback_DateTime__c,
            'All rows of one submission share the same timestamp');
    }

    // A due date well in the future, standing in for what the portal used to send as feedbackDate.
    private static final Date STALE_DUE_DATE = Date.today().addDays(30);

    @isTest
    static void testErrorScenario() {
        Blackboard_Integration__c bbSettings = new Blackboard_Integration__c(
            SetupOwnerId = UserInfo.getOrganizationId(), // Organization level
            Username__c = 'testUser',
            Password__c = 'testPass'
        );
        insert bbSettings;
        Test.setMock(HttpCalloutMock.class, new MockCallout());
        setupErrorScenarioRequest();
    }

    @isTest
    static void testInvalidData() {
        Blackboard_Integration__c bbSettings = new Blackboard_Integration__c(
            SetupOwnerId = UserInfo.getOrganizationId(), // Organization level
            Username__c = 'testUser',
            Password__c = 'testPass'
        );
        insert bbSettings;
        Test.setMock(HttpCalloutMock.class, new MockCallout());
        setupInvalidJsonRequest();
    }

    @isTest
    static void testEmptyRequest() {
        Blackboard_Integration__c bbSettings = new Blackboard_Integration__c(
            SetupOwnerId = UserInfo.getOrganizationId(), // Organization level
            Username__c = 'testUser',
            Password__c = 'testPass'
        );
        insert bbSettings;
        Test.setMock(HttpCalloutMock.class, new MockCallout());
        setupEmptyRequest();
    }

    // ✅ New Test: Mixed Success and Failure in Upsert
    @isTest
    static void testMixedSuccessAndFailure() {
        Blackboard_Integration__c bbSettings = new Blackboard_Integration__c(
            SetupOwnerId = UserInfo.getOrganizationId(), // Organization level
            Username__c = 'testUser',
            Password__c = 'testPass'
        );
        insert bbSettings;
        Test.startTest();

        Account acc = new Account(Name = 'Test Acc');
        insert acc;

        Contact contact = new Contact(LastName = 'Test Contact');
        insert contact;

        hed__Term__c term = new hed__Term__c(Name = 'Test Term', hed__Account__c = acc.Id,Term_Reference__c='Term 1');
        insert term;

        //Id recordTypeId = Schema.SObjectType.Collected_Feedback_Data__c.getRecordTypeInfosByName().get('Standard').getRecordTypeId();

        // Valid Feedback Item
        Feedback_Item__c validFeedbackItem = new Feedback_Item__c(Feedback_Status__c = 'Pending');
        insert validFeedbackItem;

        // Valid Request
        RestApi_CreateFeedbackCollection.requestCreateFeedbackCollectionDataWrapper validRequest = new RestApi_CreateFeedbackCollection.requestCreateFeedbackCollectionDataWrapper();
        validRequest.contactId = contact.Id;
        validRequest.termId = term.Id;
        validRequest.recordType = 'Standard';
        validRequest.feedbackItemId = validFeedbackItem.Id;
        validRequest.parameter = 'Valid Question';

        // Invalid Request (Missing Required Field)
        RestApi_CreateFeedbackCollection.requestCreateFeedbackCollectionDataWrapper invalidRequest = validRequest.clone();
        invalidRequest.termId = null; // Term__c is required

        List<RestApi_CreateFeedbackCollection.requestCreateFeedbackCollectionDataWrapper> requestList = new List<RestApi_CreateFeedbackCollection.requestCreateFeedbackCollectionDataWrapper>{validRequest, invalidRequest};

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/createFeedbackCollection';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(requestList));

        RestContext.request = req;
        RestContext.response = new RestResponse();

        RestApi_CreateFeedbackCollection.doCreateFeedbackCollection();
        Test.stopTest();
    }

    // ✅ New Test: Invalid Date Format
    @isTest
    static void testInvalidDateFormat() {
        Blackboard_Integration__c bbSettings = new Blackboard_Integration__c(
            SetupOwnerId = UserInfo.getOrganizationId(), // Organization level
            Username__c = 'testUser',
            Password__c = 'testPass'
        );
        insert bbSettings;
        Test.startTest();

        Account acc = new Account(Name = 'Test Acc');
        insert acc;

        Contact contact = new Contact(LastName = 'Test Contact');
        insert contact;

        RestApi_CreateFeedbackCollection.requestCreateFeedbackCollectionDataWrapper request = new RestApi_CreateFeedbackCollection.requestCreateFeedbackCollectionDataWrapper();
        request.contactId = contact.Id;
        request.recordType = 'Standard';
        request.parameter = 'Question';
        request.feedbackDate = 'Invalid-Date'; // Invalid format

        List<RestApi_CreateFeedbackCollection.requestCreateFeedbackCollectionDataWrapper> requestList = new List<RestApi_CreateFeedbackCollection.requestCreateFeedbackCollectionDataWrapper>{request};

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/createFeedbackCollection';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(requestList));

        RestContext.request = req;
        RestContext.response = new RestResponse();

        RestApi_CreateFeedbackCollection.doCreateFeedbackCollection();
        Test.stopTest();
    }

    // ✅ New Test: Feedback Item Update Fails (e.g., via Validation Rule)
    @isTest
    static void testFeedbackItemUpdateError() {
        Blackboard_Integration__c bbSettings = new Blackboard_Integration__c(
            SetupOwnerId = UserInfo.getOrganizationId(), // Organization level
            Username__c = 'testUser',
            Password__c = 'testPass'
        );
        insert bbSettings;
        Test.startTest();

        

        Account acc = new Account(Name = 'Test Acc');
        insert acc;

        Contact contact = new Contact(LastName = 'Test Contact');
        insert contact;

        hed__Term__c term = new hed__Term__c(Name = 'Test Term', hed__Account__c = acc.Id,Term_Reference__c = 'Term 1');
        insert term;

        //Id recordTypeId = Schema.SObjectType.Collected_Feedback_Data__c.getRecordTypeInfosByName().get('Standard').getRecordTypeId();

        Feedback_Item__c feedbackItem = new Feedback_Item__c(Feedback_Status__c = 'Pending');
        insert feedbackItem;

        RestApi_CreateFeedbackCollection.requestCreateFeedbackCollectionDataWrapper request = new RestApi_CreateFeedbackCollection.requestCreateFeedbackCollectionDataWrapper();
        request.contactId = contact.Id;
        request.termId = term.Id;
        request.recordType = 'Standard';
        request.feedbackItemId = feedbackItem.Id;
        request.parameter = 'Question';

        List<RestApi_CreateFeedbackCollection.requestCreateFeedbackCollectionDataWrapper> requestList = new List<RestApi_CreateFeedbackCollection.requestCreateFeedbackCollectionDataWrapper>{request};

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/createFeedbackCollection';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(requestList));

        RestContext.request = req;
        RestContext.response = new RestResponse();

        RestApi_CreateFeedbackCollection.doCreateFeedbackCollection();
        Test.stopTest();
    }

    
    @isTest
    static void testInnerException() {
        Blackboard_Integration__c bbSettings = new Blackboard_Integration__c(
            SetupOwnerId = UserInfo.getOrganizationId(), // Organization level
            Username__c = 'testUser',
            Password__c = 'testPass'
        );
        insert bbSettings;
        Test.startTest();

        RestApi_CreateFeedbackCollection.requestCreateFeedbackCollectionDataWrapper request = new RestApi_CreateFeedbackCollection.requestCreateFeedbackCollectionDataWrapper();
        request.recordType = 'Standard'; // Missing required fields

        List<RestApi_CreateFeedbackCollection.requestCreateFeedbackCollectionDataWrapper> requestList = new List<RestApi_CreateFeedbackCollection.requestCreateFeedbackCollectionDataWrapper>{request};

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/createFeedbackCollection';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(requestList));

        RestContext.request = req;
        RestContext.response = new RestResponse();

        RestApi_CreateFeedbackCollection.doCreateFeedbackCollection();
        
        Test.stopTest();
    }
    
    @isTest
static void testUpsertFailureReachesElseBlock() {
    Blackboard_Integration__c bbSettings = new Blackboard_Integration__c(
            SetupOwnerId = UserInfo.getOrganizationId(), // Organization level
            Username__c = 'testUser',
            Password__c = 'testPass'
        );
        insert bbSettings;
    // Create a real record type for Collected_Feedback_Data__c
    Id rtId = Schema.SObjectType.Collected_Feedback_Data__c
        .getRecordTypeInfosByName()
        .get('End Term Feedback')
        .getRecordTypeId();

    // Construct a JSON payload with an invalid Contact ID to force failure
    String body = '[{'+
        '"contactId": "003000000000000",' + // Invalid Contact ID
        '"termId": "a0B000000000000",' +    // Invalid Term ID
        '"recordType": "End Term Feedback",' +
        '"feedbackMasterId": "a0C000000000000",' +
        '"feedbackMasterChildId": "a0D000000000000",' +
        '"courseId": "a0E000000000000",' +
        '"feedbackItemId": "a0F000000000000",' +
        '"facultyId": "003000000000001",' +
        '"feedbackDate": "2025-05-01",' +
        '"parameter": "How was the class?",' +
        '"answer": "Good",' +
        '"rating": "5"' +
    '}]';

    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();
    req.requestUri = '/services/apexrest/createFeedbackCollection';
    req.httpMethod = 'POST';
    req.requestBody = Blob.valueOf(body);
    RestContext.request = req;
    RestContext.response = res;

    Test.startTest();
    RestApi_CreateFeedbackCollection.doCreateFeedbackCollection();
    Test.stopTest();

    System.assertEquals(200, res.statusCode); // Even failures return 200 with error details
    System.assert(res.responseBody.toString().contains('"success":"false"'));
}

    
     

    // Helper: Setup Test Data and Send Request
    private static void setupTestDataAndExecuteRequest() {
        Account testAcc = new Account(Name = 'testAcc');
        insert testAcc;

        Contact testContact = new Contact(LastName = 'Test Contact');
        insert testContact;

        hed__Term__c testTerm = new hed__Term__c(Name = 'Test Term', hed__Account__c = testAcc.id, Term_Reference__c = 'Term 1');
        insert testTerm;

        Id questRecordTypeId = [SELECT Id FROM RecordType WHERE Name = 'Feedback' AND SObjectType = 'Questionnaire_Metadata__c'].Id;
        Questionnaire_Metadata__c testFeedbackMaster = new Questionnaire_Metadata__c(
            Name = 'Test Feedback Master',
            Program__c = testAcc.id,
            RecordTypeId = questRecordTypeId
        );
        insert testFeedbackMaster;

        Id questionRecordTypeId = [SELECT Id FROM RecordType WHERE Name = 'Feedback' AND SObjectType = 'Question_Metadata__c'].Id;
        Question_Metadata__c testFeedbackMasterChild = new Question_Metadata__c(
            Questionnaire__c = testFeedbackMaster.id,
            RecordTypeId = questionRecordTypeId
        );
        insert testFeedbackMasterChild;

        hed__Course__c testCourse = new hed__Course__c(Name = 'Test Course', hed__Account__c = testAcc.id);
        insert testCourse;

        hed__Course_Offering__c testCourseOffering = new hed__Course_Offering__c(
            Name = 'Test Course Offering',
            hed__Course__c = testCourse.Id,
            hed__Term__c = testTerm.id
        );
        insert testCourseOffering;

        Contact testFaculty = new Contact(LastName = 'Test Faculty');
        insert testFaculty;

        Feedback_Item__c testFeedbackItem = new Feedback_Item__c(Feedback_Status__c = 'Pending');
        insert testFeedbackItem;
        
        RecordType rt = [
    SELECT Id 
    FROM RecordType 
    WHERE SObjectType = 'Collected_Feedback_Data__c' 
    AND Name = 'End Term Feedback' 
    LIMIT 1
];

        RestApi_CreateFeedbackCollection.requestCreateFeedbackCollectionDataWrapper requestData = new RestApi_CreateFeedbackCollection.requestCreateFeedbackCollectionDataWrapper();
        requestData.contactId = testContact.Id;
        requestData.termId = testTerm.Id;
        requestData.recordType = 'End Term Feedback';
        requestData.feedbackMasterId = testFeedbackMaster.Id;
        requestData.feedbackMasterChildId = testFeedbackMasterChild.Id;
        requestData.parameter = 'Test Question';
        requestData.answer = 'Test Answer';
        requestData.courseId = testCourse.Id;
        requestData.courseOfferingId = testCourseOffering.Id;
        requestData.facultyId = testFaculty.Id;
        requestData.rating = '5';
        requestData.feedbackDate = String.valueOf(STALE_DUE_DATE);
        requestData.feedbackItemId = testFeedbackItem.Id;

        // A second answer row in the same submission.
        RestApi_CreateFeedbackCollection.requestCreateFeedbackCollectionDataWrapper secondRow = requestData.clone();
        secondRow.parameter = 'Second Question';

        List<RestApi_CreateFeedbackCollection.requestCreateFeedbackCollectionDataWrapper> requestList = new List<RestApi_CreateFeedbackCollection.requestCreateFeedbackCollectionDataWrapper>{requestData, secondRow};

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/createFeedbackCollection';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(requestList));
        RestContext.request = req;
        RestContext.response = new RestResponse();

        RestApi_CreateFeedbackCollection.doCreateFeedbackCollection();
    }

    // Helper: Error Scenario
    private static void setupErrorScenarioRequest() {
        Account testAcc = new Account(Name = 'testAcc');
        insert testAcc;

        Contact testContact = new Contact(LastName = 'Test Contact');
        insert testContact;

        RestApi_CreateFeedbackCollection.requestCreateFeedbackCollectionDataWrapper requestData = new RestApi_CreateFeedbackCollection.requestCreateFeedbackCollectionDataWrapper();
        requestData.contactId = testContact.Id;
        requestData.recordType = 'Standard';
        requestData.parameter = 'Test Question';

        List<RestApi_CreateFeedbackCollection.requestCreateFeedbackCollectionDataWrapper> requestList = new List<RestApi_CreateFeedbackCollection.requestCreateFeedbackCollectionDataWrapper>{requestData};

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/createFeedbackCollection';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(requestList));
        RestContext.request = req;
        RestContext.response = new RestResponse();

        RestApi_CreateFeedbackCollection.doCreateFeedbackCollection();
    }

    // Helper: Invalid JSON Request
    private static void setupInvalidJsonRequest() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/createFeedbackCollection';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('[{"invalid": "data"}]');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        RestApi_CreateFeedbackCollection.doCreateFeedbackCollection();
    }

    // Helper: Empty Request Body
    private static void setupEmptyRequest() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/createFeedbackCollection';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('[]');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        RestApi_CreateFeedbackCollection.doCreateFeedbackCollection();
    }

    public class MockCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(201);
            res.setBody('{"success": false}');
            return res;
        }
    }
}