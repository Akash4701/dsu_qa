@IsTest
private class RequestWrapper_Test {

    // Mock classes for HTTP callouts
    public class SuccessHttpMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"success": "true","data": {"Identifier": "98765","Code": "Ken BBA-01","Name": "Ken - BBA Template","Path": "/content/enforced/6887-KenBBA-01"}}');
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

    @TestSetup
    static void setupTestData() {

        // NOTE: only one mock is active at a time (last set wins)
        Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());

        // ✅ FIX: Make LMS_URL__c Names unique (Name appears to be unique in your org)
        insert new List<LMS_URL__c>{
            new LMS_URL__c(Name = 'course url', Bulk_Enroll__c = 'https://dummyendpoint.com'),
            new LMS_URL__c(Name = 'course url 2', Bulk_Enroll__c = 'TestUrl'),          // changed
            new LMS_URL__c(Name = 'course offering url', Bulk_Enroll__c = 'TestUrl'),
            new LMS_URL__c(Name = 'Bulk Enrollment', Bulk_Enroll__c = 'TestUrl')
        };

        // Create Account
        Account acc = new Account(
            Name = 'Test University',
            LMS_Id__c = '12345'
        );
        insert acc;

        // Program Plan
        hed__Program_Plan__c programPlan = new hed__Program_Plan__c(
            Name = 'Computer Science',
            hed__Account__c = acc.Id
        );
        insert programPlan;

        // Term
        hed__Term__c term = new hed__Term__c(
            Name = 'Term 1',
            hed__Account__c = acc.Id,
            hed__Start_Date__c = Date.today(),
            hed__End_Date__c = Date.today().addDays(90),
            Program_Plan__c = programPlan.Id,
            Term_Reference__c = 'Term 1'
        );
        insert term;

        // Course
        hed__Course__c course = new hed__Course__c(
            Name = 'Mathematics',
            Credits__c = 3,
            hed__Credit_Hours__c = 3,
            hed__Account__c = acc.Id,
            hed__Course_ID__c = 'TC001',
            LMS_ID__c = '54321'
        );
        insert course;

        // Course Offering
        hed__Course_Offering__c offering = new hed__Course_Offering__c(
            Name = 'Math - Section A',
            hed__Course__c = course.Id,
            hed__Term__c = term.Id,
            hed__Section_ID__c = 'A',
            hed__Start_Date__c = Date.today(),
            hed__End_Date__c = Date.today().addDays(90)
        );
        insert offering;

        // Course Evaluation Component (required for Exam validation)
        Course_Evaluation_Component__c component = new Course_Evaluation_Component__c(
            Name = 'CIA Component',
            Course_Offering__c = offering.Id,
            Exam_Type__c = 'CIA',
            Maximum_Marks_for_the_Component__c = 100,
            Pass_Weightage__c = 40
        );
        insert component;

        // Exam Cycle
        Exam_Cycle__c examCycle = new Exam_Cycle__c(
            Name = 'Test Exam Cycle',
            Exam_Name__c = 'CIA',
            Start_Date__c = Date.today().addDays(-1),
            End_Date__c = Date.today().addDays(30)
        );
        insert examCycle;

        // Contacts
        Contact studentContact = new Contact(
            FirstName = 'John',
            LastName = 'Doe',
            Email = 'john.doe@example.com'
        );
        insert studentContact;

        Contact evaluatorContact = new Contact(
            FirstName = 'Jane',
            LastName = 'Smith',
            Email = 'jane.smith@example.com'
        );
        insert evaluatorContact;

        // Facility
        hed__Facility__c hedFacility = new hed__Facility__c(Name = 'Main Hall HED');
        insert hedFacility;

        // Course Version
        Course_Version__c courseVersion = new Course_Version__c(
            Course__c = course.Id,
            Term__c = term.Id,
            Start_Date__c = System.today(),
            End_Date__c = System.today().addDays(1)
        );
        insert courseVersion;

        // Exam (fixed: set Course_Evaluation_Component__c)
        Exam__c exam = new Exam__c(
            Course_Version__c = courseVersion.Id,
            Course_Evaluation_Component__c = component.Id,
            Exam_Date__c = Date.today(),
            Start_Time__c = Time.newInstance(11, 0, 0, 0),
            End_Time__c = Time.newInstance(13, 0, 0, 0)
        );

        // If field exists in your org
        try { exam.put('Exam_Cycle__c', examCycle.Id); } catch (Exception ignore) {}

        insert exam;

        // Exam Connections
        Exam_Connections__c examConnection = new Exam_Connections__c(
            Student_Name__c = studentContact.Id
        );
        insert examConnection;

        // Evaluation
        Evaluation__c evaluation = new Evaluation__c(
            Contact__c = evaluatorContact.Id,
            Evaluator_Acceptance_Status__c = '',
            Exam_ID__c = exam.Id,
            Course_Offering__c = offering.Id,
            Reason_For_Rejection__c = 'Test Reason'
        );
        insert evaluation;

        // Facility Booking
        Facility_Booking__c booking = new Facility_Booking__c(
            Start_Date_and_Time__c = DateTime.now(),
            End_Date_and_Time__c = DateTime.now().addHours(2),
            FacilityID__c = hedFacility.Id,
            Number_Of_Invigilators_Required__c = 2,
            Exam__c = exam.Id,
            Inter_Candidate_Spacing__c = 1.5
        );
        insert booking;
    }

    // ----------- YOUR TEST METHODS (unchanged) -----------

    @IsTest
    static void testMainWrapperInitialization() {
        Test.startTest();

        List<RequestWrapper.FacilitiesWrapper> facilities = new List<RequestWrapper.FacilitiesWrapper>();
        RequestWrapper.FacilitiesWrapper facilityWrapper = new RequestWrapper.FacilitiesWrapper();
        facilityWrapper.facilityId = 'a01000000000001AAA';
        facilityWrapper.facilityName = 'Test Facility';
        facilities.add(facilityWrapper);

        List<Exam_Connections__c> examConnections = [
            SELECT Id, Student_Name__c, Student_Name__r.Id, Student_Name__r.Name, Student_Roll_Number__c
            FROM Exam_Connections__c
        ];

        RequestWrapper.MainWrapper mainWrapper =
            new RequestWrapper.MainWrapper(10, facilities, examConnections, examConnections);

        Test.stopTest();

        System.assertEquals(10, mainWrapper.eligibelStudents);
        System.assertEquals(1, mainWrapper.facilities.size());
        System.assertEquals(examConnections.size(), mainWrapper.examConnections.size());
        System.assertEquals(examConnections.size(), mainWrapper.otherExamRelatedExamConnections.size());
    }

    @IsTest
    static void testExamConnectionsWrapperGetRecord() {
        Exam_Connections__c conn = [
            SELECT Id, Student_Name__c, Student_Name__r.Id, Student_Name__r.Name, Student_Roll_Number__c
            FROM Exam_Connections__c
            LIMIT 1
        ];

        RequestWrapper.ExamConnectionsWrapper wrapper = new RequestWrapper.ExamConnectionsWrapper(conn);
        wrapper.courseConnectionId = 'a03000000000001AAA';
        wrapper.seatNumber = 15;
        wrapper.facilityId = 'a01000000000001AAA';
        wrapper.facilityName = 'Test Facility';
        wrapper.columnNumber = 3;
        wrapper.rowNumber = 5;

        Exam_Connections__c result = (Exam_Connections__c) wrapper.getRecord();

        System.assertEquals(conn.Id, result.Id);
        System.assertEquals(conn.Student_Name__c, result.Student_Name__c);
        System.assertEquals(wrapper.courseConnectionId, result.Course_Connection_ID__c);
        System.assertEquals(15, result.Seat_Number__c);
    }

    @IsTest
    static void testEvaluatorWrapperGetRecord() {
        Evaluation__c eval = [
            SELECT Id, Contact__c, Contact__r.Name, Contact__r.Email,
                   Exam_ID__c, Course_Offering__c, Course_Offering__r.hed__Section_ID__c,
                   Evaluator_Acceptance_Status__c, Reason_For_Rejection__c
            FROM Evaluation__c
            LIMIT 1
        ];

        RequestWrapper.EvaluatorWrapper wrapper = new RequestWrapper.EvaluatorWrapper(eval);

        System.assertEquals(eval.Id, wrapper.evaluatorId);
        System.assertEquals(eval.Contact__c, wrapper.contactId);
        System.assertEquals(eval.Contact__r.Name, wrapper.contcatName);
        System.assertEquals(eval.Contact__r.Email, wrapper.contactEmail);

        Evaluation__c result = (Evaluation__c) wrapper.getRecord();

        System.assertEquals(eval.Id, result.Id);
        System.assertEquals(eval.Contact__c, result.Contact__c);
        System.assertEquals(eval.Exam_ID__c, result.Exam_ID__c);
        System.assertEquals(eval.Evaluator_Acceptance_Status__c, result.Evaluator_Acceptance_Status__c);
        System.assertEquals(eval.Reason_For_Rejection__c, result.Reason_For_Rejection__c);
    }

    @IsTest
    static void testFacilityBookingWrapperGetRecord() {
        Facility_Booking__c booking = [
            SELECT Id, Start_Date_and_Time__c, End_Date_and_Time__c, FacilityID__c, Exam__c,
                   Number_Of_Invigilators_Required__c, Inter_Candidate_Spacing__c
            FROM Facility_Booking__c
            LIMIT 1
        ];

        RequestWrapper.FacilityBookingWrapper wrapper = new RequestWrapper.FacilityBookingWrapper();
        wrapper.facilityBookingRecordId = booking.Id;
        wrapper.bookedStartDateTime = booking.Start_Date_and_Time__c;
        wrapper.bookedEndDateTime = booking.End_Date_and_Time__c;
        wrapper.facilityId = booking.FacilityID__c;
        wrapper.examId = booking.Exam__c;
        wrapper.noOfInvigilators = 3;
        wrapper.intercandidateSpacing = 2.0;
        wrapper.bookedCapacity = 50;
        wrapper.bookedByContactId = 'a03000000000001AAA';

        Facility_Booking__c result = (Facility_Booking__c) wrapper.getRecord();

        System.assertEquals(booking.Id, result.Id);
        System.assertEquals(booking.FacilityID__c, result.FacilityID__c);
        System.assertEquals(booking.Exam__c, result.Exam__c);
        System.assertEquals(3, result.Number_Of_Invigilators_Required__c);
        System.assertEquals(2.0, result.Inter_Candidate_Spacing__c);
    }

    @IsTest
    static void testAccountWrapperWithBatchesAndTerms() {
        Account acc = [SELECT Id, Name FROM Account LIMIT 1];
        List<hed__Program_Plan__c> plans = [
            SELECT Id, Name, (SELECT Id, Name FROM Terms__r)
            FROM hed__Program_Plan__c
        ];

        RequestWrapper.AccountWrapper accountWrapper = new RequestWrapper.AccountWrapper(acc, plans);

        System.assertEquals(acc.Id, accountWrapper.accountId);
        System.assertEquals(acc.Name, accountWrapper.accountName);
        System.assertEquals(plans.size(), accountWrapper.batches.size());
    }

    @IsTest
    static void testBatchWrapperInitialization() {
        hed__Program_Plan__c plan = [SELECT Id, Name FROM hed__Program_Plan__c LIMIT 1];
        List<hed__Term__c> terms = [SELECT Id, Name FROM hed__Term__c];

        RequestWrapper.BatchWrapper batchWrapper = new RequestWrapper.BatchWrapper(plan, terms);

        System.assertEquals(plan.Id, batchWrapper.programPlanId);
        System.assertEquals(plan.Name, batchWrapper.programPlanName);
        System.assertEquals(terms.size(), batchWrapper.terms.size());
    }

    @IsTest
    static void testTermWrapperInitialization() {
        hed__Term__c term = [SELECT Id, Name FROM hed__Term__c LIMIT 1];

        RequestWrapper.TermWrapper termWrapper = new RequestWrapper.TermWrapper(term);

        System.assertEquals(term.Id, termWrapper.termId);
        System.assertEquals(term.Name, termWrapper.termName);
    }

    @IsTest
    static void testCourseWrapperInitialization() {
        hed__Course_Offering__c offering = [
            SELECT Id, hed__Course__r.Name, hed__Section_ID__c
            FROM hed__Course_Offering__c
            LIMIT 1
        ];

        RequestWrapper.CourseWrapper wrapper = new RequestWrapper.CourseWrapper(offering);

        System.assertEquals(offering.Id, wrapper.courseOfferingId);
        System.assertEquals(offering.hed__Course__r.Name, wrapper.courseName);
        System.assertEquals(offering.hed__Section_ID__c, wrapper.section);
    }

    @IsTest
    static void testSectionsWrapperInitialization() {
        hed__Course_Offering__c offering = [SELECT Id, hed__Section_ID__c FROM hed__Course_Offering__c LIMIT 1];

        RequestWrapper.SectionsWrapper sectionWrapper = new RequestWrapper.SectionsWrapper();
        sectionWrapper.courseOfferingId = offering.Id;
        sectionWrapper.section = offering.hed__Section_ID__c;
        sectionWrapper.courseOfferingExamConnectionId = 'a03000000000001AAA';

        System.assertEquals(offering.Id, sectionWrapper.courseOfferingId);
        System.assertEquals(offering.hed__Section_ID__c, sectionWrapper.section);
        System.assertEquals('a03000000000001AAA', sectionWrapper.courseOfferingExamConnectionId);
    }

    @IsTest
    static void testFacilitiesWrapperInitialization() {
        RequestWrapper.FacilitiesWrapper facilityWrapper = new RequestWrapper.FacilitiesWrapper();
        facilityWrapper.facilityId = 'a01000000000001AAA';
        facilityWrapper.facilityName = 'Science Lab';
        facilityWrapper.facilityBookingRecordId = 'a02000000000001AAA';
        facilityWrapper.noOfInvigilators = 2;
        facilityWrapper.effectiveCapacity = 100;
        facilityWrapper.noOfColumns = 10;
        facilityWrapper.noOfRows = 10;
        facilityWrapper.seatsPerBench = '2';
        facilityWrapper.chosen = true;
        facilityWrapper.intercandidateSpacing = 1.5;

        System.assertEquals('a01000000000001AAA', facilityWrapper.facilityId);
        System.assertEquals('Science Lab', facilityWrapper.facilityName);
        System.assertEquals(true, facilityWrapper.chosen);
        System.assertEquals(2, facilityWrapper.noOfInvigilators);
        System.assertEquals(100, facilityWrapper.effectiveCapacity);
    }

    @IsTest
    static void testExamWrapperInitialization() {
        RequestWrapper.ExamWrapper examWrapper = new RequestWrapper.ExamWrapper();
        examWrapper.examRecordId = 'a02000000000001AAA';
        examWrapper.examDate = Date.today();
        examWrapper.startTime = Time.newInstance(9, 0, 0, 0);
        examWrapper.endTime = Time.newInstance(11, 0, 0, 0);
        examWrapper.examType = 'Midterm';
        examWrapper.programName = 'Computer Science';
        examWrapper.termName = 'Term 1';
        examWrapper.courseName = 'Mathematics';
        examWrapper.examName = 'Math Midterm';
        examWrapper.dueDate = Date.today().addDays(7);
        examWrapper.approvalStatus = 'Approved';
        examWrapper.examFormat = 'Written';
        examWrapper.examPattern = 'Descriptive';
        examWrapper.examMode = 'Offline';
        examWrapper.courseCode = 'MATH101';
        examWrapper.sections = new List<String>{ 'A', 'B' };

        System.assertEquals('a02000000000001AAA', examWrapper.examRecordId);
        System.assertEquals(Date.today(), examWrapper.examDate);
        System.assertEquals('Midterm', examWrapper.examType);

        examWrapper.getRecord();
    }

    @IsTest
    static void testRequestWrapperMainProperties() {
        RequestWrapper requestWrapper = new RequestWrapper();

        requestWrapper.wrapper = new RequestWrapper.MainWrapper(
            5,
            new List<RequestWrapper.FacilitiesWrapper>(),
            null,
            null
        );
        requestWrapper.facilities = new List<RequestWrapper.FacilitiesWrapper>();
        requestWrapper.examConnections = new List<RequestWrapper.ExamConnectionsWrapper>();
        requestWrapper.facilityBookings = new List<RequestWrapper.FacilityBookingWrapper>();
        requestWrapper.sections = new List<RequestWrapper.SectionsWrapper>();
        requestWrapper.batches = new List<RequestWrapper.BatchWrapper>();
        requestWrapper.terms = new List<RequestWrapper.TermWrapper>();
        requestWrapper.courses = new List<RequestWrapper.CourseWrapper>();
        requestWrapper.evaluators = new List<RequestWrapper.EvaluatorWrapper>();
        requestWrapper.exams = new List<RequestWrapper.ExamWrapper>();

        Account acc = [SELECT Id, Name FROM Account LIMIT 1];
        requestWrapper.programs = new RequestWrapper.AccountWrapper(acc, new List<hed__Program_Plan__c>());

        System.assertEquals(5, requestWrapper.wrapper.eligibelStudents);
        System.assertNotEquals(null, requestWrapper.programs);
    }

    @IsTest
    static void testMainWrapperWithNullValues() {
        Test.startTest();

        RequestWrapper.MainWrapper mainWrapper = new RequestWrapper.MainWrapper(0, null, null, null);

        Test.stopTest();

        System.assertEquals(0, mainWrapper.eligibelStudents);
        System.assertEquals(null, mainWrapper.facilities);
        System.assertEquals(0, mainWrapper.examConnections.size());
        System.assertEquals(0, mainWrapper.otherExamRelatedExamConnections.size());
    }

    @IsTest
    static void testExamConnectionsWrapperWithNullFields() {
        Contact studentContact = [SELECT Id, Name FROM Contact WHERE FirstName = 'John' LIMIT 1];

        Exam_Connections__c examConn = new Exam_Connections__c(Student_Name__c = studentContact.Id);
        insert examConn;

        Exam_Connections__c connWithRelation = [
            SELECT Id, Student_Name__c, Student_Name__r.Id, Student_Name__r.Name, Student_Roll_Number__c
            FROM Exam_Connections__c
            WHERE Id = :examConn.Id
        ];

        RequestWrapper.ExamConnectionsWrapper wrapper = new RequestWrapper.ExamConnectionsWrapper(connWithRelation);

        System.assertEquals(connWithRelation.Id, wrapper.examConnectionRecordId);
        System.assertEquals(connWithRelation.Student_Name__r.Id, wrapper.studentRecordId);
        System.assertEquals(connWithRelation.Student_Name__r.Name, wrapper.studentName);
    }

    @IsTest
    static void testFacilityBookingWrapperWithNullFields() {
        RequestWrapper.FacilityBookingWrapper wrapper = new RequestWrapper.FacilityBookingWrapper();

        Facility_Booking__c result = wrapper.getRecord();

        System.assertEquals(null, result.Id);
        System.assertEquals(null, result.Start_Date_and_Time__c);
        System.assertEquals(null, result.End_Date_and_Time__c);
    }

    @IsTest
    static void testEvaluatorWrapperWithNullFields() {
        Contact evaluatorContact = [SELECT Id, Name, Email FROM Contact WHERE FirstName = 'Jane' LIMIT 1];
        Exam__c exam = [SELECT Id FROM Exam__c LIMIT 1];
        hed__Course_Offering__c offering = [SELECT Id, hed__Section_ID__c FROM hed__Course_Offering__c LIMIT 1];

        Evaluation__c eval = new Evaluation__c(
            Contact__c = evaluatorContact.Id,
            Exam_ID__c = exam.Id,
            Course_Offering__c = offering.Id
        );
        insert eval;

        Evaluation__c evalWithRelation = [
            SELECT Id, Contact__c, Contact__r.Name, Contact__r.Email,
                   Exam_ID__c, Course_Offering__c, Course_Offering__r.hed__Section_ID__c,
                   Evaluator_Acceptance_Status__c, Reason_For_Rejection__c
            FROM Evaluation__c
            WHERE Id = :eval.Id
        ];

        RequestWrapper.EvaluatorWrapper wrapper = new RequestWrapper.EvaluatorWrapper(evalWithRelation);

        Evaluation__c result = wrapper.getRecord();

        System.assertEquals(evalWithRelation.Id, result.Id);
        System.assertEquals(evalWithRelation.Contact__c, result.Contact__c);
        System.assertEquals(evalWithRelation.Exam_ID__c, result.Exam_ID__c);
    }
}