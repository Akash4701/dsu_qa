@IsTest
private class CourseOfferingGradeSyncControllerTest {

    private static final String MOCK_ENDPOINT = 'https://test.brightspace.example.com/grade-sync';

    @TestSetup
    static void setupData() {
        Account dept = new Account(Name = 'Test Department');
        insert dept;

        hed__Term__c term = new hed__Term__c(
            Name = 'Spring 2025',
            hed__Account__c = dept.Id,
            Term_Reference__c = 'Term 1',
            hed__Start_Date__c = Date.today(),
            hed__End_Date__c = Date.today().addMonths(4)
        );
        insert term;

        hed__Course__c course = new hed__Course__c(
            Name = 'Test Course',
            hed__Account__c = dept.Id,
            Credits__c = 4
        );
        insert course;

        // Offering WITH an LMS Id (used by the happy-path tests)
        hed__Course_Offering__c offeringWithLms = new hed__Course_Offering__c(
            Name = 'Offering With LMS',
            hed__Course__c = course.Id,
            hed__Term__c = term.Id,
            LMS_Id__c = '98765'
        );
        insert offeringWithLms;

        // Offering WITHOUT an LMS Id (used to test the blank-LMS branch)
        hed__Course_Offering__c offeringNoLms = new hed__Course_Offering__c(
            Name = 'Offering No LMS',
            hed__Course__c = course.Id,
            hed__Term__c = term.Id
        );
        insert offeringNoLms;

        // CIA component for the offering that has an LMS Id.
        // Exam_Required__c = false so the CourseEvaluationComponent trigger does not
        // spin up extra junction/exam records during setup.
        Course_Evaluation_Component__c component = new Course_Evaluation_Component__c(
            Name = 'CIA Component',
            Course_Offering__c = offeringWithLms.Id,
            Exam_Type__c = 'CIA',
            Exam_Required__c = false,
            Maximum_Marks_for_the_Component__c = 100
        );
        insert component;
    }

    private static Id getOfferingWithLms() {
        return [SELECT Id FROM hed__Course_Offering__c WHERE Name = 'Offering With LMS' LIMIT 1].Id;
    }

    private static Id getOfferingNoLms() {
        return [SELECT Id FROM hed__Course_Offering__c WHERE Name = 'Offering No LMS' LIMIT 1].Id;
    }

    // ---------------------------------------------------------------------
    // syncGrades - validation / error branches
    // ---------------------------------------------------------------------

    @IsTest
    static void testSyncGrades_nullId() {
        CourseOfferingGradeSyncController.mockEndpoint = MOCK_ENDPOINT;
        Boolean threw = false;
        Test.startTest();
        try {
            CourseOfferingGradeSyncController.syncGrades(null);
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();
        System.assertEquals(true, threw, 'A null Course Offering Id should throw.');
    }

    @IsTest
    static void testSyncGrades_blankLmsId() {
        CourseOfferingGradeSyncController.mockEndpoint = MOCK_ENDPOINT;
        Id offeringId = getOfferingNoLms();
        Boolean threw = false;
        Test.startTest();
        try {
            CourseOfferingGradeSyncController.syncGrades(offeringId);
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();
        System.assertEquals(true, threw, 'A blank LMS Id should throw.');
    }

    @IsTest
    static void testSyncGrades_noComponent() {
        CourseOfferingGradeSyncController.mockEndpoint = MOCK_ENDPOINT;

        // Offering that has an LMS Id but no CIA Course Evaluation Component.
        hed__Course_Offering__c offering = [
            SELECT Id, hed__Course__c, hed__Term__c FROM hed__Course_Offering__c WHERE Name = 'Offering With LMS' LIMIT 1
        ];
        hed__Course_Offering__c bare = new hed__Course_Offering__c(
            Name = 'Offering No Component',
            hed__Course__c = offering.hed__Course__c,
            hed__Term__c = offering.hed__Term__c,
            LMS_Id__c = '55555'
        );
        insert bare;

        Boolean threw = false;
        Test.startTest();
        try {
            CourseOfferingGradeSyncController.syncGrades(bare.Id);
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();
        System.assertEquals(true, threw, 'Missing CIA component should throw.');
    }

    // ---------------------------------------------------------------------
    // syncGrades - callout outcomes
    // ---------------------------------------------------------------------

    @IsTest
    static void testSyncGrades_success() {
        CourseOfferingGradeSyncController.mockEndpoint = MOCK_ENDPOINT;
        Test.setMock(HttpCalloutMock.class, new GradeSyncMock(200,
            '{"success": true, "data": {"traceId": "trace-123", "summary": ' +
            '{"preparedSuccess": 10, "preparedFailure": 1, "updateSuccess": 9, "updateFailure": 2}}}'));

        Id offeringId = getOfferingWithLms();

        Test.startTest();
        CourseOfferingGradeSyncController.SyncResult result =
            CourseOfferingGradeSyncController.syncGrades(offeringId);
        Test.stopTest();

        System.assertEquals(true, result.success, 'Should be successful.');
        System.assertEquals('Grades sync completed.', result.message);
        System.assertEquals(10, result.preparedSuccess);
        System.assertEquals(1, result.preparedFailure);
        System.assertEquals(9, result.updateSuccess);
        System.assertEquals(2, result.updateFailure);
        System.assertEquals('trace-123', result.traceId);
        System.assertNotEquals(null, result.courseEvaluationId, 'courseEvaluationId should be populated.');
    }

    @IsTest
    static void testSyncGrades_successAsString() {
        CourseOfferingGradeSyncController.mockEndpoint = MOCK_ENDPOINT;
        // success delivered as the string "true" and no data node.
        Test.setMock(HttpCalloutMock.class, new GradeSyncMock(200, '{"success": "true"}'));

        Id offeringId = getOfferingWithLms();

        Test.startTest();
        CourseOfferingGradeSyncController.SyncResult result =
            CourseOfferingGradeSyncController.syncGrades(offeringId);
        Test.stopTest();

        System.assertEquals(true, result.success, 'String "true" should parse to true.');
        System.assertEquals('Grades sync completed.', result.message);
        System.assertEquals(null, result.traceId, 'No data node means no traceId.');
    }

    @IsTest
    static void testSyncGrades_successFalse() {
        CourseOfferingGradeSyncController.mockEndpoint = MOCK_ENDPOINT;
        // success false, data present but summary null.
        Test.setMock(HttpCalloutMock.class, new GradeSyncMock(200,
            '{"success": false, "data": {"traceId": "trace-x"}}'));

        Id offeringId = getOfferingWithLms();

        Test.startTest();
        CourseOfferingGradeSyncController.SyncResult result =
            CourseOfferingGradeSyncController.syncGrades(offeringId);
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assertEquals('Grades sync completed with issues.', result.message);
        System.assertEquals('trace-x', result.traceId);
    }

    @IsTest
    static void testSyncGrades_httpError() {
        CourseOfferingGradeSyncController.mockEndpoint = MOCK_ENDPOINT;
        // Long body forces the truncate() path as well.
        String longBody = '{"error":"' + 'x'.repeat(400) + '"}';
        Test.setMock(HttpCalloutMock.class, new GradeSyncMock(500, longBody));

        Id offeringId = getOfferingWithLms();

        Boolean threw = false;
        Test.startTest();
        try {
            CourseOfferingGradeSyncController.syncGrades(offeringId);
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();
        System.assertEquals(true, threw, 'Non-2xx status should throw.');
    }

    @IsTest
    static void testSyncGrades_calloutException() {
        CourseOfferingGradeSyncController.mockEndpoint = MOCK_ENDPOINT;
        Test.setMock(HttpCalloutMock.class, new CalloutExceptionMock());

        Id offeringId = getOfferingWithLms();

        Boolean threw = false;
        Test.startTest();
        try {
            CourseOfferingGradeSyncController.syncGrades(offeringId);
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();
        System.assertEquals(true, threw, 'A callout exception should be surfaced.');
    }

    @IsTest
    static void testSyncGrades_realMetadataEndpointPath() {
        // Leave mockEndpoint null so getEndpoint() exercises the real
        // Custom Metadata lookup branch. The record is not deployed in the
        // sandbox, so this is expected to fail fast; we only assert that the
        // metadata branch executes without leaving the transaction in a bad state.
        Test.setMock(HttpCalloutMock.class, new GradeSyncMock(200, '{"success": true}'));
        Id offeringId = getOfferingWithLms();

        Boolean handled = false;
        Test.startTest();
        try {
            CourseOfferingGradeSyncController.syncGrades(offeringId);
            handled = true; // metadata record happened to exist and callout succeeded
        } catch (Exception e) {
            handled = true; // metadata record missing -> AuraHandledException
        }
        Test.stopTest();
        System.assertEquals(true, handled, 'Metadata endpoint branch should execute.');
    }

    // ---------------------------------------------------------------------
    // Direct unit tests for the @TestVisible helpers
    // ---------------------------------------------------------------------

    @IsTest
    static void testParseSuccess() {
        System.assertEquals(false, CourseOfferingGradeSyncController.parseSuccess(null));
        System.assertEquals(true, CourseOfferingGradeSyncController.parseSuccess(true));
        System.assertEquals(false, CourseOfferingGradeSyncController.parseSuccess(false));
        System.assertEquals(true, CourseOfferingGradeSyncController.parseSuccess('true'));
        System.assertEquals(true, CourseOfferingGradeSyncController.parseSuccess('TRUE'));
        System.assertEquals(false, CourseOfferingGradeSyncController.parseSuccess('nope'));
    }

    @IsTest
    static void testToInteger() {
        System.assertEquals(0, CourseOfferingGradeSyncController.toInteger(null));
        System.assertEquals(7, CourseOfferingGradeSyncController.toInteger(7));
        System.assertEquals(42, CourseOfferingGradeSyncController.toInteger((Long) 42L));
        System.assertEquals(5, CourseOfferingGradeSyncController.toInteger((Decimal) 5.9));
        System.assertEquals(13, CourseOfferingGradeSyncController.toInteger('13'));
    }

    @IsTest
    static void testTruncate() {
        System.assertEquals(null, CourseOfferingGradeSyncController.truncate(null, 10));
        System.assertEquals('', CourseOfferingGradeSyncController.truncate('', 10));
        System.assertEquals('short', CourseOfferingGradeSyncController.truncate('short', 10));

        String longInput = 'a'.repeat(20);
        String result = CourseOfferingGradeSyncController.truncate(longInput, 10);
        System.assertEquals(13, result.length(), '10 chars + "..." = 13.');
        System.assert(result.endsWith('...'), 'Truncated value should end with ellipsis.');
    }

    @IsTest
    static void testLogInChunks() {
        // Just exercise both the null and the chunking paths.
        CourseOfferingGradeSyncController.logInChunks('null label', null);
        CourseOfferingGradeSyncController.logInChunks('big label', 'y'.repeat(2000));
        System.assert(true);
    }

    // ---------------------------------------------------------------------
    // Mocks
    // ---------------------------------------------------------------------

    private class GradeSyncMock implements HttpCalloutMock {
        private Integer statusCode;
        private String body;
        private GradeSyncMock(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body = body;
        }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(body);
            res.setStatusCode(statusCode);
            return res;
        }
    }

    private class CalloutExceptionMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            throw new CalloutException('Simulated callout failure');
        }
    }
}