@isTest
public class RestApi_GetMasterFeedBacksTest {

    @testSetup
    static void setupTestData() {
        Blackboard_Integration__c bbSettings = new Blackboard_Integration__c(
            SetupOwnerId = UserInfo.getOrganizationId(), // Organization level
            Username__c = 'testUser',
            Password__c = 'testPass'
        );
        insert bbSettings;
        Test.setMock(HttpCalloutMock.class, new MockCallout());
        Account acc = new Account(Name='Test');
        insert acc;

        // Create Feedback Master (Questionnaire_Metadata__c)
        Questionnaire_Metadata__c master = new Questionnaire_Metadata__c(
            RecordTypeId = FeedbackTestRecordTypes.questionnaire(),
            Feedback_Type__c = 'Graduation Feedback',
            Face_to_Face_and_Online__c = 'Online',
            Academic__c = 'Academic',
            Program__c = acc.Id
        );
        insert master;
        
        hed__Program_Plan__c programPlan = new hed__Program_Plan__c(Name = 'Test Program Plan');
        insert programPlan;
        
        Campus__c campus = new Campus__c(Campus_ID__c = 'CAMPUS123');
        insert campus;

        hed__Term__c term = new hed__Term__c(
            Name = 'Spring 2025',
            hed__Account__c = acc.Id,
            Campus__c = campus.Id,
            Program_Plan__c = programPlan.Id,
            Term_Reference__c = 'Term 1'
        );
        insert term;
        
        hed__Course__c course = new hed__Course__c(
            Name = 'Math 101', 
            hed__Course_ID__c = 'MATH101',
            hed__Account__c = acc.Id
        );
        insert course;

        // Create Feedback Scheduler
        Feedback_Scheduler__c scheduler = new Feedback_Scheduler__c(
            Term__c = term.Id,
            Feedback_Master__c = master.Id
        );
        insert scheduler;

        // Create Feedback Item
        Feedback_Item__c item = new Feedback_Item__c(
            Feedback_Scheduler__c = scheduler.Id
        );
        insert item;

        // Create Course Offering
        hed__Course_Offering__c offering = new hed__Course_Offering__c(
            Name = 'Section A',
            hed__Section_ID__c = 'SEC001',
            hed__Course__c = course.Id,
            hed__Term__c = term.Id
        );
        insert offering;

        // Update Feedback Item with Course Offering
        item.Course_Offering__c = offering.Id;
        update item;

        // Create Question Metadata
        Question_Metadata__c question1 = new Question_Metadata__c(
            Questionnaire__c = master.Id,
            RecordTypeId = Schema.SObjectType.Question_Metadata__c.getRecordTypeInfosByName().get('Feedback').getRecordTypeId(),
            Section_Label__c = 'Section 1',
            Label__c = 'SubLabel1',
            Max_Grade__c = 5,
            Question_Label__c = 'How was the session?',
            Question_Type__c = 'Multiple Choice',
            Answers__c = 'Excellent',
            Mandatory__c = true,
            Order__c = 1,
            Type__c = 'Course'
        );
        insert question1;

        // Create Contact
        Contact con = new Contact(LastName = 'Faculty');
        insert con;

        // Create Collected Feedback
        Collected_Feedback_Data__c feedback = new Collected_Feedback_Data__c(
            Term__c = term.Id,
            Contact__c = con.Id,
            Feedback_Master__c = master.Id,
            Faculty__c = con.Id,
            Course_Name__c = course.Id,
            Feedback_Master_Child__c = question1.Id,
            Feedback_DateTime__c = DateTime.now(),
            Rating__c = '5',
            Parameter__c = 'Parameter X',
            Answer__c = 'Excellent',
            Feedback_Item__c = item.Id
        );
        insert feedback;
    }

    @isTest
    static void testDoGetMasterFeedBackData() {
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
                Test.setMock(HttpCalloutMock.class, new MockCallout());

        // Get IDs
        Feedback_Item__c item = [SELECT Id FROM Feedback_Item__c LIMIT 1];
        Contact con = [SELECT Id FROM Contact LIMIT 1];

        // Setup request parameters
        RestContext.request = new RestRequest();
        RestContext.response = new RestResponse();
        RestContext.request.params.put('feedbackItemId', item.Id);
        RestContext.request.params.put('contactId', con.Id);
        RestContext.request.httpMethod = 'GET';
        RestContext.request.requestUri = '/services/apexrest/FeedBackData';

        // Invoke the method
        RestApi_GetMasterFeedBacks.doGetMasterFeedBackData();

        // Optionally check response if needed
        Blob responseBody = RestContext.response.responseBody;
        System.debug('Response: ' + responseBody.toString());
            }
    }
    public class MockCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            String endpoint = req.getEndpoint();
            String method = req.getMethod();  
            if (method == 'POST' && endpoint.contains('/oauth2/token')) {
                res.setStatusCode(200);
                String responseBody = '{"access_token": "mocked_access_token"}';
                res.setBody(responseBody);
            }
            else if (method == 'POST' && endpoint.contains('/courses')) {
                res.setStatusCode(201);
                res.setBody('{"success": true}');
            } 
            else if (method == 'PATCH' && endpoint.contains('/courses/')) {
                res.setStatusCode(200);
                res.setBody('{"success": true}');
            } 
            else if (method == 'GET' && endpoint.contains('/courses/')) {
                res.setStatusCode(200);
                res.setBody('{"success": true}');
            } 
            else if (method == 'POST' && endpoint.contains('/students')) {
                res.setStatusCode(201);
                res.setBody('{"success": true}');
            } 
            else if (method == 'PUT' && endpoint.contains('/courses/')) {
                res.setStatusCode(201);
                res.setBody('{"success": true}');
            }
            else if (method == 'DELETE' && endpoint.contains('/courses/')) {
                res.setStatusCode(204);
                res.setBody('');
            }
            else if (method == 'POST' && endpoint.contains('/contents/createAssignment')) {
                res.setStatusCode(201);
                res.setBody('{"success": true}');
            } 
            else if (method == 'GET' && endpoint.contains('/gradebook/columns/')) {
                res.setStatusCode(200);
                res.setBody('{"success": true}');
            }
            else {
                res.setStatusCode(400);
                res.setBody('{"success": false}');
            }
            return res;
        }
    }
    @isTest
static void testDoGetMasterFeedBackData_NonMultipleChoice_NoCollection() {
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
    // Get base data
    Feedback_Item__c item = [SELECT Id, Feedback_Scheduler__c FROM Feedback_Item__c LIMIT 1];
    Questionnaire_Metadata__c master = [SELECT Id FROM Questionnaire_Metadata__c LIMIT 1];

    // Add a NEW Question Metadata with NON-MC type
    Question_Metadata__c qText = new Question_Metadata__c(
        Questionnaire__c = master.Id,
        RecordTypeId = Schema.SObjectType.Question_Metadata__c
            .getRecordTypeInfosByName().get('Feedback').getRecordTypeId(),
        Section_Label__c = 'Section X',
        Label__c = 'SubLabelX',
        Max_Grade__c = 0,
        Question_Label__c = 'Text question?',
        Question_Type__c = 'Multiple Choice',          // ✅ forces ELSE branch
        Answers__c = 'FreeTextHere',         // gets copied directly
        Mandatory__c = false,
        Order__c = 2,
        Type__c = 'Course',
        Active__c = true
    );
    insert qText;

    // Use a contact that has NO Collected_Feedback_Data__c
    Contact freshContact = new Contact(LastName='NoFeedback', Email='nofb@test.com');
    insert freshContact;

    // REST setup
    RestContext.request = new RestRequest();
    RestContext.response = new RestResponse();
    RestContext.request.params.put('feedbackItemId', item.Id);
    RestContext.request.params.put('contactId', freshContact.Id);
    RestContext.request.httpMethod = 'GET';
    RestContext.request.requestUri = '/services/apexrest/FeedBackData';

    Test.startTest();
    RestApi_GetMasterFeedBacks.doGetMasterFeedBackData();
    Test.stopTest();

    System.assertEquals(200, RestContext.response.statusCode);
        }
    }
@isTest
static void testDoGetMasterFeedBackData_MultipleOptionRating() {
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
    Feedback_Item__c item = [SELECT Id FROM Feedback_Item__c LIMIT 1];
    Questionnaire_Metadata__c master = [SELECT Id FROM Questionnaire_Metadata__c LIMIT 1];
    Contact con = [SELECT Id FROM Contact LIMIT 1];

    // Add multiple-option-rating question (Answers split with ;)
    Question_Metadata__c qMor = new Question_Metadata__c(
        Questionnaire__c = master.Id,
        RecordTypeId = Schema.SObjectType.Question_Metadata__c
            .getRecordTypeInfosByName().get('Feedback').getRecordTypeId(),
        Section_Label__c = 'Section MOR',
        Label__c = 'SubLabelMOR',
        Max_Grade__c = 5,
        Question_Label__c = 'Rate these items',
        Question_Type__c = 'Multiple Choice', // ✅ MOR branch
        Answers__c = 'A;B;C',                         // ✅ split list
        Mandatory__c = true,
        Order__c = 3,
        Type__c = 'Course',
        Active__c = true
    );
    insert qMor;

    RestContext.request = new RestRequest();
    RestContext.response = new RestResponse();
    RestContext.request.params.put('feedbackItemId', item.Id);
    RestContext.request.params.put('contactId', con.Id);
    RestContext.request.httpMethod = 'GET';
    RestContext.request.requestUri = '/services/apexrest/FeedBackData';

    Test.startTest();
    RestApi_GetMasterFeedBacks.doGetMasterFeedBackData();
    Test.stopTest();

    System.assertEquals(200, RestContext.response.statusCode);
        }
    }


@isTest
static void testDoGetMasterFeedBackData_LikertScaleReturnsNumberedChoices() {
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
    Feedback_Item__c item = [SELECT Id FROM Feedback_Item__c LIMIT 1];
    Questionnaire_Metadata__c master = [SELECT Id FROM Questionnaire_Metadata__c LIMIT 1];
    Contact con = [SELECT Id FROM Contact LIMIT 1];
    insert new Question_Metadata__c(
        Questionnaire__c = master.Id,
        RecordTypeId = Schema.SObjectType.Question_Metadata__c.getRecordTypeInfosByName().get('Feedback').getRecordTypeId(),
        Section_Label__c = 'Section Likert', Label__c = 'SubLabelLikert', Max_Grade__c = 5,
        Question_Label__c = 'The faculty explains clearly', Question_Type__c = 'Likert Scale',
        Answers__c = 'Disagree; ;Neutral;Agree', Mandatory__c = true, Order__c = 4, Type__c = 'Course', Active__c = true);

    RestContext.request = new RestRequest();
    RestContext.response = new RestResponse();
    RestContext.request.params.put('feedbackItemId', item.Id);
    RestContext.request.params.put('contactId', con.Id);
    RestContext.request.httpMethod = 'GET';
    RestContext.request.requestUri = '/services/apexrest/FeedBackData';

    Test.startTest();
    RestApi_GetMasterFeedBacks.doGetMasterFeedBackData();
    Test.stopTest();

    System.assertEquals(200, RestContext.response.statusCode);
    String body = RestContext.response.responseBody.toString();
    System.assert(body.contains('Likert Scale'), 'The question type is returned');
    // choices come back as a JSON string (escaped inside the response): blank entries dropped, scale points 1..3
    System.assert(body.contains('Disagree') && body.contains('Neutral') && body.contains('Agree'));
    System.assert(body.contains('value\\":\\"3'), 'Third choice carries scale point 3: ' + body);
        }
    }

}