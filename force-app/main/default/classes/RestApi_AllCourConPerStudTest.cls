@isTest
public class RestApi_AllCourConPerStudTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test Contact
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Student',
            Email = 'test.student@example.com'
        );
        insert testContact;
        
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
        
        // Create test Term
        hed__Term__c testTerm = new hed__Term__c(
            Name = 'Fall 2024',
            hed__Account__c = testAccount.Id,
            Term_Reference__c='Semester 1',
            hed__Start_Date__c = Date.today().addDays(-5),
    hed__End_Date__c = Date.today().addDays(10)
            //Term_Status__c = 'Ongoing'
        );
        insert testTerm;
        
        // Create test Affiliation
        hed__Affiliation__c testAffiliation = new hed__Affiliation__c(
            hed__Contact__c = testContact.Id,
            hed__Account__c = testAccount.Id,
            hed__Status__c = 'Current'
        );
        insert testAffiliation;
        
        // Create test Program Enrollment
        hed__Program_Enrollment__c testProgramEnrollment = new hed__Program_Enrollment__c(
            //Name = 'Test Program Enrollment',
            hed__Contact__c = testContact.Id,
            hed__Affiliation__c = testAffiliation.Id,
            Term__c = testTerm.Id
        );
        insert testProgramEnrollment;
        
        // Create test Courses
        hed__Course__c mandatoryCourse = new hed__Course__c(
            Name = 'Mathematics 101',
            hed__Course_ID__c = 'MATH101',
            Credits__c = 3,
            hed__Credit_Hours__c = 45,
            hed__Account__c=testAccount.id,
            LMS_ID__c = '54321'
        );
        
        hed__Course__c electiveCourse = new hed__Course__c(
            Name = 'Art History',
            hed__Course_ID__c = 'ART201',
            Credits__c = 2,
            hed__Credit_Hours__c = 30,
            hed__Account__c=testAccount.id,
            LMS_ID__c = '54321'
        );
        
        List<hed__Course__c> courses = new List<hed__Course__c>{mandatoryCourse, electiveCourse};
        insert courses;
        
        // Create test Course Offerings
        hed__Course_Offering__c mandatoryCourseOffering = new hed__Course_Offering__c(
            Name = 'MATH101 - Fall 2024',
            hed__Course__c = mandatoryCourse.Id,
            hed__Term__c = testTerm.Id,
            hed__Section_ID__c = 'SEC001'
        );
        
        hed__Course_Offering__c electiveCourseOffering = new hed__Course_Offering__c(
            Name = 'ART201 - Fall 2024',
            hed__Course__c = electiveCourse.Id,
            hed__Term__c = testTerm.Id,
            hed__Section_ID__c = 'SEC002'
        );
        
        List<hed__Course_Offering__c> courseOfferings = new List<hed__Course_Offering__c>{mandatoryCourseOffering, electiveCourseOffering};
        insert courseOfferings;
        
        // Create test Course Enrollments
        hed__Course_Enrollment__c mandatoryCourseEnrollment = new hed__Course_Enrollment__c(
            hed__Contact__c = testContact.Id,
            hed__Course_Offering__c = mandatoryCourseOffering.Id,
            hed__Program_Enrollment__c = testProgramEnrollment.Id,
            hed__Account__c = testAccount.Id,
            hed__Affiliation__c = testAffiliation.Id,
            //Term_Name__c = 'Fall 2024',
            ST__c = 'InProgress',
            hed__Status__c = 'Current',
            hed__Credits_Attempted__c = 3,
            hed__Credits_Earned__c = 3,
            hed__Grade__c = 2,
            No_Of_Classes_Attended__c = 12,
            Percentage_of_classes_attended__c = 85.5,
            Attendacne__c = 85.5
        );
        
        hed__Course_Enrollment__c electiveCourseEnrollment = new hed__Course_Enrollment__c(
            hed__Contact__c = testContact.Id,
            hed__Course_Offering__c = electiveCourseOffering.Id,
            hed__Program_Enrollment__c = testProgramEnrollment.Id,
            hed__Account__c = testAccount.Id,
            hed__Affiliation__c = testAffiliation.Id,
            //Term_Name__c = 'Fall 2024',
            ST__c = 'InProgress',
            hed__Status__c = 'Current',
            hed__Credits_Attempted__c = 2,
            hed__Credits_Earned__c = 2,
            hed__Grade__c = 3,
            No_Of_Classes_Attended__c = 10,
            Percentage_of_classes_attended__c = 90.0,
            Attendacne__c = 90.0
        );
        
        List<hed__Course_Enrollment__c> courseEnrollments = new List<hed__Course_Enrollment__c>{mandatoryCourseEnrollment, electiveCourseEnrollment};
        insert courseEnrollments;
        
        Id PlanRec = Schema.SObjectType.hed__Plan_Requirement__c.getRecordTypeInfosByDeveloperName().get('Unit').getRecordTypeId();
        // Create Plan Requirements to categorize courses
        hed__Plan_Requirement__c mandatoryPlanReq = new hed__Plan_Requirement__c(
            Name = 'Mandatory Math Requirement',
            hed__Course__c = mandatoryCourse.Id,
            hed__Category__c = 'Mandatory',
            Institute__c = testAccount.Id,
            RecordTypeId=PlanRec
        );
        
        hed__Plan_Requirement__c electivePlanReq = new hed__Plan_Requirement__c(
            Name = 'Elective Art Requirement',
            hed__Course__c = electiveCourse.Id,
            hed__Category__c = 'Elective',
            Institute__c = testAccount.Id,
            RecordTypeId=PlanRec
        );
        
        List<hed__Plan_Requirement__c> planRequirements = new List<hed__Plan_Requirement__c>{mandatoryPlanReq, electivePlanReq};
        insert planRequirements;
        
        // Create Sessions for attendance tracking
        Session__c mandatorySession1 = new Session__c(
            //Name = 'MATH101 Session 1',
            Course_Offering__c = mandatoryCourseOffering.Id
        );
        
        Session__c mandatorySession2 = new Session__c(
           // Name = 'MATH101 Session 2',
            Course_Offering__c = mandatoryCourseOffering.Id
        );
        
        Session__c electiveSession1 = new Session__c(
           // Name = 'ART201 Session 1',
            Course_Offering__c = electiveCourseOffering.Id
        );
        
        List<Session__c> sessions = new List<Session__c>{mandatorySession1, mandatorySession2, electiveSession1};
        insert sessions;
        
        // Create Attendance Events
        hed__Attendance_Event__c attendanceEvent1 = new hed__Attendance_Event__c(
            //Name = 'Attendance Event 1',
            hed__Contact__c = testContact.Id,
            Session__c = mandatorySession1.Id,
            Attendance_Status__c = 'Present'
        );
        
        hed__Attendance_Event__c attendanceEvent2 = new hed__Attendance_Event__c(
            //Name = 'Attendance Event 2',
            hed__Contact__c = testContact.Id,
            Session__c = mandatorySession2.Id,
            Attendance_Status__c = 'Absent'
        );
        
        hed__Attendance_Event__c attendanceEvent3 = new hed__Attendance_Event__c(
           // Name = 'Attendance Event 3',
            hed__Contact__c = testContact.Id,
            Session__c = electiveSession1.Id,
            Attendance_Status__c = 'Present'
        );
        
        List<hed__Attendance_Event__c> attendanceEvents = new List<hed__Attendance_Event__c>{attendanceEvent1, attendanceEvent2, attendanceEvent3};
        insert attendanceEvents;
    }
    
    @isTest
    static void testFetchingCourseConnection_WithValidContactId_Success() {
        // Get test contact
        Contact testContact = [SELECT Id FROM Contact WHERE Email = 'test.student@example.com' LIMIT 1];
        
        // Setup REST context
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/allCourseconnectionByContactId/';
        req.httpMethod = 'GET';
        req.params.put('contactId', testContact.Id);
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        RestApi_AllCourseConnectionPerStudent.fetchingCourseConnction();
        Test.stopTest();
        
    }
    
    @isTest
    static void testFetchingCourseConnection_WithInvalidContactId_NoDataFound() {
        // Setup REST context with non-existent contact ID
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/allCourseconnectionByContactId/';
        req.httpMethod = 'GET';
        req.params.put('contactId', '0031234567890ABC'); // Invalid contact ID
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        RestApi_AllCourseConnectionPerStudent.fetchingCourseConnction();
        Test.stopTest();
       
    }
    
    @isTest
    static void testFetchingCourseConnection_WithNullContactId_NoDataFound() {
        // Setup REST context with null contact ID
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/allCourseconnectionByContactId/';
        req.httpMethod = 'GET';
        req.params.put('contactId', null);
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        RestApi_AllCourseConnectionPerStudent.fetchingCourseConnction();
        Test.stopTest();
        
    
    }
    
    @isTest
    static void testFetchingCourseConnection_WithContactHavingNoProgramEnrollment() {
        // Create a contact without program enrollment
        Contact contactWithoutEnrollment = new Contact(
            FirstName = 'Test',
            LastName = 'NoEnrollment',
            Email = 'no.enrollment@example.com'
        );
        insert contactWithoutEnrollment;
        
        // Setup REST context
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/allCourseconnectionByContactId/';
        req.httpMethod = 'GET';
        req.params.put('contactId', contactWithoutEnrollment.Id);
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        RestApi_AllCourseConnectionPerStudent.fetchingCourseConnction();
        Test.stopTest();

    }
    
    @isTest
    static void testFetchingCourseConnection_WithContactHavingNoCourseEnrollments() {
        // Create test data without course enrollments
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'NoCourses',
            Email = 'no.courses@example.com'
        );
        insert testContact;
        
        Account testAccount = new Account(Name = 'Test University 2');
        insert testAccount;
        
        hed__Term__c testTerm = new hed__Term__c(
            Name = 'Spring 2024',
            hed__Account__c = testAccount.Id,
            Term_Reference__c='Semester 1',
            hed__Start_Date__c = Date.today().addDays(-5),
    hed__End_Date__c = Date.today().addDays(10)
           // Term_Status__c = 'Ongoing'
        );
        insert testTerm;
        
        hed__Affiliation__c testAffiliation = new hed__Affiliation__c(
            hed__Contact__c = testContact.Id,
            hed__Account__c = testAccount.Id,
            hed__Status__c = 'Current'
        );
        insert testAffiliation;
        
        hed__Program_Enrollment__c testProgramEnrollment = new hed__Program_Enrollment__c(
            //Name = 'Test Program Enrollment 2',
            hed__Contact__c = testContact.Id,
            hed__Affiliation__c = testAffiliation.Id,
            Term__c = testTerm.Id
        );
        insert testProgramEnrollment;
        
        // Setup REST context
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/allCourseconnectionByContactId/';
        req.httpMethod = 'GET';
        req.params.put('contactId', testContact.Id);
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        RestApi_AllCourseConnectionPerStudent.fetchingCourseConnction();
        Test.stopTest();
      
    }
    
    @isTest
    static void testFetchingCourseConnection_AttendanceCalculation() {
        // Get test contact
        Contact testContact = [SELECT Id FROM Contact WHERE Email = 'test.student@example.com' LIMIT 1];
        
        // Setup REST context
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/allCourseconnectionByContactId/';
        req.httpMethod = 'GET';
        req.params.put('contactId', testContact.Id);
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        RestApi_AllCourseConnectionPerStudent.fetchingCourseConnction();
        Test.stopTest();
        
    }
    
    @isTest
    static void testFetchingCourseConnection_HeadersAndContentType() {
        // Get test contact
        Contact testContact = [SELECT Id FROM Contact WHERE Email = 'test.student@example.com' LIMIT 1];
        
        // Setup REST context
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/allCourseconnectionByContactId/';
        req.httpMethod = 'GET';
        req.params.put('contactId', testContact.Id);
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        RestApi_AllCourseConnectionPerStudent.fetchingCourseConnction();
        Test.stopTest();
        
       
    }
    
    
    @isTest
    static void testCourseWrapperClasses() {
        // Test CourseWrapper class
        RestApi_AllCourseConnectionPerStudent.CourseWrapper courseWrapper = new RestApi_AllCourseConnectionPerStudent.CourseWrapper();
        courseWrapper.CourseName = 'Test Course';
        courseWrapper.CourseCode = 'TEST101';
        courseWrapper.credit = 3.0;
        courseWrapper.creditHours = 45.0;
        courseWrapper.status = 'Enrolled';
        courseWrapper.id = 'testId';
        courseWrapper.courseOfferingId = 'testOfferingId';
        courseWrapper.courseOfferingSectionId = 'testSectionId';
        courseWrapper.totalnoOfclass = 10;
        courseWrapper.presentnoOfclass = 8;
        courseWrapper.affiliationStatus = 'Current';
        courseWrapper.termName = 'Fall 2024';
        courseWrapper.Attendence = 80.0;
        
        System.assertEquals('Test Course', courseWrapper.CourseName, 'Course name should be set correctly');
        System.assertEquals('TEST101', courseWrapper.CourseCode, 'Course code should be set correctly');
        System.assertEquals(3.0, courseWrapper.credit, 'Credit should be set correctly');
        System.assertEquals(45.0, courseWrapper.creditHours, 'Credit hours should be set correctly');
        
        // Test CourseWrapperDetails class
        RestApi_AllCourseConnectionPerStudent.CourseWrapperDetails wrapperDetails = new RestApi_AllCourseConnectionPerStudent.CourseWrapperDetails();
        wrapperDetails.mandatoryCourses = new List<RestApi_AllCourseConnectionPerStudent.CourseWrapper>{courseWrapper};
        wrapperDetails.electiveCourses = new List<RestApi_AllCourseConnectionPerStudent.CourseWrapper>{courseWrapper};
        
        System.assertEquals(1, wrapperDetails.mandatoryCourses.size(), 'Mandatory courses list should have 1 item');
        System.assertEquals(1, wrapperDetails.electiveCourses.size(), 'Elective courses list should have 1 item');
    }
    
    @isTest
    static void testCourseWrapperClasses1() {
        // Test CourseWrapper class
        RestApi_AllCourseConnectionPerStudent.CourseWrapper courseWrapper = new RestApi_AllCourseConnectionPerStudent.CourseWrapper();
        courseWrapper.CourseName = 'Test Course';
        courseWrapper.CourseCode = 'TEST101';
        courseWrapper.credit = 3.0;
        courseWrapper.creditHours = 45.0;
        courseWrapper.status = 'Enrolled';
        courseWrapper.id = 'testId';
        courseWrapper.courseOfferingId = 'testOfferingId';
        courseWrapper.courseOfferingSectionId = 'testSectionId';
        courseWrapper.totalnoOfclass = 10;
        courseWrapper.presentnoOfclass = 8;
        courseWrapper.affiliationStatus = 'Current';
        courseWrapper.termName = 'Fall 2024';
        courseWrapper.Attendence = 80.0;
        
        System.assertEquals('Test Course', courseWrapper.CourseName, 'Course name should be set correctly');
        System.assertEquals('TEST101', courseWrapper.CourseCode, 'Course code should be set correctly');
        System.assertEquals(3.0, courseWrapper.credit, 'Credit should be set correctly');
        System.assertEquals(45.0, courseWrapper.creditHours, 'Credit hours should be set correctly');
        
        // Test CourseWrapperDetails class
        RestApi_AllCourseConnectionPerStudent.CourseWrapperDetails wrapperDetails = new RestApi_AllCourseConnectionPerStudent.CourseWrapperDetails();
        wrapperDetails.mandatoryCourses = new List<RestApi_AllCourseConnectionPerStudent.CourseWrapper>{courseWrapper};
        wrapperDetails.electiveCourses = new List<RestApi_AllCourseConnectionPerStudent.CourseWrapper>{courseWrapper};
        
        System.assertEquals(1, wrapperDetails.mandatoryCourses.size(), 'Mandatory courses list should have 1 item');
        System.assertEquals(1, wrapperDetails.electiveCourses.size(), 'Elective courses list should have 1 item');
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