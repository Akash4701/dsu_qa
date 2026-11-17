@IsTest
public class RestApi_GetCourseVersion_Test {

    @TestSetup
    static void setupData() {
        // This setup is only used by testDoGetCourseVersionData(), not method1()
        Account acc = new Account(Name = 'Global MBA');
        insert acc;

        hed__Term__c term = new hed__Term__c(
            Name = 'Spring 2025',
            hed__Account__c = acc.Id,
            Term_Reference__c = 'Term 1',
            hed__Start_Date__c = Date.today(),
            hed__End_Date__c = Date.today().addMonths(4)
        );
        insert term;

        hed__Course__c course = new hed__Course__c(
            Name = 'Test Course',
            hed__Course_ID__c = 'TC-101',
            Credits__c = 4,
            hed__Account__c = acc.Id
        );
        insert course;

        hed__Course_Offering__c offering = new hed__Course_Offering__c(
            Name = 'Test Course Offering',
            hed__Course__c = course.Id,
            hed__Term__c = term.Id,
            hed__Section_ID__c = 'A'
        );
        insert offering;

        Course_Evaluation_Component__c cecCIA = new Course_Evaluation_Component__c(
            Name = 'CIA Component',
            Course_Offering__c = offering.Id,
            Exam_Type__c = 'CIA',
            Maximum_Marks_for_the_Component__c = 100
        );
        insert cecCIA;

        Exam_Cycle__c examCycleCIA = new Exam_Cycle__c(
            Name = 'CIA Exam Cycle',
            Exam_Name__c = 'CIA',
            Start_Date__c = Date.today().addDays(-1),
            End_Date__c = Date.today().addDays(30)
        );
        insert examCycleCIA;

        Exam_Cycle_Term_Connection__c ectc = new Exam_Cycle_Term_Connection__c(
            Term__c = term.Id,
            Exam_Cycle__c = examCycleCIA.Id
        );
        insert ectc;

        Contact student = new Contact(LastName = 'Test Student');
        insert student;

        Exam__c exam = new Exam__c(
            Course_Evaluation_Component__c = cecCIA.Id,
            Exam_Date__c = Date.today(),
            Start_Time__c = Time.newInstance(9, 0, 0, 0),
            End_Time__c = Time.newInstance(12, 0, 0, 0)
        );
        insert exam;
    }

    @IsTest
    static void method1() {
        Test.setMock(HttpCalloutMock.class, new MockEnrollmentRespBBClass());

        Account acc = [SELECT Id, Name FROM Account WHERE Name = 'Global MBA' LIMIT 1];
        Contact con = [SELECT Id, Email FROM Contact WHERE LastName = 'Test Student' LIMIT 1];

        // Campus
        Campus__c camp = new Campus__c(Name='test', Campus_ID__c='SNG');
        insert camp;

        // Program Plan
        hed__Program_Plan__c programPlan = new hed__Program_Plan__c(
            Name='Test Program Plan',
            hed__Account__c=acc.Id,
            Intake__c='FEB',
            Batch__c='Batch A',
            Working_Days__c='Monday'
        );
        insert programPlan;

        // Term (NEW TERM – NOT from @TestSetup!)
        hed__Term__c tr = new hed__Term__c(
            Name='2040-Jul-PS-Term',
            hed__Account__c=acc.Id,
            hed__Start_Date__c=Date.today(),
            hed__End_Date__c=Date.today().addDays(7),
            hed__Grading_Period_Sequence__c=10,
            Campus__c=camp.Id,
            Program_Plan__c=programPlan.Id,
            RecordTypeId=Schema.SObjectType.hed__Term__c.getRecordTypeInfosByName()
                .get('Default Record').getRecordTypeId(),
            Term_Reference__c='Term 1'
        );
        insert tr;

        // Academic Planner + Activity
        K42_Academic_Planner__c acPlanner = new K42_Academic_Planner__c(
            Name='test',
            Program_Plan__c=programPlan.Id,
            Term__c=tr.Id,
            RecordTypeId=Schema.SObjectType.K42_Academic_Planner__c.getRecordTypeInfosByName()
                .get('Default').getRecordTypeId()
        );
        insert acPlanner;

        K42_Academic_Planner_Activity__c acPlannerAct = new K42_Academic_Planner_Activity__c(
            Academic_Planner__c=acPlanner.Id,
            Activity_Start_Date__c=Date.today(),
            Activity_End_Date__c=Date.today().addDays(1)
        );
        insert acPlannerAct;

        // Course
        hed__Course__c course = new hed__Course__c(
            Name='2040-Jul-PS-Term',
            hed__Course_ID__c='test',
            Credits__c=1,
            hed__Account__c=acc.Id
        );
        insert course;

        // Course Version
        Course_Version__c courseVersion = new Course_Version__c(
            Course__c=course.Id,
            Term__c=tr.Id,
            Start_Date__c=Date.today(),
            End_Date__c=Date.today().addDays(1),
            Exam_Required__c=true
        );
        insert courseVersion;

        // Course Offering
        hed__Course_Offering__c courseOffering = new hed__Course_Offering__c(
            Name='test',
            hed__Section_ID__c='B',
            hed__Course__c=course.Id,
            hed__Term__c=tr.Id,
            Course_Version__c=courseVersion.Id
        );
        insert courseOffering;

        // Faculty Course Enrollment
        hed__Course_Enrollment__c courseConn = new hed__Course_Enrollment__c(
            hed__Course_Offering__c=courseOffering.Id,
            hed__Contact__c=con.Id,
            hed__Status__c='Current',
            RecordTypeId=Schema.SObjectType.hed__Course_Enrollment__c.getRecordTypeInfosByName()
                .get('Faculty').getRecordTypeId()
        );
        insert courseConn;

        // Subject Planner + Activity
        Subject_Planner__c subPlanner = new Subject_Planner__c(
            Academic_Planner_Activity__c=acPlannerAct.Id,
            Course_Version__c=courseVersion.Id,
            Start_Date_Time__c=Date.today(),
            End_Date_Time__c=Date.today().addDays(1)
        );
        insert subPlanner;

        Subject_Activity__c subActivity = new Subject_Activity__c(
            Course_Version__c=courseVersion.Id,
            Duration__c=100
        );
        insert subActivity;

        // --------------------------------------------------------------------
        // CRITICAL: Create CEC, Exam Cycle, and Connection for the NEW TERM (tr)
        // --------------------------------------------------------------------

        // 1. Course Evaluation Component
        Course_Evaluation_Component__c cec = new Course_Evaluation_Component__c(
            Name='CEC - Test',
            Course_Offering__c=courseOffering.Id,
            Exam_Type__c='CIA',
            Maximum_Marks_for_the_Component__c=100,
            Pass_Weightage__c=40
        );
        insert cec;

        // 2. Active Exam Cycle for "CIA"
        Exam_Cycle__c examCycle = new Exam_Cycle__c(
            Name='CIA Cycle for 2040',
            Exam_Name__c='CIA',
            Start_Date__c=Date.today().addDays(-10),
            End_Date__c=Date.today().addDays(60)
        );
        insert examCycle;

        // 3. Link Exam Cycle to the NEW Term (tr)
        Exam_Cycle_Term_Connection__c ectc = new Exam_Cycle_Term_Connection__c(
            Term__c=tr.Id,
            Exam_Cycle__c=examCycle.Id
        );
        insert ectc;

        // 4. Now safe to insert Exam
        Exam__c exam = new Exam__c(
            Exam_Date__c=Date.today(),
            Start_Time__c=Time.newInstance(9, 0, 0, 0),
            End_Time__c=Time.newInstance(12, 0, 0, 0),
            Seating_Plan_Status__c='Completed',
            Invigilators_Assignment_Status__c='Pending',
            Course_Evaluation_Component__c=cec.Id,
            Exam_Cycle__c=examCycle.Id // Optional but safe
        );
        insert exam;

        // Facility
        hed__Facility__c facility = new hed__Facility__c(
            Name='Engaged Learning Centre 2-D',
            Facility_Number__c=6,
            hed__Facility_Type__c='Lecture Room',
            Number_Of_Seat_Per_Bench__c=76,
            hed__Capacity__c=76
        );
        insert facility;

        Facility_Booking__c facilityBooking = new Facility_Booking__c(
            Exam__c=exam.Id,
            FacilityID__c=facility.Id,
            Start_Date_and_Time__c=DateTime.now(),
            End_Date_and_Time__c=DateTime.now().addHours(3),
            Number_Of_Student_To_Be_Booked__c=0,
            Inter_Candidate_Spacing__c=3,
            Invigilation_Status__c='In Progress',
            Activity_type__c='Teaching'
        );
        insert facilityBooking;

        // REST call
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/CourseVersionData';
        req.httpMethod = 'GET';

        req.addParameter('term', tr.Id);
        req.addParameter('programName', acc.Name);
        req.addParameter('intake', 'Jul');
        req.addParameter('year', '2040');
        req.addParameter('course', course.Name);

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        RestApi_GetCourseVersion.doGetCourseVersionData();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
    }

    @IsTest
    static void testDoGetCourseVersionData() {
        Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());

        // Academic Program Account
        RecordType programRT = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType='Account' AND DeveloperName='Academic_Program'
            LIMIT 1
        ];
        Account acc = new Account(Name='Test Program', RecordTypeId=programRT.Id);
        insert acc;

        // Term
        hed__Term__c term = new hed__Term__c(
            Name='Jan 2025',
            hed__Account__c=acc.Id,
            Term_Reference__c='Term 1',
            RecordTypeId=Schema.SObjectType.hed__Term__c.getRecordTypeInfosByName()
                .get('Default Record').getRecordTypeId(),
            hed__Start_Date__c=Date.today(),
            hed__End_Date__c=Date.today().addDays(30)
        );
        insert term;

        // Course + CV + Offering
        hed__Course__c course = new hed__Course__c(
            Name='Test Course',
            hed__Course_ID__c='TC001',
            Credits__c=3,
            hed__Account__c=acc.Id
        );
        insert course;

        Course_Version__c cv = new Course_Version__c(
            Course__c=course.Id,
            Term__c=term.Id,
            Exam_Required__c=true,
            Start_Date__c=Date.today(),
            End_Date__c=Date.today().addDays(90)
        );
        insert cv;

        hed__Course_Offering__c co = new hed__Course_Offering__c(
            Course_Version__c=cv.Id,
            hed__Section_ID__c='SEC-01',
            Name='Test Offering',
            hed__Term__c=term.Id,
            hed__Course__c=course.Id
        );
        insert co;

        // Faculty + enrollment
        Contact faculty = new Contact(LastName='Prof. John');
        insert faculty;

        RecordType facultyRT = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType='hed__Course_Enrollment__c' AND Name='Faculty'
            LIMIT 1
        ];
        insert new hed__Course_Enrollment__c(
            hed__Course_Offering__c=co.Id,
            hed__Contact__c=faculty.Id,
            RecordTypeId=facultyRT.Id,
            hed__Status__c='Current'
        );

        // REST
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/CourseVersionData/';
        req.httpMethod = 'GET';
      //  req.params = new Map<String, String>();
        req.params.put('programName', acc.Name);
        req.params.put('intake', 'Jan');
        req.params.put('year', '2025');
        req.params.put('term', term.Id);

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        RestApi_GetCourseVersion.doGetCourseVersionData();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        System.assertNotEquals(null, RestContext.response.responseBody);
    }

    // ----------------- Mocks -----------------
    public class SuccessHttpMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"success":"true","data":{"Identifier":"98765"}}');
            res.setStatusCode(200);
            return res;
        }
    }

    public class FailureHttpMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"error":"Internal Server Error"}');
            res.setStatusCode(500);
            return res;
        }
    }

    public class MockEnrollmentRespBBClass implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse res = new HttpResponse();
            res.setBody('{"status":"success"}');
            res.setStatusCode(200);
            return res;
        }
    }
}