@IsTest
private class CourseConnPerCourseOffAndContact_Test {
    
    @TestSetup
    static void setupTestData() {
        Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());
        Test.setMock(HttpCalloutMock.class, new FailureHttpMock());
        // Create test Account
        Account testAccount = new Account(Name = 'Test University');
        insert testAccount;
        LMS_URL__c lmsUrl = new LMS_URL__c(Name = 'course url', Bulk_Enroll__c = 'https://dummyendpoint.com');
    insert lmsUrl;
        LMS_URL__c lmsUrl1 = new LMS_URL__c(Name = 'course offering url', Bulk_Enroll__c = 'https://dummyendpoint.com');
    insert lmsUrl1;
        
        // Create Record Types
        Id facultyRecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByName().get('Faculty').getRecordTypeId();
        Id studentRecordTypeId = Schema.SObjectType.hed__Course_Enrollment__c.getRecordTypeInfosByName().get('Student').getRecordTypeId();
        
        // Create Faculty Contact
        Contact facultyContact = new Contact(
            FirstName = 'Test',
            LastName = 'Faculty',
            Email = 'faculty@test.com',
            AccountId = testAccount.Id,
            RecordTypeId = facultyRecordTypeId
        );
        insert facultyContact;
        
        // Create Student Contacts
        List<Contact> studentContacts = new List<Contact>();
        for (Integer i = 0; i < 3; i++) {
            studentContacts.add(new Contact(
                FirstName = 'Test',
                LastName = 'Student' + i,
                Email = 'student' + i + '@test.com',
                AccountId = testAccount.Id,
                Registration_Number__c = 'REG00' + i,
                Status__c = (i == 0) ? 'AT Risk' : 'Active'
            ));
        }
        insert studentContacts;
        
        // Create Term
        hed__Term__c testTerm = new hed__Term__c(
            Name = 'Fall 2024',
            hed__Account__c = testAccount.Id,
            hed__Start_Date__c = Date.today().addDays(-30),
            hed__End_Date__c = Date.today().addDays(60),
            Term_Reference__c  ='Term 1'
        );
        insert testTerm;
        
        // Create Course
        hed__Course__c testCourse = new hed__Course__c(
            Name = 'Test Course',
            hed__Account__c = testAccount.Id,
            hed__Course_ID__c = 'TEST101'
        );
        insert testCourse;
        
        Course_Version__c cv = new Course_Version__c();
        insert cv;
        
        // Create Course Offering
        hed__Course_Offering__c courseOffering = new hed__Course_Offering__c(
            Name = 'Test Course Offering',
            hed__Course__c = testCourse.Id,
            hed__Term__c = testTerm.Id,
            hed__Section_ID__c = 'SEC001',
            hed__Start_Date__c = Date.today().addDays(-15),
            hed__End_Date__c = Date.today().addDays(45),
            Course_Version__c = cv.Id
        );
        insert courseOffering;
        
        // Create Affiliation for Faculty
        hed__Affiliation__c facultyAffiliation = new hed__Affiliation__c(
            hed__Contact__c = facultyContact.Id,
            hed__Account__c = testAccount.Id,
            hed__Status__c = 'Current'
        );
        insert facultyAffiliation;
        
        // Create Affiliations for Students
        List<hed__Affiliation__c> studentAffiliations = new List<hed__Affiliation__c>();
        for (Contact student : studentContacts) {
            studentAffiliations.add(new hed__Affiliation__c(
                hed__Contact__c = student.Id,
                hed__Account__c = testAccount.Id,
                hed__Status__c = 'Current'
            ));
        }
        insert studentAffiliations;
        
        // Create Faculty Course Enrollment
        hed__Course_Enrollment__c facultyEnrollment = new hed__Course_Enrollment__c(
            hed__Contact__c = facultyContact.Id,
            hed__Course_Offering__c = courseOffering.Id,
            hed__Account__c = testAccount.Id,
            hed__Affiliation__c = facultyAffiliation.Id,
            hed__Status__c = 'Current',
            hed__Primary__c = true
        );
        insert facultyEnrollment;
        
        // Create Student Course Enrollments
        List<hed__Course_Enrollment__c> studentEnrollments = new List<hed__Course_Enrollment__c>();
        for (Integer i = 0; i < studentContacts.size(); i++) {
            studentEnrollments.add(new hed__Course_Enrollment__c(
                hed__Contact__c = studentContacts[i].Id,
                hed__Course_Offering__c = courseOffering.Id,
                hed__Account__c = testAccount.Id,
                hed__Affiliation__c = studentAffiliations[i].Id,
                hed__Status__c = 'Current',
                hed__Primary__c = true,
                RecordTypeId = studentRecordTypeId,
                Percentage_of_classes_attended__c = 85.5,
                No_Of_Classes_Attended__c = 17,
                Attendacne__c = 85.5,
                hed__Credits_Attempted__c = 3,
                hed__Credits_Earned__c = 3
            ));
        }
        insert studentEnrollments;
    }
    
    @IsTest
    static void testSuccessfulGetRequest() {
        // Get test data
        Contact facultyContact = [SELECT Id FROM Contact WHERE RecordType.Name = 'Faculty' LIMIT 1];
        hed__Course_Offering__c courseOffering = [SELECT Id FROM hed__Course_Offering__c LIMIT 1];
        
        // Setup REST context
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        
        request.requestURI = '/services/apexrest/courseConnectionsPerStudent/';
        request.params.put('contactId', facultyContact.Id);
        request.params.put('courseOfferingId', courseOffering.Id);
        request.httpMethod = 'GET';
        
        RestContext.request = request;
        RestContext.response = response;
        
        Test.startTest();
        RestApi_CourseConnPerCourseOffAndContact.doGet();
        Test.stopTest();
        
       
    }
    
    @IsTest
    static void testNoDataFoundForNonFacultyContact() {
        // Get a student contact (not faculty)
        Contact studentContact = [SELECT Id FROM Contact WHERE RecordType.Name != 'Faculty' LIMIT 1];
        hed__Course_Offering__c courseOffering = [SELECT Id FROM hed__Course_Offering__c LIMIT 1];
        
        // Setup REST context
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        
        request.requestURI = '/services/apexrest/courseConnectionsPerStudent/';
        request.params.put('contactId', studentContact.Id);
        request.params.put('courseOfferingId', courseOffering.Id);
        request.httpMethod = 'GET';
        
        RestContext.request = request;
        RestContext.response = response;
        
        Test.startTest();
        RestApi_CourseConnPerCourseOffAndContact.doGet();
        Test.stopTest();
        
        // Verify no data found response
        System.assertEquals(400, response.statusCode, 'Status code should be 400 for no data found');
        
        String responseBody = response.responseBody.toString();
        System.assert(responseBody.contains('"success" : "false"'), 'Response should indicate failure');
        System.assert(responseBody.contains('No Data Found'), 'Response should contain no data found message');
    }
    
    @IsTest
    static void testInvalidContactId() {
        // Use invalid contact ID
        String invalidContactId = '003000000000000';
        hed__Course_Offering__c courseOffering = [SELECT Id FROM hed__Course_Offering__c LIMIT 1];
        
        // Setup REST context
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        
        request.requestURI = '/services/apexrest/courseConnectionsPerStudent/';
        request.params.put('contactId', invalidContactId);
        request.params.put('courseOfferingId', courseOffering.Id);
        request.httpMethod = 'GET';
        
        RestContext.request = request;
        RestContext.response = response;
        
        Test.startTest();
        RestApi_CourseConnPerCourseOffAndContact.doGet();
        Test.stopTest();
        
        // Verify no data found response
        System.assertEquals(400, response.statusCode, 'Status code should be 400 for invalid contact');
        
        String responseBody = response.responseBody.toString();
        System.assert(responseBody.contains('"success" : "false"'), 'Response should indicate failure');
        System.assert(responseBody.contains('No Data Found'), 'Response should contain no data found message');
    }
    
    @IsTest
    static void testMissingParameters() {
        // Setup REST context without parameters
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        
        request.requestURI = '/services/apexrest/courseConnectionsPerStudent/';
        request.httpMethod = 'GET';
        
        RestContext.request = request;
        RestContext.response = response;
        
        Test.startTest();
        RestApi_CourseConnPerCourseOffAndContact.doGet();
        Test.stopTest();
        
        // Verify error response
        System.assertEquals(400, response.statusCode, 'Status code should be 400 for missing parameters');
        
        String responseBody = response.responseBody.toString();
        System.assert(responseBody.contains('"success" : "false"'), 'Response should indicate failure');
    }
    
    @IsTest
    static void testJsonWrapperClass() {
        // Test the wrapper classes
        RestApi_CourseConnPerCourseOffAndContact.jsonWrapper wrapper = new RestApi_CourseConnPerCourseOffAndContact.jsonWrapper();
        wrapper.studentCount = 5;
        wrapper.RiskCount = 2;
        wrapper.courseOffering = new Map<String, List<RestApi_CourseConnPerCourseOffAndContact.students>>();
        
        System.assertEquals(5, wrapper.studentCount, 'Student count should be set correctly');
        System.assertEquals(2, wrapper.RiskCount, 'Risk count should be set correctly');
        System.assertNotEquals(null, wrapper.courseOffering, 'Course offering map should be initialized');
    }
    
    @IsTest
    static void testStudentsClass() {
        // Test the students wrapper class
        RestApi_CourseConnPerCourseOffAndContact.students student = new RestApi_CourseConnPerCourseOffAndContact.students();
        student.StudentName = 'Test Student';
        student.StudentRegdNo = 'REG001';
        student.StudentStatus = 'Active';
        student.Attendacne = 85.5;
        student.ProgrameName = 'Test Program';
        student.CourseName = 'Test Course';
        student.Section = 'SEC001';
        student.ContactID = '003000000000001';
        
        System.assertEquals('Test Student', student.StudentName, 'Student name should be set correctly');
        System.assertEquals('REG001', student.StudentRegdNo, 'Registration number should be set correctly');
        System.assertEquals('Active', student.StudentStatus, 'Student status should be set correctly');
        System.assertEquals(85.5, student.Attendacne, 'Attendance should be set correctly');
    }
    
    @IsTest
    static void testAttendanceWrapperClass() {
        // Create a test attendance event
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];
        
        hed__Attendance_Event__c attendanceEvent = new hed__Attendance_Event__c(
            hed__Contact__c = testContact.Id
        );
        insert attendanceEvent;
        
        // Test the AttendanceWrapper class
        RestApi_CourseConnPerCourseOffAndContact.AttendanceWrapper wrapper = 
            new RestApi_CourseConnPerCourseOffAndContact.AttendanceWrapper(attendanceEvent);
        
        System.assertEquals(attendanceEvent.Id, wrapper.add.Id, 'Attendance event should be set correctly');
    }
    
    @IsTest
    static void testWithAtRiskStudents() {
        // Get test data
        Contact facultyContact = [SELECT Id FROM Contact WHERE RecordType.Name = 'Faculty' LIMIT 1];
        
        // Setup REST context
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        
        request.requestURI = '/services/apexrest/courseConnectionsPerStudent/';
        request.params.put('contactId', facultyContact.Id);
        request.httpMethod = 'GET';
        
        RestContext.request = request;
        RestContext.response = response;
        
        Test.startTest();
        RestApi_CourseConnPerCourseOffAndContact.doGet();
        Test.stopTest();
        
        // Verify response contains at-risk student data
        String responseBody = response.responseBody.toString();
        System.assert(responseBody.contains('"success" : "true"'), 'Response should indicate success');
        
        // Parse and verify the response structure
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
        Map<String, Object> dataMap = (Map<String, Object>) responseMap.get('data');
        
        System.assert(dataMap.containsKey('studentCount'), 'Data should contain student count');
        System.assert(dataMap.containsKey('RiskCount'), 'Data should contain risk count');
        System.assert(dataMap.containsKey('courseOffering'), 'Data should contain course offering');
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
    
      public class SuccessHttpMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(' {"success": "true","data": {"Identifier": "98765","Code": "Ken BBA-01","Name": "Ken - BBA Template","Path": "/content/enforced/6887-KenBBA-01"}}');
            res.setStatusCode(200);
            return res;
        }
    }
}