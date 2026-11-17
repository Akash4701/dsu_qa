@RestResource(urlMapping = '/studentexamportal/*')
global without sharing class StudentExamPortalRestAPI {
    private static final String URL_BASE = '/studentexamportal/';
    private static final Integer HTTP_BAD_REQUEST = 400;
    private static final Integer HTTP_NOT_FOUND = 404;
    private static final Integer HTTP_ERROR = 500;
    private static final String ERROR_URL_INVALID = 'The request URL is invalid.';


	@HttpPost
    global static void doPost() {
        String requestURI = RestContext.request.requestURI;
        requestURI = requestURI.replace(URL_BASE, '');
        String[] urlParts = requestURI.split('/');
    
        if (urlParts.size() < 2) {
            RestApiUtility.addError(HTTP_NOT_FOUND, ERROR_URL_INVALID);
            return;
        }
    
        // POST endpoint
        if (urlParts[0] + '/' + urlParts[1] == 'create/studentServiceRequest') {
            createStudentServiceRequest();
        } else {
            RestApiUtility.addError(HTTP_NOT_FOUND, ERROR_URL_INVALID);
            return;
        }
    }

    
    @HttpGet
    global static void doGet() {
        String requestURI = RestContext.request.requestURI;
        requestURI = requestURI.replace(URL_BASE, '');
        String[] urlParts = requestURI.split('/');
        
        if (urlParts.size() < 2) {
            RestApiUtility.addError(
                HTTP_NOT_FOUND,
                ERROR_URL_INVALID // Pass the error message string directly
            );
            return;
        }
        
        if (urlParts[0] + '/' + urlParts[1] == 'retrieve/examSlotSetup') {
            retrieveExamSlotSetup();
        } else if (urlParts[0] + '/' + urlParts[1] == 'retrieve/examConnectionsByStudent') {
            retrieveExamConnectionsByStudent();
        } else if (urlParts[0] + '/' + urlParts[1] == 'retrieve/resultPublish') {
    		retrieveResultPublish();
        } else if (urlParts[0] + '/' + urlParts[1] == 'retrieve/hallTickets') {
    		retrieveHallTicketsByContact();
		} else if (urlParts[0] + '/' + urlParts[1] == 'retrieve/gradeCards') {
    		retrieveGradeCardsByStudent();
		} else if (urlParts[0] + '/' + urlParts[1] == 'retrieve/downloadResultPdfPublic') {
    		downloadResultPdfPublic();
        } else if (urlParts[0] + '/' + urlParts[1] == 'retrieve/requestExams') {
    		RetrieveRequestExams();
        } else if (urlParts[0] + '/' + urlParts[1] == 'retrieve/idCard') {
    		retrieveIdCardByAffiliation();
		



        } else {
            RestApiUtility.addError(
                HTTP_NOT_FOUND,
                ERROR_URL_INVALID // Pass the error message string directly
            );
            return;
        }
    }
    
    public static void retrieveExamSlotSetup() {
        RestRequest request = RestContext.request;
        String examId = RestContext.request.params.get('examId');
        System.debug('examId'+examId);
        
        List<ExamSlotSetupWrapper> recurringSlots = new List<ExamSlotSetupWrapper>();
        List<ExamSlotSetupWrapper> individualSlots = new List<ExamSlotSetupWrapper>();
        
        if(String.isBlank(examId)) {
            RestApiUtility.addError(
                HTTP_BAD_REQUEST,
                'Missing examId' // Pass the error message string directly
            );
            return;
        }
        
        List<Exam_Slot_Setup__c> slotSetups = [
            SELECT Id, Start_Date__c, Start_Time__c, End_Date__c, End_Time__c, Exam__c, RecordType.DeveloperName,Exam__r.Exam_Cycle__c,
            Exam__r.Course_Evaluation_Component__r.Course_Offering__r.hed__Term__r.Term_Reference__c
            FROM Exam_Slot_Setup__c 
            WHERE Exam__c = :examId
        ];
        
        if(slotSetups.isEmpty()) {
            Map<String, Object> response = new Map<String, Object>{
                'recurringSlots' => new List<ExamSlotSetupWrapper>(),
                'individualSlots' => new List<ExamSlotSetupWrapper>()
            };
            RestApiUtility.createSuccessGetResponse(response);
            return;
        }
        
        for(Exam_Slot_Setup__c slotSetup : slotSetups) {
            ExamSlotSetupWrapper wrapper = new ExamSlotSetupWrapper();
            wrapper.id = slotSetup.Id;
            wrapper.startDate = slotSetup.Start_Date__c;
            wrapper.startTime = slotSetup.Start_Time__c;
            wrapper.endDate = slotSetup.End_Date__c;
            wrapper.endTime = slotSetup.End_Time__c;
            wrapper.examId = slotSetup.Exam__c;
            wrapper.semester = slotSetup.Exam__r.Course_Evaluation_Component__r.Course_Offering__r.hed__Term__r.Term_Reference__c;
            wrapper.examcycle = slotSetup.Exam__r.Exam_Cycle__c;
            wrapper.recordTypeDeveloperName = slotSetup.RecordType.DeveloperName;
            
            
            if(slotSetup.RecordType.DeveloperName == 'Individual') {
                individualSlots.add(wrapper);
            } else if(slotSetup.RecordType.DeveloperName == 'Recurring') {
                recurringSlots.add(wrapper);
            }
        }
        
        Map<String, Object> response = new Map<String, Object>{
            'recurringSlots' => recurringSlots,
            'individualSlots' => individualSlots
        };
        
        RestApiUtility.createSuccessGetResponse(response);
		System.debug(response);
    }
    
    	public static void retrieveExamConnectionsByStudent() {
        RestRequest request = RestContext.request;
        String studentId = RestContext.request.params.get('studentId');
    
        if (String.isBlank(studentId)) {
            RestApiUtility.addError(HTTP_BAD_REQUEST, 'Missing studentId');
            return;
        }
    
        // Query Exam Connections
        List<Exam_Connections__c> examConnList = [
            SELECT Id,
                   Course_Connection_ID__r.hed__Course_Offering__r.hed__Course__r.Name,
                   Course_Connection_ID__r.hed__Course_Offering__r.hed__Course__c,
                   Course_Connection_ID__r.hed__Course_Offering__r.hed__Course__r.hed__Course_ID__c,
                   Exam_Name__r.Exam_Name__c,
                   Exam_Name__r.Course_Evaluation_Component__r.Course_Offering__r.hed__Term__r.Term_Reference__c,
                   Course_Connection_ID__r.hed__Course_Offering__r.hed__Course__r.Credits__c,
                   Eligibility__c,
                   Exam_Name__c,
                   Exam_Name__r.Start_Date__c,
                   Exam_Name__r.Start_Time__c,
                   Exam_Name__r.Exam_Date__c,
                   Exam_Name__r.End_Time__c,
                   Exam_Name__r.Exam_Cycle__r.Name,
				   Exam_Name__r.Exam_Cycle__r.Last_Date_to_Enroll__c,
                   Exam_Name__r.Exam_Cycle__r.Is_Active__c,
                   Exam_Type__c
            FROM Exam_Connections__c
            WHERE Student_Name__c = :studentId AND Exam_Name__r.Exam_Cycle__r.Is_Active__c=True
        ];
    
        // Early exit if no exam connections
        if (examConnList.isEmpty()) {
            Map<String, Object> response = new Map<String, Object>{
                'examConnections' => new List<ExamConnectionByStudentWrapper>(),
                'scheduledSlots' => new List<ScheduledSlotWrapper>()
            };
            RestApiUtility.createSuccessGetResponse(response);
            return;
        }
    
        // Collect Exam Connection IDs
        Set<Id> examConnIds = new Set<Id>();
        for (Exam_Connections__c ec : examConnList) {
            examConnIds.add(ec.Id);
        }
    
        // Find which Exam Connections have at least one non-expired Slot Scheduled
        Set<Id> examConnIdsWithActiveSlot = new Set<Id>();
        for (AggregateResult ar : [
            SELECT Exam_Connection__c
            FROM Slot_Scheduled__c
            WHERE Exam_Connection__c IN :examConnIds
              AND Is_Expired__c = false
            GROUP BY Exam_Connection__c
        ]) {
            examConnIdsWithActiveSlot.add((Id) ar.get('Exam_Connection__c'));
        }

        // Exam fee paid status per Exam Connection
        Map<Id, Boolean> examFeePaidByExamConnId = new Map<Id, Boolean>();
        for (Student_Service_Request__c ssr : [
            SELECT Id, Exam_Connection__c, Paid_Exam_Fee__c
            FROM Student_Service_Request__c
            WHERE Exam_Connection__c IN :examConnIds
        ]) {
            if (ssr.Exam_Connection__c != null) {
                examFeePaidByExamConnId.put(ssr.Exam_Connection__c, ssr.Paid_Exam_Fee__c == true);
            }
        }

        // Build examConnections list with new flag
        List<ExamConnectionByStudentWrapper> examConnections = new List<ExamConnectionByStudentWrapper>();
        for (Exam_Connections__c examConn : examConnList) {
            ExamConnectionByStudentWrapper wrapper = new ExamConnectionByStudentWrapper();
            wrapper.id = examConn.Id;
            wrapper.courseName = examConn.Course_Connection_ID__r?.hed__Course_Offering__r?.hed__Course__r?.Name;
            wrapper.courseCode = examConn.Course_Connection_ID__r?.hed__Course_Offering__r?.hed__Course__r?.hed__Course_ID__c;
            wrapper.examName = examConn.Exam_Name__r?.Exam_Name__c;
            wrapper.credits = examConn.Course_Connection_ID__r?.hed__Course_Offering__r?.hed__Course__r?.Credits__c;
            wrapper.eligibility = examConn.Eligibility__c;
            wrapper.examid = examConn.Exam_Name__c;
            wrapper.StartDate = examConn.Exam_Name__r?.Start_Date__c;
            wrapper.StartTime = examConn.Exam_Name__r?.Start_Time__c;
            wrapper.EndDate = examConn.Exam_Name__r?.Exam_Date__c;
            wrapper.EndTime = examConn.Exam_Name__r?.End_Time__c;
            wrapper.CourseId = examConn.Course_Connection_ID__r?.hed__Course_Offering__r?.hed__Course__c;
            wrapper.examcycle = examConn.Exam_Name__r?.Exam_Cycle__r?.Name;
            wrapper.examcycleId = examConn.Exam_Name__r?.Exam_Cycle__c;
            wrapper.LastDatetoEnroll = examConn.Exam_Name__r?.Exam_Cycle__r?.Last_Date_to_Enroll__c;
            wrapper.Semenster = examConn.Exam_Name__r?.Course_Evaluation_Component__r?.Course_Offering__r?.hed__Term__r?.Term_Reference__c;
            wrapper.examConnectionSlotScheduled = examConnIdsWithActiveSlot.contains(examConn.Id);
            wrapper.examCycleStatus = examConn.Exam_Name__r?.Exam_Cycle__r?.Is_Active__c;
            wrapper.examTypeCategory = examConn.Exam_Type__c;
            wrapper.examFeePaid = examFeePaidByExamConnId.containsKey(examConn.Id) && examFeePaidByExamConnId.get(examConn.Id);
    
            examConnections.add(wrapper);
        }
    
        // Now handle scheduledSlots (as before)
        List<Slot_Scheduled__c> scheduledSlotList = [
            SELECT Id, Start_Date_Time__c, End_Date_Time__c, Exam__c, Schedule_URL__c, Schedule_Id__c, 
                   Student_ID__c, Course_ID__c, Course_ID__r.Name, Exam__r.Name, 
                   Exam__r.Exam_Cycle__r.Name,Exam__r.Exam_Cycle__c,
                   Exam__r.Course_Evaluation_Component__r.Course_Offering__r.hed__Term__r.Term_Reference__c,
                   Exam_Connection__r.Exam_Type__c  
            FROM Slot_Scheduled__c 
            WHERE Student_ID__c = :studentId 
              AND Exam_Connection__r.Course_Connection_ID__r.Exam_Eligibility__c = 'Eligible' AND Exam__r.Exam_Cycle__r.Is_Active__c=True
        ];
    
        Set<Id> slotIds = new Set<Id>();
        for (Slot_Scheduled__c slot : scheduledSlotList) {
            slotIds.add(slot.Id);
        }
    
        Map<Id, List<Component_Scores__c>> scoresBySlotId = new Map<Id, List<Component_Scores__c>>();
        for (Component_Scores__c score : [
            SELECT Id, Slot_Scheduled__c
            FROM Component_Scores__c 
            WHERE Slot_Scheduled__c IN :slotIds
        ]) {
            if (!scoresBySlotId.containsKey(score.Slot_Scheduled__c)) {
                scoresBySlotId.put(score.Slot_Scheduled__c, new List<Component_Scores__c>());
            }
            scoresBySlotId.get(score.Slot_Scheduled__c).add(score);
        }
    
        List<ScheduledSlotWrapper> scheduledSlots = new List<ScheduledSlotWrapper>();
        for (Slot_Scheduled__c slot : scheduledSlotList) {
            ScheduledSlotWrapper wrapper = new ScheduledSlotWrapper();
            wrapper.id = slot.Id;
            wrapper.startDateTime = slot.Start_Date_Time__c;
            wrapper.endDateTime = slot.End_Date_Time__c;
            wrapper.examId = slot.Exam__c;
            wrapper.scheduleUrl = slot.Schedule_URL__c;
            wrapper.scheduleId = slot.Schedule_Id__c;
            wrapper.studentId = slot.Student_ID__c;
            wrapper.courseId = slot.Course_ID__c;
            wrapper.courseName = slot.Course_ID__r?.Name;
            wrapper.examName = slot.Exam__r?.Name;
            wrapper.semester = slot.Exam__r?.Course_Evaluation_Component__r?.Course_Offering__r?.hed__Term__r?.Term_Reference__c;
            wrapper.examcycle = slot.Exam__r?.Exam_Cycle__r?.Name;
            wrapper.examcycleID = slot.Exam__r?.Exam_Cycle__c;
            wrapper.examType = slot.Exam_Connection__r?.Exam_Type__c;

            wrapper.componentScores = new List<ComponentScoreWrapper>();
            if (scoresBySlotId.containsKey(slot.Id)) {
                for (Component_Scores__c cs : scoresBySlotId.get(slot.Id)) {
                    ComponentScoreWrapper scoreWrapper = new ComponentScoreWrapper();
                    scoreWrapper.id = cs.Id;
                    wrapper.componentScores.add(scoreWrapper);
                }
            }
    
            scheduledSlots.add(wrapper);
        }
    
        // Final response
        Map<String, Object> response = new Map<String, Object>{
            'examConnections' => examConnections,
            'scheduledSlots' => scheduledSlots
        };
    
        RestApiUtility.createSuccessGetResponse(response);
    }
    
    public static void retrieveResultPublish() {
        String studentId = RestContext.request.params.get('studentId');
    
        if (String.isBlank(studentId)) {
            RestApiUtility.addError(HTTP_BAD_REQUEST, 'Missing studentId');
            return;
        }
    
        List<ResultPublishWrapper> results = new List<ResultPublishWrapper>();
    
        List<hed__Course_Enrollment__c> ceList = [
            SELECT Id,
                   hed__Course_Offering__r.hed__Course__r.Name,
                   hed__Course_Offering__r.hed__Course__r.hed__Course_ID__c,
                   hed__Course_Offering__r.hed__Course__r.Credits__c,
                   Final_Grade__c,
                   Component_Final_Score__c,
                   hed__Program_Enrollment__r.SGPA__c,
                   hed__Program_Enrollment__r.Term__r.Term_Reference__c,
                   hed__Program_Enrollment__r.Term__r.hed__End_Date__c,
                   hed__Program_Enrollment__r.Term__r.hed__Start_Date__c,
				   hed__Program_Enrollment__r.hed__Program_Plan__c,
				   hed__Program_Enrollment__r.hed__Program_Plan__r.hed__Account__r.Number_of_Terms__c,
                   hed__Credits_Earned__c,
                   hed__Course_Offering__r.Result_Published__c,
                   hed__Program_Enrollment__r.Term__c,
                   hed__Contact__c
            FROM hed__Course_Enrollment__c
            WHERE hed__Program_Enrollment__r.Term__r.Result_Published__c = true
              AND hed__Course_Offering__r.Result_Published__c = true
              AND hed__Contact__c = :studentId
              AND Result_with_hold__c = false
        ];
    
        if (ceList.isEmpty()) {
            Map<String, Object> response = new Map<String, Object>{
                'resultPublish' => new List<ResultPublishWrapper>()
            };
            RestApiUtility.createSuccessGetResponse(response);
            return;
        }
    
        // ----------------------------
        // ✅ NEW: Fetch CGPA once using contactId (from ceList)
        // ----------------------------
        Id contactId = ceList[0].hed__Contact__c;
        Id programplan =ceList[0].hed__Program_Enrollment__r.hed__Program_Plan__c;
        Decimal cgpaValue; String TermDuriation;
        try {
            hed__Affiliation__c aff = [
                SELECT Id, CGPA__c,Program_Plan__r.hed__Account__r.Number_of_Terms__c
                FROM hed__Affiliation__c
                WHERE hed__Contact__c = :contactId AND Program_Plan__c =:programplan
                LIMIT 1
            ];
            cgpaValue = aff.CGPA__c;
			TermDuriation = aff.Program_Plan__r.hed__Account__r.Number_of_Terms__c;
        } catch (Exception e) {
            cgpaValue = null; // if no affiliation found
        }
    
        // Collect Course Enrollment Ids (used as Course_Connection__c as per your requirement)
        Set<Id> courseConnIds = new Set<Id>();
        for (hed__Course_Enrollment__c ce : ceList) {
            courseConnIds.add(ce.Id);
        }
    
        // Fetch latest exam cycle name per course connection for the remarks field
        Map<Id, String> examCycleNameByCourseConnId = new Map<Id, String>();
        for (Exam_Connections__c ec : [
            SELECT Id, Course_Connection_ID__c, CreatedDate, Exam_Name__r.Exam_Cycle__r.Name
            FROM Exam_Connections__c
            WHERE Course_Connection_ID__c IN :courseConnIds
            ORDER BY CreatedDate DESC
        ]) {
            if (!examCycleNameByCourseConnId.containsKey(ec.Course_Connection_ID__c)) {
                examCycleNameByCourseConnId.put(ec.Course_Connection_ID__c, ec.Exam_Name__r?.Exam_Cycle__r?.Name);
            }
        }

        // Fetch marks breakdown for all course connections in bulk
        Map<Id, List<MarksBreakdownWrapper>> breakdownByCourseConnId = new Map<Id, List<MarksBreakdownWrapper>>();
        for (Component_Scores__c cs : [
            SELECT Id, Marks_Obtained__c, Component_Name__r.Pass_Weightage__c, Component_Name__r.Name, Course_Connection__c
            FROM Component_Scores__c
            WHERE Course_Connection__c IN :courseConnIds
        ]) {
            if (!breakdownByCourseConnId.containsKey(cs.Course_Connection__c)) {
                breakdownByCourseConnId.put(cs.Course_Connection__c, new List<MarksBreakdownWrapper>());
            }
    
            MarksBreakdownWrapper mb = new MarksBreakdownWrapper();
            mb.id = cs.Id;
            mb.name = cs.Component_Name__r != null ? cs.Component_Name__r.Name : null;
            mb.marksObtained = cs.Marks_Obtained__c;
            mb.passWeightage = cs.Component_Name__r != null ? cs.Component_Name__r.Pass_Weightage__c : null;
    
            breakdownByCourseConnId.get(cs.Course_Connection__c).add(mb);
        }
    
        // Build response
        for (hed__Course_Enrollment__c ce : ceList) {
            ResultPublishWrapper w = new ResultPublishWrapper();
            w.id = ce.Id;
            w.courseName = ce.hed__Course_Offering__r?.hed__Course__r?.Name;
            w.courseCode = ce.hed__Course_Offering__r?.hed__Course__r?.hed__Course_ID__c;
            w.credits = ce.hed__Course_Offering__r?.hed__Course__r?.Credits__c;
            w.finalGrade = ce.Final_Grade__c;
            w.componentFinalScore = ce.Component_Final_Score__c;
            w.gpa = ce.hed__Program_Enrollment__r?.SGPA__c;
            w.termReference = ce.hed__Program_Enrollment__r?.Term__r?.Term_Reference__c;
            w.SemesterStartDate = ce.hed__Program_Enrollment__r?.Term__r?.hed__Start_Date__c;
            w.SemesterEndDate = ce.hed__Program_Enrollment__r?.Term__r?.hed__End_Date__c;
            w.CreditsEarned = ce.hed__Credits_Earned__c;
            w.TermId = ce.hed__Program_Enrollment__r?.Term__c;
    
            // ✅ NEW: set cgpa for each item (same value for the student)
            w.cgpa = cgpaValue;

            w.remarks = examCycleNameByCourseConnId.get(ce.Id);

            // nested wrapper list
            w.marksBreakdown = breakdownByCourseConnId.containsKey(ce.Id)
                ? breakdownByCourseConnId.get(ce.Id)
                : new List<MarksBreakdownWrapper>();
    
            results.add(w);
        }
    
        Map<String, Object> response = new Map<String, Object>{
            'resultPublish' => results,
            'cgpa' => cgpaValue ,
            'TermDuriation' =>TermDuriation
        };
    
        RestApiUtility.createSuccessGetResponse(response);
    }

    
    public static void retrieveHallTicketsByContact() {
        RestRequest req = RestContext.request;
        String contactId = req.params.get('contactId');
        String examCycleId = req.params.get('examCycleId');
    
        // === Input Validation ===
        if (String.isBlank(contactId)) {
            RestApiUtility.addError(HTTP_BAD_REQUEST, 'Missing contactId');
            return;
        }
        if (String.isBlank(examCycleId)) {
            RestApiUtility.addError(HTTP_BAD_REQUEST, 'Missing examCycleId');
            return;
        }
    
        // === Validate Exam Cycle exists AND is published for hall tickets ===
        Exam_Cycle__c examCycle;
        try {
            examCycle = [
                SELECT Id,Publish_Hall_Ticket__c
                FROM Exam_Cycle__c
                WHERE Id = :examCycleId
                AND Publish_Hall_Ticket__c = true
                AND Active__c = true
                LIMIT 1
            ];
        } catch (Exception e) {
            RestApiUtility.addError(HTTP_NOT_FOUND, 'Exam cycle not found or hall tickets not published');
            return;
        }
    
        if (examCycle == null) {
            RestApiUtility.addError(HTTP_NOT_FOUND, 'Exam cycle not found or hall tickets not published');
            return;
        }
    
        // === Fetch Contact ===
        Contact con;
        try {
            con = [
                SELECT Id, Name, Passport_Size_Photo__c
                FROM Contact
                WHERE Id = :contactId
                LIMIT 1
            ];
        } catch (Exception e) {
            RestApiUtility.addError(HTTP_NOT_FOUND, 'Contact not found');
            return;
        }
    
        // === Fetch Affiliation (Roll Number & Program Plan) ===
        hed__Affiliation__c aff = null;
        List<hed__Affiliation__c> affList = [
            SELECT Roll_Number__c, Program_Plan__r.Name
            FROM hed__Affiliation__c
            WHERE hed__Contact__c = :contactId
              AND Roll_Number__c != null
            LIMIT 1
        ];
    
        if (!affList.isEmpty()) {
            aff = affList[0];
        }
    
        // === Fetch Scheduled Slots with course details ===
        List<Slot_Scheduled__c> slots = [
            SELECT Id,
                   Start_Date_Time__c,
                   End_Date_Time__c,
                   Course_ID__r.hed__Course_ID__c,
                   Course_ID__r.Name,
            	   Exam__r.Course_Evaluation_Component__r.Course_Offering__r.hed__Term__r.Term_Reference__c,
            	   Exam__r.Exam_Cycle__r.Publish_Hall_Ticket__c
            FROM Slot_Scheduled__c
            WHERE Student_ID__c = :contactId
              AND Exam__r.Exam_Cycle__c = :examCycleId
              AND Start_Date_Time__c != null
              AND Is_Expired__c = false
            ORDER BY Start_Date_Time__c ASC
        ];
    
        // === Build course list ===
        List<CourseSlotWrapper> courseSlots = new List<CourseSlotWrapper>();
        for (Slot_Scheduled__c slot : slots) {
            CourseSlotWrapper cw = new CourseSlotWrapper();
            cw.slotScheduledId = slot.Id;
            cw.startDateTime = slot.Start_Date_Time__c;
            cw.endDateTime = slot.End_Date_Time__c;
            cw.courseCode = slot.Course_ID__r?.hed__Course_ID__c;
            cw.courseName = slot.Course_ID__r?.Name;
         //   cw.PublishHallTicket = slot.Exam__r.Exam_Cycle__r.Publish_Hall_Ticket__c;
            cw.Semester = slot.Exam__r.Course_Evaluation_Component__r.Course_Offering__r.hed__Term__r.Term_Reference__c;
            courseSlots.add(cw);
        }
    
        // === Final response ===
        HallTicketResponseWrapper responseWrapper = new HallTicketResponseWrapper();
        responseWrapper.contactId = con.Id;
        responseWrapper.PublishHallTicket = examCycle.Publish_Hall_Ticket__c;
        responseWrapper.contactName = con.Name;
        responseWrapper.contactPhoto = String.isBlank(con.Passport_Size_Photo__c) ? null : con.Passport_Size_Photo__c.trim();

        responseWrapper.usnNumber = aff != null ? aff.Roll_Number__c : null;
        responseWrapper.programPlan = aff != null ? aff.Program_Plan__r.Name : null;
        responseWrapper.courses = courseSlots;
    
        Map<String, Object> response = new Map<String, Object>{
            'hallTicket' => responseWrapper
        };
    
        RestApiUtility.createSuccessGetResponse(response);
    }

	public static void retrieveGradeCardsByStudent() {
        String studentId = RestContext.request.params.get('studentId');
    
        if (String.isBlank(studentId)) {
            RestApiUtility.addError(HTTP_BAD_REQUEST, 'Missing studentId');
            return;
        }
    
        // 1) Program Enrollments for the student (Term wise)
        List<hed__Program_Enrollment__c> peList = [
            SELECT Id, Term__c, Term__r.Term_Reference__c
            FROM hed__Program_Enrollment__c
            WHERE hed__Contact__c = :studentId
        ];
    
        if (peList.isEmpty()) {
            Map<String, Object> response = new Map<String, Object>{
                'gradeCards' => new List<GradeCardWrapper>()
            };
            RestApiUtility.createSuccessGetResponse(response);
            return;
        }
    
        Set<Id> programEnrollmentIds = new Set<Id>();
        Map<Id, String> termRefByPeId = new Map<Id, String>();
        for (hed__Program_Enrollment__c pe : peList) {
            programEnrollmentIds.add(pe.Id);
            termRefByPeId.put(pe.Id, pe.Term__r != null ? pe.Term__r.Term_Reference__c : null);
        }
    
        // 2) ContentDocumentLinks sorted DESC (NO LIMIT) - pick first per LinkedEntityId in Apex
        Map<Id, GradeCardWrapper> latestGradeCardByPE = new Map<Id, GradeCardWrapper>();
        List<ContentDocumentLink> cdlList = [
            SELECT LinkedEntityId,
                   ContentDocumentId,
                   ContentDocument.Title,
                   ContentDocument.FileExtension,
                   ContentDocument.ContentSize,
                   ContentDocument.CreatedDate
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :programEnrollmentIds
            ORDER BY ContentDocument.CreatedDate DESC
        ];
    
        if (cdlList.isEmpty()) {
            Map<String, Object> response = new Map<String, Object>{
                'gradeCards' => new List<GradeCardWrapper>()
            };
            RestApiUtility.createSuccessGetResponse(response);
            return;
        }
    
        // 3) Collect ContentDocumentIds
        Set<Id> contentDocIds = new Set<Id>();
        for (ContentDocumentLink cdl : cdlList) {
            contentDocIds.add(cdl.ContentDocumentId);
        }
    
        // 4) Latest ContentVersion per ContentDocumentId where Document_Type__c = 'Grade Card'
        Map<Id, ContentVersion> latestCvByDocId = new Map<Id, ContentVersion>();
        for (ContentVersion cv : [
            SELECT Id,
                   ContentDocumentId,
                   Title,
                   FileType,
                   VersionNumber,
                   ContentSize,
                   CreatedDate,
                   Document_Type__c
            FROM ContentVersion
            WHERE ContentDocumentId IN :contentDocIds
              AND IsLatest = true
              AND Document_Type__c = 'Grade Card'
            ORDER BY CreatedDate DESC
        ]) {
            if (!latestCvByDocId.containsKey(cv.ContentDocumentId)) {
                latestCvByDocId.put(cv.ContentDocumentId, cv);
            }
        }
    
        if (latestCvByDocId.isEmpty()) {
            Map<String, Object> response = new Map<String, Object>{
                'gradeCards' => new List<GradeCardWrapper>()
            };
            RestApiUtility.createSuccessGetResponse(response);
            return;
        }
    
        // 5) Build 1 latest grade card per Program Enrollment (LinkedEntityId)
        // Also generate/reuse ContentDistribution public links
        for (ContentDocumentLink cdl : cdlList) {
    
            // already picked for this Program Enrollment
            if (latestGradeCardByPE.containsKey(cdl.LinkedEntityId)) continue;
    
            // skip if not a grade card document
            if (!latestCvByDocId.containsKey(cdl.ContentDocumentId)) continue;
    
            ContentVersion cv = latestCvByDocId.get(cdl.ContentDocumentId);
    
            GradeCardWrapper w = new GradeCardWrapper();
            w.studentId = studentId;
            w.programEnrollmentId = (Id) cdl.LinkedEntityId;
            w.termReference = termRefByPeId.get(cdl.LinkedEntityId);
    
            w.contentDocumentId = cdl.ContentDocumentId;
            w.contentVersionId = cv.Id;
    
            w.title = cv.Title;
            w.fileType = cv.FileType;
            w.versionNumber = cv.VersionNumber;
            w.contentSize = cv.ContentSize;
            w.createdDate = cv.CreatedDate;
    
            // -----------------------------
            // ✅ PUBLIC DOWNLOAD / PREVIEW URL (no session)
            // Create or reuse a public link using ContentDistribution
            // -----------------------------
            ContentDistribution cd;
            List<ContentDistribution> existing = [
                SELECT Id, DistributionPublicUrl, ContentDownloadUrl, ContentVersionId
                FROM ContentDistribution
                WHERE ContentVersionId = :cv.Id
                LIMIT 1
            ];
    
            if (!existing.isEmpty()) {
                cd = existing[0];
            } else {
                cd = new ContentDistribution();
                cd.Name = cv.Title;
                cd.ContentVersionId = cv.Id;
    
                // preferences (adjust if you want stricter behavior)
                cd.PreferencesAllowViewInBrowser = true;
                cd.PreferencesAllowOriginalDownload = true;
                cd.PreferencesLinkLatestVersion = true;
                cd.PreferencesNotifyOnVisit = false;
    
                insert cd;
    
                cd = [
                    SELECT Id, DistributionPublicUrl, ContentDownloadUrl
                    FROM ContentDistribution
                    WHERE Id = :cd.Id
                    LIMIT 1
                ];
            }
    
            // Give both (frontend can use either)
            w.previewUrl = cd.DistributionPublicUrl;   // opens in browser
            w.downloadUrl = cd.ContentDownloadUrl;     // direct download link
    
            latestGradeCardByPE.put(cdl.LinkedEntityId, w);
        }
    
        // 6) Response list
        List<GradeCardWrapper> outList = new List<GradeCardWrapper>();
        outList.addAll(latestGradeCardByPE.values());
    
        Map<String, Object> response = new Map<String, Object>{
            'gradeCards' => outList
        };
        RestApiUtility.createSuccessGetResponse(response);
    }


	
    	global static void downloadResultPdfPublic() {
    
            RestRequest req = RestContext.request;
            RestResponse res = RestContext.response;
        
            String contentDocumentId = req.params.get('contentDocumentId');
            if (String.isBlank(contentDocumentId)) {
                res.statusCode = HTTP_BAD_REQUEST;
                res.responseBody = Blob.valueOf('Missing contentDocumentId');
                return;
            }
        
            try {
                ContentVersion cv = [
                    SELECT VersionData, Title, FileExtension
                    FROM ContentVersion
                    WHERE ContentDocumentId = :contentDocumentId
                      AND IsLatest = true
                    LIMIT 1
                ];
        
                // Headers for browser + public usage
                res.addHeader('Content-Type', 'application/pdf');
                res.addHeader(
                    'Content-Disposition',
                    'inline; filename="' + cv.Title + '.pdf"'
                );
                res.addHeader('Cache-Control', 'public, max-age=3600');
        
                res.responseBody = cv.VersionData;
        
            } catch (Exception e) {
                res.statusCode = HTTP_NOT_FOUND;
                res.responseBody = Blob.valueOf('File not found or access denied');
            }
        }
        
       
    
    
    
    
    public static void RetrieveRequestExams() {
            RestRequest req = RestContext.request;
            String contactId = req.params.get('contactId');
        
            if (String.isBlank(contactId)) {
                RestApiUtility.addError(HTTP_BAD_REQUEST, 'Missing contactId');
                return;
            }
        
            // ----------------------------
            // Query 1: Re-Exam eligible (Final Grade = F / IC)
            // ----------------------------
            List<Exam_Connections__c> reExamConnList = [
                SELECT Id,
                       Course_Connection_ID__c,
                       Course_Connection_ID__r.hed__Course_Offering__c,
                       Course_Connection_ID__r.Final_Grade__c,
                       Course_Connection_ID__r.hed__Course_Offering__r.Result_Published__c,
                       Course_Connection_ID__r.hed__Course_Offering__r.hed__Course__c,
                       Course_Connection_ID__r.hed__Course_Offering__r.hed__Course__r.Name,
                       Course_Connection_ID__r.hed__Course_Offering__r.hed__Term__r.Term_Reference__c,
                       Course_Connection_ID__r.hed__Course_Offering__r.hed__Course__r.hed__Course_ID__c,
                       Course_Connection_ID__r.hed__Course_Offering__r.hed__Course__r.Credits__c,
                       Exam_Name__c,
                       Exam_Name__r.Exam_Name__c,
                       Exam_Name__r.Exam_Cycle__c,
                       Course_Connection_ID__r.hed__Course_Offering__r.hed__Term__c
                FROM Exam_Connections__c
                WHERE Student_Name__c = :contactId
                  AND (Course_Connection_ID__r.Final_Grade__c = 'F' OR Course_Connection_ID__r.Final_Grade__c = 'IC')
                  AND Eligibility__c = 'Eligible'
                  AND Course_Connection_ID__r.Exam_Eligibility__c = 'Eligible'
                  AND Course_Connection_ID__r.Enrollment_Status__c = 'Enrolled'
                  AND Course_Connection_ID__r.hed__Course_Offering__r.Result_Published__c = true
                  AND Exam_Type__c !='Retest'
                  AND Exam_Name__c != null
            ];

            // ----------------------------
            // Re-Exam scope: course codes that have an exam in any ACTIVE exam cycle.
            // A failed/IC course connection is only offered for re-exam when its course
            // code (hed__Course_ID__c) currently appears in an active exam cycle's exams.
            // ----------------------------
            // Failed connections can belong to OLD cycles, so the re-exam is driven by the
            // ACTIVE exam cycle that currently offers the course (matched by course code).
            // Capture that active cycle + term per course code so the fee application
            // (Student_Service_Request_Application__c) is matched against the active cycle.
            Set<String> activeExamCycleCourseCodes = new Set<String>();
            Map<String, Id> activeCycleIdByCourseCode = new Map<String, Id>();
            Map<String, Id> activeTermIdByCourseCode = new Map<String, Id>();
            for (Exam__c ex : [
                SELECT Id,
                       Exam_Cycle__c,
                       Course_Evaluation_Component__r.Course_Offering__r.hed__Term__c,
                       Course_Evaluation_Component__r.Course_Offering__r.hed__Course__r.hed__Course_ID__c
                FROM Exam__c
                WHERE Exam_Cycle__r.Is_Active__c = true
            ]) {
                String code = (ex.Course_Evaluation_Component__r != null
                        && ex.Course_Evaluation_Component__r.Course_Offering__r != null
                        && ex.Course_Evaluation_Component__r.Course_Offering__r.hed__Course__r != null)
                    ? ex.Course_Evaluation_Component__r.Course_Offering__r.hed__Course__r.hed__Course_ID__c
                    : null;
                if (String.isNotBlank(code)) {
                    activeExamCycleCourseCodes.add(code);
                    if (!activeCycleIdByCourseCode.containsKey(code) && ex.Exam_Cycle__c != null) {
                        activeCycleIdByCourseCode.put(code, ex.Exam_Cycle__c);
                    }
                    Id activeTermId = (ex.Course_Evaluation_Component__r != null
                            && ex.Course_Evaluation_Component__r.Course_Offering__r != null)
                        ? ex.Course_Evaluation_Component__r.Course_Offering__r.hed__Term__c
                        : null;
                    if (!activeTermIdByCourseCode.containsKey(code) && activeTermId != null) {
                        activeTermIdByCourseCode.put(code, activeTermId);
                    }
                }
            }
        
            // ----------------------------
            // Query 2: Re-Evaluation eligible (no Final Grade filter)
            // ----------------------------
            List<Exam_Connections__c> reEvalConnList = [
                SELECT Id,
                       Course_Connection_ID__c,
                       Course_Connection_ID__r.hed__Course_Offering__c,
                       Course_Connection_ID__r.Final_Grade__c,
                    
                       Course_Connection_ID__r.hed__Course_Offering__r.hed__Course__c,
                       Course_Connection_ID__r.hed__Course_Offering__r.hed__Course__r.Name,
                       Course_Connection_ID__r.hed__Course_Offering__r.hed__Term__r.Term_Reference__c,
                       Course_Connection_ID__r.hed__Course_Offering__r.hed__Course__r.hed__Course_ID__c,
                       Course_Connection_ID__r.hed__Course_Offering__r.hed__Course__r.Credits__c,
                       Course_Connection_ID__r.hed__Course_Offering__r.Result_Published__c,
                       Exam_Name__c,
                       Exam_Name__r.Exam_Name__c,
                       Exam_Name__r.Exam_Cycle__c,
                       Course_Connection_ID__r.hed__Course_Offering__r.hed__Term__c
                FROM Exam_Connections__c
                WHERE Student_Name__c = :contactId
                  // Is_Active filter removed: re-eval eligibility is gated by the course code
                  // being offered in an active exam cycle (same approach as re-exam).
                  AND Eligibility__c = 'Eligible'
                  AND Course_Connection_ID__r.Exam_Eligibility__c = 'Eligible'
                  AND Course_Connection_ID__r.Enrollment_Status__c = 'Enrolled'
                  AND Course_Connection_ID__r.hed__Course_Offering__r.Result_Published__c = true
                  AND Exam_Type__c !='Retest'
                  AND Exam_Name__c != null

            ];
        
            // ----------------------------
            // Requested Exams Query (Approved Student Service Requests)
            // ----------------------------
            List<Student_Service_Request__c> requestedApprovedSsrList = [
                SELECT Id,
                       Course_Connection__c,
                       Course_Connection__r.hed__Course_Offering__c,
                       Course_Connection__r.Final_Grade__c,
                       Course_Connection__r.hed__Course_Offering__r.hed__Course__c,
                       Course_Connection__r.hed__Course_Offering__r.hed__Course__r.Name,
                       Course_Connection__r.hed__Course_Offering__r.hed__Term__r.Term_Reference__c,
                       Course_Connection__r.hed__Course_Offering__r.hed__Course__r.hed__Course_ID__c,
                       Course_Connection__r.hed__Course_Offering__r.hed__Course__r.Credits__c,
                       Course_Connection__r.hed__Course_Offering__r.hed__Term__c,
                       Fee_Assignment__c,
                       Fee_Assignment__r.Due_Date__c,
                       Fee_Assignment__r.Total_Amount_Payable__c,
                       Fee_Assignment__r.Fee_Amount__c,
                       Fee_Assignment__r.Remaining_Amount__c,
                       Fee_Assignment__r.Paid_Amount__c,
                       Fee_Assignment__r.Affiliation__c,
                       Fee_Assignment__r.Fee_Type__c,
                       RecordType.DeveloperName,
                       Exam__r.Exam_Name__c,
                       Exam__r.Exam_Cycle__c,
                       Exam__c,
                       Exam_Name__c,
                       Paid_Exam_Fee__c,
                       Exam_Connection__c,
                       Student_Request_Application__c
                FROM Student_Service_Request__c
                WHERE Course_Connection__r.hed__Contact__c = :contactId
                 // AND Status__c = 'Registered'
                  AND Paid_Exam_Fee__c = true
                  AND Student_Request_Application__r.Exam_Cycle__r.Is_Active__c = true
                  AND Course_Connection__r.hed__Course_Offering__r.Result_Published__c = true
            ];
        
            // If no data at all, return empty lists
            if (reExamConnList.isEmpty() && reEvalConnList.isEmpty() && requestedApprovedSsrList.isEmpty()) {
                Map<String, Object> emptyResp = new Map<String, Object>{
                    'ReExamsRequest' => new Map<String, Object>{
                        'SEE' => new List<ReExamWrapper>(),
                        'CIA' => new List<ReExamWrapper>()
                    },
                    'ReEvaluationsRequest' => new Map<String, Object>{
                        'SEE' => new List<ReEvaluationWrapper>(),
                        'CIA' => new List<ReEvaluationWrapper>()
                    },
                    'RequestedExams' => new List<RequestedExamsWrapper>()
                };
                RestApiUtility.createSuccessGetResponse(emptyResp);
                return;
            }
        
            // ----------------------------
            // Collect all (ExamCycleId, TermId) pairs across ALL lists
            // ----------------------------
            Set<Id> examCycleIds = new Set<Id>();
            Set<Id> termIds = new Set<Id>();
        
            // Re-exam applications live on the ACTIVE cycle/term that offers the course,
            // so seed those into the lookup sets (not the connection's own old cycle/term).
            examCycleIds.addAll(activeCycleIdByCourseCode.values());
            termIds.addAll(activeTermIdByCourseCode.values());

            // helper local function pattern (manual loops)
            for (Exam_Connections__c ec : reExamConnList) {
                if (ec.Exam_Name__r != null && ec.Exam_Name__r.Exam_Cycle__c != null) examCycleIds.add(ec.Exam_Name__r.Exam_Cycle__c);
                if (ec.Course_Connection_ID__r != null && ec.Course_Connection_ID__r.hed__Course_Offering__r != null
                    && ec.Course_Connection_ID__r.hed__Course_Offering__r.hed__Term__c != null) {
                    termIds.add(ec.Course_Connection_ID__r.hed__Course_Offering__r.hed__Term__c);
                }
            }
            for (Exam_Connections__c ec : reEvalConnList) {
                if (ec.Exam_Name__r != null && ec.Exam_Name__r.Exam_Cycle__c != null) examCycleIds.add(ec.Exam_Name__r.Exam_Cycle__c);
                if (ec.Course_Connection_ID__r != null && ec.Course_Connection_ID__r.hed__Course_Offering__r != null
                    && ec.Course_Connection_ID__r.hed__Course_Offering__r.hed__Term__c != null) {
                    termIds.add(ec.Course_Connection_ID__r.hed__Course_Offering__r.hed__Term__c);
                }
            }
            for (Student_Service_Request__c ssr : requestedApprovedSsrList) {
                if (ssr.Exam__r != null && ssr.Exam__r.Exam_Cycle__c != null) examCycleIds.add(ssr.Exam__r.Exam_Cycle__c);
                if (ssr.Course_Connection__r != null && ssr.Course_Connection__r.hed__Course_Offering__r != null
                    && ssr.Course_Connection__r.hed__Course_Offering__r.hed__Term__c != null) {
                    termIds.add(ssr.Course_Connection__r.hed__Course_Offering__r.hed__Term__c);
                }
            }
        
            // ----------------------------
            // Bulk query Student_Service_Request_Application__c and keep latest per (cycle, term).
            // The application no longer carries a single Term__c lookup - the term(s) of an exam
            // cycle come from Exam_Cycle_Term_Connection__c (one cycle can have multiple terms),
            // so an application applies to ALL terms connected to its exam cycle.
            // ----------------------------
            Map<String, Student_Service_Request_Application__c> ssraByCycleTermKey = new Map<String, Student_Service_Request_Application__c>();
            Map<String, Student_Service_Request_Application__c> reExamSsraByCycleTermKey = new Map<String, Student_Service_Request_Application__c>();
            Map<String, Student_Service_Request_Application__c> reEvalSsraByCycleTermKey = new Map<String, Student_Service_Request_Application__c>();
            Map<Id, Student_Service_Request_Application__c> ssraByIdMap = new Map<Id, Student_Service_Request_Application__c>();

            if (!examCycleIds.isEmpty()) {
                // Terms connected to each exam cycle (junction).
                Map<Id, Set<Id>> termsByExamCycle = new Map<Id, Set<Id>>();
                for (Exam_Cycle_Term_Connection__c ctc : [
                    SELECT Exam_Cycle__c, Term__c
                    FROM Exam_Cycle_Term_Connection__c
                    WHERE Exam_Cycle__c IN :examCycleIds
                ]) {
                    if (ctc.Exam_Cycle__c == null || ctc.Term__c == null) continue;
                    if (!termsByExamCycle.containsKey(ctc.Exam_Cycle__c)) {
                        termsByExamCycle.put(ctc.Exam_Cycle__c, new Set<Id>());
                    }
                    termsByExamCycle.get(ctc.Exam_Cycle__c).add(ctc.Term__c);
                }

                for (Student_Service_Request_Application__c s : [
                    SELECT Id,
                           Exam_Cycle__c,
                           Request_Type__c,
                           Fee_Type__r.Due_Date__c,
                           Fee_Type__r.Amount__c,
                           Fee_Type__c,
                           Request_End_DateTime__c,
                           CreatedDate
                    FROM Student_Service_Request_Application__c
                    WHERE Exam_Cycle__c IN :examCycleIds
                    ORDER BY CreatedDate DESC
                ]) {
                    if (s.Exam_Cycle__c == null) continue;
                    ssraByIdMap.put(s.Id, s);
                    Set<Id> cycleTerms = termsByExamCycle.get(s.Exam_Cycle__c);
                    if (cycleTerms == null || cycleTerms.isEmpty()) continue;

                    // One application covers every term linked to its exam cycle.
                    for (Id tId : cycleTerms) {
                        String key = String.valueOf(s.Exam_Cycle__c) + '-' + String.valueOf(tId);
                        if (!ssraByCycleTermKey.containsKey(key)) {
                            ssraByCycleTermKey.put(key, s);
                        }
                        if (s.Request_Type__c == 'Re-Examination' && !reExamSsraByCycleTermKey.containsKey(key)) {
                            reExamSsraByCycleTermKey.put(key, s);
                        }
                        if (s.Request_Type__c == 'Re-Evaluation' && !reEvalSsraByCycleTermKey.containsKey(key)) {
                            reEvalSsraByCycleTermKey.put(key, s);
                        }
                    }
                }
            }

            // ----------------------------
            // Once a request is applied it appears under RequestedExams (Submitted SSR in an
            // active exam cycle). Such course connections must be hidden from ReExam/ReEval so
            // the same course cannot be applied for twice. Built from requestedApprovedSsrList
            // (no extra SOQL), split by the SSR RecordType.
            // ----------------------------
            Set<Id> courseConnIdsWithExistingReExamRequest = new Set<Id>();
            Set<Id> courseConnIdsWithExistingReEvalRequest = new Set<Id>();
            for (Student_Service_Request__c ssr : requestedApprovedSsrList) {
                if (ssr.Course_Connection__c == null) continue;
                String rtDev = ssr.RecordType != null ? ssr.RecordType.DeveloperName : null;
                if (rtDev == 'Re_Exam') {
                    courseConnIdsWithExistingReExamRequest.add(ssr.Course_Connection__c);
                } else if (rtDev == 'Revaluation') {
                    courseConnIdsWithExistingReEvalRequest.add(ssr.Course_Connection__c);
                }
            }
        
            // ----------------------------
            // Final_Grade (F/IC) is at the COURSE level, so a course connection with both a
            // SEE and a CIA exam connection returns both. The student only re-sits the exam
            // TYPE he actually failed, so map the failed exam types (from active Component
            // Scores with Result = 'Fail') per course connection and match them against each
            // exam connection's exam type (Exam_Name__r.Exam_Name__c).
            // ----------------------------
            Set<Id> reExamCourseConnIds = new Set<Id>();
            for (Exam_Connections__c ec : reExamConnList) {
                if (ec.Course_Connection_ID__c != null) reExamCourseConnIds.add(ec.Course_Connection_ID__c);
            }
            Map<Id, Set<String>> failedExamTypesByCourseConn = new Map<Id, Set<String>>();
            if (!reExamCourseConnIds.isEmpty()) {
                for (Component_Scores__c cs : [
                    SELECT Course_Connection__c, Exam_Type__c
                    FROM Component_Scores__c
                    WHERE Course_Connection__c IN :reExamCourseConnIds
                      AND Is_Active__c = true
                      AND Component_Score_Result__c IN ('Fail', 'In complete')
                ]) {
                    if (cs.Course_Connection__c == null || String.isBlank(cs.Exam_Type__c)) continue;
                    if (!failedExamTypesByCourseConn.containsKey(cs.Course_Connection__c)) {
                        failedExamTypesByCourseConn.put(cs.Course_Connection__c, new Set<String>());
                    }
                    failedExamTypesByCourseConn.get(cs.Course_Connection__c).add(cs.Exam_Type__c);
                }
            }

            // ----------------------------
            // Build ReExam wrappers (same as your current logic)
            // ----------------------------
            List<ReExamWrapper> reExamOut = new List<ReExamWrapper>();
            for (Exam_Connections__c ec : reExamConnList) {
                // Only show the connection when its course code is offered in an active exam cycle.
                String connCourseCode = ec.Course_Connection_ID__r?.hed__Course_Offering__r?.hed__Course__r?.hed__Course_ID__c;
                if (String.isBlank(connCourseCode) || !activeExamCycleCourseCodes.contains(connCourseCode)) continue;

                // Only show the exam TYPE (SEE/CIA) the student actually failed for this course.
                String connExamType = ec.Exam_Name__r?.Exam_Name__c;
                Set<String> failedTypes = failedExamTypesByCourseConn.get(ec.Course_Connection_ID__c);
                if (failedTypes == null || String.isBlank(connExamType) || !failedTypes.contains(connExamType)) continue;

                // The re-exam happens in the ACTIVE cycle that offers this course, so match the
                // fee application against the active cycle + term (NOT the connection's old cycle).
                Id cycleId = activeCycleIdByCourseCode.get(connCourseCode);
                Id termId  = activeTermIdByCourseCode.get(connCourseCode);

                String key = (cycleId != null && termId != null) ? String.valueOf(cycleId) + '-' + String.valueOf(termId) : null;
                Student_Service_Request_Application__c ssra = (key != null) ? reExamSsraByCycleTermKey.get(key) : null;
                if (ssra == null || ssra.Id == null) continue;
                if (ec.Course_Connection_ID__c != null && courseConnIdsWithExistingReExamRequest.contains(ec.Course_Connection_ID__c)) continue;
        
                ReExamWrapper w = new ReExamWrapper();
                w.course = ec.Course_Connection_ID__r?.hed__Course_Offering__r?.hed__Course__r?.Name;
                w.semester = ec.Course_Connection_ID__r?.hed__Course_Offering__r?.hed__Term__r?.Term_Reference__c;
                w.courseCode = ec.Course_Connection_ID__r?.hed__Course_Offering__r?.hed__Course__r?.hed__Course_ID__c;
                w.credit = ec.Course_Connection_ID__r?.hed__Course_Offering__r?.hed__Course__r?.Credits__c;
                w.type = ec.Exam_Name__r?.Exam_Name__c;
                w.examTypeLabel = ec.Exam_Name__r?.Exam_Name__c;
                w.ExamConnectionID = ec.Id;
        		w.CourseOfferingID = ec.Course_Connection_ID__r?.hed__Course_Offering__c;
                w.CourseConnectionID = ec.Course_Connection_ID__c;
                w.courseConnectionFinalGrade = ec.Course_Connection_ID__r?.Final_Grade__c;
              
                w.ExamID = ec.Exam_Name__c;
                w.examCycleId = cycleId;
                w.termId = termId;
        
                w.studentServiceRequestApplicationId = ssra.Id;
                w.feeTypeId = ssra.Fee_Type__c;
                w.fee = ssra.Fee_Type__r != null ? ssra.Fee_Type__r.Amount__c : null;
                w.dueDate = ssra.Request_End_DateTime__c;
                reExamOut.add(w);
            }
        
            // ----------------------------
            // Build ReEvaluation wrappers (same as your current logic)
            // ----------------------------
            List<ReEvaluationWrapper> reEvalOut = new List<ReEvaluationWrapper>();
            for (Exam_Connections__c ec : reEvalConnList) {
                // Only show the connection when its course code is offered in an active exam cycle.
                String connCourseCode = ec.Course_Connection_ID__r?.hed__Course_Offering__r?.hed__Course__r?.hed__Course_ID__c;
                if (String.isBlank(connCourseCode) || !activeExamCycleCourseCodes.contains(connCourseCode)) continue;

                // Re-evaluation happens in the ACTIVE cycle that offers this course, so match the
                // fee application against the active cycle + term (NOT the connection's old cycle).
                Id cycleId = activeCycleIdByCourseCode.get(connCourseCode);
                Id termId  = activeTermIdByCourseCode.get(connCourseCode);

                String key = (cycleId != null && termId != null) ? String.valueOf(cycleId) + '-' + String.valueOf(termId) : null;
                Student_Service_Request_Application__c ssra = (key != null) ? reEvalSsraByCycleTermKey.get(key) : null;
                if (ssra == null || ssra.Id == null) continue;
                if (ec.Course_Connection_ID__c != null && courseConnIdsWithExistingReEvalRequest.contains(ec.Course_Connection_ID__c)) continue;
        
                ReEvaluationWrapper w = new ReEvaluationWrapper();
                w.course = ec.Course_Connection_ID__r?.hed__Course_Offering__r?.hed__Course__r?.Name;
                w.semester = ec.Course_Connection_ID__r?.hed__Course_Offering__r?.hed__Term__r?.Term_Reference__c;
                w.courseCode = ec.Course_Connection_ID__r?.hed__Course_Offering__r?.hed__Course__r?.hed__Course_ID__c;
                w.credit = ec.Course_Connection_ID__r?.hed__Course_Offering__r?.hed__Course__r?.Credits__c;
                w.type = ec.Exam_Name__r?.Exam_Name__c;
                w.examTypeLabel = ec.Exam_Name__r?.Exam_Name__c;
                w.ExamConnectionID = ec.Id;
        		w.CourseOfferingID = ec.Course_Connection_ID__r?.hed__Course_Offering__c;
                w.CourseConnectionID = ec.Course_Connection_ID__c;
                w.courseConnectionFinalGrade = ec.Course_Connection_ID__r?.Final_Grade__c;
              
                w.ExamID = ec.Exam_Name__c;
                w.examCycleId = cycleId;
                w.termId = termId;
        
                w.studentServiceRequestApplicationId = ssra.Id;
                w.feeTypeId = ssra.Fee_Type__c;
                w.fee = ssra.Fee_Type__r != null ? ssra.Fee_Type__r.Amount__c : null;
                w.dueDate = ssra.Request_End_DateTime__c;
                reEvalOut.add(w);
            }

            // ===================================================================
            // CIA sub-lists. CIA has NO Exam / Exam Connection / slot - only an
            // active Component_Scores__c row. So query Component Scores directly
            // (ignore its always-null Exam__c / Exam_Connection__c lookups).
            //   ReExam.CIA -> only failed components (Result = 'Fail' / 'In complete')
            //   ReEval.CIA -> all active CIA (no pass/fail check)
            // Same gating as SEE: course code offered in an active cycle, matched to
            // the active cycle + term application, and hidden once already applied.
            // ===================================================================
            List<ReExamWrapper> reExamCiaOut = new List<ReExamWrapper>();
            List<ReEvaluationWrapper> reEvalCiaOut = new List<ReEvaluationWrapper>();

            List<Component_Scores__c> ciaScores = [
                SELECT Course_Connection__c,
                       Component_Score_Result__c,
                       Course_Connection__r.Final_Grade__c,
                       Course_Connection__r.hed__Course_Offering__c,
                       Course_Connection__r.hed__Course_Offering__r.hed__Course__r.Name,
                       Course_Connection__r.hed__Course_Offering__r.hed__Term__r.Term_Reference__c,
                       Course_Connection__r.hed__Course_Offering__r.hed__Course__r.hed__Course_ID__c,
                       Course_Connection__r.hed__Course_Offering__r.hed__Course__r.Credits__c
                FROM Component_Scores__c
                WHERE Course_Connection__r.hed__Contact__c = :contactId
                  AND Exam_Type__c = 'CIA'
                  AND Is_Active__c = true
                  AND Course_Connection__r.Exam_Eligibility__c = 'Eligible'
                  AND Course_Connection__r.Enrollment_Status__c = 'Enrolled'
                  AND Course_Connection__r.hed__Course_Offering__r.Result_Published__c = true
            ];

            for (Component_Scores__c cs : ciaScores) {
                String ciaCourseCode = cs.Course_Connection__r?.hed__Course_Offering__r?.hed__Course__r?.hed__Course_ID__c;
                if (String.isBlank(ciaCourseCode) || !activeExamCycleCourseCodes.contains(ciaCourseCode)) continue;

                Id cycleId = activeCycleIdByCourseCode.get(ciaCourseCode);
                Id termId  = activeTermIdByCourseCode.get(ciaCourseCode);
                String key = (cycleId != null && termId != null) ? String.valueOf(cycleId) + '-' + String.valueOf(termId) : null;
                Boolean isFailed = (cs.Component_Score_Result__c == 'Fail' || cs.Component_Score_Result__c == 'In complete');

                // --- ReExam CIA: failed components only ---
                Student_Service_Request_Application__c reExamSsra = (key != null) ? reExamSsraByCycleTermKey.get(key) : null;
                if (isFailed && reExamSsra != null && reExamSsra.Id != null
                    && !(cs.Course_Connection__c != null && courseConnIdsWithExistingReExamRequest.contains(cs.Course_Connection__c))) {
                    ReExamWrapper w = new ReExamWrapper();
                    w.course = cs.Course_Connection__r?.hed__Course_Offering__r?.hed__Course__r?.Name;
                    w.semester = cs.Course_Connection__r?.hed__Course_Offering__r?.hed__Term__r?.Term_Reference__c;
                    w.courseCode = ciaCourseCode;
                    w.credit = cs.Course_Connection__r?.hed__Course_Offering__r?.hed__Course__r?.Credits__c;
                    w.type = 'CIA';
                    w.examTypeLabel = 'CIA';
                    w.CourseOfferingID = cs.Course_Connection__r?.hed__Course_Offering__c;
                    w.CourseConnectionID = cs.Course_Connection__c;
                    w.courseConnectionFinalGrade = cs.Course_Connection__r?.Final_Grade__c;
                    w.examCycleId = cycleId;
                    w.termId = termId;
                    w.studentServiceRequestApplicationId = reExamSsra.Id;
                    w.feeTypeId = reExamSsra.Fee_Type__c;
                    w.fee = reExamSsra.Fee_Type__r != null ? reExamSsra.Fee_Type__r.Amount__c : null;
                    w.dueDate = reExamSsra.Request_End_DateTime__c;
                    reExamCiaOut.add(w);
                }

                // --- ReEval CIA: all active CIA (no pass/fail check) ---
                Student_Service_Request_Application__c reEvalSsra = (key != null) ? reEvalSsraByCycleTermKey.get(key) : null;
                if (reEvalSsra != null && reEvalSsra.Id != null
                    && !(cs.Course_Connection__c != null && courseConnIdsWithExistingReEvalRequest.contains(cs.Course_Connection__c))) {
                    ReEvaluationWrapper w = new ReEvaluationWrapper();
                    w.course = cs.Course_Connection__r?.hed__Course_Offering__r?.hed__Course__r?.Name;
                    w.semester = cs.Course_Connection__r?.hed__Course_Offering__r?.hed__Term__r?.Term_Reference__c;
                    w.courseCode = ciaCourseCode;
                    w.credit = cs.Course_Connection__r?.hed__Course_Offering__r?.hed__Course__r?.Credits__c;
                    w.type = 'CIA';
                    w.examTypeLabel = 'CIA';
                    w.CourseOfferingID = cs.Course_Connection__r?.hed__Course_Offering__c;
                    w.CourseConnectionID = cs.Course_Connection__c;
                    w.courseConnectionFinalGrade = cs.Course_Connection__r?.Final_Grade__c;
                    w.examCycleId = cycleId;
                    w.termId = termId;
                    w.studentServiceRequestApplicationId = reEvalSsra.Id;
                    w.feeTypeId = reEvalSsra.Fee_Type__c;
                    w.fee = reEvalSsra.Fee_Type__r != null ? reEvalSsra.Fee_Type__r.Amount__c : null;
                    w.dueDate = reEvalSsra.Request_End_DateTime__c;
                    reEvalCiaOut.add(w);
                }
            }

            // =========================================================
            //  Requested Exams logic (Approved SSR directly)
            // =========================================================
            Set<Id> requestedFeeAssignmentIds = new Set<Id>();
            for (Student_Service_Request__c ssr : requestedApprovedSsrList) {
                if (ssr.Fee_Assignment__c != null) requestedFeeAssignmentIds.add(ssr.Fee_Assignment__c);
            }

            Map<Id, Fee_Installment__c> latestFeeInstallmentByFeeAssignmentId = new Map<Id, Fee_Installment__c>();
            if (!requestedFeeAssignmentIds.isEmpty()) {
                for (Fee_Installment__c fi : [
                    SELECT Id,
                           Fee_Assignment__c,
                           Fee_Amount__c,
                           Due_Date__c
                    FROM Fee_Installment__c
                    WHERE Fee_Assignment__c IN :requestedFeeAssignmentIds
                    ORDER BY CreatedDate DESC
                ]) {
                    if (fi.Fee_Assignment__c != null && !latestFeeInstallmentByFeeAssignmentId.containsKey(fi.Fee_Assignment__c)) {
                        latestFeeInstallmentByFeeAssignmentId.put(fi.Fee_Assignment__c, fi);
                    }
                }
            }

            // Payment transaction line items for each requested fee installment (bulk, one query).
            Set<Id> requestedFeeInstallmentIds = new Set<Id>();
            for (Fee_Installment__c fi : latestFeeInstallmentByFeeAssignmentId.values()) {
                if (fi.Id != null) requestedFeeInstallmentIds.add(fi.Id);
            }

            Map<Id, List<PaymentTransactionWrapper>> paymentTxnsByInstallmentId = new Map<Id, List<PaymentTransactionWrapper>>();
            if (!requestedFeeInstallmentIds.isEmpty()) {
                for (Payment_Transaction_Line_Item__c pli : [
                    SELECT Id,
                           Fee_Installment__c,
                           Payment_Transaction__r.Order_Id__c,
                           Payment_Transaction__r.Transaction_Date__c,
                           Payment_Transaction__r.Transaction_Id__c,
                           Payment_Transaction__r.Payment_Mode__c,
                           Payment_Transaction__r.Amount__c,
                           Receipt__r.Receipt_URL__c,
                           Payment_Status__c,
                           Received_Amount__c
                    FROM Payment_Transaction_Line_Item__c
                    WHERE Fee_Installment__c IN :requestedFeeInstallmentIds
                ]) {
                    if (pli.Fee_Installment__c == null) continue;
                    if (!paymentTxnsByInstallmentId.containsKey(pli.Fee_Installment__c)) {
                        paymentTxnsByInstallmentId.put(pli.Fee_Installment__c, new List<PaymentTransactionWrapper>());
                    }
                    PaymentTransactionWrapper pw = new PaymentTransactionWrapper();
                    if (pli.Payment_Transaction__r != null) {
                        pw.orderId = pli.Payment_Transaction__r.Order_Id__c;
                        pw.transactionDate = pli.Payment_Transaction__r.Transaction_Date__c;
                        pw.transactionId = pli.Payment_Transaction__r.Transaction_Id__c;
                        pw.paymentMode = pli.Payment_Transaction__r.Payment_Mode__c;
                        pw.amount = pli.Payment_Transaction__r.Amount__c;
                    }
                    pw.receiptUrl = pli.Receipt__r?.Receipt_URL__c;
                    pw.paymentStatus = pli.Payment_Status__c;
                    pw.receivedAmount = pli.Received_Amount__c;
                    paymentTxnsByInstallmentId.get(pli.Fee_Installment__c).add(pw);
                }
            }

            // Slot booked? An Exam Connection with a non-expired Slot_Scheduled__c counts as booked.
            Set<Id> requestedExamConnIds = new Set<Id>();
            for (Student_Service_Request__c ssr : requestedApprovedSsrList) {
                if (ssr.Exam_Connection__c != null) requestedExamConnIds.add(ssr.Exam_Connection__c);
            }
            Set<Id> examConnIdsWithActiveSlot = new Set<Id>();
            if (!requestedExamConnIds.isEmpty()) {
                for (AggregateResult ar : [
                    SELECT Exam_Connection__c
                    FROM Slot_Scheduled__c
                    WHERE Exam_Connection__c IN :requestedExamConnIds
                      AND Is_Expired__c = false
                    GROUP BY Exam_Connection__c
                ]) {
                    examConnIdsWithActiveSlot.add((Id) ar.get('Exam_Connection__c'));
                }
            }

            List<RequestedExamsWrapper> requestedOut = new List<RequestedExamsWrapper>();
            for (Student_Service_Request__c ssr : requestedApprovedSsrList) {
                RequestedExamsWrapper w = new RequestedExamsWrapper();
                w.course = ssr.Course_Connection__r?.hed__Course_Offering__r?.hed__Course__r?.Name;
                w.semester = ssr.Course_Connection__r?.hed__Course_Offering__r?.hed__Term__r?.Term_Reference__c;
                w.courseCode = ssr.Course_Connection__r?.hed__Course_Offering__r?.hed__Course__r?.hed__Course_ID__c;
                w.credit = ssr.Course_Connection__r?.hed__Course_Offering__r?.hed__Course__r?.Credits__c;
                w.type = ssr.Exam__r?.Exam_Name__c;
                w.examTypeLabel = ssr.Exam__r?.Exam_Name__c;
                w.examName = ssr.Exam_Name__c;
                w.paidExamFee = ssr.Paid_Exam_Fee__c;
                w.examConnectionId = ssr.Exam_Connection__c;
                w.isSlotBooked = ssr.Exam_Connection__c != null && examConnIdsWithActiveSlot.contains(ssr.Exam_Connection__c);
                w.RequestType = ssr.RecordType != null ? ssr.RecordType.DeveloperName : null;
                w.courseConnectionFinalGrade = ssr.Course_Connection__r?.Final_Grade__c;
                w.examName = ssr.Exam_Name__c;
                w.paidExamFee = ssr.Paid_Exam_Fee__c;

                Fee_Installment__c latestInstallment = ssr.Fee_Assignment__c != null
                    ? latestFeeInstallmentByFeeAssignmentId.get(ssr.Fee_Assignment__c)
                    : null;

                w.studentServiceRequestApplicationId = ssr.Student_Request_Application__c;
                w.feeTypeId = ssr.Fee_Assignment__r != null ? ssr.Fee_Assignment__r.Fee_Type__c : null;
                w.fee = latestInstallment != null ? latestInstallment.Fee_Amount__c : null;
                Student_Service_Request_Application__c requestedSsra = ssr.Student_Request_Application__c != null
                    ? ssraByIdMap.get(ssr.Student_Request_Application__c)
                    : null;
                w.dueDate = requestedSsra != null ? requestedSsra.Request_End_DateTime__c : null;
                w.feeAssignmentId = ssr.Fee_Assignment__c;
                w.feeInstallmentId = latestInstallment != null ? latestInstallment.Id : null;

                // Payment transactions for this request's fee installment
                w.paymentTransactions = (latestInstallment != null && paymentTxnsByInstallmentId.containsKey(latestInstallment.Id))
                    ? paymentTxnsByInstallmentId.get(latestInstallment.Id)
                    : new List<PaymentTransactionWrapper>();

                w.courseOfferingId = ssr.Course_Connection__r != null ? ssr.Course_Connection__r.hed__Course_Offering__c : null;
                w.courseConnectionId = ssr.Course_Connection__c;
                w.CourseID = ssr.Course_Connection__r?.hed__Course_Offering__r?.hed__Course__c;
                w.examId = ssr.Exam__c;
                w.examCycleId = ssr.Exam__r != null ? ssr.Exam__r.Exam_Cycle__c : null;
                w.termId = (ssr.Course_Connection__r != null && ssr.Course_Connection__r.hed__Course_Offering__r != null)
                    ? ssr.Course_Connection__r.hed__Course_Offering__r.hed__Term__c
                    : null;
                w.studentServiceRequestId = ssr.Id;

                requestedOut.add(w);
            }
        
            // Final response - ReExam/ReEval are split into SEE and CIA sub-lists.
            Map<String, Object> response = new Map<String, Object>{
                'ReExamsRequest' => new Map<String, Object>{
                    'SEE' => reExamOut,
                    'CIA' => reExamCiaOut
                },
                'ReEvaluationsRequest' => new Map<String, Object>{
                    'SEE' => reEvalOut,
                    'CIA' => reEvalCiaOut
                },
                'RequestedExams' => requestedOut
            };
        
            RestApiUtility.createSuccessGetResponse(response);
        }

        /**
         * GET /studentexamportal/retrieve/idCard?affiliationId=...
         * Returns the public URL of the ID card file stored on the affiliation
         * (ContentVersion with Document_Type__c = 'Student ID Card').
         */
        public static void retrieveIdCardByAffiliation() {
            String affiliationId = RestContext.request.params.get('affiliationId');
            if (String.isBlank(affiliationId)) {
                RestApiUtility.addError(HTTP_BAD_REQUEST, 'Missing affiliationId');
                return;
            }

            // Documents linked to the affiliation
            Set<Id> docIds = new Set<Id>();
            for (ContentDocumentLink cdl : [
                SELECT ContentDocumentId
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :affiliationId
            ]) {
                docIds.add(cdl.ContentDocumentId);
            }

            if (docIds.isEmpty()) {
                RestApiUtility.createSuccessGetResponse(new Map<String, Object>{ 'idCard' => null });
                return;
            }

            // Latest ID card version among those documents
            List<ContentVersion> cvs = [
                SELECT Id, ContentDocumentId, Title, FileType, CreatedDate
                FROM ContentVersion
                WHERE ContentDocumentId IN :docIds
                  AND IsLatest = true
                  AND Document_Type__c = :StudentIdCardController.DOCUMENT_TYPE
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            if (cvs.isEmpty()) {
                RestApiUtility.createSuccessGetResponse(new Map<String, Object>{ 'idCard' => null });
                return;
            }
            ContentVersion cv = cvs[0];

            // Reuse an existing public distribution or create one (no session-bound URL)
            ContentDistribution cd;
            List<ContentDistribution> existing = [
                SELECT Id, DistributionPublicUrl, ContentDownloadUrl, ContentVersionId
                FROM ContentDistribution
                WHERE ContentVersionId = :cv.Id
                LIMIT 1
            ];
            if (!existing.isEmpty()) {
                cd = existing[0];
            } else {
                cd = new ContentDistribution();
                cd.Name = cv.Title;
                cd.ContentVersionId = cv.Id;
                cd.PreferencesAllowViewInBrowser = true;
                cd.PreferencesAllowOriginalDownload = true;
                cd.PreferencesLinkLatestVersion = true;
                cd.PreferencesNotifyOnVisit = false;
                insert cd;

                cd = [
                    SELECT Id, DistributionPublicUrl, ContentDownloadUrl
                    FROM ContentDistribution
                    WHERE Id = :cd.Id
                    LIMIT 1
                ];
            }

            Map<String, Object> idCard = new Map<String, Object>{
                'affiliationId' => affiliationId,
                'contentDocumentId' => cv.ContentDocumentId,
                'contentVersionId' => cv.Id,
                'title' => cv.Title,
                'fileType' => cv.FileType,
                'createdDate' => cv.CreatedDate,
                'previewUrl' => cd.DistributionPublicUrl,
                'downloadUrl' => cd.ContentDownloadUrl
            };

            RestApiUtility.createSuccessGetResponse(new Map<String, Object>{ 'idCard' => idCard });
        }

        private static String buildStudentServiceCategoryKey(Id studentId, Id requestWindowId) {
            return String.valueOf(studentId) + '|' + String.valueOf(requestWindowId);
        }

        private static String buildStudentServiceRequestKey(
            Id courseOfferingId,
            Id courseConnectionId,
            Id studentRequestApplicationId,
            Id examId
        ) {
            return String.valueOf(courseOfferingId) + '|' +
                String.valueOf(courseConnectionId) + '|' +
                String.valueOf(studentRequestApplicationId) + '|' +
                String.valueOf(examId);
        }

		public static void createStudentServiceRequest() {
            RestRequest req = RestContext.request;
        
            if (req.requestBody == null || String.isBlank(req.requestBody.toString())) {
                RestApiUtility.addError(HTTP_BAD_REQUEST, 'Missing request body');
                return;
            }
        
            Object raw;
            try {
                raw = JSON.deserializeUntyped(req.requestBody.toString());
            } catch (Exception e) {
                RestApiUtility.addError(HTTP_BAD_REQUEST, 'Invalid JSON payload: ' + e.getMessage());
                return;
            }
        
            List<Object> items = new List<Object>();
            if (raw instanceof List<Object>) {
                items = (List<Object>) raw;
            } else if (raw instanceof Map<String, Object>) {
                items.add(raw);
            } else {
                RestApiUtility.addError(HTTP_BAD_REQUEST, 'Payload must be an object or an array of objects');
                return;
            }
        
            if (items.isEmpty()) {
                RestApiUtility.addError(HTTP_BAD_REQUEST, 'Payload is empty');
                return;
            }

            System.debug(LoggingLevel.INFO, 'createStudentServiceRequest: payload item count = ' + items.size());
        
            //  Query RecordTypes once
            Map<String, Id> rtByDevName = new Map<String, Id>();
            for (RecordType rt : [
                SELECT Id, DeveloperName
                FROM RecordType
                WHERE SObjectType = 'Student_Service_Request__c'
                  AND DeveloperName IN ('Re_Exam', 'Revaluation')
            ]) {
                rtByDevName.put(rt.DeveloperName, rt.Id);
            }

            Map<Id, Student_Service_Request_Application__c> ssraById = new Map<Id, Student_Service_Request_Application__c>();
            Set<Id> studentReqAppIds = new Set<Id>();
            Set<Id> contactIds = new Set<Id>();
            Set<Id> feeTypeIds = new Set<Id>();
            Set<Id> courseConnectionIdSet = new Set<Id>();
            for (Object o : items) {
                if (!(o instanceof Map<String, Object>)) continue;
                String studentReqAppId = (String) ((Map<String, Object>) o).get('Student_Request_Application__c');
                String contactId = (String) ((Map<String, Object>) o).get('Contactid');
                String feeTypeId = (String) ((Map<String, Object>) o).get('Feetypeid');
                String courseConnectionId = (String) ((Map<String, Object>) o).get('Course_Connection__c');

                if (!String.isBlank(courseConnectionId)) {
                    try {
                        courseConnectionIdSet.add((Id) courseConnectionId);
                    } catch (Exception e) {
                        // handled during item-level validation
                    }
                }
                if (!String.isBlank(studentReqAppId)) {
                    try {
                        studentReqAppIds.add((Id) studentReqAppId);
                    } catch (Exception e) {
                        // handled during item-level validation
                    }
                }
                if (!String.isBlank(contactId)) {
                    try {
                        contactIds.add((Id) contactId);
                    } catch (Exception e) {
                        // handled during item-level validation
                    }
                }
                if (!String.isBlank(feeTypeId)) {
                    try {
                        feeTypeIds.add((Id) feeTypeId);
                    } catch (Exception e) {
                        // handled during item-level validation
                    }
                }
            }

            if (!studentReqAppIds.isEmpty()) {
                for (Student_Service_Request_Application__c ssra : [
                    SELECT Id, Request_Type__c
                    FROM Student_Service_Request_Application__c
                    WHERE Id IN :studentReqAppIds
                ]) {
                    ssraById.put(ssra.Id, ssra);
                }
            }

            Map<Id, hed__Affiliation__c> affiliationByContactId = new Map<Id, hed__Affiliation__c>();
            if (!contactIds.isEmpty()) {
                for (hed__Affiliation__c aff : [
                    SELECT Id, hed__Contact__c, Program_Plan__c
                    FROM hed__Affiliation__c
                    WHERE hed__Contact__c IN :contactIds
                    ORDER BY CreatedDate DESC
                ]) {
                    if (aff.hed__Contact__c != null && !affiliationByContactId.containsKey(aff.hed__Contact__c)) {
                        affiliationByContactId.put(aff.hed__Contact__c, aff);
                    }
                }
            }

            Map<Id, String> contactNameById = new Map<Id, String>();
            if (!contactIds.isEmpty()) {
                for (Contact c : [SELECT Id, Name FROM Contact WHERE Id IN :contactIds]) {
                    contactNameById.put(c.Id, c.Name);
                }
            }

            Map<Id, Fee_Type__c> feeTypeById = new Map<Id, Fee_Type__c>();
            if (!feeTypeIds.isEmpty()) {
                for (Fee_Type__c ft : [
                    SELECT Id, Amount__c, Due_Date__c
                    FROM Fee_Type__c
                    WHERE Id IN :feeTypeIds
                ]) {
                    feeTypeById.put(ft.Id, ft);
                }
            }

            // Only SEE has an Exam record (CIA is component-score only). The Exam__c lookup +
            // Exam Connection are only relevant for SEE, so map the active SEE exam by course
            // code (hed__Course_ID__c).
            Map<String, Id> seeExamIdByCourseCode = new Map<String, Id>();
            for (Exam__c ex : [
                SELECT Id, Exam_Name__c, Course_Evaluation_Component__r.Course_Offering__r.hed__Course__r.hed__Course_ID__c
                FROM Exam__c
                WHERE Exam_Cycle__r.Is_Active__c = true
                  AND Exam_Name__c = 'SEE'
            ]) {
                String code = (ex.Course_Evaluation_Component__r != null
                        && ex.Course_Evaluation_Component__r.Course_Offering__r != null
                        && ex.Course_Evaluation_Component__r.Course_Offering__r.hed__Course__r != null)
                    ? ex.Course_Evaluation_Component__r.Course_Offering__r.hed__Course__r.hed__Course_ID__c
                    : null;
                if (String.isNotBlank(code) && !seeExamIdByCourseCode.containsKey(code)) {
                    seeExamIdByCourseCode.put(code, ex.Id);
                }
            }

            // ...and resolve each payload Course_Connection__c to its course code.
            Map<Id, String> courseCodeByConnId = new Map<Id, String>();
            if (!courseConnectionIdSet.isEmpty()) {
                for (hed__Course_Enrollment__c ce : [
                    SELECT Id, hed__Course_Offering__r.hed__Course__r.hed__Course_ID__c
                    FROM hed__Course_Enrollment__c
                    WHERE Id IN :courseConnectionIdSet
                ]) {
                    String code = (ce.hed__Course_Offering__r != null && ce.hed__Course_Offering__r.hed__Course__r != null)
                        ? ce.hed__Course_Offering__r.hed__Course__r.hed__Course_ID__c
                        : null;
                    courseCodeByConnId.put(ce.Id, code);
                }
            }

            List<Student_Service_Request__c> toInsert = new List<Student_Service_Request__c>();
            List<Map<String, Object>> errors = new List<Map<String, Object>>();
            List<Id> feeContactIds = new List<Id>();
            List<Id> feeTypeIdByRow = new List<Id>();
            List<Id> feeAffiliationIds = new List<Id>();
            List<Id> feeProgramPlanIds = new List<Id>();
            List<Decimal> feeAmounts = new List<Decimal>();
            List<Date> feeDueDates = new List<Date>();
            List<String> requestTypesByRow = new List<String>();
            List<Id> categoryStudentIdsByRow = new List<Id>();
            List<Id> categoryRequestWindowIdsByRow = new List<Id>();
            Set<Id> categoryStudentIds = new Set<Id>();
            Set<Id> categoryRequestWindowIds = new Set<Id>();
        
            Integer index = 0;
            for (Object o : items) {
                index++;
        
                if (!(o instanceof Map<String, Object>)) {
                    errors.add(new Map<String, Object>{
                        'index' => index,
                        'message' => 'Each item must be a JSON object'
                    });
                    continue;
                }
        
                Map<String, Object> m = (Map<String, Object>) o;
        
                String requestType = (String) m.get('RequestType');
                String courseOfferingId = (String) m.get('Course_Offering__c');
                String courseConnectionId = (String) m.get('Course_Connection__c');
                // String courseNameId = (String) m.get('Course_Name__c'); // ⚠️ READ-ONLY FIELD (do not insert)
                String studentReqAppId = (String) m.get('Student_Request_Application__c');
                // Exam__c is NOT read from the payload - it is resolved from the active SEE exam.
                // ExamType drives whether an Exam + Exam Connection are needed (SEE/CIA/Both).
                String examType = (String) m.get('ExamType');
                String contactId = (String) m.get('Contactid');
                String feeTypeId = (String) m.get('Feetypeid');

                // Required fields (excluding Course_Name__c because it's read-only)
                List<String> missing = new List<String>();
                if (String.isBlank(requestType)) missing.add('RequestType');
                if (String.isBlank(courseOfferingId)) missing.add('Course_Offering__c');
                if (String.isBlank(courseConnectionId)) missing.add('Course_Connection__c');
                if (String.isBlank(studentReqAppId)) missing.add('Student_Request_Application__c');
                if (String.isBlank(contactId)) missing.add('Contactid');
                if (String.isBlank(feeTypeId)) missing.add('Feetypeid');
                if (String.isBlank(examType)) missing.add('ExamType');

                if (!missing.isEmpty()) {
                    errors.add(new Map<String, Object>{
                        'index' => index,
                        'message' => 'Missing required fields: ' + String.join(missing, ', ')
                    });
                    continue;
                }

                // Normalize ExamType -> 'SEE' | 'CIA' | 'SEE & CIA'
                String examTypeNorm;
                String examTypeRaw = examType.trim().toLowerCase();
                if (examTypeRaw == 'see') {
                    examTypeNorm = 'SEE';
                } else if (examTypeRaw == 'cia') {
                    examTypeNorm = 'CIA';
                } else if (examTypeRaw == 'see & cia') {
                    examTypeNorm = 'SEE & CIA';
                } else {
                    errors.add(new Map<String, Object>{
                        'index' => index,
                        'message' => 'Invalid ExamType. Allowed: SEE, CIA, SEE & CIA'
                    });
                    continue;
                }
                // SEE and SEE & CIA require an active SEE exam lookup; CIA needs neither.
                // Re-exam SEE also gets an Exam Connection; Re-evaluation SEE does not.
                Boolean needsSeeExam = (examTypeNorm == 'SEE' || examTypeNorm == 'SEE & CIA');

                Id contactLookupId;
                try {
                    contactLookupId = (Id) contactId;
                } catch (Exception e) {
                    errors.add(new Map<String, Object>{
                        'index' => index,
                        'message' => 'Invalid Contactid'
                    });
                    continue;
                }

                Id feeTypeLookupId;
                try {
                    feeTypeLookupId = (Id) feeTypeId;
                } catch (Exception e) {
                    errors.add(new Map<String, Object>{
                        'index' => index,
                        'message' => 'Invalid Feetypeid'
                    });
                    continue;
                }
        
                // RecordType mapping
                String norm = requestType.trim().toLowerCase();
                Id rtId;
                String expectedSsraRequestType = null;
        
                if (norm == 're-exam' || norm == 're exam' || norm == 'reexam') {
                    rtId = rtByDevName.get('Re_Exam');
                    expectedSsraRequestType = 'Re-Examination';
                    if (rtId == null) {
                        errors.add(new Map<String, Object>{
                            'index' => index,
                            'message' => 'RecordType not found for Re-exam (DeveloperName expected: Re_Exam)'
                        });
                        continue;
                    }
                } else if (norm == 're-evaluation' || norm == 're evaluation' || norm == 'reevaluation' || norm == 'revaluation') {
                    rtId = rtByDevName.get('Revaluation');
                    expectedSsraRequestType = 'Re-Evaluation';
                    if (rtId == null) {
                        errors.add(new Map<String, Object>{
                            'index' => index,
                            'message' => 'RecordType not found for Re-evaluation (DeveloperName expected: Revaluation)'
                        });
                        continue;
                    }
                } else {
                    errors.add(new Map<String, Object>{
                        'index' => index,
                        'message' => 'Invalid RequestType. Allowed: Re-exam, Re-evaluation'
                    });
                    continue;
                }

                Id studentReqAppLookupId;
                try {
                    studentReqAppLookupId = (Id) studentReqAppId;
                } catch (Exception e) {
                    errors.add(new Map<String, Object>{
                        'index' => index,
                        'message' => 'Invalid Student_Request_Application__c Id'
                    });
                    continue;
                }

                Student_Service_Request_Application__c ssra = ssraById.get(studentReqAppLookupId);
                if (ssra == null) {
                    errors.add(new Map<String, Object>{
                        'index' => index,
                        'message' => 'Student_Service_Request_Application__c not found for the provided Student_Request_Application__c'
                    });
                    continue;
                }

                if (ssra.Request_Type__c != expectedSsraRequestType) {
                    errors.add(new Map<String, Object>{
                        'index' => index,
                        'message' => 'RequestType mismatch. Expected Student_Service_Request_Application__c.Request_Type__c = ' + expectedSsraRequestType
                    });
                    continue;
                }

                hed__Affiliation__c affiliation = affiliationByContactId.get(contactLookupId);
                if (affiliation == null) {
                    errors.add(new Map<String, Object>{
                        'index' => index,
                        'message' => 'Affiliation not found for the provided Contactid'
                    });
                    continue;
                }

                Fee_Type__c feeType = feeTypeById.get(feeTypeLookupId);
                if (feeType == null) {
                    errors.add(new Map<String, Object>{
                        'index' => index,
                        'message' => 'Fee_Type__c not found for the provided Feetypeid'
                    });
                    continue;
                }
        
                Student_Service_Request__c ssr = new Student_Service_Request__c();
                ssr.RecordTypeId = rtId;
                ssr.Status__c = 'Submitted';
        
                ssr.Course_Offering__c = (Id) courseOfferingId;
                ssr.Course_Connection__c = (Id) courseConnectionId;
                ssr.Student_Request_Application__c = studentReqAppLookupId;
                // Store the requested exam type on the SSR text field.
                ssr.Exam_Name__c = examTypeNorm;

                // SEE / Both -> resolve the active SEE exam (Exam Connection created later for Re-exam only).
                // CIA -> no Exam lookup, no Exam Connection. Re-evaluation SEE -> Exam lookup only, no Exam Connection.
                if (needsSeeExam) {
                    String connCourseCode = courseCodeByConnId.get((Id) courseConnectionId);
                    Id resolvedExamId = String.isNotBlank(connCourseCode)
                        ? seeExamIdByCourseCode.get(connCourseCode)
                        : null;
                    if (resolvedExamId == null) {
                        errors.add(new Map<String, Object>{
                            'index' => index,
                            'message' => 'No active SEE exam found for this course in the current active exam cycle'
                        });
                        continue;
                    }
                    ssr.Exam__c = resolvedExamId;
                }
                // For CIA, ssr.Exam__c stays null (and no Exam Connection is created).

                toInsert.add(ssr);
                feeContactIds.add(contactLookupId);
                feeTypeIdByRow.add(feeTypeLookupId);
                feeAffiliationIds.add(affiliation.Id);
                feeProgramPlanIds.add(affiliation.Program_Plan__c);
                feeAmounts.add(feeType.Amount__c);
                feeDueDates.add(feeType.Due_Date__c);
                requestTypesByRow.add(requestType);
                categoryStudentIdsByRow.add(contactLookupId);
                categoryRequestWindowIdsByRow.add(studentReqAppLookupId);
                categoryStudentIds.add(contactLookupId);
                categoryRequestWindowIds.add(studentReqAppLookupId);
            }
        
            // Validation errors: stop before DML
            if (!errors.isEmpty()) {
                Map<String, Object> errResp = new Map<String, Object>{
                    'success' => false,
                    'errors' => errors
                };
                RestContext.response.statusCode = HTTP_BAD_REQUEST;
                RestContext.response.responseBody = Blob.valueOf(JSON.serialize(errResp));
                return;
            }

            // Existing SSR dedupe by payload identity:
            // Course_Offering__c + Course_Connection__c + Student_Request_Application__c + Exam__c
            List<String> payloadSsrKeysByRow = new List<String>();
            Set<Id> payloadCourseOfferingIds = new Set<Id>();
            Set<Id> payloadCourseConnectionIds = new Set<Id>();
            Set<Id> payloadStudentReqAppIds = new Set<Id>();
            Set<Id> payloadExamIds = new Set<Id>();
            for (Student_Service_Request__c candidate : toInsert) {
                payloadSsrKeysByRow.add(
                    buildStudentServiceRequestKey(
                        candidate.Course_Offering__c,
                        candidate.Course_Connection__c,
                        candidate.Student_Request_Application__c,
                        candidate.Exam__c
                    )
                );
                if (candidate.Course_Offering__c != null) payloadCourseOfferingIds.add(candidate.Course_Offering__c);
                if (candidate.Course_Connection__c != null) payloadCourseConnectionIds.add(candidate.Course_Connection__c);
                if (candidate.Student_Request_Application__c != null) payloadStudentReqAppIds.add(candidate.Student_Request_Application__c);
                if (candidate.Exam__c != null) payloadExamIds.add(candidate.Exam__c);
            }

            Map<String, Student_Service_Request__c> existingSsrByKey = new Map<String, Student_Service_Request__c>();
            if (!payloadCourseOfferingIds.isEmpty() &&
                !payloadCourseConnectionIds.isEmpty() &&
                !payloadStudentReqAppIds.isEmpty() &&
                !payloadExamIds.isEmpty()) {
                for (Student_Service_Request__c existingSsr : [
                    SELECT Id,
                           RecordTypeId,
                           Status__c,
                           Course_Offering__c,
                           Course_Connection__c,
                           Student_Request_Application__c,
                           Exam__c,
                           Fee_Assignment__c,
                           Fee_Assignment__r.Total_Amount_Payable__c,
                           Fee_Assignment__r.Remaining_Amount__c,
                           Fee_Assignment__r.Due_Date__c,
                           Student_Service_Category__c,
                           CreatedDate
                    FROM Student_Service_Request__c
                    WHERE Course_Offering__c IN :payloadCourseOfferingIds
                      AND Course_Connection__c IN :payloadCourseConnectionIds
                      AND Student_Request_Application__c IN :payloadStudentReqAppIds
                      AND Exam__c IN :payloadExamIds
                    ORDER BY CreatedDate DESC
                ]) {
                    String existingKey = buildStudentServiceRequestKey(
                        existingSsr.Course_Offering__c,
                        existingSsr.Course_Connection__c,
                        existingSsr.Student_Request_Application__c,
                        existingSsr.Exam__c
                    );
                    if (!existingSsrByKey.containsKey(existingKey)) {
                        existingSsrByKey.put(existingKey, existingSsr);
                    }
                }
            }

            // CIA dedup: Exam__c is null for CIA records so Exam__c IN :payloadExamIds never
            // matches them. Run a separate query keyed on Offering+Connection+RequestApp where
            // Exam__c IS NULL so re-applications after a failed payment update rather than
            // insert a second SSR.
            Set<Id> payloadCiaOfferingIds = new Set<Id>();
            Set<Id> payloadCiaCourseConnIds = new Set<Id>();
            Set<Id> payloadCiaStudentReqAppIds = new Set<Id>();
            for (Student_Service_Request__c candidate : toInsert) {
                if (candidate.Exam__c == null) {
                    if (candidate.Course_Offering__c != null) payloadCiaOfferingIds.add(candidate.Course_Offering__c);
                    if (candidate.Course_Connection__c != null) payloadCiaCourseConnIds.add(candidate.Course_Connection__c);
                    if (candidate.Student_Request_Application__c != null) payloadCiaStudentReqAppIds.add(candidate.Student_Request_Application__c);
                }
            }
            if (!payloadCiaOfferingIds.isEmpty() && !payloadCiaCourseConnIds.isEmpty() && !payloadCiaStudentReqAppIds.isEmpty()) {
                for (Student_Service_Request__c existingSsr : [
                    SELECT Id,
                           RecordTypeId,
                           Status__c,
                           Course_Offering__c,
                           Course_Connection__c,
                           Student_Request_Application__c,
                           Exam__c,
                           Fee_Assignment__c,
                           Fee_Assignment__r.Total_Amount_Payable__c,
                           Fee_Assignment__r.Remaining_Amount__c,
                           Fee_Assignment__r.Due_Date__c,
                           Student_Service_Category__c,
                           CreatedDate
                    FROM Student_Service_Request__c
                    WHERE Course_Offering__c IN :payloadCiaOfferingIds
                      AND Course_Connection__c IN :payloadCiaCourseConnIds
                      AND Student_Request_Application__c IN :payloadCiaStudentReqAppIds
                      AND Exam__c = null
                    ORDER BY CreatedDate DESC
                ]) {
                    String existingKey = buildStudentServiceRequestKey(
                        existingSsr.Course_Offering__c,
                        existingSsr.Course_Connection__c,
                        existingSsr.Student_Request_Application__c,
                        null
                    );
                    if (!existingSsrByKey.containsKey(existingKey)) {
                        existingSsrByKey.put(existingKey, existingSsr);
                    }
                }
            }

            List<Student_Service_Request__c> ssrToInsert = new List<Student_Service_Request__c>();
            List<Student_Service_Request__c> ssrToUpdate = new List<Student_Service_Request__c>();
            List<Id> insertFeeContactIds = new List<Id>();
            List<Id> insertFeeTypeIdByRow = new List<Id>();
            List<Id> insertFeeAffiliationIds = new List<Id>();
            List<Decimal> insertFeeAmounts = new List<Decimal>();
            List<Date> insertFeeDueDates = new List<Date>();
            List<String> insertRequestTypes = new List<String>();
            List<Id> insertCategoryStudentIdsByRow = new List<Id>();
            List<Id> insertCategoryRequestWindowIdsByRow = new List<Id>();
            Set<Id> insertCategoryStudentIds = new Set<Id>();
            Set<Id> insertCategoryRequestWindowIds = new Set<Id>();
            Set<String> queuedInsertKeys = new Set<String>();
            Set<Id> queuedUpdateIds = new Set<Id>();
            Map<Id, String> requestTypeByUpdatedSsrId = new Map<Id, String>();

            for (Integer i = 0; i < toInsert.size(); i++) {
                Student_Service_Request__c candidate = toInsert[i];
                String candidateKey = payloadSsrKeysByRow[i];
                Student_Service_Request__c existingSsr = existingSsrByKey.get(candidateKey);

                if (existingSsr != null) {
                    if (!queuedUpdateIds.contains(existingSsr.Id)) {
                        existingSsr.RecordTypeId = candidate.RecordTypeId;
                        existingSsr.Status__c = candidate.Status__c;
                        existingSsr.Course_Offering__c = candidate.Course_Offering__c;
                        existingSsr.Course_Connection__c = candidate.Course_Connection__c;
                        existingSsr.Student_Request_Application__c = candidate.Student_Request_Application__c;
                        existingSsr.Exam__c = candidate.Exam__c;
                        ssrToUpdate.add(existingSsr);
                        queuedUpdateIds.add(existingSsr.Id);
                        requestTypeByUpdatedSsrId.put(existingSsr.Id, requestTypesByRow[i]);
                    }
                    continue;
                }

                if (queuedInsertKeys.contains(candidateKey)) {
                    continue;
                }

                queuedInsertKeys.add(candidateKey);
                ssrToInsert.add(candidate);
                insertFeeContactIds.add(feeContactIds[i]);
                insertFeeTypeIdByRow.add(feeTypeIdByRow[i]);
                insertFeeAffiliationIds.add(feeAffiliationIds[i]);
                insertFeeAmounts.add(feeAmounts[i]);
                insertFeeDueDates.add(feeDueDates[i]);
                insertRequestTypes.add(requestTypesByRow[i]);
                insertCategoryStudentIdsByRow.add(categoryStudentIdsByRow[i]);
                insertCategoryRequestWindowIdsByRow.add(categoryRequestWindowIdsByRow[i]);
                insertCategoryStudentIds.add(categoryStudentIdsByRow[i]);
                insertCategoryRequestWindowIds.add(categoryRequestWindowIdsByRow[i]);
            }

            Map<String, Id> categoryIdByKey = new Map<String, Id>();
            if (!insertCategoryStudentIds.isEmpty() && !insertCategoryRequestWindowIds.isEmpty()) {
                for (Student_Service_Category__c category : [
                    SELECT Id, Student__c, Student_Request_Window__c
                    FROM Student_Service_Category__c
                    WHERE Student__c IN :insertCategoryStudentIds
                      AND Student_Request_Window__c IN :insertCategoryRequestWindowIds
                ]) {
                    categoryIdByKey.put(
                        buildStudentServiceCategoryKey(category.Student__c, category.Student_Request_Window__c),
                        category.Id
                    );
                }
            }

            List<Student_Service_Category__c> categoriesToInsert = new List<Student_Service_Category__c>();
            Set<String> categoriesQueued = new Set<String>();
            for (Integer i = 0; i < ssrToInsert.size(); i++) {
                String key = buildStudentServiceCategoryKey(insertCategoryStudentIdsByRow[i], insertCategoryRequestWindowIdsByRow[i]);
                if (!categoryIdByKey.containsKey(key) && !categoriesQueued.contains(key)) {
                    categoriesQueued.add(key);
                    String studentName = contactNameById.get(insertCategoryStudentIdsByRow[i]);
                    categoriesToInsert.add(new Student_Service_Category__c(
                        Name = (studentName != null ? studentName : '') + ' Request Category',
                        Student__c = insertCategoryStudentIdsByRow[i],
                        Student_Request_Window__c = insertCategoryRequestWindowIdsByRow[i]
                    ));
                }
            }
        
            //  All-or-none insert (atomic)
            Savepoint sp = Database.setSavepoint();
            try {
                System.debug(
                    LoggingLevel.INFO,
                    'createStudentServiceRequest: valid row count = ' + toInsert.size() +
                    ', insert count = ' + ssrToInsert.size() +
                    ', update count = ' + ssrToUpdate.size()
                );

                if (!categoriesToInsert.isEmpty()) {
                    System.debug(LoggingLevel.INFO, 'createStudentServiceRequest: inserting Student_Service_Category__c count = ' + categoriesToInsert.size());
                    Database.insert(categoriesToInsert, true);
                    for (Student_Service_Category__c insertedCategory : categoriesToInsert) {
                        categoryIdByKey.put(
                            buildStudentServiceCategoryKey(insertedCategory.Student__c, insertedCategory.Student_Request_Window__c),
                            insertedCategory.Id
                        );
                    }
                    System.debug(LoggingLevel.INFO, 'createStudentServiceRequest: inserted Student_Service_Category__c count = ' + categoriesToInsert.size());
                }

                List<Fee_Assignment__c> feeAssignmentsToInsert = new List<Fee_Assignment__c>();
                if (!ssrToInsert.isEmpty()) {
                    for (Integer i = 0; i < ssrToInsert.size(); i++) {
                        Fee_Assignment__c fa = new Fee_Assignment__c();
                        fa.Fee_Type__c = insertFeeTypeIdByRow[i];
                        fa.Contact__c = insertFeeContactIds[i];
                        fa.Affiliation__c = insertFeeAffiliationIds[i];
                        fa.Total_Amount_Payable__c = insertFeeAmounts[i];
                        fa.Remaining_Amount__c = insertFeeAmounts[i];
                        // Fee_Assignment__c.Due_Date__c is a cross-object formula (Fee_Type__r.Due_Date__c),
                        // so it is read-only and auto-derives from the Fee Type. Nothing to write here.
                        fa.Fee_Preference__c = 'Semester-wise fee';
                        String rawRt = insertRequestTypes[i].trim().toLowerCase();
                        fa.Fee_Head__c = (rawRt == 're-exam' || rawRt == 're exam' || rawRt == 'reexam')
                            ? 'Backlog examination Fee'
                            : 'Re-Evaluation Fee';
                        fa.Is_Active__c = true;
                        feeAssignmentsToInsert.add(fa);
                    }

                    System.debug(LoggingLevel.INFO, 'createStudentServiceRequest: inserting Fee_Assignment__c count = ' + feeAssignmentsToInsert.size());
                    Database.insert(feeAssignmentsToInsert, true);
                    System.debug(LoggingLevel.INFO, 'createStudentServiceRequest: inserted Fee_Assignment__c count = ' + feeAssignmentsToInsert.size());
                }

                List<Fee_Installment__c> feeInstallmentsToInsert = new List<Fee_Installment__c>();
                if (!feeAssignmentsToInsert.isEmpty()) {
                    for (Integer i = 0; i < feeAssignmentsToInsert.size(); i++) {
                        Fee_Installment__c fi = new Fee_Installment__c();
                        fi.Fee_Assignment__c = feeAssignmentsToInsert[i].Id;
                        fi.Fee_Type__c = insertFeeTypeIdByRow[i];
                        fi.Affiliation__c = insertFeeAffiliationIds[i];
                        fi.Contact__c = insertFeeContactIds[i];
                        fi.Total_Amount_Payable__c = insertFeeAmounts[i];
                        feeInstallmentsToInsert.add(fi);
                    }

                    System.debug(LoggingLevel.INFO, 'createStudentServiceRequest: inserting Fee_Installment__c count = ' + feeInstallmentsToInsert.size());
                    Database.insert(feeInstallmentsToInsert, true);
                    System.debug(LoggingLevel.INFO, 'createStudentServiceRequest: inserted Fee_Installment__c count = ' + feeInstallmentsToInsert.size());
                }

                // Create a Retest Exam Connection ONLY for Re-exam SEE / Both rows.
                // CIA rows (ssr.Exam__c == null) and Re-evaluation rows get no Exam Connection —
                // re-evaluation is a paper review and requires no slot booking.
                List<Exam_Connections__c> examConnectionsToInsert = new List<Exam_Connections__c>();
                List<Integer> examConnRowIndex = new List<Integer>();
                for (Integer i = 0; i < ssrToInsert.size(); i++) {
                    if (ssrToInsert[i].Exam__c == null) continue; // CIA: skip
                    String rtRaw = insertRequestTypes[i].trim().toLowerCase();
                    if (rtRaw == 're-evaluation' || rtRaw == 're evaluation' || rtRaw == 'reevaluation' || rtRaw == 'revaluation') continue; // Re-evaluation: skip
                    examConnectionsToInsert.add(new Exam_Connections__c(
                        Exam_Type__c = 'Retest',
                        Exam_Name__c = ssrToInsert[i].Exam__c,
                        Student_Name__c = insertFeeContactIds[i],
                        Course_Connection_ID__c = ssrToInsert[i].Course_Connection__c
                    ));
                    examConnRowIndex.add(i);
                }
                if (!examConnectionsToInsert.isEmpty()) {
                    System.debug(LoggingLevel.INFO, 'createStudentServiceRequest: inserting Exam_Connections__c count = ' + examConnectionsToInsert.size());
                    Database.insert(examConnectionsToInsert, true);
                    for (Integer j = 0; j < examConnectionsToInsert.size(); j++) {
                        ssrToInsert[examConnRowIndex[j]].Exam_Connection__c = examConnectionsToInsert[j].Id;
                    }
                }

                for (Integer i = 0; i < ssrToInsert.size(); i++) {
                    String categoryKey = buildStudentServiceCategoryKey(insertCategoryStudentIdsByRow[i], insertCategoryRequestWindowIdsByRow[i]);
                    ssrToInsert[i].Fee_Assignment__c = feeAssignmentsToInsert[i].Id;
                    ssrToInsert[i].Student_Service_Category__c = categoryIdByKey.get(categoryKey);
                }
                if (!ssrToInsert.isEmpty()) {
                    System.debug(LoggingLevel.INFO, 'createStudentServiceRequest: inserting Student_Service_Request__c count = ' + ssrToInsert.size());
                    Database.insert(ssrToInsert, true);
                    System.debug(LoggingLevel.INFO, 'createStudentServiceRequest: inserted Student_Service_Request__c count = ' + ssrToInsert.size());
                }

                if (!ssrToUpdate.isEmpty()) {
                    System.debug(LoggingLevel.INFO, 'createStudentServiceRequest: updating Student_Service_Request__c count = ' + ssrToUpdate.size());
                    Database.update(ssrToUpdate, true);
                    System.debug(LoggingLevel.INFO, 'createStudentServiceRequest: updated Student_Service_Request__c count = ' + ssrToUpdate.size());
                }

                List<Id> ids = new List<Id>();
                Set<Id> studentServiceCategoryIdSet = new Set<Id>();
                List<StudentServiceRequestPostRecordWrapper> insertedRecords = new List<StudentServiceRequestPostRecordWrapper>();
                List<StudentServiceRequestPostRecordWrapper> updatedRecords = new List<StudentServiceRequestPostRecordWrapper>();
                List<StudentServiceRequestPostRecordWrapper> allRecords = new List<StudentServiceRequestPostRecordWrapper>();
                for (Integer i = 0; i < ssrToInsert.size(); i++) {
                    ids.add(ssrToInsert[i].Id);
                    if (ssrToInsert[i].Student_Service_Category__c != null) {
                        studentServiceCategoryIdSet.add(ssrToInsert[i].Student_Service_Category__c);
                    }

                    StudentServiceRequestPostRecordWrapper insertedRow = new StudentServiceRequestPostRecordWrapper();
                    insertedRow.operation = 'Inserted';
                    insertedRow.studentServiceRequestId = ssrToInsert[i].Id;
                    insertedRow.studentServiceCategoryId = ssrToInsert[i].Student_Service_Category__c;
                    insertedRow.feeAssignmentId = feeAssignmentsToInsert[i].Id;
                    insertedRow.feeInstallmentId = feeInstallmentsToInsert[i].Id;
                    // Fee details sourced from the Fee_Assignment__c records already in memory (no re-query).
                    // Due_Date__c is a formula (Fee_Type__r.Due_Date__c) that is not populated in-memory
                    // after insert, so use the Fee Type due date captured for this row.
                    insertedRow.requestType = insertRequestTypes[i];
                    insertedRow.totalFee = feeAssignmentsToInsert[i].Total_Amount_Payable__c;
                    insertedRow.remainingFee = feeAssignmentsToInsert[i].Remaining_Amount__c;
                    insertedRow.dueDate = insertFeeDueDates[i];
                    insertedRecords.add(insertedRow);
                    allRecords.add(insertedRow);
                }
                List<Id> updatedIds = new List<Id>();
                Set<Id> updatedFeeAssignmentIds = new Set<Id>();
                for (Student_Service_Request__c updatedSsr : ssrToUpdate) {
                    if (updatedSsr.Fee_Assignment__c != null) {
                        updatedFeeAssignmentIds.add(updatedSsr.Fee_Assignment__c);
                    }
                }

                Map<Id, Id> feeInstallmentIdByFeeAssignmentId = new Map<Id, Id>();
                if (!updatedFeeAssignmentIds.isEmpty()) {
                    for (Fee_Installment__c fi : [
                        SELECT Id, Fee_Assignment__c
                        FROM Fee_Installment__c
                        WHERE Fee_Assignment__c IN :updatedFeeAssignmentIds
                        ORDER BY CreatedDate DESC
                    ]) {
                        if (fi.Fee_Assignment__c != null && !feeInstallmentIdByFeeAssignmentId.containsKey(fi.Fee_Assignment__c)) {
                            feeInstallmentIdByFeeAssignmentId.put(fi.Fee_Assignment__c, fi.Id);
                        }
                    }
                }

                for (Student_Service_Request__c updatedSsr : ssrToUpdate) {
                    updatedIds.add(updatedSsr.Id);
                    if (updatedSsr.Student_Service_Category__c != null) {
                        studentServiceCategoryIdSet.add(updatedSsr.Student_Service_Category__c);
                    }

                    StudentServiceRequestPostRecordWrapper updatedRow = new StudentServiceRequestPostRecordWrapper();
                    updatedRow.operation = 'Updated';
                    updatedRow.studentServiceRequestId = updatedSsr.Id;
                    updatedRow.studentServiceCategoryId = updatedSsr.Student_Service_Category__c;
                    updatedRow.feeAssignmentId = updatedSsr.Fee_Assignment__c;
                    updatedRow.feeInstallmentId = updatedSsr.Fee_Assignment__c != null
                        ? feeInstallmentIdByFeeAssignmentId.get(updatedSsr.Fee_Assignment__c)
                        : null;
                    // Fee details from the existing Fee_Assignment__c fetched in the dedupe query (no re-query)
                    updatedRow.requestType = requestTypeByUpdatedSsrId.get(updatedSsr.Id);
                    updatedRow.totalFee = updatedSsr.Fee_Assignment__r != null ? updatedSsr.Fee_Assignment__r.Total_Amount_Payable__c : null;
                    updatedRow.remainingFee = updatedSsr.Fee_Assignment__r != null ? updatedSsr.Fee_Assignment__r.Remaining_Amount__c : null;
                    updatedRow.dueDate = updatedSsr.Fee_Assignment__r != null ? updatedSsr.Fee_Assignment__r.Due_Date__c : null;
                    updatedRecords.add(updatedRow);
                    allRecords.add(updatedRow);
                }

                List<Id> studentServiceCategoryIds = new List<Id>(studentServiceCategoryIdSet);
        
                Map<String, Object> okResp = new Map<String, Object>{
                    'success' => true,
                    'insertedCount' => ids.size(),
                    'updatedCount' => updatedIds.size(),
                    'ids' => ids,
                    'updatedIds' => updatedIds,
                    'studentServiceCategoryIds' => studentServiceCategoryIds,
                    'insertedRecords' => insertedRecords,
                    'updatedRecords' => updatedRecords,
                    'records' => allRecords
                };
                RestApiUtility.createSuccessGetResponse(okResp);
        
            } catch (DmlException de) {
                Database.rollback(sp);
                System.debug(LoggingLevel.ERROR, 'createStudentServiceRequest: DML exception -> ' + de.getMessage());
                List<Map<String, Object>> dmlErrors = new List<Map<String, Object>>();
                for (Integer i = 0; i < de.getNumDml(); i++) {
                    dmlErrors.add(new Map<String, Object>{
                        'index' => (i + 1),
                        'message' => de.getDmlMessage(i)
                    });
                }
        
                Map<String, Object> errResp = new Map<String, Object>{
                    'success' => false,
                    'errors' => dmlErrors
                };
                RestContext.response.statusCode = HTTP_BAD_REQUEST;
                RestContext.response.responseBody = Blob.valueOf(JSON.serialize(errResp));
            }
        }





    public class StudentServiceRequestPostRecordWrapper {
        public String operation;
        public Id studentServiceRequestId;
        public Id studentServiceCategoryId;
        public Id feeAssignmentId;
        public Id feeInstallmentId;

        // Fee details required by front-end payment integration
        public String requestType;
        public Decimal totalFee;
        public Decimal remainingFee;
        public Date dueDate;
    }

    // Wrapper class to structure the response data for Exam_Slot_Setup__c
    public class ExamSlotSetupWrapper {
        public Id id;
        public Date startDate;
        public Time startTime;
        public Date endDate;
        public Time endTime;
        public Id examId;
        public Id examcycle;
        public String semester;
        public String recordTypeDeveloperName;
        
        
        
        public ExamSlotSetupWrapper() {}
    }
    
    // Wrapper class to structure the response data for Exam_Connections__c
    public class ExamConnectionByStudentWrapper {
        public Id id;
        public String courseName;
        public String courseId;
        public String courseCode;
        public String examName;
        public Decimal credits;
        public String eligibility;
        public String examid;
        public date StartDate;
        public time StartTime;
        public date EndDate;
        public date LastDatetoEnroll;
        public time EndTime;
        public String examcycle;
        public ID examcycleId;
        public String Semenster;
        public Boolean examConnectionSlotScheduled;
        public Boolean examCycleStatus;
        public String examTypeCategory;
        public Boolean examFeePaid;

        public ExamConnectionByStudentWrapper() {}
    }
    
    public class ComponentScoreWrapper {
        public String id;

	}
    
    // Wrapper class to structure the response data for Slot_Scheduled__c
    public class ScheduledSlotWrapper {
        public Id id;
        public DateTime startDateTime;
        public DateTime endDateTime;
        public Id examId;
        public String scheduleUrl;
        public String scheduleId;
        public Id studentId;
        public Id courseId;
        public String courseName;
        public String examName;
        public String examcycle;
        public ID examcycleID;
        public String semester;
        public String examType;
        public List<ComponentScoreWrapper> componentScores;
        public ScheduledSlotWrapper() {}
    } 
    
        public class ResultPublishWrapper {
        public Id id;
        public String courseName;
        public String courseCode;
        public Decimal credits;
        public String finalGrade;
        public Decimal componentFinalScore;
        public Decimal gpa;
        public String termReference;
        public Decimal CreditsEarned;
        public String TermId;
        public Date SemesterStartDate;
        public Date SemesterEndDate;
    
        // NEW
        public Decimal cgpa;

        public String remarks;

        // NEW
        public List<MarksBreakdownWrapper> marksBreakdown;
    }

    
    //  NEW NESTED WRAPPER
    public class MarksBreakdownWrapper {
        public Id id;
        public String name;
        public Decimal marksObtained;
        public Decimal passWeightage;
    }
    
	public class HallTicketResponseWrapper {
        public Id contactId;
        public String contactName;
        public String contactPhoto;
        public String usnNumber;
        public String programPlan;
        public Boolean PublishHallTicket;
        public List<CourseSlotWrapper> courses;
    
        public HallTicketResponseWrapper() {
            this.courses = new List<CourseSlotWrapper>();
        }
    }
    
    public class CourseSlotWrapper {
        public Id slotScheduledId;
        public DateTime startDateTime;
        public DateTime endDateTime;
        public String courseCode;
        public String courseName;
        Public String Semester;
     //   Public Boolean PublishHallTicket;
    
        public CourseSlotWrapper() {}
    }
    
    public class GradeCardWrapper {
        public Id studentId;
        public Id programEnrollmentId;
        public String termReference;
    
        public Id contentDocumentId;
        public Id contentVersionId;
    
        public String title;
        public String fileType;
        public String versionNumber;
        public Integer contentSize;
        public Datetime createdDate;
    
        public String downloadUrl;
        public String previewUrl;
    }
		
        public class ReExamWrapper {
        public String course;
        public String semester;
        public String courseCode;
        public Decimal credit;
        public String type;
        public String examTypeLabel;   // Exam_Name__r.Exam_Name__c

        public Id studentServiceRequestApplicationId;
        public Id feeTypeId;
        public Decimal fee;
        public DateTime dueDate;

        // optional but helpful for debugging/frontend
        public Id examCycleId;
        public Id termId;
        public Id ExamConnectionID;
        public Id ExamID;
		public Id CourseConnectionID;
		public Id CourseOfferingID;
        public String courseConnectionFinalGrade;
        public String examConnectionFinalGrade;
    }

    public class ReEvaluationWrapper {
        public String course;
        public String semester;
        public String courseCode;
        public Decimal credit;
        public String type;
        public String examTypeLabel;   // Exam_Name__r.Exam_Name__c

        public Id studentServiceRequestApplicationId;
        public Id feeTypeId;
        public Decimal fee;
        public DateTime dueDate;

        // optional but helpful for debugging/frontend
        public Id examCycleId;
        public Id termId;
        public Id ExamConnectionID;
		public Id ExamID;
		public Id CourseConnectionID;
		public Id CourseOfferingID;
        public String courseConnectionFinalGrade;
        public String examConnectionFinalGrade;
    }

    public class RequestedExamsWrapper {
        public String course;
        public String semester;
        public String courseCode;
        public Decimal credit;
        public String type;
        public String examTypeLabel;   // Exam__r.Exam_Name__c
		public String RequestType;
        public String examName;        // Student_Service_Request__c.Exam_Name__c
        public Boolean paidExamFee;    // Student_Service_Request__c.Paid_Exam_Fee__c
        public Id examConnectionId;    // Student_Service_Request__c.Exam_Connection__c
        public Boolean isSlotBooked;   // true when the Exam Connection has a non-expired Slot_Scheduled__c
    
        public Id studentServiceRequestApplicationId;
        public Id feeTypeId;
        public Decimal fee;
        public DateTime dueDate;
        public Id feeAssignmentId;
        public Id feeInstallmentId;

        // IDs needed for SSR matching / frontend usage
        public Id courseOfferingId;
        public Id courseConnectionId;
        public Id CourseID;   // Course_Connection__r.hed__Course_Offering__r.hed__Course__c
        public Id examId;                    
        public Id examCycleId;               
        public Id termId;                    
        public String courseConnectionFinalGrade;

        // optional: if you want to return SSR id
        public Id studentServiceRequestId;

        // Payment transaction details tied to this request's fee installment
        public List<PaymentTransactionWrapper> paymentTransactions;
    }

    public class PaymentTransactionWrapper {
        public String orderId;            // Payment_Transaction__r.Order_Id__c
        public Datetime transactionDate;  // Payment_Transaction__r.Transaction_Date__c
        public String transactionId;      // Payment_Transaction__r.Transaction_Id__c
        public String paymentMode;        // Payment_Transaction__r.Payment_Mode__c
        public Decimal amount;            // Payment_Transaction__r.Amount__c
        public String receiptUrl;         // Receipt__r.Receipt_URL__c
        public String paymentStatus;      // Payment_Status__c
        public Decimal receivedAmount;    // Received_Amount__c
    }

}