@isTest
private class RestApi_CreateActivities_Test {

    @testSetup
    static void setupTestData() {

		Test.setMock(HttpCalloutMock.class, new SessionMockCallout());
         Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());
        Test.setMock(HttpCalloutMock.class, new FailureHttpMock());
        
        LMS_URL__c lmsUrl = new LMS_URL__c(Name = 'course url', Bulk_Enroll__c = 'https://dummyendpoint.com');
    insert lmsUrl;
        LMS_URL__c URL1 = new LMS_URL__c(Name = 'course offering url',Bulk_Enroll__c = 'TestUrl');
        insert URL1;
        LMS_URL__c URL2 = new LMS_URL__c(Name = 'Bulk Enrollment',Bulk_Enroll__c = 'TestUrl');
        insert URL2;
		Id accRec = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Academic_Program').getRecordTypeId();
        // Create test Accounts
        Account acc = new Account(Name = 'Test Faculty',LMS_Id__c = '12345',RecordTypeId =accRec);
        insert acc;

        // Create a test Course Version
        Course_Version__c courseVersion = new Course_Version__c(Start_Date__c = Date.valueOf('2023-10-10'));
        insert courseVersion;

        // Create a test Term
        hed__Term__c term = new hed__Term__c(Name = 'Test Term', 
            hed__Start_Date__c = Date.today(), 
            hed__End_Date__c = Date.today().addMonths(3),
            hed__Account__c = acc.id , 
            Term_Reference__c = 'Semester 1',
            RecordTypeId = Schema.SObjectType.hed__Term__c.getRecordTypeInfosByName().get('Default Record').getRecordTypeId()
		);
        insert term;

		hed__Course__c course = new hed__Course__c(
            Name = 'Test Course',
            hed__Account__c = acc.Id,
            hed__Credit_Hours__c = 3.0,
            LMS_Id__c = '54321'
        );
        insert course;

        hed__Course_Offering__c courseOffering = new hed__Course_Offering__c(
            Name = 'Section A',
            hed__Course__c = course.Id,
            hed__Term__c = term.Id,
            hed__Section_ID__c = 'SEC123'
        );
        insert courseOffering;

		hed__Facility__c facility = new hed__Facility__c(Name = 'Test Facility');
        insert facility;

        K42_Academic_Planner__c act = new K42_Academic_Planner__c(Name = 'Test Activity Planner',
             Term__c=term.Id,
             RecordTypeId = Schema.SObjectType.K42_Academic_Planner__c.getRecordTypeInfosByName().get('Default').getRecordTypeId()
		);
        insert act;
    }

    @isTest
    static void testCreateActivity_Success() {
        RestApi_CreateActivities.requestActivitiesWrapper reqWrapper = new RestApi_CreateActivities.requestActivitiesWrapper();
        reqWrapper.Operation = 'Create';
        reqWrapper.Activity = new RestApi_CreateActivities.requestActivityWrapper();
        reqWrapper.Activity.termId = [SELECT Id FROM hed__Term__c LIMIT 1].Id;
        reqWrapper.Activity.facultyIds = [SELECT PersonContactId FROM Account LIMIT 1].Id;
        reqWrapper.Activity.courseVersionId = [SELECT Id FROM Course_Version__c LIMIT 1].Id;
        reqWrapper.Activity.activityType = 'Teaching';
        reqWrapper.Activity.activityStartDate = '2023-10-15T12:30:00';
		reqWrapper.Activity.activityEndDate = '2023-10-20T12:30:00';
        reqWrapper.Activity.courseOfferingId = [SELECT Id FROM hed__Course_Offering__c LIMIT 1].Id;
        reqWrapper.Activity.numberOfSessions = 2.0;
        reqWrapper.Activity.numberOfhoursSessions = 2.0;
        reqWrapper.Activity.activityId = [SELECT Id FROM K42_Academic_Planner__c LIMIT 1].Id;
		reqWrapper.Activity.duration = 5;
        reqWrapper.Activity.facilityId = [SELECT Id FROM hed__Facility__c LIMIT 1].Id;

        RestApi_CreateActivities.responseActivitiesWrapper response = new RestApi_CreateActivities.responseActivitiesWrapper();
        response.activityId = 'TestId123';
        String retrievedActivityId = response.activityId;

        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/createActivities';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(reqWrapper));

        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        // Call the method
        Test.startTest();
        RestApi_CreateActivities.doCreateActivities();
        Test.stopTest();
    }

    @isTest
    static void testDeleteActivity_Success() {
        // Create a test Activity
        Activity__c activity = new Activity__c(Name = 'Test Activity');
        insert activity;

        // Prepare delete request
        RestApi_CreateActivities.requestActivitiesWrapper reqWrapper = new RestApi_CreateActivities.requestActivitiesWrapper();
        reqWrapper.Operation = 'Delete';
        reqWrapper.Activity = new RestApi_CreateActivities.requestActivityWrapper();
        reqWrapper.Activity.activityId = activity.Id;

        // Simulate REST API call
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/createActivities';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(reqWrapper));

        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        // Call the method
        Test.startTest();
        RestApi_CreateActivities.doCreateActivities();
        Test.stopTest();
    }

    @isTest
    static void testInvalidOperation() {
        // Prepare an invalid operation request
        RestApi_CreateActivities.requestActivitiesWrapper reqWrapper = new RestApi_CreateActivities.requestActivitiesWrapper();
        reqWrapper.Operation = 'InvalidOperation';

        // Simulate REST API call
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/createActivities';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(reqWrapper));

        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        // Call the method
        Test.startTest();
        RestApi_CreateActivities.doCreateActivities();
        Test.stopTest();
    }
	@isTest
    static void testCreateAcademicPlannerWhenEmpty() {
        // Fetch test data
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        hed__Term__c testTerm = new hed__Term__c(
            Name = 'Spring 2024',
            hed__Account__c = testAccount.Id,
            Term_Reference__c = 'Semester 1',
            hed__Start_Date__c = Date.today(),
            hed__End_Date__c = Date.today().addMonths(6),
            RecordTypeId = Schema.SObjectType.hed__Term__c.getRecordTypeInfosByName().get('Default Record').getRecordTypeId()
        );
        insert testTerm;
        
        Course_Version__c testCourseVersion = new Course_Version__c(
            Start_Date__c = Date.today()
        );
        insert testCourseVersion;
        
        // Ensure there is no existing K42_Academic_Planner__c record for this term
        List<K42_Academic_Planner__c> academicPlan = [
            SELECT Id 
            FROM K42_Academic_Planner__c 
            WHERE Term__c = :testTerm.Id AND RecordType.Name = 'Default'
        ];
        System.assertEquals(0, academicPlan.size(), 'There should be no existing academic planner for this term');

        // Prepare request body
        RestApi_CreateActivities.requestActivitiesWrapper requestBody = new RestApi_CreateActivities.requestActivitiesWrapper();
        requestBody.Operation = 'Create';
        RestApi_CreateActivities.requestActivityWrapper activity = new RestApi_CreateActivities.requestActivityWrapper();
        activity.termId = testTerm.Id;
        activity.courseVersionId = testCourseVersion.Id;
        activity.activityType = 'Lecture';
        activity.duration = 5;
        activity.numberOfhoursSessions = 2.5;
        activity.facultyIds = testAccount.Id;
        activity.courseOfferingId = testCourseVersion.Id;
        activity.numberOfSessions = 10;
        requestBody.Activity = activity;

        // Set up REST context
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/createActivities';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(requestBody));
        RestContext.request = req;
        RestContext.response = res;

        // Call the method
        Test.startTest();
        RestApi_CreateActivities.doCreateActivities();
        Test.stopTest();
    }
    
       public class SuccessHttpMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(' {"success": "true","data": {"Identifier": "98765","Code": "Ken BBA-01","Name": "Ken - BBA Template","Path": "/content/enforced/6887-KenBBA-01"}}');
            res.setStatusCode(200);
            return res;
        }
    }
    
    public class FailureHttpMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"error": "Internal Server Error"}');
            res.setStatusCode(500);
            return res;
        }
    }
}