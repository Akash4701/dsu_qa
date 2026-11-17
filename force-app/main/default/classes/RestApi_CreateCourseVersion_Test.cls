@IsTest
global class RestApi_CreateCourseVersion_Test {

    // -------------------------
    // Common data factory
    // -------------------------
    private class TestData {
        Account institute;
        Contact facultyContact;
        hed__Program_Plan__c programPlan;
        hed__Term__c term1;
        hed__Course__c course;
        Course_Version__c cv;
        hed__Course_Offering__c offering;
        Course_Evaluation_Component__c component;
        Exam_Cycle__c examCycle;
    }

    @testSetup
    static void setup() {

        // Unique LMS URLs (avoid FIELD_INTEGRITY_EXCEPTION Name dup)
        insert new List<LMS_URL__c>{
            new LMS_URL__c(Name='course url - RCv', Bulk_Enroll__c='TestUrl'),
            new LMS_URL__c(Name='course offering url - RCv', Bulk_Enroll__c='TestUrl'),
            new LMS_URL__c(Name='Bulk Enrollment - RCv', Bulk_Enroll__c='TestUrl')
        };

        // Base institute
        Account institute = new Account(Name='Test Institute', LMS_Id__c='12345');
        insert institute;

        // Faculty contact (used in Activity / Faculty_Booking)
        Contact fac = new Contact(LastName='Faculty One');
        insert fac;

        // Program plan
        hed__Program_Plan__c plan = new hed__Program_Plan__c(
            Name='Plan 2026',
            hed__Account__c=institute.Id,
            hed__Start_Date__c=Date.today().addDays(-10),
            hed__End_Date__c=Date.today().addDays(100),
            hed__Status__c='Current',
            Working_Days__c='Monday;Tuesday;Wednesday;Thursday;Friday'
        );
        insert plan;

        // Term (Default Record)
        Id termRtId = Schema.SObjectType.hed__Term__c.getRecordTypeInfosByName().get('Default Record').getRecordTypeId();
        hed__Term__c term = new hed__Term__c(
            Name='Term 1',
            hed__Account__c=institute.Id,
            Program_Plan__c=plan.Id,
            Term_Reference__c='Term 1',
            hed__Start_Date__c=Date.today().addDays(-5),
            hed__End_Date__c=Date.today().addDays(90),
            RecordTypeId=termRtId
        );
        insert term;

        // Course
        hed__Course__c c = new hed__Course__c(
            Name='Test Course',
            hed__Account__c=institute.Id,
            Credits__c=3,
            hed__Course_ID__c='TC-001'
        );
        insert c;

        // Course Version
        Course_Version__c cv = new Course_Version__c(
            Course__c=c.Id,
            Term__c=term.Id,
            Start_Date__c=Date.today(),
            End_Date__c=Date.today().addDays(1),
            Exam_Required__c=true
        );
        insert cv;

        // Course Offering
        hed__Course_Offering__c off = new hed__Course_Offering__c(
            Name='Offering A',
            hed__Course__c=c.Id,
            hed__Term__c=term.Id,
            hed__Section_ID__c='A',
            Course_Version__c=cv.Id,
            hed__Start_Date__c=Date.today(),
            hed__End_Date__c=Date.today().addDays(60)
        );
        insert off;

        // Course Evaluation Component (required by Exam validation)
        Course_Evaluation_Component__c comp = new Course_Evaluation_Component__c(
            Name='CIA Component',
            Course_Offering__c=off.Id,
            Exam_Type__c='CIA',
            Maximum_Marks_for_the_Component__c=100,
            Pass_Weightage__c=40
        );
        insert comp;

        // Exam Cycle (safe)
        Exam_Cycle__c cycle = new Exam_Cycle__c(
            Name='CIA Cycle',
            Exam_Name__c='CIA',
            Start_Date__c=Date.today().addDays(-1),
            End_Date__c=Date.today().addDays(30)
        );
        insert cycle;

        // Exam (MUST include Course_Evaluation_Component__c)
        Exam__c ex = new Exam__c(
            Exam_Date__c=Date.today(),
            Start_Time__c=Time.newInstance(10,0,0,0),
            End_Time__c=Time.newInstance(12,0,0,0),
            Course_Version__c=cv.Id,
            Course_Evaluation_Component__c=comp.Id
        );
        // If Exam__c has Exam_Cycle__c in your org, set dynamically (won't fail compile if field absent)
        try { ex.put('Exam_Cycle__c', cycle.Id); } catch (Exception ignore) {}
        insert ex;

        // Child records for delete-by-term and delete-by-courseVersion coverage

        // Activity (queried by createFacultyBooking)
        Activity__c act = new Activity__c(
            Name='Activity 1',
            Subject__c=cv.Id,
            Start_date__c=Date.today(),
            End_date__c=Date.today().addDays(3),
            Activity_Duration__c=3,
            Offset__c=1,
            Faculty1__c=fac.Id,
            Activity_type__c='Teaching',
            Number_of_Sessions__c=4
        );
        insert act;

        // Faculty booking (so delete branches delete it)
        Faculty_Booking__c fb = new Faculty_Booking__c(
            Course_Version__c=cv.Id,
            Booked_By__c=fac.Id,
            Activity_Type__c='Exam',
            Type__c='Planned',
            Start_Date_Time__c=DateTime.now(),
            End_Date_Time__c=Date.today().addDays(10)
        );
        insert fb;

        // Subject activity + planner
        insert new Subject_Activity__c(Course_Version__c=cv.Id, Duration__c=10, Type_of_Activity__c='Tutorial');
        insert new Subject_Planner__c(Course_Version__c=cv.Id, Type_of_Activity__c='Other');

        // Plan Requirement (Unit) so delete-by-term deletes it
        Id unitRtId;
        try {
            unitRtId = Schema.SObjectType.hed__Plan_Requirement__c.getRecordTypeInfosByName().get('Unit').getRecordTypeId();
        } catch (Exception e) {
            unitRtId = null;
        }
        if (unitRtId != null) {
            insert new hed__Plan_Requirement__c(
                Name='Unit Plan Req',
                Institute__c=institute.Id,
                Term__c=term.Id,
                hed__Course__c=c.Id,
                RecordTypeId=unitRtId
            );
        }
    }

    // -------------------------
    // Helper to invoke REST
    // -------------------------
    private static void invokeRest(RestApi_CreateCourseVersion.requestCourseVersionWrapper reqWrap) {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/createCourseVersion';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(reqWrap));
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        RestApi_CreateCourseVersion.doCourseVersion();
        Test.stopTest();
    }

    // ------------------------------------------
    // 1) Delete branch: termId present
    // ------------------------------------------
    @IsTest
    static void testDeleteByTermId() {
        hed__Term__c t = [SELECT Id FROM hed__Term__c WHERE Name='Term 1' LIMIT 1];

        RestApi_CreateCourseVersion.requestCourseVersionWrapper w = new RestApi_CreateCourseVersion.requestCourseVersionWrapper();
        w.Operation = 'Delete';
        w.termId = t.Id;
        w.CourseVersion = new RestApi_CreateCourseVersion.requestCourseVersionDataWrapper(); // not used in this branch

        invokeRest(w);
    }

    // ------------------------------------------
    // 2) Delete branch: courseVersionId present
    // ------------------------------------------
    @IsTest
    static void testDeleteByCourseVersionId() {
        // Create a new small CV just for this branch (so previous test doesn't remove it)
        Account acc = [SELECT Id FROM Account LIMIT 1];
        hed__Term__c term = [SELECT Id, Name, hed__Account__c, Program_Plan__c, RecordTypeId, Term_Reference__c, hed__Start_Date__c, hed__End_Date__c
                             FROM hed__Term__c LIMIT 1];
        hed__Course__c course = [SELECT Id FROM hed__Course__c LIMIT 1];

        Course_Version__c cv2 = new Course_Version__c(
            Course__c=course.Id, Term__c=term.Id, Start_Date__c=Date.today(), End_Date__c=Date.today().addDays(1)
        );
        insert cv2;

        RestApi_CreateCourseVersion.requestCourseVersionWrapper w = new RestApi_CreateCourseVersion.requestCourseVersionWrapper();
        w.Operation = 'Delete';
        w.termId = null;

        RestApi_CreateCourseVersion.requestCourseVersionDataWrapper data = new RestApi_CreateCourseVersion.requestCourseVersionDataWrapper();
        data.courseVersionId = cv2.Id;
        w.CourseVersion = data;

        invokeRest(w);
    }

    // ------------------------------------------
    // 3) Non-delete branch: blank termName + blank courseId
    // ------------------------------------------
    @IsTest
    static void testNoDataFoundEarlyReturn() {
        RestApi_CreateCourseVersion.requestCourseVersionWrapper w = new RestApi_CreateCourseVersion.requestCourseVersionWrapper();
        w.Operation = 'insert';

        RestApi_CreateCourseVersion.requestCourseVersionDataWrapper data = new RestApi_CreateCourseVersion.requestCourseVersionDataWrapper();
        data.termName = '';
        data.courseId = '';
        w.CourseVersion = data;

        invokeRest(w);
    }

    // ------------------------------------------
    // 4) Operation == null → duplicate record found
    // ------------------------------------------
    @IsTest
    static void testOperationNull_DuplicateRecordFound() {
        hed__Course__c course = [SELECT Id FROM hed__Course__c LIMIT 1];

        // ensure a CV already exists in Term 1 for that course (from @testSetup)
        RestApi_CreateCourseVersion.requestCourseVersionWrapper w = new RestApi_CreateCourseVersion.requestCourseVersionWrapper();
        w.Operation = null;

        RestApi_CreateCourseVersion.requestCourseVersionDataWrapper data = new RestApi_CreateCourseVersion.requestCourseVersionDataWrapper();
        data.termName = 'Term 1';
        data.courseId = course.Id;
        data.startDate = Date.today().format();
        data.endDate = Date.today().addDays(2).format();
        data.examRequired = true;
        w.CourseVersion = data;

        invokeRest(w);
    }

    // ------------------------------------------
    // 5) Operation == null → prerequisites not met (Term 1 case returns false)
    // ------------------------------------------
    @IsTest
    static void testOperationNull_PrerequisitesNotMet() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        hed__Term__c term = [SELECT Id, Name, Term_Reference__c, RecordTypeId, hed__Account__c FROM hed__Term__c WHERE Name='Term 1' LIMIT 1];

        // Create a new course with prerequisites in Master Unit
        hed__Course__c mainCourse = new hed__Course__c(
            Name='Course With PreReq', hed__Account__c=acc.Id, Credits__c=1, hed__Course_ID__c='PR-001'
        );
        insert mainCourse;

        hed__Course__c pre1 = new hed__Course__c(
            Name='PreReq 1', hed__Account__c=acc.Id, Credits__c=1, hed__Course_ID__c='PR-101'
        );
        insert pre1;

        // RecordType Master Unit
        Id masterUnitRtId;
        try {
            masterUnitRtId = Schema.SObjectType.hed__Plan_Requirement__c.getRecordTypeInfosByName().get('Master Unit').getRecordTypeId();
        } catch (Exception e) {
            masterUnitRtId = null;
        }

        if (masterUnitRtId != null) {
            insert new hed__Plan_Requirement__c(
                Name='Master Unit With PreReq',
                hed__Course__c=mainCourse.Id,
                Term__c=term.Id,
                Institute__c=acc.Id,
                Pre_Requisites_1__c=pre1.Id,
                RecordTypeId=masterUnitRtId
            );
        }

        // Call with Operation == null → validatePlanRequirement should fail (no CV for prereq in Term 1)
        RestApi_CreateCourseVersion.requestCourseVersionWrapper w = new RestApi_CreateCourseVersion.requestCourseVersionWrapper();
        w.Operation = null;

        RestApi_CreateCourseVersion.requestCourseVersionDataWrapper data = new RestApi_CreateCourseVersion.requestCourseVersionDataWrapper();
        data.termName = 'Term 1';
        data.courseId = mainCourse.Id;
        data.startDate = Date.today().format();
        data.endDate = Date.today().addDays(1).format();
        data.examRequired = true;
        w.CourseVersion = data;

        invokeRest(w);
    }

    // ------------------------------------------
    // 6) Operation == null → duplicate from previous term
    // ------------------------------------------
    @IsTest
    static void testOperationNull_DuplicateFromPreviousTerm() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        // Create Term 2 (so previous term exists by reference compare)
        Id termRtId = Schema.SObjectType.hed__Term__c.getRecordTypeInfosByName().get('Default Record').getRecordTypeId();
        hed__Term__c term2 = new hed__Term__c(
            Name='Term 2',
            hed__Account__c=acc.Id,
            Term_Reference__c='Term 2',
            hed__Start_Date__c=Date.today().addDays(-1),
            hed__End_Date__c=Date.today().addDays(100),
            RecordTypeId=termRtId
        );
        insert term2;

        // Program campus combo + term campus relationships
        Program_Campus_Relationship__c pcc = new Program_Campus_Relationship__c(CurrencyIsoCode='INR');
        insert pcc;

        Term_Campus_Relationship__c tcr1 = new Term_Campus_Relationship__c(Program_Campus_Combination__c=pcc.Id, Term__c=[SELECT Id FROM hed__Term__c WHERE Name='Term 1' LIMIT 1].Id);
        insert tcr1;
        Term_Campus_Relationship__c tcr2 = new Term_Campus_Relationship__c(Program_Campus_Combination__c=pcc.Id, Term__c=term2.Id);
        insert tcr2;

        // Create a new course and create a course version in Term 1 (previous term)
        hed__Course__c courseX = new hed__Course__c(
            Name='Course Duplicate PrevTerm',
            hed__Account__c=acc.Id,
            Credits__c=1,
            hed__Course_ID__c='DP-001'
        );
        insert courseX;

        Course_Version__c prevCv = new Course_Version__c(
            Course__c=courseX.Id,
            Term__c=[SELECT Id FROM hed__Term__c WHERE Name='Term 1' LIMIT 1].Id,
            Start_Date__c=Date.today().addMonths(-2),
            End_Date__c=Date.today().addMonths(-1)
        );
        insert prevCv;

        // Now request in Term 2 with Operation == null → validateDuplicateRecordsFromPrevTerms should return false
        RestApi_CreateCourseVersion.requestCourseVersionWrapper w = new RestApi_CreateCourseVersion.requestCourseVersionWrapper();
        w.Operation = null;

        RestApi_CreateCourseVersion.requestCourseVersionDataWrapper data = new RestApi_CreateCourseVersion.requestCourseVersionDataWrapper();
        data.termName = 'Term 2';
        data.courseId = courseX.Id;
        data.startDate = Date.today().format();
        data.endDate = Date.today().addDays(1).format();
        data.examRequired = true;
        w.CourseVersion = data;

        invokeRest(w);
    }

    // ------------------------------------------
    // 7) Normal upsert path (non-delete) + faculty booking creation path
    // ------------------------------------------
    @IsTest
    static void testNormalUpsertPath() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        hed__Term__c term = [SELECT Id, Name, hed__End_Date__c FROM hed__Term__c WHERE Name='Term 1' LIMIT 1];
        hed__Course__c course = [SELECT Id FROM hed__Course__c LIMIT 1];

        // Create a fresh CV to update through API using courseVersionId
        Course_Version__c cv3 = new Course_Version__c(
            Course__c=course.Id, Term__c=term.Id, Start_Date__c=Date.today(), End_Date__c=Date.today().addDays(1)
        );
        insert cv3;

        // Create an Activity for this CV so createFacultyBooking hits Activity query + map logic
        Contact fac = [SELECT Id FROM Contact LIMIT 1];
        insert new Activity__c(
            Name='Act for CV3',
            Subject__c=cv3.Id,
            Start_date__c=Date.today(),
            End_date__c=Date.today().addDays(2),
            Activity_Duration__c=2,
            Offset__c=1,
            Faculty1__c=fac.Id,
            Activity_type__c='Teaching',
            Number_of_Sessions__c=2
        );

        // Call API (Operation not Delete, not null) → goes through upsert & response building.
        // Keep facultyWithId blank to avoid dependency on PersonAccount mapping; still covers upsert + json response.
        RestApi_CreateCourseVersion.requestCourseVersionWrapper w = new RestApi_CreateCourseVersion.requestCourseVersionWrapper();
        w.Operation = 'insert';

        RestApi_CreateCourseVersion.requestCourseVersionDataWrapper data = new RestApi_CreateCourseVersion.requestCourseVersionDataWrapper();
        data.termName = 'Term 1';
        data.courseVersionId = cv3.Id;
        data.courseId = course.Id;
        data.startDate = Date.today().format();
        data.endDate = Date.today().addDays(5).format();
        data.examRequired = true;
        data.numOfSessions = 4;
        data.facultyWithId = ''; // skip loop safely
        w.CourseVersion = data;

        invokeRest(w);
    }

    // ------------------------------------------
    // 8) Directly cover getConatctFromAccount()
    // ------------------------------------------
    @IsTest
    static void testGetContactFromAccount() {
        // Provide facultyIds in expected format "X-<Id>"
        Account acc = [SELECT Id FROM Account LIMIT 1];
        List<String> facIds = new List<String>{ 'ACC-' + acc.Id };

        Test.startTest();
        List<Account> outAccs = RestApi_CreateCourseVersion.getConatctFromAccount(facIds);
        Test.stopTest();
    }

    // ------------------------------------------
    // Mock (only if your code makes callouts elsewhere in your org)
    // ------------------------------------------
    global class MockEnrollmentRespBBClass implements HttpCalloutMock {
        global HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"success": true}');
            return res;
        }
    }

@IsTest
static void testValidateCoursesFromPreviousTerm_Covered() {

    Account acc = new Account(Name='Inst - PrevTerm');
    insert acc;

    Id termRtId = Schema.SObjectType.hed__Term__c
        .getRecordTypeInfosByName().get('Default Record').getRecordTypeId();

    // Previous term (reference '1') and current term (reference '2')
    hed__Term__c term1 = new hed__Term__c(
        Name='TERM-1-PREV',
        hed__Account__c=acc.Id,
        Term_Reference__c='1',
        hed__Start_Date__c=Date.today().addMonths(-2),
        hed__End_Date__c=Date.today().addMonths(-1),
        RecordTypeId=termRtId
    );
    insert term1;

    hed__Term__c term2 = new hed__Term__c(
        Name='TERM-2-CURR',
        hed__Account__c=acc.Id,
        Term_Reference__c='2',
        hed__Start_Date__c=Date.today(),
        hed__End_Date__c=Date.today().addDays(60),
        RecordTypeId=termRtId
    );
    insert term2;

    // PCC + term campus relationships (required by method)
    Program_Campus_Relationship__c pcc = new Program_Campus_Relationship__c(CurrencyIsoCode='INR');
    insert pcc;

    insert new Term_Campus_Relationship__c(Program_Campus_Combination__c=pcc.Id, Term__c=term1.Id);
    insert new Term_Campus_Relationship__c(Program_Campus_Combination__c=pcc.Id, Term__c=term2.Id);

    // Two prerequisite courses
    hed__Course__c pre1 = new hed__Course__c(Name='PRE-1', hed__Account__c=acc.Id, Credits__c=1, hed__Course_ID__c='P-1');
    hed__Course__c pre2 = new hed__Course__c(Name='PRE-2', hed__Account__c=acc.Id, Credits__c=1, hed__Course_ID__c='P-2');
    insert new List<hed__Course__c>{ pre1, pre2 };

    // Put BOTH prerequisites into the previous term via Course Versions
    insert new Course_Version__c(Course__c=pre1.Id, Term__c=term1.Id, Start_Date__c=Date.today().addMonths(-2), End_Date__c=Date.today().addMonths(-1));
    insert new Course_Version__c(Course__c=pre2.Id, Term__c=term1.Id, Start_Date__c=Date.today().addMonths(-2), End_Date__c=Date.today().addMonths(-1));

    // Now call the method directly
    Set<Id> prereqIds = new Set<Id>{ pre1.Id, pre2.Id };

    Test.startTest();
    RestApi_CreateCourseVersion.ValidateCoursesFromPreviousTerm(term2.Name, prereqIds);
    Test.stopTest();

    // (No asserts as per your rule)
}



}