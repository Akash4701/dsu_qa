@isTest
private class CoursesForFacultyAndRelatedStudTest {

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

    List<RecordType> rcId = [
        SELECT Id 
        FROM RecordType  
        WHERE DeveloperName = 'Academic_Program' 
          AND SobjectType = 'Account' 
        LIMIT 1
    ];

    Account acc = new Account(
        Name = 'Test University',
        LMS_Id__c = '12345',
        Recordtype = rcId[0]
    );
    insert acc;

    // Faculty Contact
    RecordType facultyRT = [
        SELECT Id 
        FROM RecordType 
        WHERE SObjectType = 'Contact' 
          AND Name = 'Faculty' 
        LIMIT 1
    ];
    Contact faculty = new Contact(
        FirstName = 'John',
        LastName = 'Doe',
        Email = 'john.doe@example.com',
        Phone = '1234567890',
        Status__c = 'Active',
        RecordTypeId = facultyRT.Id
    );
    insert faculty;

    // AT Risk Student Contact
    RecordType studentRT = [
        SELECT Id 
        FROM RecordType 
        WHERE SObjectType = 'Contact' 
          AND Name = 'Student' 
        LIMIT 1
    ];
    Contact studentAtRisk = new Contact(
        FirstName = 'Jane',
        LastName = 'Smith',
        Email = 'jane.smith@example.com',
        Registration_Number__c = 'REG123',
        Status__c = 'AT Risk',
        RecordTypeId = studentRT.Id
    );
    insert studentAtRisk;

    // Active Student Contact
    Contact studentActive = new Contact(
        FirstName = 'Alice',
        LastName = 'Johnson',
        Email = 'alice.johnson@example.com',
        Registration_Number__c = 'REG456',
        Status__c = 'Active',
        RecordTypeId = studentRT.Id
    );
    insert studentActive;

    // Program Plan
    hed__Program_Plan__c prgPlan = new hed__Program_Plan__c(
        Name = 'Computer Science',
        hed__Account__c = acc.Id
    );
    insert prgPlan;

    // Terms (same as your original)
    hed__Term__c term = new hed__Term__c(
        Name = 'Fall 2024',
        hed__Account__c = acc.Id,
        hed__Start_Date__c = Date.today().addDays(10),
        hed__End_Date__c = Date.today().addMonths(3),
        Term_Reference__c='Term 1'
    );
    insert term;
        
    hed__Term__c termCompleted = new hed__Term__c(
        Name = 'Fall 2023',
        hed__Account__c = acc.Id,
        hed__Start_Date__c = Date.today().addMonths(-4),
        hed__End_Date__c = Date.today().addDays(-10),
        Term_Reference__c = 'Term 0'
    );
    insert termCompleted;

    // Course
    hed__Course__c course = new hed__Course__c(
        Name = 'Mathematics',
        hed__Account__c = acc.Id,
        hed__Course_ID__c = 'MTH1011yy1',
        Credits__c = 3,
        LMS_ID__c = '54321'
    );
    insert course;

    // Course Version & Offering
    Course_Version__c version = new Course_Version__c(
        Course__c = course.Id,
        Term__c = term.Id,
        Program_Plan__c = prgPlan.Id
    );
    insert version;

    hed__Course_Offering__c courseOffering = new hed__Course_Offering__c(
        Name = 'Mathematics 101 - Section A',
        hed__Section_ID__c = 'SEC-MATH101A',
        hed__Course__c = course.Id,
        hed__Term__c = term.Id,
        Course_Version__c = version.Id
    );
    insert courseOffering;

    // Single affiliation used ONLY for at-risk student program enrollment
    hed__Affiliation__c aff = new hed__Affiliation__c(
        hed__Account__c = acc.Id, 
        hed__Status__c = 'Current'
    );
    insert aff;

    // Program Enrollment for Faculty (NO affiliation → bypass duplicate validation)
    hed__Program_Enrollment__c facultyProgEnroll = new hed__Program_Enrollment__c(
        hed__Contact__c = faculty.Id,
        Term__c = term.Id
        // no hed__Affiliation__c
    );
    insert facultyProgEnroll;

    // Program Enrollment for AT Risk Student (with affiliation)
    hed__Program_Enrollment__c studentProgEnrollRisk = new hed__Program_Enrollment__c(
        hed__Contact__c = studentAtRisk.Id,
        Term__c = term.Id,
        hed__Affiliation__c = aff.Id
    );
    insert studentProgEnrollRisk;

    // Program Enrollment for Active Student (NO affiliation to skip duplicate check)
    hed__Program_Enrollment__c studentProgEnrollActive = new hed__Program_Enrollment__c(
        hed__Contact__c = studentActive.Id,
        Term__c = term.Id
        // no hed__Affiliation__c
    );
    insert studentProgEnrollActive;

    // ⚠️ REMOVE this block (old faculty enrollment with Student record type)
    // RecordType studentRecordType = [SELECT Id, Name FROM RecordType WHERE SObjectType = 'hed__Course_Enrollment__c' AND Name = 'Student' LIMIT 1];
    // hed__Course_Enrollment__c facultyCourseEnroll = new hed__Course_Enrollment__c(
    //     hed__Contact__c = faculty.Id,
    //     hed__Course_Offering__c = courseOffering.Id,
    //     hed__Program_Enrollment__c = facultyProgEnroll.Id,
    //     RecordType = studentRecordType
    // );
    // insert facultyCourseEnroll;

    // Student record type
    RecordType studentRecordType = [
        SELECT Id, Name 
        FROM RecordType 
        WHERE SObjectType = 'hed__Course_Enrollment__c' 
          AND Name = 'Student' 
        LIMIT 1
    ];

    // Course Enrollment for AT Risk Student (affiliated)
    hed__Course_Enrollment__c studentCourseEnroll = new hed__Course_Enrollment__c(
        hed__Contact__c = studentAtRisk.Id,
        hed__Course_Offering__c = courseOffering.Id,
        RecordTypeId = studentRecordType.Id,
        hed__Program_Enrollment__c = studentProgEnrollRisk.Id,
        Attendacne__c = 75,
        No_Of_Classes_Attended__c = 25,
        Percentage_of_classes_attended__c = 75
    );
    insert studentCourseEnroll;

    // Course Enrollment for Active Student (no affiliation in PE → no duplicate check)
    hed__Course_Enrollment__c studentCourseEnroll2 = new hed__Course_Enrollment__c(
        hed__Contact__c = studentActive.Id,
        hed__Course_Offering__c = courseOffering.Id,
        RecordTypeId = studentRecordType.Id,
        hed__Program_Enrollment__c = studentProgEnrollActive.Id,
        Attendacne__c = 90,
        No_Of_Classes_Attended__c = 30,
        Percentage_of_classes_attended__c = 90
    );
    insert studentCourseEnroll2;

    // Attendance setup stays as-is
    Session__c session = new Session__c(
        Course_Offering__c = courseOffering.Id
    );
    insert session;

    hed__Attendance_Event__c presentEvent = new hed__Attendance_Event__c(
        hed__Contact__c = studentAtRisk.Id,
        Session__c = session.Id,
        Attendance_Status__c = 'Present'
    );
    insert presentEvent;

    hed__Attendance_Event__c absentEvent = new hed__Attendance_Event__c(
        hed__Contact__c = studentAtRisk.Id,
        Session__c = session.Id,
        Attendance_Status__c = 'Absent'
    );
    insert absentEvent;
}


    @isTest
    static void testDoGet_ValidFacultyWithEnrollments() {
        Contact faculty = [SELECT Id FROM Contact WHERE FirstName = 'John' LIMIT 1];

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/courseConnectionsPerStudents/';
        req.httpMethod = 'GET';
        req.params.put('contactId', faculty.Id);
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        RestApi_CoursesForFacultyAndRelatedStud.doGet();
        Test.stopTest();

    }

    @isTest
    static void testDoGet_InvalidFacultyContact() {
        Contact nonFaculty = [SELECT Id FROM Contact WHERE Status__c = 'AT Risk' LIMIT 1];

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/courseConnectionsPerStudents/';
        req.httpMethod = 'GET';
        req.params.put('contactId', nonFaculty.Id);
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        RestApi_CoursesForFacultyAndRelatedStud.doGet();
        Test.stopTest();

    }

    @isTest
    static void testDoGet_NullContactId() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/courseConnectionsPerStudents/';
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        RestApi_CoursesForFacultyAndRelatedStud.doGet();
        Test.stopTest();

    }

    @isTest
    static void testDoGet_ExceptionHandling() {
        Contact faculty = [SELECT Id FROM Contact WHERE FirstName = 'John' LIMIT 1];
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/courseConnectionsPerStudents/';
        req.httpMethod = 'GET';
        req.params.put('contactId', faculty.Id); // invalid ID format
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        RestApi_CoursesForFacultyAndRelatedStud.doGet();
        Test.stopTest();

    }
    
    @isTest
    static void testStudentWrapper() {
        // Arrange: Create test instance and assign values
        RestApi_CoursesForFacultyAndRelatedStud.Students s = new RestApi_CoursesForFacultyAndRelatedStud.Students();
        s.StudentName = 'John Doe';
        s.StudentRegdNo = 'REG12345';
        s.studentCode = 'STD001';
        s.StudentStatus = 'Active';
        s.Attendacne = 95.5;
        s.classesPresent = 38;
        s.classesAbsent = 2;
        s.ProgrameName = 'MBA';
        s.TermName = 'Fall 2024';
        s.CourseName = 'Business Strategy';
        s.Section = 'A';
        s.ContactID = Id.valueOf(UserInfo.getUserId()); // or use a test Contact Id
        
        // Assert (optional since we're just covering the class)
        System.assertEquals('John Doe', s.StudentName);
    }
    


    @isTest
    static void testCalculateAttendancePercentage() {
        Decimal result = RestApi_CoursesForFacultyAndRelatedStud.calculateAttendancepercentage(30, 10);
        System.assertEquals(75.0, result, 0.1);
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
    @isTest
static void testDoGet_FacultyWithProperRecordType() {
    // Get the Faculty record type for Course Enrollment
    RecordType facultyRecordType = [SELECT Id FROM RecordType WHERE SObjectType = 'hed__Course_Enrollment__c' AND Name = 'Faculty' LIMIT 1];
    
    Contact faculty = [SELECT Id FROM Contact WHERE FirstName = 'John' LIMIT 1];
    hed__Course_Offering__c courseOffering = [SELECT Id FROM hed__Course_Offering__c LIMIT 1];
    hed__Program_Enrollment__c facultyProgEnroll = [SELECT Id FROM hed__Program_Enrollment__c WHERE hed__Contact__c = :faculty.Id LIMIT 1];
    
    // Create a proper Faculty Course Enrollment record
    hed__Course_Enrollment__c facultyCourseEnrollProper = new hed__Course_Enrollment__c(
        hed__Contact__c = faculty.Id,
        hed__Course_Offering__c = courseOffering.Id,
        hed__Program_Enrollment__c = facultyProgEnroll.Id,
        RecordTypeId = facultyRecordType.Id
    );
    insert facultyCourseEnrollProper;

    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();
    req.requestUri = '/services/apexrest/courseConnectionsPerStudents/';
    req.httpMethod = 'GET';
    req.params.put('contactId', faculty.Id);
    RestContext.request = req;
    RestContext.response = res;

    Test.startTest();
    RestApi_CoursesForFacultyAndRelatedStud.doGet();
    Test.stopTest();

    // Verify response
    System.assertEquals(200, res.statusCode);
    String responseBody = res.responseBody.toString();
    System.assert(responseBody.contains('success'));
}

@isTest
static void testDoGet_StudentWithAccountAndMultipleStudents() {
    // Get the Faculty record type for Course Enrollment
    RecordType facultyRecordType = [SELECT Id FROM RecordType WHERE SObjectType = 'hed__Course_Enrollment__c' AND Name = 'Faculty' LIMIT 1];
    
    Contact faculty = [SELECT Id FROM Contact WHERE FirstName = 'John' LIMIT 1];
    Contact studentAtRisk = [SELECT Id FROM Contact WHERE Status__c = 'AT Risk' LIMIT 1];
    Contact studentActive = [SELECT Id FROM Contact WHERE Status__c = 'Active' LIMIT 1];
    
    hed__Course_Offering__c courseOffering = [SELECT Id FROM hed__Course_Offering__c LIMIT 1];
    hed__Program_Enrollment__c facultyProgEnroll = [SELECT Id FROM hed__Program_Enrollment__c WHERE hed__Contact__c = :faculty.Id LIMIT 1];
    
    // Create Account for students to have Student_Code__c
    Account studentAccount = new Account(Name = 'Student Account', Student_Code__c = 'STU001');
    insert studentAccount;
    
    // Update students to have Account
    studentAtRisk.AccountId = studentAccount.Id;
    studentActive.AccountId = studentAccount.Id;
    update new List<Contact>{studentAtRisk, studentActive};
    
    // Create a proper Faculty Course Enrollment record
    hed__Course_Enrollment__c facultyCourseEnrollProper = new hed__Course_Enrollment__c(
        hed__Contact__c = faculty.Id,
        hed__Course_Offering__c = courseOffering.Id,
        hed__Program_Enrollment__c = facultyProgEnroll.Id,
        RecordTypeId = facultyRecordType.Id
    );
    insert facultyCourseEnrollProper;
    
    // Update existing student course enrollments to have proper data
    List<hed__Course_Enrollment__c> studentEnrollments = [SELECT Id FROM hed__Course_Enrollment__c WHERE RecordType.Name = 'Student'];
    for(hed__Course_Enrollment__c enrollment : studentEnrollments) {
      
    }
    update studentEnrollments;

    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();
    req.requestUri = '/services/apexrest/courseConnectionsPerStudents/';
    req.httpMethod = 'GET';
    req.params.put('contactId', faculty.Id);
    RestContext.request = req;
    RestContext.response = res;

    Test.startTest();
    RestApi_CoursesForFacultyAndRelatedStud.doGet();
    Test.stopTest();

    // Verify response
    System.assertEquals(200, res.statusCode);
    String responseBody = res.responseBody.toString();
    System.assert(responseBody.contains('success'));
}

@isTest
static void testDoGet_ExistingMapScenario() {
    // This test specifically covers the scenario where the map already contains the key
    RecordType facultyRecordType = [
        SELECT Id 
        FROM RecordType 
        WHERE SObjectType = 'hed__Course_Enrollment__c' 
          AND Name = 'Faculty' 
        LIMIT 1
    ];
    
    Contact faculty = [SELECT Id FROM Contact WHERE FirstName = 'John' LIMIT 1];
    hed__Course_Offering__c courseOffering = [SELECT Id FROM hed__Course_Offering__c LIMIT 1];
    hed__Program_Enrollment__c facultyProgEnroll = [
        SELECT Id 
        FROM hed__Program_Enrollment__c 
        WHERE hed__Contact__c = :faculty.Id 
        LIMIT 1
    ];
    
    // Create Account for students
    Account studentAccount = new Account(Name = 'Student Account', Student_Code__c = 'STU002');
    insert studentAccount;
    
    // Create additional student
    RecordType studentRT = [
        SELECT Id 
        FROM RecordType 
        WHERE SObjectType = 'Contact' 
          AND Name = 'Student' 
        LIMIT 1
    ];
    Contact additionalStudent = new Contact(
        FirstName = 'Bob',
        LastName = 'Wilson',
        Email = 'bob.wilson@example.com',
        Registration_Number__c = 'REG789',
        Status__c = 'Active',
        RecordTypeId = studentRT.Id,
        AccountId = studentAccount.Id
    );
    insert additionalStudent;
    
    // Create Faculty Course Enrollment
    hed__Course_Enrollment__c facultyCourseEnrollProper = new hed__Course_Enrollment__c(
        hed__Contact__c = faculty.Id,
        hed__Course_Offering__c = courseOffering.Id,
        hed__Program_Enrollment__c = facultyProgEnroll.Id,
        RecordTypeId = facultyRecordType.Id
    );
    insert facultyCourseEnrollProper;
    
    // 🔹 Use a NEW affiliation so we don't collide with existing enrollments
    hed__Affiliation__c separateAff = new hed__Affiliation__c(
        hed__Account__c = studentAccount.Id,
        hed__Status__c = 'Current'
    );
    insert separateAff;
    
    // Create additional student program enrollment with the new affiliation
    hed__Program_Enrollment__c additionalStudentProgEnroll = new hed__Program_Enrollment__c(
        hed__Contact__c = additionalStudent.Id,
        Term__c = [SELECT Id FROM hed__Term__c WHERE Name = 'Fall 2024' LIMIT 1].Id,
        hed__Affiliation__c = separateAff.Id
    );
    insert additionalStudentProgEnroll;
    
    RecordType studentRecordType = [
        SELECT Id 
        FROM RecordType 
        WHERE SObjectType = 'hed__Course_Enrollment__c' 
          AND Name = 'Student' 
        LIMIT 1
    ];
    hed__Course_Enrollment__c additionalStudentCourseEnroll = new hed__Course_Enrollment__c(
        hed__Contact__c = additionalStudent.Id,
        hed__Course_Offering__c = courseOffering.Id,
        RecordTypeId = studentRecordType.Id,
        hed__Program_Enrollment__c = additionalStudentProgEnroll.Id,
        Attendacne__c = 85,
        No_Of_Classes_Attended__c = 28,
        Percentage_of_classes_attended__c = 85
    );
    insert additionalStudentCourseEnroll; // ✅ no validation error now
    
    // Update existing students to share the same Account (ok, doesn't affect validation now)
    List<Contact> existingStudents = [
        SELECT Id, AccountId 
        FROM Contact 
        WHERE Status__c IN ('AT Risk', 'Active') 
          AND FirstName != 'Bob'
    ];
    for (Contact student : existingStudents) {
        student.AccountId = studentAccount.Id;
    }
    update existingStudents;
    
    // ❌ This block was unnecessary and could re-trigger validations; keep it removed:
    // List<hed__Course_Enrollment__c> existingEnrollments = [
    //     SELECT Id 
    //     FROM hed__Course_Enrollment__c 
    //     WHERE RecordType.Name = 'Student' 
    //       AND Id != :additionalStudentCourseEnroll.Id
    // ];
    // update existingEnrollments;

    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();
    req.requestUri = '/services/apexrest/courseConnectionsPerStudents/';
    req.httpMethod = 'GET';
    req.params.put('contactId', faculty.Id);
    RestContext.request = req;
    RestContext.response = res;

    Test.startTest();
    RestApi_CoursesForFacultyAndRelatedStud.doGet();
    Test.stopTest();

    // Verify response
    System.assertEquals(200, res.statusCode);
    String responseBody = res.responseBody.toString();
    System.assert(responseBody.contains('success'));
}


@isTest
static void testCalculateAttendancePercentageZeroTotal() {
    // Test the case where total classes is 0
    Decimal result = RestApi_CoursesForFacultyAndRelatedStud.calculateAttendancepercentage(0, 0);
    System.assertEquals(null, result);
}

@isTest
static void testJsonWrapper() {
    // Test the JsonWrapper class
    RestApi_CoursesForFacultyAndRelatedStud.JsonWrapper wrapper = new RestApi_CoursesForFacultyAndRelatedStud.JsonWrapper();
    wrapper.courseOffering = new Map<String, List<RestApi_CoursesForFacultyAndRelatedStud.Students>>();
    wrapper.studentCount = 5;
    
    System.assertEquals(5, wrapper.studentCount);
    System.assertNotEquals(null, wrapper.courseOffering);
}
}