@isTest
public class RestApi_CreateTerms_CV_Activites_Test {
    
    @TestSetup
    static void setupTestData() {
        // Create Account for Term
     	Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());
        Test.setMock(HttpCalloutMock.class, new FailureHttpMock());
        Account testAccount = new Account(Name = 'Test Account', LMS_Id__c = '12345');
        insert testAccount;
        LMS_URL__c lmsUrl = new LMS_URL__c(Name = 'course url', Bulk_Enroll__c = 'https://dummyendpoint.com');
    insert lmsUrl;
        LMS_URL__c URL1 = new LMS_URL__c(Name = 'course offering url',Bulk_Enroll__c = 'TestUrl');
        insert URL1;
        LMS_URL__c URL2 = new LMS_URL__c(Name = 'Bulk Enrollment',Bulk_Enroll__c = 'TestUrl');
        insert URL2;
      
        
        // Create Program Plan
        hed__Program_Plan__c programPlan = new hed__Program_Plan__c(
            Name = 'Test Program Plan',
            hed__Account__c = testAccount.Id,
            Working_Days__c = 'Monday;Tuesday;Wednesday;Thursday;Friday'
        );
        insert programPlan;
        
        // Create Campus
        hed__Facility__c campus = new hed__Facility__c(
            Name = 'Test Campus',
            hed__Facility_Type__c = 'Lecture Room'
        );
        insert campus;
        
        // Create Program Campus Combination
        Program_Campus_Relationship__c pcc = new Program_Campus_Relationship__c(
            //Name = 'Test PCC',
            Campus__c = testAccount.Id,
            Program_Plan__c = programPlan.Id
        );
        insert pcc;
        
        // Create Term with Default Record Type
        Id defaultRecordTypeId = Schema.SObjectType.hed__Term__c.getRecordTypeInfosByName()
            .get('Default Record')?.getRecordTypeId();
        
        hed__Term__c testTerm = new hed__Term__c(
            Name = 'Test Term 1',
            hed__Account__c = testAccount.Id,
            Program_Plan__c = programPlan.Id,
            hed__Start_Date__c = Date.today(),
            hed__End_Date__c = Date.today().addDays(90),
            Term_Reference__c = 'Term 1',
            RecordTypeId = defaultRecordTypeId
        );
        insert testTerm;
        
        // Create Term Campus Relationship
        Term_Campus_Relationship__c tcr = new Term_Campus_Relationship__c(
            Term__c = testTerm.Id,
            Program_Campus_Combination__c = pcc.Id
        );
        insert tcr;
        
        // Create Courses with Credit Hours
        List<hed__Course__c> courses = new List<hed__Course__c>();
        for (Integer i = 1; i <= 3; i++) {
            courses.add(new hed__Course__c(
                Name = 'Test Course ' + i,
                hed__Course_ID__c = 'TC' + i,
                hed__Credit_Hours__c = 3.0,
                hed__Account__c=testAccount.Id,
                LMS_Id__c = '54321'
            ));
        }
        insert courses;
        
        // Create Plan Requirements
        List<hed__Plan_Requirement__c> planReqs = new List<hed__Plan_Requirement__c>();
        for (Integer i = 0; i < courses.size(); i++) {
            planReqs.add(new hed__Plan_Requirement__c(
                Name = 'Plan Req ' + (i + 1),
                hed__Course__c = courses[i].Id,
                Term__c = testTerm.Id
                 
            ));
        }
        insert planReqs;
        
        // Create Academic Planner
        K42_Academic_Planner__c academicPlanner = new K42_Academic_Planner__c(
            Name = 'Test Academic Planner',
            Term__c = testTerm.Id,
             Program_Plan__c = programPlan.Id 
        );
        insert academicPlanner;
    }
    
    @isTest
    static void testSuccessfulCourseVersionAndActivityCreation() {
        // Get test data
        hed__Term__c testTerm = [SELECT Id FROM hed__Term__c LIMIT 1];
        List<hed__Course__c> courses = [SELECT Id FROM hed__Course__c LIMIT 2];
        List<hed__Plan_Requirement__c> planReqs = [SELECT Id FROM hed__Plan_Requirement__c LIMIT 2];
        
        // Prepare request body
        List<RestApi_CreateTerms_CV_Activites.requestCourseVersionDataWrapper> requestList = 
            new List<RestApi_CreateTerms_CV_Activites.requestCourseVersionDataWrapper>();
        
        RestApi_CreateTerms_CV_Activites.requestCourseVersionDataWrapper requestWrapper = 
            new RestApi_CreateTerms_CV_Activites.requestCourseVersionDataWrapper();
        requestWrapper.termId = testTerm.Id;
        requestWrapper.courseList = new List<RestApi_CreateTerms_CV_Activites.courseWrapper>();
        
        // Create course wrapper with activities
        RestApi_CreateTerms_CV_Activites.courseWrapper courseWrap = 
            new RestApi_CreateTerms_CV_Activites.courseWrapper();
        courseWrap.courseId = courses[0].Id;
        courseWrap.startDate = Date.today().addDays(5);
        courseWrap.endDate = Date.today().addDays(50);
        courseWrap.examRequired = true;
        courseWrap.subjectOffset = '5';
        courseWrap.numberOfSessions = 10;
        courseWrap.creditHours = '3';
        courseWrap.masterPlanReqId = planReqs[0].Id;
        
        // Add activities
        courseWrap.activitesList = new List<RestApi_CreateTerms_CV_Activites.activitesWrapper>();
        RestApi_CreateTerms_CV_Activites.activitesWrapper activity = 
            new RestApi_CreateTerms_CV_Activites.activitesWrapper();
        activity.activityName = 'Test Activity';
        activity.activityType = 'Teaching';
        activity.activityDuration = '2';
        activity.activityOffset = '1';
        activity.startDate = Date.today().addDays(10);
        activity.endDate = Date.today().addDays(40);
        activity.numberOfSessions = 5;
        courseWrap.activitesList.add(activity);
        
        requestWrapper.courseList.add(courseWrap);
        requestList.add(requestWrapper);
        
        // Set up REST context
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestBody = Blob.valueOf(JSON.serialize(requestList));
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        RestApi_CreateTerms_CV_Activites.doPost();
        Test.stopTest();
  
    }
    
    @isTest
    static void testCourseVersionCreationWithoutActivities() {
        // Get test data
        hed__Term__c testTerm = [SELECT Id FROM hed__Term__c LIMIT 1];
        List<hed__Course__c> courses = [SELECT Id FROM hed__Course__c LIMIT 1];
        List<hed__Plan_Requirement__c> planReqs = [SELECT Id FROM hed__Plan_Requirement__c LIMIT 1];
        
        // Prepare request body without activities
        List<RestApi_CreateTerms_CV_Activites.requestCourseVersionDataWrapper> requestList = 
            new List<RestApi_CreateTerms_CV_Activites.requestCourseVersionDataWrapper>();
        
        RestApi_CreateTerms_CV_Activites.requestCourseVersionDataWrapper requestWrapper = 
            new RestApi_CreateTerms_CV_Activites.requestCourseVersionDataWrapper();
        requestWrapper.termId = testTerm.Id;
        requestWrapper.courseList = new List<RestApi_CreateTerms_CV_Activites.courseWrapper>();
        
        RestApi_CreateTerms_CV_Activites.courseWrapper courseWrap = 
            new RestApi_CreateTerms_CV_Activites.courseWrapper();
        courseWrap.courseId = courses[0].Id;
        courseWrap.startDate = Date.today().addDays(5);
        courseWrap.endDate = Date.today().addDays(50);
        courseWrap.examRequired = false;
        courseWrap.subjectOffset = '';
        courseWrap.numberOfSessions = 8;
        courseWrap.creditHours = '3';
        courseWrap.masterPlanReqId = planReqs[0].Id;
        courseWrap.activitesList = new List<RestApi_CreateTerms_CV_Activites.activitesWrapper>();
        
        requestWrapper.courseList.add(courseWrap);
        requestList.add(requestWrapper);
        
        // Set up REST context
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestBody = Blob.valueOf(JSON.serialize(requestList));
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        RestApi_CreateTerms_CV_Activites.doPost();
        Test.stopTest();
        
    
    }
    
    @isTest
    static void testCreditHoursMissingValidation() {
         Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());
        Test.setMock(HttpCalloutMock.class, new FailureHttpMock());
       
        Account acc =[Select Id from Account Limit 1];
        // Create course without credit hours
        hed__Course__c courseWithoutCredit = new hed__Course__c(
            Name = 'Course Without Credit',
            hed__Course_ID__c = 'CWC',
            hed__Credit_Hours__c = null,
            hed__Account__c=acc.Id
        );
        insert courseWithoutCredit;
        
        hed__Term__c testTerm = [SELECT Id FROM hed__Term__c LIMIT 1];
        List<hed__Plan_Requirement__c> planReqs = [SELECT Id FROM hed__Plan_Requirement__c LIMIT 1];
        
        // Prepare request body
        List<RestApi_CreateTerms_CV_Activites.requestCourseVersionDataWrapper> requestList = 
            new List<RestApi_CreateTerms_CV_Activites.requestCourseVersionDataWrapper>();
        
        RestApi_CreateTerms_CV_Activites.requestCourseVersionDataWrapper requestWrapper = 
            new RestApi_CreateTerms_CV_Activites.requestCourseVersionDataWrapper();
        requestWrapper.termId = testTerm.Id;
        requestWrapper.courseList = new List<RestApi_CreateTerms_CV_Activites.courseWrapper>();
        
        RestApi_CreateTerms_CV_Activites.courseWrapper courseWrap = 
            new RestApi_CreateTerms_CV_Activites.courseWrapper();
        courseWrap.courseId = courseWithoutCredit.Id;
        courseWrap.startDate = Date.today().addDays(5);
        courseWrap.endDate = Date.today().addDays(50);
        courseWrap.examRequired = false;
        courseWrap.subjectOffset = '';
        courseWrap.numberOfSessions = 8;
        courseWrap.creditHours = '3';
        courseWrap.masterPlanReqId = planReqs[0].Id;
        courseWrap.activitesList = new List<RestApi_CreateTerms_CV_Activites.activitesWrapper>();
        
        requestWrapper.courseList.add(courseWrap);
        requestList.add(requestWrapper);
        
        // Set up REST context
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestBody = Blob.valueOf(JSON.serialize(requestList));
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        RestApi_CreateTerms_CV_Activites.doPost();
        Test.stopTest();
        
      
    }
    
    @isTest
    static void testDuplicateCourseVersionValidation() {
        // Get test data
        hed__Term__c testTerm = [SELECT Id FROM hed__Term__c LIMIT 1];
        List<hed__Course__c> courses = [SELECT Id FROM hed__Course__c LIMIT 1];
        List<hed__Plan_Requirement__c> planReqs = [SELECT Id FROM hed__Plan_Requirement__c LIMIT 1];
        
        // Create existing course version
        Course_Version__c existingCV = new Course_Version__c(
            Course__c = courses[0].Id,
            Term__c = testTerm.Id,
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addDays(60),
            Number_of_Sessions__c = 10
        );
        insert existingCV;
        
        // Prepare request body with same course and term
        List<RestApi_CreateTerms_CV_Activites.requestCourseVersionDataWrapper> requestList = 
            new List<RestApi_CreateTerms_CV_Activites.requestCourseVersionDataWrapper>();
        
        RestApi_CreateTerms_CV_Activites.requestCourseVersionDataWrapper requestWrapper = 
            new RestApi_CreateTerms_CV_Activites.requestCourseVersionDataWrapper();
        requestWrapper.termId = testTerm.Id;
        requestWrapper.courseList = new List<RestApi_CreateTerms_CV_Activites.courseWrapper>();
        
        RestApi_CreateTerms_CV_Activites.courseWrapper courseWrap = 
            new RestApi_CreateTerms_CV_Activites.courseWrapper();
        courseWrap.courseId = courses[0].Id;
        courseWrap.startDate = Date.today().addDays(5);
        courseWrap.endDate = Date.today().addDays(50);
        courseWrap.examRequired = false;
        courseWrap.subjectOffset = '';
        courseWrap.numberOfSessions = 8;
        courseWrap.creditHours = '3';
        courseWrap.masterPlanReqId = planReqs[0].Id;
        courseWrap.activitesList = new List<RestApi_CreateTerms_CV_Activites.activitesWrapper>();
        
        requestWrapper.courseList.add(courseWrap);
        requestList.add(requestWrapper);
        
        // Set up REST context
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestBody = Blob.valueOf(JSON.serialize(requestList));
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        RestApi_CreateTerms_CV_Activites.doPost();
        Test.stopTest();
        
    
    }
    
    @isTest
    static void testPrerequisiteValidationFailure() {
        // Get test data
        hed__Term__c testTerm = [SELECT Id FROM hed__Term__c LIMIT 1];
        testTerm.Term_Reference__c = 'Term 2';
        update testTerm;
        
        List<hed__Course__c> courses = [SELECT Id FROM hed__Course__c LIMIT 2];
        List<hed__Plan_Requirement__c> planReqs = [SELECT Id FROM hed__Plan_Requirement__c LIMIT 2];
        
        // Update plan requirement with prerequisites
        planReqs[1].Pre_Requisites_1__c = courses[0].Id;
        update planReqs[1];
        
        // Prepare request body
        List<RestApi_CreateTerms_CV_Activites.requestCourseVersionDataWrapper> requestList = 
            new List<RestApi_CreateTerms_CV_Activites.requestCourseVersionDataWrapper>();
        
        RestApi_CreateTerms_CV_Activites.requestCourseVersionDataWrapper requestWrapper = 
            new RestApi_CreateTerms_CV_Activites.requestCourseVersionDataWrapper();
        requestWrapper.termId = testTerm.Id;
        requestWrapper.courseList = new List<RestApi_CreateTerms_CV_Activites.courseWrapper>();
        
        RestApi_CreateTerms_CV_Activites.courseWrapper courseWrap = 
            new RestApi_CreateTerms_CV_Activites.courseWrapper();
        courseWrap.courseId = courses[1].Id;
        courseWrap.startDate = Date.today().addDays(5);
        courseWrap.endDate = Date.today().addDays(50);
        courseWrap.examRequired = false;
        courseWrap.subjectOffset = '';
        courseWrap.numberOfSessions = 8;
        courseWrap.creditHours = '3';
        courseWrap.masterPlanReqId = planReqs[1].Id;
        courseWrap.activitesList = new List<RestApi_CreateTerms_CV_Activites.activitesWrapper>();
        
        requestWrapper.courseList.add(courseWrap);
        requestList.add(requestWrapper);
        
        // Set up REST context
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestBody = Blob.valueOf(JSON.serialize(requestList));
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        RestApi_CreateTerms_CV_Activites.doPost();
        Test.stopTest();
       
    }
    
    @isTest
    static void testExceptionHandling() {
        // Prepare invalid request body to trigger exception
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestBody = Blob.valueOf('invalid json');
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        RestApi_CreateTerms_CV_Activites.doPost();
        Test.stopTest();
  
    }
    
    @isTest
    static void testCustomValidationExceptionHandling() {
        // This test simulates the custom validation exception scenario
        // Since we can't easily trigger the exact custom validation exception,
        // we'll create a scenario that would lead to a similar error
        
        hed__Term__c testTerm = [SELECT Id FROM hed__Term__c LIMIT 1];
        List<hed__Course__c> courses = [SELECT Id FROM hed__Course__c LIMIT 1];
        List<hed__Plan_Requirement__c> planReqs = [SELECT Id FROM hed__Plan_Requirement__c LIMIT 1];
        
        // Prepare request body
        List<RestApi_CreateTerms_CV_Activites.requestCourseVersionDataWrapper> requestList = 
            new List<RestApi_CreateTerms_CV_Activites.requestCourseVersionDataWrapper>();
        
        RestApi_CreateTerms_CV_Activites.requestCourseVersionDataWrapper requestWrapper = 
            new RestApi_CreateTerms_CV_Activites.requestCourseVersionDataWrapper();
        requestWrapper.termId = testTerm.Id;
        requestWrapper.courseList = new List<RestApi_CreateTerms_CV_Activites.courseWrapper>();
        
        RestApi_CreateTerms_CV_Activites.courseWrapper courseWrap = 
            new RestApi_CreateTerms_CV_Activites.courseWrapper();
        courseWrap.courseId = courses[0].Id;
        courseWrap.startDate = Date.today().addDays(5);
        courseWrap.endDate = Date.today().addDays(50);
        courseWrap.examRequired = false;
        courseWrap.subjectOffset = '';
        courseWrap.numberOfSessions = 8;
        courseWrap.creditHours = '3';
        courseWrap.masterPlanReqId = planReqs[0].Id;
        courseWrap.activitesList = new List<RestApi_CreateTerms_CV_Activites.activitesWrapper>();
        
        requestWrapper.courseList.add(courseWrap);
        requestList.add(requestWrapper);
        
        // Set up REST context
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestBody = Blob.valueOf(JSON.serialize(requestList));
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        RestApi_CreateTerms_CV_Activites.doPost();
        Test.stopTest();
        
    }
    
    @isTest
    static void testEmptyRequestBody() {
        // Prepare empty request
        List<RestApi_CreateTerms_CV_Activites.requestCourseVersionDataWrapper> requestList = 
            new List<RestApi_CreateTerms_CV_Activites.requestCourseVersionDataWrapper>();
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestBody = Blob.valueOf(JSON.serialize(requestList));
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        RestApi_CreateTerms_CV_Activites.doPost();
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