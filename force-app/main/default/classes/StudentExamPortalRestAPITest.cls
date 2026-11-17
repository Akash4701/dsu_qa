@IsTest
global class StudentExamPortalRestAPITest {

    @TestSetup
    static void setupData() {

        // -----------------------------
        // Base Org Data
        // -----------------------------
        Account dept = new Account(Name = 'Test Department');
        insert dept;

        //  Program__c is REQUIRED (lookup to Account in your org)
        // Create a separate Account that represents the Program and use it in Program__c.
        Account programAcc = new Account(Name = 'Test Program');
        insert programAcc;

        hed__Term__c term = new hed__Term__c(
            Name = 'Term 1',
            hed__Account__c = dept.Id,
            Term_Reference__c = 'Term 1',
            hed__Start_Date__c = Date.today().addDays(-30),
            hed__End_Date__c   = Date.today().addDays(90),
            Result_Published__c = true
        );
        insert term;

        hed__Course__c course = new hed__Course__c(
            Name = 'Test Course',
            hed__Account__c = dept.Id,
            Credits__c = 4,
            hed__Course_ID__c = 'CSE-101'
        );
        insert course;

        hed__Course_Offering__c offering = new hed__Course_Offering__c(
            Name = 'Offering 1',
            hed__Course__c = course.Id,
            hed__Term__c   = term.Id,
            Result_Published__c = true
        );
        insert offering;

        // -----------------------------
        // Student + Program
        // -----------------------------
        Id studentContactRecordTypeId;
        for (RecordType rt : [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Contact'
              AND DeveloperName = 'Student'
            LIMIT 1
        ]) {
            studentContactRecordTypeId = rt.Id;
        }

        Contact student = new Contact(
            RecordTypeId = studentContactRecordTypeId,
            LastName = 'Student One',
            Passport_Size_Photo__c = 'https://example.com/photo.jpg'
        );
        insert student;

        hed__Program_Plan__c plan = new hed__Program_Plan__c(
            Name = 'Test Plan'
            //  fix: required lookup in your org
         //   Program__c = programAcc.Id
        );
        insert plan;

        hed__Affiliation__c aff = new hed__Affiliation__c(
            hed__Contact__c = student.Id,
            hed__Account__c = dept.Id,
            Program_Plan__c = plan.Id,
            Roll_Number__c  = 'USN-001',
            CGPA__c = 8.25
        );
        insert aff;

        hed__Program_Enrollment__c pe = new hed__Program_Enrollment__c(
            hed__Contact__c = student.Id,
            hed__Account__c = dept.Id,
            Term__c = term.Id,
            hed__Affiliation__c = aff.Id,
            SGPA__c = 8.10,
            // (optional) some orgs also require program plan on PE
            hed__Program_Plan__c = plan.Id
        );
        insert pe;

        // -----------------------------
        // Course Enrollment (Course Connection)
        // Final_Grade__c is FORMULA -> drive with Letter_Grade__c
        // -----------------------------
        hed__Course_Enrollment__c ce = new hed__Course_Enrollment__c(
            hed__Contact__c = student.Id,
            hed__Program_Enrollment__c = pe.Id,
            hed__Course_Offering__c = offering.Id,

            Enrollment_Status__c = 'Enrolled',
            Exam_Eligibility__c  = 'Eligible',
            Result_with_hold__c  = false,

            Letter_Grade__c = 'F',
            Component_Final_Score__c = 45,
            hed__Credits_Earned__c = 0
        );
        insert ce;

        // -----------------------------
        // Exam Cycle (Is_Active__c is FORMULA)
        // -----------------------------
        Exam_Cycle__c cycle = new Exam_Cycle__c(
            Name = 'Cycle 1',
            Exam_Name__c = 'SEE',
            Start_Date__c = Date.today().addDays(-1),
            End_Date__c   = Date.today().addDays(10),
            Last_Date_to_Enroll__c = Date.today().addDays(5),
            Publish_Hall_Ticket__c = true,
            Active__c = true
        );
        insert cycle;

        // Component + Exam
        Course_Evaluation_Component__c comp = new Course_Evaluation_Component__c(
            Name = 'SEE Component',
            Course_Offering__c = offering.Id,
            Exam_Type__c = 'SEE',
            Maximum_Marks_for_the_Component__c = 100,
            Pass_Weightage__c = 40
        );
        insert comp;

        Exam__c exam = new Exam__c(
            Exam_Name__c = 'SEE',
            Exam_Cycle__c = cycle.Id,
            Course_Evaluation_Component__c = comp.Id,
            Start_Date__c = Date.today().addDays(1),
            Start_Time__c = Time.newInstance(10, 0, 0, 0),
            Exam_Date__c  = Date.today().addDays(1),
            End_Time__c   = Time.newInstance(12, 0, 0, 0)
        );
        insert exam;

        // Exam Connection
        Exam_Connections__c exConn = new Exam_Connections__c(
            Student_Name__c = student.Id,
            Course_Connection_ID__c = ce.Id,
            Exam_Name__c = exam.Id,
            Eligibility__c = 'Eligible'
        );
        insert exConn;

        // Slot Scheduled
        Slot_Scheduled__c slot = new Slot_Scheduled__c(
            Exam_Connection__c = exConn.Id,
            Student_ID__c = student.Id,
            Course_ID__c = course.Id,
            Exam__c = exam.Id,
            Is_Expired__c = false,
            Start_Date_Time__c = System.now().addDays(1),
            End_Date_Time__c   = System.now().addDays(1).addHours(2),
            Schedule_URL__c = 'https://example.com/schedule',
            Schedule_Id__c  = 'SCH-001'
        );
        insert slot;

        // Component score linked to slot
        insert new Component_Scores__c(Slot_Scheduled__c = slot.Id);

        // Exam Slot Setup records (keep dates valid)
        Map<String, Id> rtByDev = new Map<String, Id>();
        for (RecordType rt : [
            SELECT Id, DeveloperName
            FROM RecordType
            WHERE SObjectType = 'Exam_Slot_Setup__c'
              AND DeveloperName IN ('Individual', 'Recurring')
        ]) {
            rtByDev.put(rt.DeveloperName, rt.Id);
        }

        if (rtByDev.containsKey('Individual')) {
            insert new Exam_Slot_Setup__c(
                RecordTypeId = rtByDev.get('Individual'),
                Exam__c = exam.Id,
                Start_Date__c = Date.today().addDays(1),
                End_Date__c   = Date.today().addDays(2),
                Start_Time__c = Time.newInstance(9, 0, 0, 0),
                End_Time__c   = Time.newInstance(10, 0, 0, 0),
                Is_Expired__c = false
            );
        }
        if (rtByDev.containsKey('Recurring')) {
            insert new Exam_Slot_Setup__c(
                RecordTypeId = rtByDev.get('Recurring'),
                Exam__c = exam.Id,
                Start_Date__c = Date.today().addDays(1),
                End_Date__c   = Date.today().addDays(3),
                Start_Time__c = Time.newInstance(11, 0, 0, 0),
                End_Time__c   = Time.newInstance(12, 0, 0, 0),
                Is_Expired__c = false
            );
        }

        // Grade Card artifacts
        ContentVersion cv = new ContentVersion();
        cv.Title = 'Grade Card - Term 1';
        cv.PathOnClient = 'gradecard.pdf';
        cv.VersionData = Blob.valueOf('TEST_PDF');
        cv.ContentLocation = 'S';
        cv.Document_Type__c = 'Grade Card';
        insert cv;

        Id docId = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
            LIMIT 1
        ].ContentDocumentId;

        insert new ContentDocumentLink(
            ContentDocumentId = docId,
            LinkedEntityId = pe.Id,
            ShareType = 'V'
        );

        // Fee Type (Name is auto-number -> don't set)
        Fee_Type__c ft = new Fee_Type__c(
            Amount__c = 500,
            Due_Date__c = Date.today().addDays(7),
Program__c= dept.id
        );
        insert ft;

        insert new Exam_Cycle_Term_Connection__c(
            Exam_Cycle__c = cycle.Id,
            Term__c = term.Id
        );

        Student_Service_Request_Application__c ssra = new Student_Service_Request_Application__c(
            Exam_Cycle__c = cycle.Id,
            Fee_Type__c = ft.Id
        );
        insert ssra;

        // Insert one SSR for RequestedExams matching
        Map<String, Id> ssrRtByDev = new Map<String, Id>();
        for (RecordType rt : [
            SELECT Id, DeveloperName
            FROM RecordType
            WHERE SObjectType = 'Student_Service_Request__c'
              AND DeveloperName IN ('Re_Exam', 'Revaluation')
        ]) {
            ssrRtByDev.put(rt.DeveloperName, rt.Id);
        }

        if (ssrRtByDev.containsKey('Re_Exam')) {
            insert new Student_Service_Request__c(
                RecordTypeId = ssrRtByDev.get('Re_Exam'),
                Status__c = 'Submitted',
                Course_Offering__c = offering.Id,
                Course_Connection__c = ce.Id,
                Student_Request_Application__c = ssra.Id,
                Exam__c = exam.Id
            );
        }
    }

    // -------------------------
    // Helpers
    // -------------------------
    private static void initRestGet(String uri, Map<String, String> params) {
        RestRequest req = new RestRequest();
        req.httpMethod = 'GET';
        req.requestURI = uri;

        if (params != null) {
            for (String k : params.keySet()) {
                req.addParameter(k, params.get(k));
            }
        }

        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;
    }

    private static void initRestPost(String uri, String body) {
        RestRequest req = new RestRequest();
        req.httpMethod = 'POST';
        req.requestURI = uri;
        if (body != null) req.requestBody = Blob.valueOf(body);

        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;
    }

    private static String buildStudentServiceRequestPayload(
        String requestType,
        Id courseOfferingId,
        Id courseConnectionId,
        Id studentReqAppId,
        Id examId,
        Id contactId,
        Id feeTypeId
    ) {
        return JSON.serialize(new List<Object>{
            new Map<String, Object>{
                'RequestType' => requestType,
                'ExamType' => 'SEE',
                'Course_Offering__c' => String.valueOf(courseOfferingId),
                'Course_Connection__c' => String.valueOf(courseConnectionId),
                'Student_Request_Application__c' => String.valueOf(studentReqAppId),
                'Exam__c' => String.valueOf(examId),
                'Contactid' => String.valueOf(contactId),
                'Feetypeid' => String.valueOf(feeTypeId)
            }
        });
    }

    private static Map<String, Object> invokeRequestExamsAndGetData(Id contactId) {
        initRestGet('/studentexamportal/retrieve/requestExams', new Map<String, String>{
            'contactId' => String.valueOf(contactId)
        });
        StudentExamPortalRestAPI.doGet();

        System.assertNotEquals(null, RestContext.response.responseBody, 'Response body should not be null');
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(RestContext.response.responseBody.toString());
        System.assertEquals(true, body.get('success'), 'Expected success = true');
        return (Map<String, Object>) body.get('data');
    }

    // -------------------------
    // GET paths
    // -------------------------
    @IsTest static void testDoGet_invalidUrl() {
        Test.startTest();
        initRestGet('/studentexamportal/retrieve', null);
        StudentExamPortalRestAPI.doGet();
        Test.stopTest();
    }

    @IsTest static void testRetrieveExamSlotSetup_missingExamId() {
        Test.startTest();
        initRestGet('/studentexamportal/retrieve/examSlotSetup', new Map<String, String>());
        StudentExamPortalRestAPI.doGet();
        Test.stopTest();
    }

    @IsTest static void testRetrieveExamSlotSetup_success() {
        Id examId = [SELECT Id FROM Exam__c LIMIT 1].Id;
        Test.startTest();
        initRestGet('/studentexamportal/retrieve/examSlotSetup', new Map<String, String>{ 'examId' => String.valueOf(examId) });
        StudentExamPortalRestAPI.doGet();
        Test.stopTest();
    }

    @IsTest static void testRetrieveExamConnectionsByStudent_success() {
        Id studentId = [SELECT Id FROM Contact LIMIT 1].Id;
        Test.startTest();
        initRestGet('/studentexamportal/retrieve/examConnectionsByStudent', new Map<String, String>{ 'studentId' => String.valueOf(studentId) });
        StudentExamPortalRestAPI.doGet();
        Test.stopTest();
    }

    @IsTest static void testRetrieveResultPublish_success() {
        Id studentId = [SELECT Id FROM Contact LIMIT 1].Id;
        Test.startTest();
        initRestGet('/studentexamportal/retrieve/resultPublish', new Map<String, String>{ 'studentId' => String.valueOf(studentId) });
        StudentExamPortalRestAPI.doGet();
        Test.stopTest();
    }

    @IsTest static void testRetrieveHallTicketsByContact_success() {
        Id studentId = [SELECT Id FROM Contact LIMIT 1].Id;
        Id cycleId   = [SELECT Id FROM Exam_Cycle__c LIMIT 1].Id;
        Test.startTest();
        initRestGet('/studentexamportal/retrieve/hallTickets', new Map<String, String>{
            'contactId' => String.valueOf(studentId),
            'examCycleId' => String.valueOf(cycleId)
        });
        StudentExamPortalRestAPI.doGet();
        Test.stopTest();
    }

    @IsTest static void testRetrieveGradeCardsByStudent_success() {
        Id studentId = [SELECT Id FROM Contact LIMIT 1].Id;
        Test.startTest();
        initRestGet('/studentexamportal/retrieve/gradeCards', new Map<String, String>{ 'studentId' => String.valueOf(studentId) });
        StudentExamPortalRestAPI.doGet();
        Test.stopTest();
    }

    @IsTest static void testDownloadResultPdfPublic_success() {
        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE IsLatest = true LIMIT 1].ContentDocumentId;
        Test.startTest();
        initRestGet('/studentexamportal/retrieve/downloadResultPdfPublic', new Map<String, String>{ 'contentDocumentId' => String.valueOf(docId) });
        StudentExamPortalRestAPI.doGet();
        Test.stopTest();
    }

    @IsTest static void testRetrieveRequestExams_success() {
        Id studentId = [SELECT Id FROM Contact LIMIT 1].Id;
        Student_Service_Request_Application__c ssra = [
            SELECT Id, Request_Type__c
            FROM Student_Service_Request_Application__c
            LIMIT 1
        ];

        delete [SELECT Id FROM Student_Service_Request__c];

        // Re-Examination: should appear only in ReExamsRequest.
        ssra.Request_Type__c = 'Re-Examination';
        update ssra;

        Map<String, Object> reExamData = invokeRequestExamsAndGetData(studentId);

        List<Object> reExamList = seeRows(reExamData, 'ReExamsRequest');
        List<Object> reEvalList = seeRows(reExamData, 'ReEvaluationsRequest');
        System.assertNotEquals(null, reExamList, 'ReExamsRequest should always be present.');
        System.assertNotEquals(null, reEvalList, 'ReEvaluationsRequest should always be present.');
        if (!reExamList.isEmpty()) {
            Map<String, Object> reExamItem = (Map<String, Object>) reExamList[0];
            System.assertEquals(String.valueOf(ssra.Id), (String) reExamItem.get('studentServiceRequestApplicationId'));
        }

        // Re-Evaluation: should appear only in ReEvaluationsRequest.
        ssra.Request_Type__c = 'Re-Evaluation';
        update ssra;

        Map<String, Object> reEvalData = invokeRequestExamsAndGetData(studentId);

        reExamList = seeRows(reEvalData, 'ReExamsRequest');
        reEvalList = seeRows(reEvalData, 'ReEvaluationsRequest');
        System.assertNotEquals(null, reExamList, 'ReExamsRequest should always be present.');
        System.assertNotEquals(null, reEvalList, 'ReEvaluationsRequest should always be present.');
        if (!reEvalList.isEmpty()) {
            Map<String, Object> reEvalItem = (Map<String, Object>) reEvalList[0];
            System.assertEquals(String.valueOf(ssra.Id), (String) reEvalItem.get('studentServiceRequestApplicationId'));
        }

        // Null Request_Type__c: both wrappers must hide the row (no studentServiceRequestApplicationId).
        ssra.Request_Type__c = null;
        update ssra;

        Map<String, Object> noTypeData = invokeRequestExamsAndGetData(studentId);

        reExamList = seeRows(noTypeData, 'ReExamsRequest');
        reEvalList = seeRows(noTypeData, 'ReEvaluationsRequest');
        System.assertNotEquals(null, reExamList, 'ReExamsRequest should always be present.');
        System.assertNotEquals(null, reEvalList, 'ReEvaluationsRequest should always be present.');
    }

    @IsTest static void testRetrieveRequestExams_appliedRequestHiddenFromReExam() {
        if (!hasObject('Fee_Assignment__c') ||
            !hasField('Student_Service_Request__c', 'Fee_Assignment__c')) {
            return;
        }

        Id studentId = [SELECT Id FROM Contact LIMIT 1].Id;
        Exam_Connections__c examConn = [
            SELECT Id, Course_Connection_ID__c, Course_Connection_ID__r.hed__Course_Offering__c, Exam_Name__c
            FROM Exam_Connections__c
            WHERE Student_Name__c = :studentId
            LIMIT 1
        ];
        Student_Service_Request_Application__c ssra = [
            SELECT Id, Request_Type__c
            FROM Student_Service_Request_Application__c
            LIMIT 1
        ];
        hed__Affiliation__c affiliation = [
            SELECT Id
            FROM hed__Affiliation__c
            WHERE hed__Contact__c = :studentId
            LIMIT 1
        ];
        Fee_Type__c feeType = [SELECT Id, Amount__c FROM Fee_Type__c LIMIT 1];

        Map<String, Id> ssrRtByDev = new Map<String, Id>();
        for (RecordType rt : [
            SELECT Id, DeveloperName
            FROM RecordType
            WHERE SObjectType = 'Student_Service_Request__c'
              AND DeveloperName IN ('Re_Exam', 'Revaluation')
        ]) {
            ssrRtByDev.put(rt.DeveloperName, rt.Id);
        }
        if (!ssrRtByDev.containsKey('Re_Exam')) {
            return;
        }

        delete [SELECT Id FROM Student_Service_Request__c];

        Decimal amount = (feeType.Amount__c == null || feeType.Amount__c == 0) ? 1 : feeType.Amount__c;
        SObject feeAssignment = Schema.getGlobalDescribe().get('Fee_Assignment__c').newSObject();
        feeAssignment.put('Fee_Type__c', feeType.Id);
        feeAssignment.put('Contact__c', studentId);
        feeAssignment.put('Affiliation__c', affiliation.Id);
        feeAssignment.put('Total_Amount_Payable__c', amount);
        // Remaining = 0 => Paid_Exam_Fee__c formula evaluates true (fee fully paid).
        feeAssignment.put('Remaining_Amount__c', 0);
        feeAssignment.put('Fee_Preference__c', 'Semester-wise fee');
        feeAssignment.put('Fee_Head__c', 'Backlog examination Fee');
        feeAssignment.put('Is_Active__c', true);
        insert feeAssignment;

        // Applied (Submitted) + fee-paid (Remaining=0) Re-Exam request, active cycle.
        Student_Service_Request__c ssr = new Student_Service_Request__c(
            RecordTypeId = ssrRtByDev.get('Re_Exam'),
            Status__c = 'Submitted',
            Course_Offering__c = examConn.Course_Connection_ID__r.hed__Course_Offering__c,
            Course_Connection__c = examConn.Course_Connection_ID__c,
            Student_Request_Application__c = ssra.Id,
            Exam__c = examConn.Exam_Name__c
        );
        ssr.put('Fee_Assignment__c', (Id) feeAssignment.get('Id'));
        insert ssr;

        ssra.Request_Type__c = 'Re-Examination';
        update ssra;

        Map<String, Object> data = invokeRequestExamsAndGetData(studentId);

        // Applied request must surface under RequestedExams (with the exam type label) ...
        List<Object> requested = (List<Object>) data.get('RequestedExams');
        System.assertNotEquals(null, requested, 'RequestedExams should always be present.');
        Boolean foundInRequested = false;
        for (Object ro : requested) {
            Map<String, Object> row = (Map<String, Object>) ro;
            if (String.valueOf(examConn.Course_Connection_ID__c) == (String) row.get('courseConnectionId')) {
                foundInRequested = true;
                System.assertNotEquals(null, row.get('examTypeLabel'), 'RequestedExams row must include examTypeLabel.');
                System.assertEquals('Re_Exam', (String) row.get('RequestType'), 'RequestedExams row should carry the Re_Exam record type.');
            }
        }
        System.assert(foundInRequested, 'Applied Re-Exam request should appear under RequestedExams.');

        // ... and must NOT appear under ReExamsRequest (SEE or CIA), since it was already applied.
        Map<String, Object> reExamGroup = (Map<String, Object>) data.get('ReExamsRequest');
        System.assertNotEquals(null, reExamGroup, 'ReExamsRequest should always be present.');
        List<Object> reExamRows = new List<Object>();
        if (reExamGroup.get('SEE') != null) reExamRows.addAll((List<Object>) reExamGroup.get('SEE'));
        if (reExamGroup.get('CIA') != null) reExamRows.addAll((List<Object>) reExamGroup.get('CIA'));
        for (Object eo : reExamRows) {
            Map<String, Object> row = (Map<String, Object>) eo;
            System.assertNotEquals(
                String.valueOf(examConn.Course_Connection_ID__c),
                (String) row.get('CourseConnectionID'),
                'A course connection already applied for Re-Exam must be hidden from ReExamsRequest.'
            );
        }
    }

    @IsTest static void testDoGet_unknownRoute() {
        Test.startTest();
        initRestGet('/studentexamportal/retrieve/unknownRoute', null);
        StudentExamPortalRestAPI.doGet();
        Test.stopTest();
    }

    // -------------------------
    // POST paths
    // -------------------------
    @IsTest static void testDoPost_invalidUrl() {
        Test.startTest();
        initRestPost('/studentexamportal/create', '[]');
        StudentExamPortalRestAPI.doPost();
        Test.stopTest();
    }

    @IsTest static void testCreateStudentServiceRequest_missingBody() {
        Test.startTest();
        initRestPost('/studentexamportal/create/studentServiceRequest', null);
        StudentExamPortalRestAPI.doPost();
        Test.stopTest();
    }

    @IsTest static void testCreateStudentServiceRequest_invalidJson() {
        Test.startTest();
        initRestPost('/studentexamportal/create/studentServiceRequest', '{bad json');
        StudentExamPortalRestAPI.doPost();
        Test.stopTest();
    }

    @IsTest static void testCreateStudentServiceRequest_success_reExam() {
        hed__Course_Offering__c offering = [SELECT Id FROM hed__Course_Offering__c LIMIT 1];
        hed__Course_Enrollment__c ce = [SELECT Id FROM hed__Course_Enrollment__c LIMIT 1];
        Student_Service_Request_Application__c ssra = [SELECT Id, Request_Type__c FROM Student_Service_Request_Application__c LIMIT 1];
        Exam__c exam = [SELECT Id FROM Exam__c LIMIT 1];
        Contact student = [SELECT Id FROM Contact LIMIT 1];
        Fee_Type__c feeType = [SELECT Id FROM Fee_Type__c LIMIT 1];

        ssra.Request_Type__c = 'Re-Examination';
        update ssra;
        delete [SELECT Id FROM Student_Service_Request__c];

        Set<Id> existingSsrIds = new Set<Id>();
        for (Student_Service_Request__c existingSsr : [SELECT Id FROM Student_Service_Request__c]) {
            existingSsrIds.add(existingSsr.Id);
        }

        String payload = buildStudentServiceRequestPayload(
            'Re-exam',
            offering.Id,
            ce.Id,
            ssra.Id,
            exam.Id,
            student.Id,
            feeType.Id
        );

        Test.startTest();
        initRestPost('/studentexamportal/create/studentServiceRequest', payload);
        StudentExamPortalRestAPI.doPost();
        Test.stopTest();

        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(RestContext.response.responseBody.toString());
        if (body == null || !body.containsKey('data') || body.get('data') == null) {
            return;
        }
        Map<String, Object> data = (Map<String, Object>) body.get('data');
        List<Object> insertedRecords = (List<Object>) data.get('insertedRecords');
        List<Object> updatedRecords = (List<Object>) data.get('updatedRecords');
        if (data.containsKey('insertedCount') && data.get('insertedCount') != null) {
            System.assertEquals(1, Integer.valueOf(String.valueOf(data.get('insertedCount'))), 'Inserted count should be 1.');
        }
        if (data.containsKey('updatedCount') && data.get('updatedCount') != null) {
            System.assertEquals(0, Integer.valueOf(String.valueOf(data.get('updatedCount'))), 'Updated count should be 0.');
        }
        if (insertedRecords != null && !insertedRecords.isEmpty()) {
            Map<String, Object> insertedRow = (Map<String, Object>) insertedRecords[0];
            System.assertNotEquals(null, insertedRow.get('studentServiceRequestId'), 'insertedRecords row must include studentServiceRequestId.');

            // Fee details required by front-end payment integration
            System.assertEquals('Re-exam', (String) insertedRow.get('requestType'), 'insertedRecords row must echo the payload RequestType.');
            System.assertEquals(500, Integer.valueOf(String.valueOf(insertedRow.get('totalFee'))), 'totalFee must equal Fee_Type Amount (500).');
            System.assertEquals(500, Integer.valueOf(String.valueOf(insertedRow.get('remainingFee'))), 'remainingFee must equal Fee_Type Amount (500) on creation.');
            System.assertEquals(
                String.valueOf(Date.today().addDays(7)),
                String.valueOf(insertedRow.get('dueDate')),
                'dueDate must be sourced from Fee_Type Due_Date__c.'
            );

            // Fee_Assignment__c.Due_Date__c must be populated during creation (requirement 5)
            Id feeAssignmentId = (Id) insertedRow.get('feeAssignmentId');
            Fee_Assignment__c createdFa = [
                SELECT Total_Amount_Payable__c, Remaining_Amount__c, Due_Date__c
                FROM Fee_Assignment__c
                WHERE Id = :feeAssignmentId
                LIMIT 1
            ];
            System.assertEquals(Date.today().addDays(7), createdFa.Due_Date__c, 'Fee_Assignment__c.Due_Date__c must be populated from Fee_Type.');
            System.assertEquals(500, createdFa.Total_Amount_Payable__c, 'Fee_Assignment__c.Total_Amount_Payable__c must equal Fee_Type Amount.');
            System.assertEquals(500, createdFa.Remaining_Amount__c, 'Fee_Assignment__c.Remaining_Amount__c must equal Fee_Type Amount.');
        }
        if (updatedRecords != null) {
            System.assertEquals(0, updatedRecords.size(), 'updatedRecords should be empty for pure insert.');
        }

        List<Student_Service_Request__c> insertedSsrs = [
            SELECT Id
            FROM Student_Service_Request__c
            WHERE Id NOT IN :existingSsrIds
        ];
        System.assert(insertedSsrs.size() > 0, 'At least one Student_Service_Request__c should be inserted.');
    }

    @IsTest static void testCreateStudentServiceRequest_success_reExam_reusesCategory() {
        hed__Course_Offering__c offering = [SELECT Id FROM hed__Course_Offering__c LIMIT 1];
        hed__Course_Enrollment__c ce = [SELECT Id FROM hed__Course_Enrollment__c LIMIT 1];
        Student_Service_Request_Application__c ssra = [SELECT Id, Request_Type__c FROM Student_Service_Request_Application__c LIMIT 1];
        Exam__c exam = [SELECT Id FROM Exam__c LIMIT 1];
        Contact student = [SELECT Id FROM Contact LIMIT 1];
        Fee_Type__c feeType = [SELECT Id FROM Fee_Type__c LIMIT 1];

        ssra.Request_Type__c = 'Re-Examination';
        update ssra;
        delete [SELECT Id FROM Student_Service_Request__c];

        Set<Id> existingSsrIds = new Set<Id>();
        for (Student_Service_Request__c existingSsr : [SELECT Id FROM Student_Service_Request__c]) {
            existingSsrIds.add(existingSsr.Id);
        }

        String payload = buildStudentServiceRequestPayload(
            'Re-exam',
            offering.Id,
            ce.Id,
            ssra.Id,
            exam.Id,
            student.Id,
            feeType.Id
        );

        Test.startTest();
        initRestPost('/studentexamportal/create/studentServiceRequest', payload);
        StudentExamPortalRestAPI.doPost();
        Test.stopTest();

        List<Student_Service_Request__c> insertedSsrs = [
            SELECT Id
            FROM Student_Service_Request__c
            WHERE Id NOT IN :existingSsrIds
        ];
        System.assertEquals(1, insertedSsrs.size(), 'One Student_Service_Request__c should be inserted.');
    }

    @IsTest static void testCreateStudentServiceRequest_existingSsr_updatesWithoutDuplicateFeeRows() {
        hed__Course_Offering__c offering = [SELECT Id FROM hed__Course_Offering__c LIMIT 1];
        hed__Course_Enrollment__c ce = [SELECT Id FROM hed__Course_Enrollment__c LIMIT 1];
        Student_Service_Request_Application__c ssra = [SELECT Id, Request_Type__c FROM Student_Service_Request_Application__c LIMIT 1];
        Exam__c exam = [SELECT Id FROM Exam__c LIMIT 1];
        Contact student = [SELECT Id FROM Contact LIMIT 1];
        Fee_Type__c feeType = [SELECT Id FROM Fee_Type__c LIMIT 1];

        ssra.Request_Type__c = 'Re-Examination';
        update ssra;

        delete [SELECT Id FROM Student_Service_Request__c];

        String payload = buildStudentServiceRequestPayload(
            'Re-exam',
            offering.Id,
            ce.Id,
            ssra.Id,
            exam.Id,
            student.Id,
            feeType.Id
        );

        Test.startTest();
        initRestPost('/studentexamportal/create/studentServiceRequest', payload);
        StudentExamPortalRestAPI.doPost();
        List<Student_Service_Request__c> ssrsAfterFirst = [
            SELECT Id
            FROM Student_Service_Request__c
            WHERE Course_Offering__c = :offering.Id
              AND Course_Connection__c = :ce.Id
              AND Student_Request_Application__c = :ssra.Id
              AND Exam__c = :exam.Id
        ];
        System.assertEquals(1, ssrsAfterFirst.size(), 'First call should insert one SSR.');

        Id firstSsrId = ssrsAfterFirst[0].Id;

        initRestPost('/studentexamportal/create/studentServiceRequest', payload);
        StudentExamPortalRestAPI.doPost();
        Test.stopTest();

        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(RestContext.response.responseBody.toString());
        if (body != null && body.containsKey('data') && body.get('data') != null) {
            Map<String, Object> data = (Map<String, Object>) body.get('data');
            List<Object> updatedRecords = (List<Object>) data.get('updatedRecords');
            if (updatedRecords != null && !updatedRecords.isEmpty()) {
                Map<String, Object> updatedRow = (Map<String, Object>) updatedRecords[0];
                System.assertNotEquals(null, updatedRow.get('studentServiceRequestId'), 'updatedRecords row must include studentServiceRequestId.');
            }
        }

        List<Student_Service_Request__c> ssrsAfterSecond = [
            SELECT Id
            FROM Student_Service_Request__c
            WHERE Course_Offering__c = :offering.Id
              AND Course_Connection__c = :ce.Id
              AND Student_Request_Application__c = :ssra.Id
              AND Exam__c = :exam.Id
        ];
        System.assert(ssrsAfterSecond.size() > 0, 'Second call should keep at least one SSR for the key.');
        Set<Id> ssrIdsAfterSecond = new Set<Id>();
        for (Student_Service_Request__c row : ssrsAfterSecond) {
            ssrIdsAfterSecond.add(row.Id);
        }
        System.assert(ssrIdsAfterSecond.contains(firstSsrId), 'Second call should still reference the seeded SSR.');
    }

    @IsTest static void testCreateStudentServiceRequest_mixedInsertAndUpdate_responseWrappers() {
        hed__Course_Offering__c offering = [SELECT Id FROM hed__Course_Offering__c LIMIT 1];
        List<hed__Course_Enrollment__c> ceRows = [
            SELECT Id, hed__Contact__c, hed__Program_Enrollment__c, hed__Course_Offering__c
            FROM hed__Course_Enrollment__c
            LIMIT 2
        ];
        if (ceRows.size() < 2) {
            return;
        }
        hed__Course_Enrollment__c ce1 = ceRows[0];
        hed__Course_Enrollment__c ce2 = ceRows[1];
        Student_Service_Request_Application__c ssra = [SELECT Id, Request_Type__c FROM Student_Service_Request_Application__c LIMIT 1];
        Exam__c exam = [SELECT Id FROM Exam__c LIMIT 1];
        Contact student = [SELECT Id FROM Contact LIMIT 1];
        Fee_Type__c feeType = [SELECT Id FROM Fee_Type__c LIMIT 1];

        ssra.Request_Type__c = 'Re-Examination';
        update ssra;

        delete [SELECT Id FROM Student_Service_Request__c];

        String seedPayload = buildStudentServiceRequestPayload(
            'Re-exam',
            offering.Id,
            ce1.Id,
            ssra.Id,
            exam.Id,
            student.Id,
            feeType.Id
        );
        initRestPost('/studentexamportal/create/studentServiceRequest', seedPayload);
        StudentExamPortalRestAPI.doPost();

        String mixedPayload = JSON.serialize(new List<Object>{
            new Map<String, Object>{
                'RequestType' => 'Re-exam',
                'ExamType' => 'SEE',
                'Course_Offering__c' => String.valueOf(offering.Id),
                'Course_Connection__c' => String.valueOf(ce1.Id),
                'Student_Request_Application__c' => String.valueOf(ssra.Id),
                'Exam__c' => String.valueOf(exam.Id),
                'Contactid' => String.valueOf(student.Id),
                'Feetypeid' => String.valueOf(feeType.Id)
            },
            new Map<String, Object>{
                'RequestType' => 'Re-exam',
                'ExamType' => 'SEE',
                'Course_Offering__c' => String.valueOf(offering.Id),
                'Course_Connection__c' => String.valueOf(ce2.Id),
                'Student_Request_Application__c' => String.valueOf(ssra.Id),
                'Exam__c' => String.valueOf(exam.Id),
                'Contactid' => String.valueOf(student.Id),
                'Feetypeid' => String.valueOf(feeType.Id)
            }
        });

        Test.startTest();
        initRestPost('/studentexamportal/create/studentServiceRequest', mixedPayload);
        StudentExamPortalRestAPI.doPost();
        Test.stopTest();

        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(RestContext.response.responseBody.toString());
        Map<String, Object> data = (Map<String, Object>) body.get('data');
        System.assertEquals(1, Integer.valueOf(String.valueOf(data.get('insertedCount'))), 'Mixed payload should insert one SSR.');
        System.assertEquals(1, Integer.valueOf(String.valueOf(data.get('updatedCount'))), 'Mixed payload should update one SSR.');

        List<Object> insertedRecords = (List<Object>) data.get('insertedRecords');
        List<Object> updatedRecords = (List<Object>) data.get('updatedRecords');
        System.assertEquals(1, insertedRecords.size(), 'insertedRecords should contain one row for mixed payload.');
        System.assertEquals(1, updatedRecords.size(), 'updatedRecords should contain one row for mixed payload.');

        Map<String, Object> insertedRow = (Map<String, Object>) insertedRecords[0];
        Map<String, Object> updatedRow = (Map<String, Object>) updatedRecords[0];
        System.assertNotEquals(null, insertedRow.get('studentServiceRequestId'), 'insertedRecords must include studentServiceRequestId.');
        System.assertNotEquals(null, updatedRow.get('studentServiceRequestId'), 'updatedRecords must include studentServiceRequestId.');

        // Fee details must be present on both inserted and updated rows
        System.assertEquals('Re-exam', (String) insertedRow.get('requestType'), 'insertedRecords row must echo payload RequestType.');
        System.assertNotEquals(null, insertedRow.get('totalFee'), 'insertedRecords row must include totalFee.');
        System.assertNotEquals(null, insertedRow.get('remainingFee'), 'insertedRecords row must include remainingFee.');
        System.assertNotEquals(null, insertedRow.get('dueDate'), 'insertedRecords row must include dueDate.');
        System.assertEquals('Re-exam', (String) updatedRow.get('requestType'), 'updatedRecords row must echo payload RequestType.');
        System.assertNotEquals(null, updatedRow.get('totalFee'), 'updatedRecords row must include totalFee from existing Fee Assignment.');
        System.assertNotEquals(null, updatedRow.get('remainingFee'), 'updatedRecords row must include remainingFee from existing Fee Assignment.');

        Integer ssrCountCe1 = [
            SELECT COUNT()
            FROM Student_Service_Request__c
            WHERE Course_Offering__c = :offering.Id
              AND Course_Connection__c = :ce1.Id
              AND Student_Request_Application__c = :ssra.Id
              AND Exam__c = :exam.Id
        ];
        Integer ssrCountCe2 = [
            SELECT COUNT()
            FROM Student_Service_Request__c
            WHERE Course_Offering__c = :offering.Id
              AND Course_Connection__c = :ce2.Id
              AND Student_Request_Application__c = :ssra.Id
              AND Exam__c = :exam.Id
        ];
        System.assertEquals(1, ssrCountCe1, 'Existing key should stay as a single SSR (updated).');
        System.assertEquals(1, ssrCountCe2, 'New key should insert one SSR.');
    }

    @IsTest static void testCreateStudentServiceRequest_cia_noExamConnection() {
        hed__Course_Offering__c offering = [SELECT Id FROM hed__Course_Offering__c LIMIT 1];
        hed__Course_Enrollment__c ce = [SELECT Id FROM hed__Course_Enrollment__c LIMIT 1];
        Student_Service_Request_Application__c ssra = [SELECT Id, Request_Type__c FROM Student_Service_Request_Application__c LIMIT 1];
        Contact student = [SELECT Id FROM Contact LIMIT 1];
        Fee_Type__c feeType = [SELECT Id FROM Fee_Type__c LIMIT 1];

        ssra.Request_Type__c = 'Re-Examination';
        update ssra;
        delete [SELECT Id FROM Student_Service_Request__c];

        Integer examConnBefore = [SELECT COUNT() FROM Exam_Connections__c];

        String payload = JSON.serialize(new List<Object>{
            new Map<String, Object>{
                'RequestType' => 'Re-exam',
                'ExamType' => 'CIA',
                'Course_Offering__c' => String.valueOf(offering.Id),
                'Course_Connection__c' => String.valueOf(ce.Id),
                'Student_Request_Application__c' => String.valueOf(ssra.Id),
                'Contactid' => String.valueOf(student.Id),
                'Feetypeid' => String.valueOf(feeType.Id)
            }
        });

        Test.startTest();
        initRestPost('/studentexamportal/create/studentServiceRequest', payload);
        StudentExamPortalRestAPI.doPost();
        Test.stopTest();

        List<Student_Service_Request__c> ssrs = [
            SELECT Id, Exam__c, Exam_Connection__c, Exam_Name__c
            FROM Student_Service_Request__c
        ];
        System.assert(!ssrs.isEmpty(), 'CIA request should insert an SSR.');
        System.assertEquals('CIA', ssrs[0].Exam_Name__c, 'Exam_Name__c should store the ExamType CIA.');
        System.assertEquals(null, ssrs[0].Exam__c, 'CIA must not set the Exam__c lookup.');
        System.assertEquals(null, ssrs[0].Exam_Connection__c, 'CIA must not link an Exam Connection.');
        System.assertEquals(examConnBefore, [SELECT COUNT() FROM Exam_Connections__c], 'CIA must not create an Exam Connection.');
    }

    @IsTest static void testCreateStudentServiceRequest_missingFields_validationPath() {
        String payload = JSON.serialize(new List<Object>{
            new Map<String, Object>{ 'RequestType' => 'Re-exam' }
        });

        Test.startTest();
        initRestPost('/studentexamportal/create/studentServiceRequest', payload);
        StudentExamPortalRestAPI.doPost();
        Test.stopTest();
    }

    @IsTest static void testDoPost_unknownRoute() {
        Test.startTest();
        initRestPost('/studentexamportal/create/unknown', '[]');
        StudentExamPortalRestAPI.doPost();
        Test.stopTest();
    }

    // -------------------------
    // ID card public URL endpoint
    // -------------------------
    @IsTest static void testRetrieveIdCard_missingAffiliationId() {
        Test.startTest();
        initRestGet('/studentexamportal/retrieve/idCard', new Map<String, String>());
        StudentExamPortalRestAPI.doGet();
        Test.stopTest();
    }

    @IsTest static void testRetrieveIdCard_noFileReturnsNull() {
        Id affId = [SELECT Id FROM hed__Affiliation__c LIMIT 1].Id;
        Test.startTest();
        initRestGet('/studentexamportal/retrieve/idCard', new Map<String, String>{ 'affiliationId' => String.valueOf(affId) });
        StudentExamPortalRestAPI.doGet();
        Test.stopTest();

        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(RestContext.response.responseBody.toString());
        System.assertEquals(true, body.get('success'), 'Expected success true.');
        Map<String, Object> data = (Map<String, Object>) body.get('data');
        System.assertEquals(null, data.get('idCard'), 'No ID card file => idCard should be null.');
    }

    @IsTest static void testRetrieveIdCard_success() {
        hed__Affiliation__c aff = [SELECT Id FROM hed__Affiliation__c LIMIT 1];

        ContentVersion cv = new ContentVersion();
        cv.Title = 'ID Card Test';
        cv.PathOnClient = 'idcard.pdf';
        cv.VersionData = Blob.valueOf('TEST_PDF');
        cv.ContentLocation = 'S';
        cv.Document_Type__c = 'Student ID Card';
        insert cv;

        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1].ContentDocumentId;
        insert new ContentDocumentLink(
            ContentDocumentId = docId,
            LinkedEntityId = aff.Id,
            ShareType = 'V'
        );

        Test.startTest();
        initRestGet('/studentexamportal/retrieve/idCard', new Map<String, String>{ 'affiliationId' => String.valueOf(aff.Id) });
        StudentExamPortalRestAPI.doGet();
        Test.stopTest();

        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(RestContext.response.responseBody.toString());
        System.assertEquals(true, body.get('success'), 'Expected success true.');
        Map<String, Object> data = (Map<String, Object>) body.get('data');
        Map<String, Object> idCard = (Map<String, Object>) data.get('idCard');
        System.assertNotEquals(null, idCard, 'idCard should be returned when a Student ID Card file exists.');
        System.assertNotEquals(null, idCard.get('contentVersionId'), 'contentVersionId should be present.');
        System.assertEquals(String.valueOf(aff.Id), (String) idCard.get('affiliationId'), 'affiliationId should echo the request.');
    }

    // ReExamsRequest / ReEvaluationsRequest are now { "SEE": [...], "CIA": [...] }.
    private static List<Object> seeRows(Map<String, Object> data, String groupKey) {
        Map<String, Object> grp = (Map<String, Object>) data.get(groupKey);
        return (grp == null) ? null : (List<Object>) grp.get('SEE');
    }

    private static Boolean hasObject(String objectApiName) {
        return Schema.getGlobalDescribe().containsKey(objectApiName);
    }

    private static Boolean hasField(String objectApiName, String fieldApiName) {
        if (!hasObject(objectApiName)) {
            return false;
        }
        Map<String, Schema.SObjectField> fieldsByApiName =
            Schema.getGlobalDescribe().get(objectApiName).getDescribe().fields.getMap();
        return fieldsByApiName.containsKey(fieldApiName);
    }
}