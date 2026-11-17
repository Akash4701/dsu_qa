@isTest
public class RestApi_GetSessionTest {

    @testSetup
    static void setupData() {
        
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
        Account acc = new Account(Name = 'Test Account',LMS_Id__c = '12345');
        insert acc;

        // Create Contact
        Contact contact = new Contact(LastName = 'TestContact');
        insert contact;

        // Create Term
        hed__Term__c term = new hed__Term__c(
            Name = 'Test Term',
            hed__Account__c = acc.Id,
            Term_Reference__c = 'TR123'
        );
        insert term;

        // Create Course
        hed__Course__c course = new hed__Course__c(
            Name = 'Test Course',
            hed__Account__c = acc.Id,
            hed__Course_ID__c = 'TC001',
            LMS_ID__c = '54321'
        );
        insert course;

        // Create Course Version
        Course_Version__c courseVersion = new Course_Version__c(
            Course__c = course.Id,
            Term__c = term.Id,
            Start_Date__c = System.today(),
            End_Date__c = System.today() + 30
        );
        insert courseVersion;

        // Create Affiliation
        hed__Affiliation__c affiliation = new hed__Affiliation__c(
            hed__Account__c = acc.Id,
            hed__Contact__c = contact.Id,
            hed__Role__c = 'Student',
            hed__StartDate__c = System.today(),
            hed__EndDate__c = System.today() + 365,
            hed__Status__c = 'Current'
        );
        insert affiliation;

        // Create Program Enrollment
        hed__Program_Enrollment__c programEnrollment = new hed__Program_Enrollment__c(
            hed__Contact__c = contact.Id,
            Term__c = term.Id,
            hed__Affiliation__c = affiliation.Id
        );
        insert programEnrollment;

        // Create Course Offering
        hed__Course_Offering__c courseOffering = new hed__Course_Offering__c(
            hed__Course__c = course.Id,
            hed__Section_ID__c = 'SEC1',
            hed__Term__c = term.Id,
            Course_Version__c = courseVersion.Id
        );
        insert courseOffering;

        // Create Course Enrollment
        hed__Course_Enrollment__c courseEnrollment = new hed__Course_Enrollment__c(
            hed__Contact__c = contact.Id,
            hed__Course_Offering__c = courseOffering.Id,
            ST__c = 'InProgress',
            hed__Program_Enrollment__c = programEnrollment.Id
        );
        insert courseEnrollment;

        // Create Facility
        hed__facility__c facility = new hed__facility__c(Name = 'Test Facility');
        insert facility;

        // Create Faculty Booking
        Faculty_Booking__c facultyBooking = new Faculty_Booking__c(
            Booked_By__c = contact.Id,
            Course_Version__c = courseVersion.Id,
            Facility__c = facility.Id
        );
        insert facultyBooking;

        // Create Facility Booking
        Facility_Booking__c facilityBooking = new Facility_Booking__c(
            FacilityID__c = facility.Id,
            Start_Date_and_Time__c = DateTime.now(),
            End_Date_and_Time__c = DateTime.now().addHours(2)
        );
        insert facilityBooking;

        // Create Session
        Id sessionRecordTypeId = Schema.SObjectType.Session__c.getRecordTypeInfosByName()
            .get('Recess')
            .getRecordTypeId();

        Session__c session = new Session__c(
         //   Name = 'Test Session',
            Course_Offering__c = courseOffering.Id,
            Faculty__c = contact.Id,
            Start_Date_Time__c = DateTime.newInstance(2024, 7, 15, 12, 0, 0),
            End_Date_Time__c = DateTime.newInstance(2024, 7, 15, 13, 0, 0),
            Facility__c = facility.Id,
            Mode_of_Delivery__c = 'Online',
            Attendance_Marked__c = true,
            recordTypeId = sessionRecordTypeId,
            Type_of_Activity__c = 'Teaching',
            Faculty_Booking__c = facultyBooking.Id,
            Facility_Booking__c = facilityBooking.Id,
            TimeZone__c = 'America/New_York'
            //Session_StartTime__c = '09:00 AM',
          //  Session_EndTime__c = '10:00 AM'
        );
        insert session;

        // Create Attendance Events
        List<hed__Attendance_Event__c> attEvents = new List<hed__Attendance_Event__c>();
        attEvents.add(new hed__Attendance_Event__c(
            hed__Contact__c = contact.Id,
            hed__Course_Connection__c = courseEnrollment.Id,
            hed__Date__c = Date.today(),
            Session__c = session.Id,
            Attendance_Status__c = 'Present'
        ));
        attEvents.add(new hed__Attendance_Event__c(
            hed__Contact__c = contact.Id,
            hed__Course_Connection__c = courseEnrollment.Id,
            hed__Date__c = Date.today(),
            Session__c = session.Id
        ));
        insert attEvents;
    }

    @isTest
    static void testAllScenarios() {
        Test.startTest();
        List<Contact> contacts = [SELECT Id FROM Contact];
        List<Session__c> sessions = [SELECT Id FROM Session__c];
        List<hed__Course_Offering__c> offerings = [SELECT Id FROM hed__Course_Offering__c];
        List<hed__Term__c> terms = [SELECT Id FROM hed__Term__c];
        List<hed__facility__c> facilities = [SELECT Id FROM hed__facility__c];

        Contact testContact = contacts[0];
        Session__c testSession = sessions[0];
        hed__Course_Offering__c testOffering = offerings[0];
        hed__Term__c testTerm = terms[0];
        hed__facility__c testFacility = facilities[0];

        // Test Case 1: Full Query with all parameters
        callRestEndpoint(testContact.Id, testOffering.Id, testTerm.Id, testFacility.Id, testContact.Id,
                         '2024-07-10T00:00:00', '2024-07-20T23:59:59', 'true');

        // Test Case 2: No attendance filter
        callRestEndpoint(testContact.Id, null, null, null, testContact.Id,
                         '2024-07-10T00:00:00', '2024-07-20T23:59:59', null);

        // Test Case 3: Only contactId provided
        callRestEndpoint(null, null, null, null, testContact.Id, null, null, null);

        // Test Case 4: Only facultyId
        callRestEndpoint(testContact.Id, null, null, null, null, null, null, null);

        // Test Case 5: Invalid query or exception scenario
        try {
            callRestEndpoint('invalidId', 'invalidId', 'invalidId', 'invalidId', 'invalidId',
                             '2024-01-01T00:00:00', '2024-01-02T00:00:00', 'true');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('Query failed'));
        }

        Test.stopTest();
    }

    static void callRestEndpoint(String facultyId, String courseOfferingId, String termId,
                                 String facilityId, String contactId, String startDate,
                                 String endDate, String attendance) {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/SessionData/';
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = res;

        if (facultyId != null) req.params.put('facultyId', facultyId);
        if (courseOfferingId != null) req.params.put('courseOfferingId', courseOfferingId);
        if (termId != null) req.params.put('termId', termId);
        if (facilityId != null) req.params.put('facilityId', facilityId);
        if (contactId != null) req.params.put('contactId', contactId);
        if (startDate != null) req.params.put('startDate', startDate);
        if (endDate != null) req.params.put('endDate', endDate);
        if (attendance != null) req.params.put('attendance', attendance);

        try {
            RestApi_GetSession.doGetSessionData();
        } catch (Exception e) {
            // Expected in some error cases
        }
    }
        @isTest
    static void testSendCoursesSuccess() {
        Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());
        
        List<hed__Course__c> courses = [SELECT Id FROM hed__Course__c LIMIT 1];
        List<Id> courseIds = new List<Id>();
        for (hed__Course__c course : courses) {
            courseIds.add(course.Id);
        }
        
        Test.startTest();
        CourseCalloutHandler.sendCourses(courseIds);
        Test.stopTest();
        
        hed__Course__c updatedCourse = [SELECT Id, LMS_Id__c FROM hed__Course__c WHERE Id = :courses[0].Id];
    }
    
    @isTest
    static void testSendCoursesFailure() {
        Test.setMock(HttpCalloutMock.class, new FailureHttpMock());
        
        List<hed__Course__c> courses = [SELECT Id FROM hed__Course__c LIMIT 1];
        List<Id> courseIds = new List<Id>();
        for (hed__Course__c course : courses) {
            courseIds.add(course.Id);
        }
        
        Test.startTest();
        System.enqueueJob(new CourseCalloutQueueable(courseIds));
        Test.stopTest();
        
        hed__Course__c updatedCourse = [SELECT Id, LMS_Id__c FROM hed__Course__c WHERE Id = :courses[0].Id];
     //   System.assertEquals(null, updatedCourse.LMS_Id__c);
    }
    
    @isTest
    static void testSendCoursesNoDataInResponse() {
        Test.setMock(HttpCalloutMock.class, new NoDataHttpMock());
        
        List<hed__Course__c> courses = [SELECT Id FROM hed__Course__c LIMIT 1];
        List<Id> courseIds = new List<Id>();
        for (hed__Course__c course : courses) {
            courseIds.add(course.Id);
        }
        
        Test.startTest();
        System.enqueueJob(new CourseCalloutQueueable(courseIds));
        Test.stopTest();
        
        hed__Course__c updatedCourse = [SELECT Id, LMS_Id__c FROM hed__Course__c WHERE Id = :courses[0].Id];
    //    System.assertEquals(null, updatedCourse.LMS_Id__c);
    }
    
    public class CourseCalloutQueueable implements Queueable, Database.AllowsCallouts {
        private List<Id> courseIds;
        
        public CourseCalloutQueueable(List<Id> courseIds) {
            this.courseIds = courseIds;
        }
        
        public void execute(QueueableContext context) {
            CourseCalloutHandler.sendCourses(courseIds);
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