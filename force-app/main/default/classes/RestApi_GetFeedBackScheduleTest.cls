@isTest
public class RestApi_GetFeedBackScheduleTest {
    // Test Setup Method
    @testSetup
    static void setupTestData() {
        Blackboard_Integration__c bbSettings = new Blackboard_Integration__c(
            SetupOwnerId = UserInfo.getOrganizationId(), // Organization level
            Username__c = 'testUser',
            Password__c = 'testPass'
        );
        insert bbSettings;
         Test.setMock(HttpCalloutMock.class, new MockCallout());
        // Create a Term record
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
        // Create a Facility
        hed__Facility__c testFacility = new hed__Facility__c(
            Name = 'Test Facility',
            hed__Capacity__c = 100
        );
        insert testFacility;
        
        // Create Program Plan
        hed__Program_Plan__c testProgramPlan = new hed__Program_Plan__c(
            Name = 'Test Program Plan',
            Batch__c = 'Test Batch'
        );
        insert testProgramPlan;
        
        // Create Term
        hed__Term__c Term = new hed__Term__c(
            Name = 'Test Term',
            Program_Plan__c = testProgramPlan.Id,
            hed__Account__c = testAccount.Id,
            Term_Reference__c = 'Term 1'
        );
        insert Term;

        // Create a Contact (Student)
        Contact studentContact = new Contact(
            LastName = 'Test Student',
            RecordTypeId = [SELECT Id FROM RecordType WHERE SObjectType = 'Contact' AND Name = 'Student'].Id
        );
        insert studentContact;

        // Create a Contact (Faculty)
        Contact facultyContact = new Contact(
            LastName = 'Test Faculty',
            RecordTypeId = [SELECT Id FROM RecordType WHERE SObjectType = 'Contact' AND Name = 'Faculty'].Id
        );
        insert facultyContact;

		 hed__Course__c testCourse = new hed__Course__c(
            Name = 'Test Course',
            hed__Account__c = testAccount.Id
        );
        insert testCourse;

        // Create a Course Offering
        hed__Course_Offering__c courseOffering = new hed__Course_Offering__c(
            hed__Course__c = testCourse.id,
            hed__Term__c = term.Id
        );
        insert courseOffering;

        // Create a Course Enrollment (Faculty)
        hed__Course_Enrollment__c courseEnrollment = new hed__Course_Enrollment__c(
            hed__Contact__c = facultyContact.Id,
            hed__Course_Offering__c = courseOffering.Id,
            hed__Status__c = 'Current'
        );
        insert courseEnrollment;
		 Questionnaire_Metadata__c qSection = new Questionnaire_Metadata__c(
            RecordTypeId = FeedbackTestRecordTypes.questionnaire(),
            Section_Label__c = 'Technical',
            Questionnaire_Weightage__c = 20,
            Program__c = testAccount.ID,
            Order__c = 1,
            Round_Number__c = 1
        );
        insert qSection;

        // Create Feedback Scheduler records
        Feedback_Scheduler__c feedbackSchedulerInterim = new Feedback_Scheduler__c(
            Term__c = term.Id,
            Feedback_Master__c =qSection.id,
            Start_Date__c = System.today(),
            End_Date__c = System.today().addDays(7)
        );
        insert feedbackSchedulerInterim;

        Feedback_Scheduler__c feedbackSchedulerFinal = new Feedback_Scheduler__c(
            Term__c = term.Id,
            Feedback_Master__c = qSection.id,
            Start_Date__c = System.today(),
            End_Date__c = System.today().addDays(7)
        );
        insert feedbackSchedulerFinal;

        // Create Collected Feedback Data records
        Collected_Feedback_Data__c collectedFeedbackInterim = new Collected_Feedback_Data__c(
            Term__c = term.Id,
            Contact__c = studentContact.Id,
            Feedback_Master__c = qSection.id
          //  Course__c = courseOffering.Id
        );
        insert collectedFeedbackInterim;

        Collected_Feedback_Data__c collectedFeedbackFinal = new Collected_Feedback_Data__c(
            Term__c = term.Id,
            Contact__c = studentContact.Id,
            Feedback_Master__c = qSection.id
        //    Course__c = courseOffering.Id
        );
        insert collectedFeedbackFinal;
    }

    // Test Method for GET Request with Valid Parameters
    @isTest
    static void testDoGetFeedBackScheduleData_ValidParams() {
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
        // Retrieve test data
        hed__Term__c term = [SELECT Id FROM hed__Term__c LIMIT 1];
        Contact studentContact = [SELECT Id FROM Contact WHERE RecordType.Name = 'Student' LIMIT 1];

        // Set up REST context
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/FeedBackScheduleData/';
        req.httpMethod = 'GET';
        req.addParameter('termId', term.Id);
        req.addParameter('contactId', studentContact.Id);
        RestContext.request = req;
        RestContext.response = new RestResponse();

        // Call the method
        RestApi_GetFeedBackSchedule.doGetFeedBackScheduleData();

        // Assert response
        RestResponse res = RestContext.response;
        System.assertEquals(200, res.statusCode, 'Expected status code 200');
        String responseBody = res.responseBody.toString();
        System.assertNotEquals(null, responseBody, 'Response body should not be null');
            }
    }

    // Test Method for GET Request with Missing Parameters
    @isTest
    static void testDoGetFeedBackScheduleData_MissingParams() {
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
        // Set up REST context
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/FeedBackScheduleData/';
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = new RestResponse();

        // Call the method
        RestApi_GetFeedBackSchedule.doGetFeedBackScheduleData();

        // Assert response
        RestResponse res = RestContext.response;
        System.assertEquals(200, res.statusCode, 'Expected status code 200');
        String responseBody = res.responseBody.toString();
        System.assert(responseBody.contains('"message": "No Data Found"'), 'Expected No Data Found message');
            }
    }

    // Test Method for Exception Handling
    @isTest
    static void testDoGetFeedBackScheduleData_ExceptionHandling() {
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
        // Set up REST context with invalid parameters
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/FeedBackScheduleData/';
        req.httpMethod = 'GET';
        req.addParameter('termId', 'InvalidTermId');
        req.addParameter('contactId', 'InvalidContactId');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        // Call the method
        RestApi_GetFeedBackSchedule.doGetFeedBackScheduleData();

        // Assert response
        RestResponse res = RestContext.response;
        System.assertEquals(400, res.statusCode, 'Expected status code 400');
        String responseBody = res.responseBody.toString();
        System.assert(responseBody.contains('"success": "false"'), 'Expected failure response');
        System.assert(responseBody.contains('"message": "bad request"'), 'Expected bad request message');
            }
    }
    
     public class MockCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"success": false}');
            res.setStatusCode(201);
            return res;
        }
    }
    @isTest
static void testDoGetFeedBackScheduleData_FacultyAndAllFeedbackTypes() {
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
    // Set up test data for comprehensive coverage
    hed__Term__c term = [SELECT Id FROM hed__Term__c LIMIT 1];
    Contact facultyContact = [SELECT Id FROM Contact WHERE RecordType.Name = 'Faculty' LIMIT 1];
    Contact studentContact = [SELECT Id FROM Contact WHERE RecordType.Name = 'Student' LIMIT 1];
    hed__Course_Offering__c courseOffering = [SELECT Id, hed__Course__c FROM hed__Course_Offering__c LIMIT 1];
    Questionnaire_Metadata__c qSection = [SELECT Id FROM Questionnaire_Metadata__c LIMIT 1];

    // Update qSection to have specific feedback types
    qSection.Section_Label__c = 'Faculty Feedback';
    update qSection;

    // Create additional Questionnaire_Metadata records for different feedback types
    Questionnaire_Metadata__c interimFeedback = new Questionnaire_Metadata__c(
            RecordTypeId = FeedbackTestRecordTypes.questionnaire(),
        Section_Label__c = 'Interim',
        Questionnaire_Weightage__c = 20,
        Program__c = [SELECT Id FROM Account LIMIT 1].Id,
        Order__c = 2,
        Round_Number__c = 1,
        Feedback_Type__c = 'Interim Feedback'
    );
    insert interimFeedback;

    Questionnaire_Metadata__c finalFeedback = new Questionnaire_Metadata__c(
            RecordTypeId = FeedbackTestRecordTypes.questionnaire(),
        Section_Label__c = 'Final',
        Questionnaire_Weightage__c = 20,
        Program__c = [SELECT Id FROM Account LIMIT 1].Id,
        Order__c = 3,
        Round_Number__c = 1,
        Feedback_Type__c = 'Final Feedback'
    );
    insert finalFeedback;

    Questionnaire_Metadata__c facultyFeedback = new Questionnaire_Metadata__c(
            RecordTypeId = FeedbackTestRecordTypes.questionnaire(),
        Section_Label__c = 'Faculty',
        Questionnaire_Weightage__c = 20,
        Program__c = [SELECT Id FROM Account LIMIT 1].Id,
        Order__c = 4,
        Round_Number__c = 1,
        Feedback_Type__c = 'Faculty Feedback'
    );
    insert facultyFeedback;

    // Create feedback schedulers for each type
    Feedback_Scheduler__c interimScheduler = new Feedback_Scheduler__c(
        Term__c = term.Id,
        Feedback_Master__c = interimFeedback.Id,
        Start_Date__c = System.today(),
        End_Date__c = System.today().addDays(7)
    );
    insert interimScheduler;

    Feedback_Scheduler__c finalScheduler = new Feedback_Scheduler__c(
        Term__c = term.Id,
        Feedback_Master__c = finalFeedback.Id,
        Start_Date__c = System.today(),
        End_Date__c = System.today().addDays(7)
    );
    insert finalScheduler;

    Feedback_Scheduler__c facultyScheduler = new Feedback_Scheduler__c(
        Term__c = term.Id,
        Feedback_Master__c = facultyFeedback.Id,
        Start_Date__c = System.today(),
        End_Date__c = System.today().addDays(7)
    );
    insert facultyScheduler;

    // Create collected feedback data with various relationships to hit different code paths
    // Interim feedback with course
    Collected_Feedback_Data__c courseInterimFeedback = new Collected_Feedback_Data__c(
        Term__c = term.Id,
        Contact__c = studentContact.Id,
        Feedback_Master__c = interimFeedback.Id
       // Course__c = courseOffering.hed__Course__c
    );
    insert courseInterimFeedback;

    // Final feedback with course
    Collected_Feedback_Data__c courseFinalFeedback = new Collected_Feedback_Data__c(
        Term__c = term.Id,
        Contact__c = studentContact.Id,
        Feedback_Master__c = finalFeedback.Id
     //   Course__c = courseOffering.hed__Course__c
    );
    insert courseFinalFeedback;

    // Interim feedback with faculty
    Collected_Feedback_Data__c facultyInterimFeedback = new Collected_Feedback_Data__c(
        Term__c = term.Id,
        Contact__c = studentContact.Id,
        Feedback_Master__c = interimFeedback.Id,
        Faculty__c = facultyContact.Id
    );
    insert facultyInterimFeedback;

    // Final feedback with faculty
    Collected_Feedback_Data__c facultyFinalFeedback = new Collected_Feedback_Data__c(
        Term__c = term.Id,
        Contact__c = studentContact.Id,
        Feedback_Master__c = finalFeedback.Id,
        Faculty__c = facultyContact.Id
    );
    insert facultyFinalFeedback;

    // Tech feedback with neither course nor faculty
    Collected_Feedback_Data__c techInterimFeedback = new Collected_Feedback_Data__c(
        Term__c = term.Id,
        Contact__c = studentContact.Id,
        Feedback_Master__c = interimFeedback.Id
    );
    insert techInterimFeedback;

    Collected_Feedback_Data__c techFinalFeedback = new Collected_Feedback_Data__c(
        Term__c = term.Id,
        Contact__c = studentContact.Id,
        Feedback_Master__c = finalFeedback.Id
    );
    insert techFinalFeedback;

    // Faculty feedback response
    Collected_Feedback_Data__c facultyFeedbackResponse = new Collected_Feedback_Data__c(
        Term__c = term.Id,
        Contact__c = facultyContact.Id,
        Feedback_Master__c = facultyFeedback.Id
    );
    insert facultyFeedbackResponse;

    // Test student view
    // Set up REST context
    RestRequest studentReq = new RestRequest();
    studentReq.requestURI = '/services/apexrest/FeedBackScheduleData/';
    studentReq.httpMethod = 'GET';
    studentReq.addParameter('termId', term.Id);
    studentReq.addParameter('contactId', studentContact.Id);
    RestContext.request = studentReq;
    RestContext.response = new RestResponse();

    // Call the method for student
    Test.startTest();
    RestApi_GetFeedBackSchedule.doGetFeedBackScheduleData();
    Test.stopTest();

    // Assert student response
    RestResponse studentRes = RestContext.response;
    System.assertEquals(200, studentRes.statusCode, 'Expected status code 200 for student');
    
    // Test faculty view
    RestRequest facultyReq = new RestRequest();
    facultyReq.requestURI = '/services/apexrest/FeedBackScheduleData/';
    facultyReq.httpMethod = 'GET';
    facultyReq.addParameter('termId', term.Id);
    facultyReq.addParameter('contactId', facultyContact.Id);
    RestContext.request = facultyReq;
    RestContext.response = new RestResponse();

    // Call the method for faculty
    RestApi_GetFeedBackSchedule.doGetFeedBackScheduleData();

    // Assert faculty response
    RestResponse facultyRes = RestContext.response;
    System.assertEquals(200, facultyRes.statusCode, 'Expected status code 200 for faculty');
        }
    }
}