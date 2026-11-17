@IsTest
private class SessionTriggerHandler_Test {

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
        Account testAccount = new Account(Name = 'Test University',LMS_Id__c = '12345');
        insert testAccount;

        // Create Campus (hed__Campus__c) - assumed custom object if needed
        Campus__c campus = new Campus__c(Name = 'Main Campus',Campus_ID__c=testAccount.id);
        insert campus;

        // Create hed__Affiliation__c
        hed__Affiliation__c affiliation = new hed__Affiliation__c(hed__Status__c = 'Current');
        insert affiliation;

        // Create Contact (Faculty)
        Contact facultyContact = new Contact(
            FirstName = 'John',
            LastName = 'Doe',
            Email = 'johndoe@example.com'
        );
        insert facultyContact;

        // Create hed__Program_Enrollment__c
        hed__Program_Enrollment__c programEnrollment = new hed__Program_Enrollment__c(
            hed__Account__c = testAccount.Id,
            hed__Contact__c = facultyContact.Id,
            hed__Affiliation__c = affiliation.Id
        );
        insert programEnrollment;

        // Create hed__Course__c
        hed__Course__c course = new hed__Course__c(
            Name = 'Math 101',
            hed__Account__c = testAccount.Id,
             hed__Course_ID__c = 'TC001',
                        LMS_ID__c = '54321'

        );
        insert course;
        
       

        // Create hed__Term__c
        hed__Term__c term = new hed__Term__c(
            Name = 'Spring 2025',
            hed__Start_Date__c = Date.today(),
            hed__End_Date__c = Date.today().addMonths(3),
            hed__Account__c = testAccount.Id,
            Term_Reference__c='Term 1',
            Campus__c=campus.id
        );
        insert term;

        // Create hed__Course_Offering__c
        hed__Course_Offering__c courseOffering = new hed__Course_Offering__c(
            hed__Course__c = course.Id,
            hed__Term__c = term.Id,
            hed__Section_ID__c='test',
            Name='test123'
        );
        insert courseOffering;

        // Create hed__Facility__c
        hed__Facility__c facility = new hed__Facility__c(
            Name = 'Room A101'
        );
        insert facility;
        
  

              EmailTemplate sessionEmail = [
    SELECT Id, Name, DeveloperName, Subject ,HtmlValue
    FROM EmailTemplate 
    LIMIT 1
];
        
          EmailTemplate rescheduleEmail = [
    SELECT Id, Name, DeveloperName, Subject ,HtmlValue
    FROM EmailTemplate 
    LIMIT 1
];


 EmailTemplate cancelEmail = [
    SELECT Id, Name, DeveloperName, Subject ,HtmlValue
    FROM EmailTemplate 
    LIMIT 1
];

      


      


    }

    @IsTest
    static void test_sessions_Insert_New_Session() {
        Test.startTest();
        Session__c session = new Session__c(
            Course_Offering__c = [SELECT Id FROM hed__Course_Offering__c LIMIT 1].Id,
            Faculty__c = [SELECT Id FROM Contact WHERE Email = 'johndoe@example.com' LIMIT 1].Id,
            Start_Date_Time__c = DateTime.now().addHours(1),
            End_Date_Time__c = DateTime.now().addHours(2),
            Facility__c = [SELECT Id FROM hed__Facility__c LIMIT 1].Id,
            Mode_of_Delivery__c = 'Online',
            Type_of_Activity__c = 'Teaching'
        );
        insert session;
        Test.stopTest();

        // Verify email sent
     //   System.assertEquals(1, Test.getEmails().size());
    }

    @IsTest
    static void test_sessions_Update_Session_Reschedule() {
        Session__c session = new Session__c(
            Course_Offering__c = [SELECT Id FROM hed__Course_Offering__c LIMIT 1].Id,
            Faculty__c = [SELECT Id FROM Contact WHERE Email = 'johndoe@example.com' LIMIT 1].Id,
            Start_Date_Time__c = DateTime.now().addHours(1),
            End_Date_Time__c = DateTime.now().addHours(2),
            Facility__c = [SELECT Id FROM hed__Facility__c LIMIT 1].Id,
            Mode_of_Delivery__c = 'Online',
            Type_of_Activity__c = 'Teaching'
        );
        insert session;

        Test.startTest();
        session.Start_Date_Time__c = DateTime.now().addHours(3);
        update session;
        Test.stopTest();

        // Verify reschedule email sent
      //  System.assertEquals(1, Test.getEmails().size());
    }

    @IsTest
    static void test_restrictDuplicateSessions() {
        Session__c session1 = new Session__c(
            Course_Offering__c = [SELECT Id FROM hed__Course_Offering__c LIMIT 1].Id,
            Faculty__c = [SELECT Id FROM Contact WHERE Email = 'johndoe@example.com' LIMIT 1].Id,
            Start_Date_Time__c = DateTime.now().addHours(1),
            End_Date_Time__c = DateTime.now().addHours(2),
            Facility__c = [SELECT Id FROM hed__Facility__c LIMIT 1].Id,
            Mode_of_Delivery__c = 'Online',
            Type_of_Activity__c = 'Teaching'
        );
        insert session1;

        Test.startTest();
        Session__c session2 = new Session__c(
            Course_Offering__c = session1.Course_Offering__c,
            Start_Date_Time__c = session1.Start_Date_Time__c,
            End_Date_Time__c = session1.End_Date_Time__c,
            Faculty__c = session1.Faculty__c,
            Facility__c = session1.Facility__c,
            Mode_of_Delivery__c = session1.Mode_of_Delivery__c,
            Type_of_Activity__c = session1.Type_of_Activity__c
        );
        try {
            insert session2;
            System.assert(false, 'Expected duplicate error');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Session was already created'));
        }
        Test.stopTest();
    }

    @IsTest
    static void test_sendCancelledEmail() {
        Session__c session = new Session__c(
            Course_Offering__c = [SELECT Id FROM hed__Course_Offering__c LIMIT 1].Id,
            Faculty__c = [SELECT Id FROM Contact WHERE Email = 'johndoe@example.com' LIMIT 1].Id,
            Start_Date_Time__c = DateTime.now().addHours(1),
            End_Date_Time__c = DateTime.now().addHours(2),
            Facility__c = [SELECT Id FROM hed__Facility__c LIMIT 1].Id,
            Mode_of_Delivery__c = 'Online',
            Type_of_Activity__c = 'Teaching'
        );
        insert session;

        Test.startTest();
        delete session;
        Test.stopTest();

        // Verify cancellation email sent
       // System.assertEquals(1, Test.getEmails().size());
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
    
    //additional test classes
	// Add these additional test methods to your existing SessionTriggerHandler_Test class

@IsTest
static void test_sessions_with_null_oldSessionRecords() {
    // Test the sessions method when oldSessionRecords is null (insert scenario)
    Test.startTest();
    
    Session__c session = new Session__c(
        Course_Offering__c = [SELECT Id FROM hed__Course_Offering__c LIMIT 1].Id,
        Faculty__c = [SELECT Id FROM Contact WHERE Email = 'johndoe@example.com' LIMIT 1].Id,
        Start_Date_Time__c = DateTime.now().addHours(1),
        End_Date_Time__c = DateTime.now().addHours(2),
        Facility__c = [SELECT Id FROM hed__Facility__c LIMIT 1].Id,
        Mode_of_Delivery__c = 'Online',
        Type_of_Activity__c = 'Teaching'
    );
    
    List<Session__c> newSessions = new List<Session__c>{session};
    
    // Call the sessions method directly with null oldSessionRecords
    SessionTriggerHandler.sessions(newSessions, null);
    
    Test.stopTest();
}

@IsTest
static void test_sessions_with_oldSessionRecords_no_changes() {
    // Test sessions method when there are old records but no date/time changes
    Session__c session = new Session__c(
        Course_Offering__c = [SELECT Id FROM hed__Course_Offering__c LIMIT 1].Id,
        Faculty__c = [SELECT Id FROM Contact WHERE Email = 'johndoe@example.com' LIMIT 1].Id,
        Start_Date_Time__c = DateTime.now().addHours(1),
        End_Date_Time__c = DateTime.now().addHours(2),
        Facility__c = [SELECT Id FROM hed__Facility__c LIMIT 1].Id,
        Mode_of_Delivery__c = 'Online',
        Type_of_Activity__c = 'Teaching'
    );
    insert session;
    
    Test.startTest();
    
    // Create old session map with same values (no changes)
    Map<Id, Session__c> oldSessionMap = new Map<Id, Session__c>();
    oldSessionMap.put(session.Id, session.clone(true, true, true, true));
    
    List<Session__c> newSessions = new List<Session__c>{session};
    
    // Call sessions method with no changes
    SessionTriggerHandler.sessions(newSessions, oldSessionMap);
    
    Test.stopTest();
}

@IsTest
static void test_sessions_with_date_time_changes() {
            Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());
Test.setMock(HttpCalloutMock.class, new FailureHttpMock());
 Test.setMock(HttpCalloutMock.class, new NoDataHttpMock());

    // Test sessions method when start/end date times are changed
    Session__c session = new Session__c(
        Course_Offering__c = [SELECT Id FROM hed__Course_Offering__c LIMIT 1].Id,
        Faculty__c = [SELECT Id FROM Contact WHERE Email = 'johndoe@example.com' LIMIT 1].Id,
        Start_Date_Time__c = DateTime.now().addHours(1),
        End_Date_Time__c = DateTime.now().addHours(2),
        Facility__c = [SELECT Id FROM hed__Facility__c LIMIT 1].Id,
        Mode_of_Delivery__c = 'Online',
        Type_of_Activity__c = 'Teaching'
    );
    insert session;
    
    Test.startTest();
    
    // Create old session with different date/time
    Session__c oldSession = session.clone(true, true, true, true);
    oldSession.Start_Date_Time__c = DateTime.now().addHours(3);
    oldSession.End_Date_Time__c = DateTime.now().addHours(4);
    
    Map<Id, Session__c> oldSessionMap = new Map<Id, Session__c>();
    oldSessionMap.put(session.Id, oldSession);
    
    List<Session__c> newSessions = new List<Session__c>{session};
    
    // Call sessions method with date/time changes
    SessionTriggerHandler.sessions(newSessions, oldSessionMap);
    
    Test.stopTest();
}

@IsTest
static void test_sendEmail_with_empty_list() {
            Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());
Test.setMock(HttpCalloutMock.class, new FailureHttpMock());
 Test.setMock(HttpCalloutMock.class, new NoDataHttpMock());

    // Test sendEmail method with empty list
    Test.startTest();
    
    List<Session__c> emptySessions = new List<Session__c>();
    SessionTriggerHandler.sendEmail(emptySessions);
    
    Test.stopTest();
}

@IsTest
static void test_sendEmail_with_multiple_sessions() {
            Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());
Test.setMock(HttpCalloutMock.class, new FailureHttpMock());
 Test.setMock(HttpCalloutMock.class, new NoDataHttpMock());

    
    // Test sendEmail method with multiple sessions for same faculty/course
    List<Session__c> sessions = new List<Session__c>();
    
    for(Integer i = 0; i < 3; i++) {
        Session__c session = new Session__c(
            Course_Offering__c = [SELECT Id FROM hed__Course_Offering__c LIMIT 1].Id,
            Faculty__c = [SELECT Id FROM Contact LIMIT 1].Id,
            Start_Date_Time__c = DateTime.now().addHours(1 + i),
            End_Date_Time__c = DateTime.now().addHours(2 + i),
            Facility__c = [SELECT Id FROM hed__Facility__c LIMIT 1].Id,
            Mode_of_Delivery__c = 'Online',
            Type_of_Activity__c = 'Teaching'
        );
        sessions.add(session);
    }
    insert sessions;
    
    Test.startTest();
    SessionTriggerHandler.sendEmail(sessions);
    Test.stopTest();
}

@IsTest
static void test_sendEmail_with_blank_course_name() {
            Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());
Test.setMock(HttpCalloutMock.class, new FailureHttpMock());
 Test.setMock(HttpCalloutMock.class, new NoDataHttpMock());

    // Test sendEmail method when course name is blank
    // Create a course with blank name
    hed__Course__c blankCourse = new hed__Course__c(
        Name = '',
        hed__Account__c = [SELECT Id FROM Account LIMIT 1].Id,
        hed__Course_ID__c = 'BC001'
    );
    insert blankCourse;
    
    hed__Course_Offering__c blankCourseOffering = new hed__Course_Offering__c(
        hed__Course__c = blankCourse.Id,
        hed__Term__c = [SELECT Id FROM hed__Term__c LIMIT 1].Id,
         hed__Section_ID__c='test'
    );
    insert blankCourseOffering;
    
    Session__c session = new Session__c(
        Course_Offering__c = blankCourseOffering.Id,
        Faculty__c = [SELECT Id FROM Contact WHERE Email = 'johndoe@example.com' LIMIT 1].Id,
        Start_Date_Time__c = DateTime.now().addHours(1),
        End_Date_Time__c = DateTime.now().addHours(2),
        Facility__c = [SELECT Id FROM hed__Facility__c LIMIT 1].Id,
        Mode_of_Delivery__c = 'Online',
        Type_of_Activity__c = 'Teaching'
    );
    insert session;
    
    Test.startTest();
    SessionTriggerHandler.sendEmail(new List<Session__c>{session});
    Test.stopTest();
}

@IsTest
static void test_sendReScheduleEmail_with_null_dates() {
    // Test sendReScheduleEmail method with null date parameters
    Session__c session = new Session__c(
        Course_Offering__c = [SELECT Id FROM hed__Course_Offering__c where  Name='test123' LIMIT 1].Id,////////////////////////////////////////////////////////////
        Faculty__c = [SELECT Id FROM Contact WHERE Email = 'johndoe@example.com' LIMIT 1].Id,
        Start_Date_Time__c = null,
        End_Date_Time__c = null,
        Facility__c = [SELECT Id FROM hed__Facility__c LIMIT 1].Id,
        Mode_of_Delivery__c = 'Online',
        Type_of_Activity__c = 'Teaching'
    );
    insert session;
    
    Test.startTest();
    SessionTriggerHandler.sendReScheduleEmail(
        session,
        'Old Course',
        'Old Section',
        'Old Campus',
        'In-Person',
        null,
        null,
        'Old Facility'
    );
    Test.stopTest();
}

@IsTest
static void test_sendReScheduleEmail_with_valid_dates() {
    // Test sendReScheduleEmail method with valid date parameters
    Session__c session = new Session__c(
        Course_Offering__c = [SELECT Id FROM hed__Course_Offering__c LIMIT 1].Id,
        Faculty__c = [SELECT Id FROM Contact WHERE Email = 'johndoe@example.com' LIMIT 1].Id,
        Start_Date_Time__c = DateTime.now().addHours(1),
        End_Date_Time__c = DateTime.now().addHours(2),
        Facility__c = [SELECT Id FROM hed__Facility__c LIMIT 1].Id,
        Mode_of_Delivery__c = 'Online',
        Type_of_Activity__c = 'Teaching'
    );
    insert session;
    
    Test.startTest();
    SessionTriggerHandler.sendReScheduleEmail(
        session,
        'Old Course Name',
        'Old Section ID',
        'Old Campus Name',
        'In-Person',
        DateTime.now().addHours(-1),
        DateTime.now(),
        'Old Facility Name'
    );
    Test.stopTest();
}

@IsTest
static void test_sendCancelledEmail_with_multiple_sessions() {
            Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());
Test.setMock(HttpCalloutMock.class, new FailureHttpMock());
 Test.setMock(HttpCalloutMock.class, new NoDataHttpMock());

    // Test sendCancelledEmail method with multiple sessions
    List<Session__c> sessions = new List<Session__c>();
    
    for(Integer i = 0; i < 2; i++) {
        Session__c session = new Session__c(
            Course_Offering__c = [SELECT Id,hed__Section_ID__c FROM hed__Course_Offering__c LIMIT 1].Id,
            Faculty__c = [SELECT Id FROM Contact WHERE Email = 'johndoe@example.com' LIMIT 1].Id,
            Start_Date_Time__c = DateTime.now().addHours(1 + i),
            End_Date_Time__c = DateTime.now().addHours(2 + i),
            Facility__c = [SELECT Id FROM hed__Facility__c LIMIT 1].Id,
            Mode_of_Delivery__c = 'Online',
            Type_of_Activity__c = 'Teaching'
        );
        sessions.add(session);
    }
    insert sessions;
    
    Test.startTest();
    SessionTriggerHandler.sendCancelledEmail(sessions);
    Test.stopTest();
}

@IsTest
static void test_sendCancelledEmail_with_blank_campus() {
            Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());
Test.setMock(HttpCalloutMock.class, new FailureHttpMock());
 Test.setMock(HttpCalloutMock.class, new NoDataHttpMock());

    // Test sendCancelledEmail method when campus name is blank
    // Create term with blank campus
    hed__Term__c termWithoutCampus = new hed__Term__c(
        Name = 'Test Term',
        hed__Start_Date__c = Date.today(),
        hed__End_Date__c = Date.today().addMonths(3),
        hed__Account__c = [SELECT Id FROM Account LIMIT 1].Id,
        Term_Reference__c='Term 1'
    );
    insert termWithoutCampus;
    
    hed__Course_Offering__c offeringWithoutCampus = new hed__Course_Offering__c(
        hed__Course__c = [SELECT Id FROM hed__Course__c LIMIT 1].Id,
        hed__Term__c = termWithoutCampus.Id,
         hed__Section_ID__c='test'
    );
    insert offeringWithoutCampus;
    
    Session__c session = new Session__c(
        Course_Offering__c = offeringWithoutCampus.Id,
        Faculty__c = [SELECT Id FROM Contact WHERE Email = 'johndoe@example.com' LIMIT 1].Id,
        Start_Date_Time__c = DateTime.now().addHours(1),
        End_Date_Time__c = DateTime.now().addHours(2),
        Facility__c = [SELECT Id FROM hed__Facility__c LIMIT 1].Id,
        Mode_of_Delivery__c = 'Online',
        Type_of_Activity__c = 'Teaching'
    );
    insert session;
    
    Test.startTest();
    SessionTriggerHandler.sendCancelledEmail(new List<Session__c>{session});
    Test.stopTest();
}
}