@isTest
private class RestApi_CoursesByFacultyId_Test {

    @TestSetup
    static void setupTestData() {
        
        Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());
        Test.setMock(HttpCalloutMock.class, new FailureHttpMock());
        Test.setMock(HttpCalloutMock.class, new NoDataHttpMock());
        
        LMS_URL__c lmsUrl = new LMS_URL__c(Name = 'course url', Bulk_Enroll__c = 'https://dummyendpoint.com');
    	insert lmsUrl;
        
         LMS_URL__c URL = new LMS_URL__c(Name = 'course url',Bulk_Enroll__c = 'TestUrl');
        insert URL;
        LMS_URL__c URL1 = new LMS_URL__c(Name = 'course offering url',Bulk_Enroll__c = 'TestUrl');
        insert URL1;
        LMS_URL__c URL2 = new LMS_URL__c(Name = 'Bulk Enrollment',Bulk_Enroll__c = 'TestUrl');
        insert URL2;
        
        // Create Account
        Account acc = new Account(Name = 'Test University',LMS_Id__c = '12345');
        insert acc;

        // Faculty Contact
        RecordType facultyRT = [SELECT Id FROM RecordType WHERE SObjectType = 'Contact' AND Name = 'Faculty' LIMIT 1];
        Contact facultyContact = new Contact(
            FirstName = 'John',
            LastName = 'Doe',
            Email = 'john.doe@example.com',
            Phone = '1234567890',
            Status__c = 'Active',
            RecordTypeId = facultyRT.Id
        );
        insert facultyContact;

        // Student Contact
        RecordType studentRT = [SELECT Id FROM RecordType WHERE SObjectType = 'Contact' AND Name = 'Student' LIMIT 1];
        Contact studentContact = new Contact(
            FirstName = 'Jane',
            LastName = 'Smith',
            Email = 'jane.smith@example.com',
            Registration_Number__c = 'REG123',
            RecordTypeId = studentRT.Id
        );
        insert studentContact;

        // Campus
        	Campus__c campus = new 	Campus__c(Name = 'Main Campus',Campus_ID__c='test');
        insert campus;

        // Term
        hed__Term__c term = new hed__Term__c(
            Name = 'Fall 2024',
            hed__Account__c = acc.Id,
            Campus__c = campus.Id,
            hed__Start_Date__c = Date.today(),
            hed__End_Date__c = Date.today().addMonths(3),
            Term_Reference__c='Term 1'
        );
        insert term;

        // Course
        hed__Course__c course = new hed__Course__c(
            Name = 'Mathematics',
            hed__Account__c = acc.Id,
            hed__Course_ID__c = 'TC001',
            hed__Credit_Hours__c = 3,
            LMS_ID__c = '54321'
        );
        insert course;

        // Course Offering
        hed__Course_Offering__c courseOffering = new hed__Course_Offering__c(
            Name = 'Math 101 - Section A',
            hed__Section_ID__c = 'SEC-MATH101A',
            hed__Term__c = term.Id,
            hed__Course__c = course.Id,
            hed__Start_Date__c = Date.today(),
            hed__End_Date__c = Date.today().addDays(90)
        );
        insert courseOffering;

        // Course Enrollment (Faculty Type)
        hed__Affiliation__c aff = new hed__Affiliation__c(hed__Account__c = acc.Id);
        insert aff;

        hed__Course_Enrollment__c enrollment = new hed__Course_Enrollment__c(
            hed__Contact__c = facultyContact.Id,
            hed__Course_Offering__c = courseOffering.Id,
            hed__Status__c = 'Enrolled',
            Is_Active__c = true
            //RecordType.Name = 'Faculty'
        );
        insert enrollment;

        // Facility
        hed__Facility__c facility = new hed__Facility__c(
            Name = 'Science Building',
            Campus__c = campus.Id
        );
        insert facility;
    }

    @isTest
    static void test_doGet_ValidFacultyAndTerm() {
        Contact faculty = [SELECT Id FROM Contact WHERE FirstName = 'John' LIMIT 1];
        hed__Term__c term = [SELECT Id FROM hed__Term__c WHERE Name = 'Fall 2024' LIMIT 1];

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/GetAllCoursesByFacultyId/';
        req.httpMethod = 'GET';
        req.params.put('facultyId', faculty.Id);
        req.params.put('termId', term.Id);
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        RestApi_CoursesByFacultyId.doGet();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
        String responseBody = res.responseBody.toString();
        System.debug('Response: ' + responseBody);
     //   System.assertTrue(responseBody.contains('"success": true'));
     //   System.assertTrue(responseBody.contains('courseName'));
     //   System.assertTrue(responseBody.contains('section'));
    //    System.assertTrue(responseBody.contains('facilityName'));
    }

    @isTest
    static void test_doGet_OnlyTerm() {
        hed__Term__c term = [SELECT Id FROM hed__Term__c WHERE Name = 'Fall 2024' LIMIT 1];

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/GetAllCoursesByFacultyId/';
        req.httpMethod = 'GET';
        req.params.put('termId', term.Id);
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        RestApi_CoursesByFacultyId.doGet();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
        String responseBody = res.responseBody.toString();
        System.debug('Response: ' + responseBody);
     //   System.assertTrue(responseBody.contains('"success": true'));
    //    System.assertTrue(responseBody.contains('courseName'));
    }

    @isTest
    static void test_doGet_WithCourseId() {
        Contact faculty = [SELECT Id FROM Contact WHERE FirstName = 'John' LIMIT 1];
        hed__Term__c term = [SELECT Id FROM hed__Term__c WHERE Name = 'Fall 2024' LIMIT 1];
        hed__Course__c course = [SELECT Id FROM hed__Course__c WHERE Name = 'Mathematics' LIMIT 1];

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/GetAllCoursesByFacultyId/';
        req.httpMethod = 'GET';
        req.params.put('facultyId', faculty.Id);
        req.params.put('termId', term.Id);
        req.params.put('courseId', course.Id);
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        RestApi_CoursesByFacultyId.doGet();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
        String responseBody = res.responseBody.toString();
        System.debug('Response: ' + responseBody);
    //    System.assertTrue(responseBody.contains('"success": true'));
    }

    @isTest
    static void test_doGet_InvalidParameters() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/GetAllCoursesByFacultyId/';
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        RestApi_CoursesByFacultyId.doGet();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
        String responseBody = res.responseBody.toString();
        System.debug('Response: ' + responseBody);
    //    System.assertTrue(responseBody.contains('errorMessage'));
    }

    @isTest
    static void test_doGet_InvalidTermId() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/GetAllCoursesByFacultyId/';
        req.httpMethod = 'GET';
        req.params.put('termId', 'a00000000000000AAA'); // invalid ID
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        RestApi_CoursesByFacultyId.doGet();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
        String responseBody = res.responseBody.toString();
        System.debug('Response: ' + responseBody);
     //   System.assertTrue(responseBody.contains('invalid termId'));
    }

    @isTest
    static void test_doGet_ExceptionHandling() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/GetAllCoursesByFacultyId/';
        req.httpMethod = 'GET';
        req.params.put('termId', 'invalid_id_format');
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        RestApi_CoursesByFacultyId.doGet();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
        String responseBody = res.responseBody.toString();
        System.debug('Response: ' + responseBody);
     //   System.assertTrue(responseBody.contains('at line number'));
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
    
    public class NoDataHttpMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"message": "Success"}');
            res.setStatusCode(200);
            return res;
        }
    }
}