@isTest
private class RestApi_GetStudentAttendanceData_Test {

    @testSetup
    static void setupTestData() {
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

        Account department = new Account(Name = 'Test Department', ParentId = testAccount.Id,LMS_Id__c = '12345');
        insert department;

        // Course
        hed__Course__c course = new hed__Course__c(
            Name = 'Test Course',
            hed__Account__c = department.Id,
            hed__Course_ID__c = 'TC123',
LMS_ID__c = '54321'
        );
        insert course;

        // Term
        hed__Term__c term = new hed__Term__c(
            Name = 'Test Term',
            hed__Account__c = department.Id,
            Term_Reference__c = 'Semester 1'
        );
        insert term;

        // Course Offering
        hed__Course_Offering__c courseOffering = new hed__Course_Offering__c(
            Name = 'Test Course Offering',
            hed__Course__c = course.Id,
            hed__Term__c = term.Id,
            hed__Section_ID__c = 'SEC001'
        );
        insert courseOffering;

        // Student Contact
        Contact student = new Contact(FirstName = 'Test', LastName = 'Student', Email = 'test@student.com');
        insert student;

        // Session
        Session__c session = new Session__c(
            Course_Offering__c = courseOffering.Id,
            Start_Date_Time__c = DateTime.now()
        );
        insert session;

        // Attendance Events (Present and Absent)
        List<hed__Attendance_Event__c> attendanceList = new List<hed__Attendance_Event__c>{
            new hed__Attendance_Event__c(
                hed__Contact__c = student.Id,
                Attendance_Status__c = 'Present',
                Session__c = session.Id
               // Start_Date_Time__c = DateTime.now()
            ),
            new hed__Attendance_Event__c(
                hed__Contact__c = student.Id,
                Attendance_Status__c = 'Absent',
                Session__c = session.Id
                //Start_Date_Time__c = DateTime.now().addDays(1)
            )
        };
        insert attendanceList;
    }

    @isTest
    static void testAttendanceFetchSuccess() {
        // Get the test student
        Contact student = [SELECT Id FROM Contact WHERE Email = 'test@student.com' LIMIT 1];

        // Set request parameters
        Test.startTest();
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestUri = '/services/apexrest/StudentAttendanceData';
        req.httpMethod = 'GET';
        req.addParameter('contactId', student.Id);
        req.addParameter('StartDate', DateTime.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''));
        req.addParameter('EndDate', DateTime.now().addDays(2).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''));

        RestContext.request = req;
        RestContext.response = res;

        // Call the method
        RestApi_GetStudentAttendanceData.fetchingAttendance();
        Test.stopTest();

        // Validate the response
        System.assertNotEquals(null, RestContext.response.responseBody, 'Response body should not be null');
        String response = RestContext.response.responseBody.toString();
        System.debug('API Response: ' + response);
        System.assert(response.contains('AttendancePercentageForAll'), 'Response should contain overall attendance percentage');
        System.assert(response.contains('courseLevelAttendanceList'), 'Response should contain course-level attendance list');
    }

    @isTest
    static void testMissingContactId() {
        Test.startTest();
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/StudentAttendanceData';
        req.httpMethod = 'GET';

        RestContext.request = req;
        RestContext.response = res;

        RestApi_GetStudentAttendanceData.fetchingAttendance();
        Test.stopTest();

        String response = RestContext.response.responseBody.toString();
        System.assert(response.contains('No match found for contact'), 'Should return contact missing message');
    }

    @isTest
    static void testNoAttendanceRecords() {
        // Create a contact with no attendance
        Contact newStudent = new Contact(FirstName = 'Empty', LastName = 'Student', Email = 'empty@student.com');
        insert newStudent;

        Test.startTest();
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestUri = '/services/apexrest/StudentAttendanceData';
        req.httpMethod = 'GET';
        req.addParameter('contactId', newStudent.Id);
        req.addParameter('StartDate', DateTime.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''));
        req.addParameter('EndDate', DateTime.now().addDays(1).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''));

        RestContext.request = req;
        RestContext.response = res;

        RestApi_GetStudentAttendanceData.fetchingAttendance();
        Test.stopTest();

        String response = RestContext.response.responseBody.toString();
        System.assert(response.contains('No attendance event found for this contact'), 'Should indicate no attendance found');
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


/**@isTest
private class RestApi_GetStudentAttendanceData_Test {

    @isTest 
    static void testFetchingAttendance() {
        Test.setMock(HttpCalloutMock.class, new SessionMockCallout());

        Test.startTest();

        // Create required test data
        Account institution = new Account(Name = 'Test Institution');
        insert institution;

        Account department = new Account(Name = 'Test Department', ParentId = institution.Id);
        insert department;

        hed__Course__c course = new hed__Course__c(
            Name = 'Test Course', 
            hed__Account__c = department.Id, 
            hed__Course_ID__c = 'TC123'
        );
        insert course;

        hed__Term__c term = new hed__Term__c(
            Name = 'Test Term',
            hed__Account__c = department.Id,
            Term_Reference__c = 'Semester 1'
        );
        insert term;

        hed__Course_Offering__c courseOffering = new hed__Course_Offering__c(
            Name = 'Test Course Offering',
            hed__Course__c = course.Id,
            hed__Term__c = term.Id,
            hed__Section_ID__c = 'SEC001'
        );
        insert courseOffering;

        Contact student = new Contact(FirstName = 'Test', LastName = 'Student', Email = 'test@student.com');
        insert student;

        Session__c session = new Session__c(
            Course_Offering__c = courseOffering.Id,
            Start_Date_Time__c = DateTime.now() // Add Session_Date__c field
        );
        insert session;

        hed__Attendance_Event__c attendanceEvent1 = new hed__Attendance_Event__c(
            hed__Contact__c = student.Id,
            Attendance_Status__c = 'Present',
            Session__c = session.Id
        );
        hed__Attendance_Event__c attendanceEvent2 = new hed__Attendance_Event__c(
            hed__Contact__c = student.Id,
            Attendance_Status__c = 'Absent',
            Session__c = session.Id
        );
        insert new List<hed__Attendance_Event__c>{ attendanceEvent1, attendanceEvent2 };

        // Mock REST request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/StudentAttendanceData';
        req.httpMethod = 'GET';
        req.addParameter('contactId', student.Id);
        req.addParameter('StartDate', DateTime.now().format('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'')); // Use current date/time
        req.addParameter('EndDate', DateTime.now().addDays(1).format('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'')); // Use next day

        RestContext.request = req;
        RestContext.response = res;

        // Call the method
        RestApi_GetStudentAttendanceData.fetchingAttendance();

        // Validate response
        //System.assertEquals(200, res.statusCode, 'HTTP status code should be 200');
        String responseBody = res.responseBody.toString();
        //System.assert(responseBody.contains('"TotalClassesForAll"'), 'Response should contain total classes');
        //System.assert(responseBody.contains('"AttendancePercentageForAll"'), 'Response should contain attendance percentage');
        //System.assert(responseBody.contains('"CourseName":"Test Course"'), 'Response should contain course name');
        //System.assert(responseBody.contains('"CourseCode":"TC123"'), 'Response should contain course code');
        //System.assert(responseBody.contains('"SectionId":"SEC001"'), 'Response should contain Section Id');

        Test.stopTest();
    }

    @isTest
    static void testFetchingAttendanceNoAttendance() {
        Test.startTest();

        Contact student = new Contact(FirstName = 'Test', LastName = 'Student2', Email = 'test2@student.com');
        insert student;

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/StudentAttendanceData';
        req.httpMethod = 'GET';
        req.addParameter('contactId', student.Id);

        RestContext.request = req;
        RestContext.response = res;

        RestApi_GetStudentAttendanceData.fetchingAttendance();

        // Validate response
        //System.assertEquals(404, res.statusCode, 'HTTP status code should be 404');
        String responseBody = res.responseBody.toString();
        //System.assert(responseBody.contains('"message": "No attendance event found for this contact"'), 'Response should contain no attendance message');

        Test.stopTest();
    }

    @isTest
    static void testFetchingAttendanceNoContact() {
        Test.startTest();

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/StudentAttendanceData';
        req.httpMethod = 'GET';

        RestContext.request = req;
        RestContext.response = res;

        RestApi_GetStudentAttendanceData.fetchingAttendance();

        // Validate response
        //System.assertEquals(400, res.statusCode, 'HTTP status code should be 400');
        String responseBody = res.responseBody.toString();
        //System.assert(responseBody.contains('"message": "No match found for contact"'), 'Response should contain no contact message');

        Test.stopTest();
    }

    @isTest
    static void testInnerClassesInstantiation() {
        // Create an instance of AttendanceDetails
        RestApi_GetStudentAttendanceData.AttendanceDetails attendanceDetails = 
            new RestApi_GetStudentAttendanceData.AttendanceDetails();
        
        // Assign values to the properties
        attendanceDetails.TotalClassesForAll = 100;
        attendanceDetails.AbsentClassesForAll = 10;
        attendanceDetails.AttendancePercentageForAll = 90;
        attendanceDetails.courseLevelAttendanceList = new List<RestApi_GetStudentAttendanceData.CourseLevelAttendance>();
        
        // Create a sample CourseLevelAttendance object
        RestApi_GetStudentAttendanceData.CourseLevelAttendance courseAttendance = 
            new RestApi_GetStudentAttendanceData.CourseLevelAttendance();
        
        courseAttendance.CourseName = 'Mathematics';
        courseAttendance.TotalClasses = 50;
        courseAttendance.AbsentClasses = 5;
        courseAttendance.AttendancePercentage = 90;
        
        // Add to list
        attendanceDetails.courseLevelAttendanceList.add(courseAttendance);
        
        // Assertions to validate data is stored correctly
        //System.assertNotEquals(attendanceDetails, null, 'AttendanceDetails object should not be null');
        //System.assertEquals(attendanceDetails.TotalClassesForAll, 100, 'Total Classes should match');
        //System.assertEquals(attendanceDetails.AbsentClassesForAll, 10, 'Absent Classes should match');
        //System.assertEquals(attendanceDetails.AttendancePercentageForAll, 90, 'Attendance Percentage should match');
        
        //System.assertNotEquals(attendanceDetails.courseLevelAttendanceList, null, 'Course Level Attendance List should not be null');
        //System.assertEquals(attendanceDetails.courseLevelAttendanceList.size(), 1, 'There should be 1 course entry');
    }

    @isTest
    static void testCourseLevelAttendanceInstantiation() {
        // Create an instance of CourseLevelAttendance
        RestApi_GetStudentAttendanceData.CourseLevelAttendance courseAttendance = 
            new RestApi_GetStudentAttendanceData.CourseLevelAttendance();
        
        // Assigning values to the properties
        courseAttendance.CourseName = 'Mathematics';
        courseAttendance.CourseCode = 'MATH101';
        courseAttendance.SectionId = 'SEC123';
        courseAttendance.CourseOfferingId = 'CO456';
        courseAttendance.TotalClasses = 40;
        courseAttendance.AbsentClasses = 5;
        courseAttendance.AttendancePercentage = 88;
        
        // Assertions to ensure correct assignment
        //System.assertNotEquals(courseAttendance, null, 'CourseLevelAttendance object should not be null');
        //System.assertEquals(courseAttendance.CourseName, 'Mathematics', 'Course Name should match');
        //System.assertEquals(courseAttendance.CourseCode, 'MATH101', 'Course Code should match');
        //System.assertEquals(courseAttendance.SectionId, 'SEC123', 'Section ID should match');
        //System.assertEquals(courseAttendance.CourseOfferingId, 'CO456', 'Course Offering ID should match');
        //System.assertEquals(courseAttendance.TotalClasses, 40, 'Total Classes should match');
        //System.assertEquals(courseAttendance.AbsentClasses, 5, 'Absent Classes should match');
        //System.assertEquals(courseAttendance.AttendancePercentage, 88, 'Attendance Percentage should match');
    }

    @isTest
    static void testToDateTime() {
        DateTime dt = RestApi_GetStudentAttendanceData.toDateTime('2023-01-01T10:00:00.000');
        //System.assertEquals(DateTime.newInstance(2023, 1, 1, 10, 0, 0), dt);
        DateTime result = DateTime.newInstance(2023, 1, 1, 10, 0, 0);
    }**/
//}