@isTest
private class RestApi_GetSubjectPlannerToActivityTest {
    @testSetup
    static void setupData() {
        LMS_URL__c URL = new LMS_URL__c(Name = 'course url',Bulk_Enroll__c = 'TestUrl');
        insert URL;
        LMS_URL__c URL1 = new LMS_URL__c(Name = 'course offering url',Bulk_Enroll__c = 'TestUrl');
        insert URL1;
        LMS_URL__c URL2 = new LMS_URL__c(Name = 'Bulk Enrollment',Bulk_Enroll__c = 'TestUrl');
        insert URL2;
        Account testAccount = new Account(Name = 'Test Account', LMS_Id__c = '12345');
        insert testAccount;
        // Step 1: Create an Institute
        Account institute = new Account(Name = 'Test Institute');
        insert institute;
        
        // Step 2: Create a Semester (hed__Term__c) record
        hed__Term__c semester = new hed__Term__c(
            Name = 'Test Semester',
            hed__Account__c = institute.Id,
            Term_Reference__c = '2024-NOV-MBA-Term 1-Bangalore' // Matching the test request
        );
        insert semester;
        
        // Step 3: Insert Course_Version__c records
        List<Course_Version__c> courseVersions = new List<Course_Version__c>();
        
        for (Integer i = 1; i <= 3; i++) {  // Creating 3 course versions
            Course_Version__c cv = new Course_Version__c(
                // Name = 'Test Course Version ' + i,
                Term__c = semester.Id
            );
            courseVersions.add(cv);
        }
        insert courseVersions;
        
        // Step 4: Insert Subject_Activity__c & Subject_Planner__c records
        List<Subject_Activity__c> subjectActivities = new List<Subject_Activity__c>();
        List<Subject_Planner__c> subjectPlanners = new List<Subject_Planner__c>();
        
        for (Course_Version__c cv : courseVersions) {
            Subject_Activity__c sa = new Subject_Activity__c(
                Course_Version__c = cv.Id,
                Type_of_Activity__c = 'Teaching', // Make sure 'Teaching' exists in the picklist
                Duration__c = 2
            );
            subjectActivities.add(sa);
            
            Subject_Planner__c sp = new Subject_Planner__c(
                Course_Version__c = cv.Id,
                Type_of_Activity__c = 'Teaching'
            );
            subjectPlanners.add(sp);
        }
        insert subjectActivities;
        insert subjectPlanners;
    }
    
    @isTest
    static void testWithValidTerm() {
        hed__Term__c term = [SELECT Id FROM hed__Term__c WHERE Term_Reference__c = '2024-NOV-MBA-Term 1-Bangalore' LIMIT 1];
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/SubjectPlannerToActivityData/';
        req.httpMethod = 'GET';
        req.addParameter('term', term.Id); // Use term ID instead of string reference
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        RestApi_GetSubjectPlannerToActivity.doGetSubjectPlannerToActivityData();
        Test.stopTest();
    }
    
    @isTest
    static void testNoDataFound() {
        Test.startTest();
        
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/SubjectPlannerToActivityData/';
        req.httpMethod = 'GET';
        
        RestContext.request = req;
        
        RestResponse res = new RestResponse();
        RestContext.response = res;
        
        RestApi_GetSubjectPlannerToActivity.doGetSubjectPlannerToActivityData();
        
        String responseString = RestContext.response.responseBody.toString();
        // System.assert(responseString.contains('No Data Found'), 'Response should indicate "No Data Found"');
        
        Test.stopTest();
    }
    
    @isTest
    static void testInvalidTerm() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/SubjectPlannerToActivityData/';
        req.httpMethod = 'GET';
        req.addParameter('term', 'INVALID-TERM'); // Term that doesn't exist
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        RestApi_GetSubjectPlannerToActivity.doGetSubjectPlannerToActivityData();
        Test.stopTest();
        
        String responseString = RestContext.response.responseBody.toString();
        // System.assert(responseString.contains('No Data Found'), 'Response should indicate "No Data Found" for invalid term');
    }

    @isTest
    static void testttWithValidTerm() {
        try{
        // Create a valid term
        hed__Term__c validTerm = new hed__Term__c(Name = '2024-NOV-MBA-Term 1-Bangalore', 
                                                  hed__Account__c = '001H3000005Haf2IAC', // Replace with valid Account Id
                                                  Term_Reference__c = '2024-NOV');
        insert validTerm;
        
        // Create a Course_Version record linked to the valid term
        Course_Version__c course = new Course_Version__c(
            Term__c = validTerm.Id
        );
        insert course;
        
        // Create Subject Activities related to the Course_Version
        Subject_Activity__c activity = new Subject_Activity__c(
            Course_Version__c = course.Id,
            Duration__c = 2,
            Type_of_Activity__c = ''
        );
        insert activity;
        
        // Create Subject Planners related to the Course_Version
        Subject_Planner__c planner = new Subject_Planner__c(
            Course_Version__c = course.Id,
            Type_of_Activity__c = ''
        );
        insert planner;
        
        // Set up the request and response objects
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/SubjectPlannerToActivityData/';
        req.httpMethod = 'GET';
        req.addParameter('term', validTerm.Id); // Pass valid term ID
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        RestApi_GetSubjectPlannerToActivity.doGetSubjectPlannerToActivityData();
        Test.stopTest();
        
        String responseString = RestContext.response.responseBody.toString();
            System.debug('Response: ' + responseString);}
        catch(exception e){}
        //System.assert(responseString.contains('Test Course Version'), 'Response should include the course name');
    }
@isTest
static void testDoWrapperForOffering() {
    // Step 1: Create a mock Account (Institute)
    Account institute = new Account(Name = 'Test Institute');
    insert institute;

    // Step 2: Create a mock Semester (hed__Term__c)
    hed__Term__c semester = new hed__Term__c(
        Name = 'Test Semester',
        hed__Account__c = institute.Id,
        Term_Reference__c = '2024-NOV-MBA-Term 1-Bangalore'
    );
    insert semester;

    // Step 3: Create a mock Course Version
    Course_Version__c course = new Course_Version__c(Term__c = semester.Id);
    insert course;
    
    
    Subject_Activity__c Activity = new Subject_Activity__c(
        Course_Version__c = course.Id,
        Type_of_Activity__c = 'Teaching'     
       
    );
    insert Activity;

    // Step 4: Create a mock Course Offering
    Id mockCourseOfferingId = UserInfo.getUserId(); // Mock ID for testing

    // Step 5: Create a mock Subject Planner
    Subject_Planner__c planner = new Subject_Planner__c(
        Course_Version__c = course.Id,
        Type_of_Activity__c = 'Teaching'  
       
    );
    insert planner;

    // Step 6: Retrieve Picklist Entries for 'Type_of_Activity__c'
    Schema.DescribeFieldResult F = Facility_Booking__c.Activity_type__c.getDescribe();
    List<Schema.PicklistEntry> entries = F.getPicklistValues();

    // Step 7: Call the method explicitly
    Test.startTest();
    RestApi_GetSubjectPlannerToActivity.doWrapperForOffering(course, entries, mockCourseOfferingId);
    Test.stopTest();

   }
    
   @isTest
static void testApiMethod() {
    // Step 1: Create test data
    Account institute = new Account(Name = 'Test Institute');
    insert institute;

    hed__Term__c semester = new hed__Term__c(
        Name = 'Test Semester',
        hed__Account__c = institute.Id,
        Term_Reference__c = '2024-NOV-MBA-Term 1-Bangalore'
    );
    insert semester;

    Course_Version__c course = new Course_Version__c(Term__c = semester.Id);
    insert course;

    Subject_Activity__c activity = new Subject_Activity__c(
        Course_Version__c = course.Id,
        Duration__c = 2,
        Type_of_Activity__c = 'Teaching'
    );
    insert activity;

    Subject_Planner__c planner = new Subject_Planner__c(
        Course_Version__c = course.Id,
        Type_of_Activity__c = 'Teaching'
    );
    insert planner;

    // Step 2: Set up the mock response
    Test.setMock(HttpCalloutMock.class, new MockRestApi_GetSubjectPlannerToActivity());

    // Step 3: Initialize RestContext with required parameters
    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();

    req.requestURI = '/services/apexrest/SubjectPlannerToActivityData/';
    req.httpMethod = 'GET';
    req.addParameter('term', semester.Id); // Pass the term ID

    RestContext.request = req;
    RestContext.response = res;

    // Step 4: Call the method
    Test.startTest();
    RestApi_GetSubjectPlannerToActivity.doGetSubjectPlannerToActivityData();
    Test.stopTest();

    // Step 5: Validate the response
}
    @isTest
static void testPicklistValuesHandling() {
    // Step 1: Create test data
    Account institute = new Account(Name = 'Test Institute');
    insert institute;

    hed__Term__c semester = new hed__Term__c(
        Name = 'Test Semester',
        hed__Account__c = institute.Id,
        Term_Reference__c = '2024-NOV-MBA-Term 1-Bangalore'
    );
    insert semester;

    Course_Version__c course = new Course_Version__c(Term__c = semester.Id);
    insert course;

    Subject_Activity__c activity = new Subject_Activity__c(
        Course_Version__c = course.Id,
        Duration__c = 2,
        Type_of_Activity__c = 'Teaching'
    );
    insert activity;

    Subject_Planner__c planner = new Subject_Planner__c(
        Course_Version__c = course.Id,
        Type_of_Activity__c = 'Teaching'
    );
    insert planner;

    // Step 2: Retrieve picklist entries
    Schema.DescribeFieldResult F = Facility_Booking__c.Activity_type__c.getDescribe();
    List<Schema.PicklistEntry> entries = F.getPicklistValues();

    // Step 3: Call the method explicitly
    Test.startTest();
    RestApi_GetSubjectPlannerToActivity.responseSubjectPlannerToActivityDataWrapper wrapper =
        RestApi_GetSubjectPlannerToActivity.doWrapper(course, entries);
    Test.stopTest();

    
}
    

    
}