@isTest
private class RestApi_AttendanceByStudentTest {
    
    @testSetup
    static void setup() {
        
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

        Account account = new Account(
            Name = 'test',
            LMS_Id__c = '12345'
        );
        insert account;
        // Create a contact
        Contact contact = new Contact(FirstName = 'Test', LastName = 'Contact');
        insert contact;
        
    }
    
    @isTest
    static void testGetAttendanceEvents() {
         Test.setMock(HttpCalloutMock.class, new MockEnrollmentRespBBClass());
        Account acc= [SELECT Id FROM Account LIMIT 1];
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];

        // Create test Term record
        hed__Term__c testTerm = new  hed__Term__c(Name = 'Test Term',hed__Account__c=acc.id, Term_Reference__c='Term 1',hed__Start_Date__c =System.today() + 10,hed__End_Date__c=System.today() + 100 );
        insert testTerm;
        
        hed__Facility__c facility = new hed__Facility__c(Name = 'test');
        insert facility;
        
        hed__Affiliation__c affRec=new hed__Affiliation__c();
        affRec.hed__Account__c=acc.id;
        affRec.hed__Contact__c=testContact.id;
        affRec.hed__Role__c='Student';
        affRec.hed__StartDate__c=system.today()+10;
        affRec.hed__EndDate__c=system.today()+1000;
        affRec.hed__Status__c='Current';
        insert affRec;

        
          hed__Program_Plan__c pp = new hed__Program_Plan__c(Name = 'test');
        insert pp;

        // Create test Program Enrollment record
        hed__Program_Enrollment__c testProgramEnrollment = new hed__Program_Enrollment__c(
            hed__Contact__c = testContact.Id,
            Term__c = testTerm.Id
        );
        insert testProgramEnrollment;
        
        // Create test Course records
        hed__Course__c testCourseMandatory = new hed__Course__c(Name = 'Mandatory Course', hed__Course_ID__c = 'TC001', Credits__c = 3, hed__Credit_Hours__c = 3,hed__Account__c=acc.id, LMS_ID__c = '54321');
        insert testCourseMandatory;
        
       

        // Create test Course Offering records
        hed__Course_Offering__c testCourseOfferingMandatory = new hed__Course_Offering__c(
            hed__Course__c = testCourseMandatory.Id,
            hed__Section_ID__c = 'M01',
            hed__Term__c=testTerm.id
        );
        insert testCourseOfferingMandatory;
        
       

        // Create test Course Enrollment records
        hed__Course_Enrollment__c testCourseEnrollmentMandatory = new hed__Course_Enrollment__c(
            hed__Contact__c = testContact.Id,
            hed__Course_Offering__c = testCourseOfferingMandatory.Id,
            hed__Program_Enrollment__c = testProgramEnrollment.Id,
            ST__c = 'InProgress'
        );
        insert testCourseEnrollmentMandatory;
        
      
        
         Session__c testSession = new Session__c(Course_Offering__c = testCourseOfferingMandatory.Id, Start_Date_Time__c = DateTime.now().addDays(1), End_Date_Time__c = DateTime.now().addDays(2).addHours(2), Select_Days__c = 'Monday', Faculty__c = testContact.id, Frequency__c = 'Weekly', RRule_String__c = 'FREQ=WEEKLY;BYDAY=MO,TU', Term__c = testTerm.id, Program_Plan__c = pp.id, Institute__c = acc.id, Facility__c = facility.id, Mode_of_Delivery__c = 'Online');
        insert testSession;


        // Create test Attendance Event records
        hed__Attendance_Event__c testAttendanceEvent1 = new hed__Attendance_Event__c(
            Attendance_Status__c = 'Present',
            Session__c = testSession.Id,
            hed__Contact__c = testContact.Id,
            Course_Offering__c=testCourseOfferingMandatory.id
        );
        insert testAttendanceEvent1;

        hed__Attendance_Event__c testAttendanceEvent2 = new hed__Attendance_Event__c(
            Attendance_Status__c = 'Absent',
               Session__c = testSession.Id,
            hed__Contact__c = testContact.Id,
             Course_Offering__c=testCourseOfferingMandatory.id
        );
        insert testAttendanceEvent2;
        
        RestApi_AttendanceByStudent.dataClass wrapper=new RestApi_AttendanceByStudent.dataClass();
        wrapper.status ='Present';
        wrapper.arrivalTime = string.ValueOf( Time.newInstance(9, 0, 0, 0));
        wrapper.attendanceType = 'Class Tardy';
        wrapper.contact = testContact.id;
        wrapper.courseConnection = testCourseEnrollmentMandatory.id;
        wrapper.courseName = 'Mathematics';
        wrapper.evntDate = string.ValueOf(Date.newInstance(2023, 7, 23));
        wrapper.startTime = string.ValueOf(Time.newInstance(10, 0, 0, 0));
        wrapper.endtime = string.ValueOf(Time.newInstance(12, 0, 0, 0));
        wrapper.resonDescription =  'Medical appointment';
        wrapper.reason = 'Excused';
        wrapper.sessionStartDate = String.valueOf(DateTime.newInstance(2023, 7, 23, 10, 0, 0));
        wrapper.sessionEndDate = String.valueOf(DateTime.newInstance(2023, 7, 23, 12, 0, 0));
            
        
        // Valid parameters
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/attendancebyStudent';
        req.httpMethod = 'GET';
        req.addParameter('contactId', testContact.Id);
        req.addParameter('startDate', '2023-01-01T00:00:00.000Z');
        req.addParameter('endDate', '2023-12-31T23:59:59.999Z');
        RestContext.request = req;
        
        RestResponse res = new RestResponse();
        RestContext.response = res;
        
        RestApi_AttendanceByStudent.gettingAttendanceEvents();
        
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
	@isTest static void testNoDataFoundScenario() {
    // Simulate request with invalid contactId (no matching records)
    RestRequest req = new RestRequest();
    req.requestUri = '/services/apexrest/attendancebyStudent';
    req.httpMethod = 'GET';
    req.addParameter('contactId', '003000000000000'); // Invalid or non-existent ID
    req.addParameter('startDate', '2023-01-01T00:00:00.000Z');
    req.addParameter('endDate', '2023-12-31T23:59:59.999Z');

    RestContext.request = req;
    RestContext.response = new RestResponse();

    Test.startTest();
    RestApi_AttendanceByStudent.gettingAttendanceEvents();
    Test.stopTest();

    // Verify response is as expected when no data is found
    System.assertEquals('{"success": "false" ,"message" : "No Data Found"}', 
                        RestContext.response.responseBody.toString());
}
    @isTest
static void testGetAttendanceEventsWithMatchingQuery() {
    Test.setMock(HttpCalloutMock.class, new MockEnrollmentRespBBClass());
    Account acc = [SELECT Id FROM Account LIMIT 1];
    Contact testContact = [SELECT Id FROM Contact LIMIT 1];

    // Create test Term record
    hed__Term__c testTerm = new hed__Term__c(Name = 'Test Term', hed__Account__c = acc.id, Term_Reference__c = 'Term 1', hed__Start_Date__c = System.today() + 10, hed__End_Date__c = System.today() + 100);
    insert testTerm;
    
    hed__Facility__c facility = new hed__Facility__c(Name = 'test');
    insert facility;
    
    hed__Affiliation__c affRec = new hed__Affiliation__c();
    affRec.hed__Account__c = acc.id;
    affRec.hed__Contact__c = testContact.id;
    affRec.hed__Role__c = 'Student';
    affRec.hed__StartDate__c = system.today() + 10;
    affRec.hed__EndDate__c = system.today() + 1000;
    affRec.hed__Status__c = 'Current';
    insert affRec;

    hed__Program_Plan__c pp = new hed__Program_Plan__c(Name = 'test');
    insert pp;

    // Create test Program Enrollment record
    hed__Program_Enrollment__c testProgramEnrollment = new hed__Program_Enrollment__c(
        hed__Contact__c = testContact.Id,
        Term__c = testTerm.Id
    );
    insert testProgramEnrollment;
    
    // Create test Course records
    hed__Course__c testCourseMandatory = new hed__Course__c(Name = 'Mandatory Course', hed__Course_ID__c = 'TC001', Credits__c = 3, hed__Credit_Hours__c = 3, hed__Account__c = acc.id, LMS_ID__c = '54321');
    insert testCourseMandatory;

    // Create test Course Offering records
    hed__Course_Offering__c testCourseOfferingMandatory = new hed__Course_Offering__c(
        hed__Course__c = testCourseMandatory.Id,
        hed__Section_ID__c = 'M01',
        hed__Term__c = testTerm.id
    );
    insert testCourseOfferingMandatory;

    // Create test Course Enrollment records
    hed__Course_Enrollment__c testCourseEnrollmentMandatory = new hed__Course_Enrollment__c(
        hed__Contact__c = testContact.Id,
        hed__Course_Offering__c = testCourseOfferingMandatory.Id,
        hed__Program_Enrollment__c = testProgramEnrollment.Id,
        ST__c = 'InProgress'
    );
    insert testCourseEnrollmentMandatory;

    // Create session with proper date range
    DateTime sessionStart = DateTime.newInstance(2023, 6, 15, 10, 0, 0);
    DateTime sessionEnd = DateTime.newInstance(2023, 6, 15, 12, 0, 0);
    
    Session__c testSession = new Session__c(
        Course_Offering__c = testCourseOfferingMandatory.Id, 
        Start_Date_Time__c = sessionStart, 
        End_Date_Time__c = sessionEnd, 
        Select_Days__c = 'Monday', 
        Faculty__c = testContact.id, 
        Frequency__c = 'Weekly', 
        RRule_String__c = 'FREQ=WEEKLY;BYDAY=MO,TU', 
        Term__c = testTerm.id, 
        Program_Plan__c = pp.id, 
        Institute__c = acc.id, 
        Facility__c = facility.id, 
        Mode_of_Delivery__c = 'Online'
    );
    insert testSession;

    // Create attendance event with all required fields populated to match the query
    hed__Attendance_Event__c testAttendanceEvent = new hed__Attendance_Event__c(
        Attendance_Status__c = 'Present',
        Session__c = testSession.Id,
        hed__Contact__c = testContact.Id,
        Course_Offering__c = testCourseOfferingMandatory.Id,
        hed__Arrival_Time__c = Time.newInstance(9, 30, 0, 0),
        hed__Attendance_Type__c = 'Class Present',
        hed__Course_Connection__c = testCourseEnrollmentMandatory.Id,
       
        hed__Date__c = Date.newInstance(2023, 6, 15),
        hed__Start_Time__c = Time.newInstance(10, 0, 0, 0),
        hed__End_Time__c = Time.newInstance(12, 0, 0, 0),
        
        hed__Reason_Description__c = 'Regular attendance',
        hed__Reason__c = 'Present'
    );
    insert testAttendanceEvent;
    
    // Set up REST context with parameters that will match the query
    RestRequest req = new RestRequest();
    req.requestUri = '/services/apexrest/attendancebyStudent';
    req.httpMethod = 'GET';
    req.addParameter('contactId', testContact.Id);
    req.addParameter('courseOfferingId', testCourseOfferingMandatory.Id);
    req.addParameter('startDate', '2023-06-01T00:00:00.000Z');
    req.addParameter('endDate', '2023-06-30T23:59:59.999Z');
    RestContext.request = req;
    
    RestResponse res = new RestResponse();
    RestContext.response = res;
    
    // Call the method
    RestApi_AttendanceByStudent.gettingAttendanceEvents();
    
    // Verify the response
    String responseBody = res.responseBody.toString();
   // System.assert(responseBody.contains('success'), 'Response should contain success');
   // System.assert(responseBody.contains('Mathematics'), 'Response should contain the subject name');
}
}