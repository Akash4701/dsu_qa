@IsTest
private class CourseVersionTriggerHandlerTest {

    // Keep if your org has callouts in some unrelated triggers.
    // Not actually required for this handler, but harmless.
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"success": true}');
            return res;
        }
    }

    // -----------------------------
    // Shared data builder
    // -----------------------------
    private class DataFactory {
        public Account acc;
        public hed__Course__c course;
        public hed__Term__c term;
        public hed__Course_Offering__c offering;
        public Course_Evaluation_Component__c component;
        public Exam_Cycle__c cycle;

        public DataFactory() {
            // URL records (your org seems to require these due to other triggers)
            insert new List<LMS_URL__c>{
                new LMS_URL__c(Name = 'course url', Bulk_Enroll__c = 'TestUrl'),
                new LMS_URL__c(Name = 'course offering url', Bulk_Enroll__c = 'TestUrl'),
                new LMS_URL__c(Name = 'Bulk Enrollment', Bulk_Enroll__c = 'TestUrl')
            };

            acc = new Account(Name = 'Test Account');
            insert acc;

            // Term (safe defaults)
            term = new hed__Term__c(
                Name = 'Spring 2026',
                hed__Account__c = acc.Id,
                Term_Reference__c = 'Term 1',
                hed__Start_Date__c = Date.today().addDays(-10),
                hed__End_Date__c = Date.today().addDays(100)
            );
            insert term;

            course = new hed__Course__c(
                Name = 'Test Course',
                hed__Account__c = acc.Id
            );
            insert course;

            offering = new hed__Course_Offering__c(
                Name = 'Test Offering',
                hed__Course__c = course.Id,
                hed__Term__c = term.Id
            );
            insert offering;

            component = new Course_Evaluation_Component__c(
                Name = 'CIA Component',
                Course_Offering__c = offering.Id,
                Exam_Type__c = 'CIA',
                Maximum_Marks_for_the_Component__c = 100,
                Pass_Weightage__c = 40
            );
            insert component;

            cycle = new Exam_Cycle__c(
                Name = 'Test Exam Cycle',
                Exam_Name__c = 'CIA',
                Start_Date__c = Date.today().addDays(-1),
                End_Date__c = Date.today().addDays(30)
            );
            insert cycle;
        }

        public Exam__c makeExam(Id courseVersionId, Date examDateOrNull) {
            Exam__c e = new Exam__c();
            e.Course_Version__c = courseVersionId;

            // ✅ Fix for your validation:
            // "Course Evaluation Component is missing. Exam Cycle cannot be determined without it."
            e.Course_Evaluation_Component__c = component.Id;

            // In many orgs Exam Cycle is derived; setting it explicitly is fine if field exists.
            e.Exam_Cycle__c = cycle.Id;

            if (examDateOrNull != null) {
                e.Date_of_Exam__c = examDateOrNull;
            }
            return e;
        }
    }

    @IsTest
    static void testCheckRelatedExams_mixedExams_deletesNullDate_and_blocksIfAllDated() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        DataFactory f = new DataFactory();

        Course_Version__c cv = new Course_Version__c(
            Course__c = f.course.Id,
            Exam_Required__c = false
        );
        insert cv;

        // One exam has Date_of_Exam__c => goes into errorExm map
        // One exam has null Date_of_Exam__c => should be deleted by handler
        Exam__c examWithDate = f.makeExam(cv.Id, Date.today());
        Exam__c examWithoutDate = f.makeExam(cv.Id, null);
        insert new List<Exam__c>{ examWithDate, examWithoutDate };

        // Call handler: should delete null-date exam, but should NOT addError
        // because errorExm.size != totalExm.size after deletion.
        Test.startTest();
        CourseVersionTriggerHandler.checkRelatedExams(
            new List<Course_Version__c>{
                [SELECT Id, Exam_Required__c FROM Course_Version__c WHERE Id = :cv.Id]
            }
        );
        Test.stopTest();
    }

    @IsTest
    static void testCheckRelatedExams_addError_when_all_related_exams_have_dates() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        DataFactory f = new DataFactory();

        Course_Version__c cv = new Course_Version__c(
            Course__c = f.course.Id,
            Exam_Required__c = false
        );
        insert cv;

        // Both exams have dates => errorExm.size == totalExm.size => addError should trigger
        insert new List<Exam__c>{
            f.makeExam(cv.Id, Date.today()),
            f.makeExam(cv.Id, Date.today().addDays(1))
        };

        Test.startTest();
        try {
            CourseVersionTriggerHandler.checkRelatedExams(
                new List<Course_Version__c>{
                    [SELECT Id, Exam_Required__c FROM Course_Version__c WHERE Id = :cv.Id]
                }
            );
        } catch (Exception e) {
            // no asserts requested
        }
        Test.stopTest();
    }

    @IsTest
    static void testCheckRelatedExams_examRequiredTrue_noProcessing() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        DataFactory f = new DataFactory();

        Course_Version__c cv = new Course_Version__c(
            Course__c = f.course.Id,
            Exam_Required__c = true
        );
        insert cv;

        Test.startTest();
        CourseVersionTriggerHandler.checkRelatedExams(new List<Course_Version__c>{ cv });
        Test.stopTest();
    }

    @IsTest
    static void testCheckRelatedExams_noExams() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        DataFactory f = new DataFactory();

        Course_Version__c cv = new Course_Version__c(
            Course__c = f.course.Id,
            Exam_Required__c = false
        );
        insert cv;

        Test.startTest();
        CourseVersionTriggerHandler.checkRelatedExams(new List<Course_Version__c>{ cv });
        Test.stopTest();
    }

    @IsTest
    static void testCheckRelatedExams_multipleVersions_only_false_is_processed() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        DataFactory f = new DataFactory();

        List<Course_Version__c> cvs = new List<Course_Version__c>{
            new Course_Version__c(Course__c = f.course.Id, Exam_Required__c = false),
            new Course_Version__c(Course__c = f.course.Id, Exam_Required__c = true)
        };
        insert cvs;

        // ✅ create exam only for the false one, with null date (so it goes to delete path)
        insert f.makeExam(cvs[0].Id, null);

        Test.startTest();
        CourseVersionTriggerHandler.checkRelatedExams(cvs);
        Test.stopTest();
    }

    @IsTest
    static void testCheckRelatedExams_emptyList() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        Test.startTest();
        CourseVersionTriggerHandler.checkRelatedExams(new List<Course_Version__c>());
        Test.stopTest();
    }
}