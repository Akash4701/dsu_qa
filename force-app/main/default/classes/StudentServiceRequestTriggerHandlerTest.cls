@IsTest
private with sharing class StudentServiceRequestTriggerHandlerTest {
    private class SetupIds {
        Id courseOfferingId;
        Id courseConnectionId;
        Id examId;
        Id studentId;
        Id requestApplicationId;
    }

    @TestSetup
    static void setupData() {
        Account dept = new Account(Name = 'SSR Trigger Dept');
        insert dept;

        hed__Term__c term = new hed__Term__c(
            Name = 'SSR Trigger Term',
            hed__Account__c = dept.Id,
            Term_Reference__c = 'Term 1',
            hed__Start_Date__c = Date.today().addDays(-10),
            hed__End_Date__c = Date.today().addDays(100)
        );
        insert term;

        Contact student = new Contact(LastName = 'SSR Trigger Student');
        insert student;

        hed__Course__c course = new hed__Course__c(
            Name = 'SSR Trigger Course',
            hed__Account__c = dept.Id,
            Credits__c = 4
        );
        insert course;

        hed__Course_Offering__c offering = new hed__Course_Offering__c(
            Name = 'SSR Trigger Offering',
            hed__Course__c = course.Id,
            hed__Term__c = term.Id
        );
        insert offering;

        hed__Course_Enrollment__c courseConnection = new hed__Course_Enrollment__c(
            hed__Contact__c = student.Id,
            hed__Course_Offering__c = offering.Id,
            Enrollment_Status__c = 'Enrolled',
            Exam_Eligibility__c = 'Eligible'
        );
        insert courseConnection;

        Exam_Cycle__c cycle = new Exam_Cycle__c(
            Name = 'SSR Trigger Cycle',
            Exam_Name__c = 'SEE',
            Start_Date__c = Date.today().addDays(-1),
            End_Date__c = Date.today().addDays(15)
        );
        insert cycle;

        insert new Exam_Cycle_Term_Connection__c(
            Term__c = term.Id,
            Exam_Cycle__c = cycle.Id
        );

        Course_Evaluation_Component__c comp = new Course_Evaluation_Component__c(
            Name = 'SSR Trigger Component',
            Course_Offering__c = offering.Id,
            Exam_Type__c = 'SEE',
            Maximum_Marks_for_the_Component__c = 100,
            Pass_Weightage__c = 40
        );
        insert comp;

        Exam__c exam = new Exam__c(
            Course_Evaluation_Component__c = comp.Id
        );
        insert exam;

        Fee_Type__c feeType = new Fee_Type__c(
            Amount__c = 500,
            Due_Date__c = Date.today().addDays(7),
            Program__c = dept.Id
        );
        insert feeType;

        insert new Student_Service_Request_Application__c(
            Exam_Cycle__c = cycle.Id,
            Fee_Type__c = feeType.Id
        );
    }

    @IsTest
    static void testAfterInsertCreatesRetestConnection() {
        SetupIds ids = getSetupIds();
        Id reExamRtId = getRecordTypeIdByDeveloperName('Re_Exam');
        String registeredStatus = getRegisteredStatusValue();

        Test.startTest();
        insert buildSsr(
            reExamRtId,
            registeredStatus,
            ids.courseOfferingId,
            ids.courseConnectionId,
            ids.requestApplicationId,
            ids.examId
        );
        Test.stopTest();

        List<Exam_Connections__c> created = queryRetestConnections(
            ids.examId,
            ids.courseConnectionId,
            ids.studentId
        );

        System.assertEquals(1, created.size(), 'Exactly one retest exam connection should be created.');
        System.assertEquals('Eligible', created[0].Eligibility__c);
        System.assertEquals('Retest', created[0].Exam_Type__c);
    }

    @IsTest
    static void testAfterInsertSkipsExistingAndBatchDuplicates() {
        SetupIds ids = getSetupIds();
        Id reExamRtId = getRecordTypeIdByDeveloperName('Re_Exam');
        String registeredStatus = getRegisteredStatusValue();

        insert new Exam_Connections__c(
            Eligibility__c = 'Eligible',
            Exam_Name__c = ids.examId,
            Course_Connection_ID__c = ids.courseConnectionId,
            Student_Name__c = ids.studentId,
            Exam_Type__c = 'Retest'
        );

        List<Student_Service_Request__c> toInsert = new List<Student_Service_Request__c>{
            buildSsr(
                reExamRtId,
                registeredStatus,
                ids.courseOfferingId,
                ids.courseConnectionId,
                ids.requestApplicationId,
                ids.examId
            ),
            buildSsr(
                reExamRtId,
                registeredStatus,
                ids.courseOfferingId,
                ids.courseConnectionId,
                ids.requestApplicationId,
                ids.examId
            )
        };

        Test.startTest();
        insert toInsert;
        Test.stopTest();

        Integer retestCount = queryRetestConnections(
            ids.examId,
            ids.courseConnectionId,
            ids.studentId
        ).size();
        System.assertEquals(
            1,
            retestCount,
            'Existing retest connection should prevent any duplicate insertions.'
        );
    }

    @IsTest
    static void testAfterUpdateCreatesOnceWhenStatusChanges() {
        SetupIds ids = getSetupIds();
        Id reExamRtId = getRecordTypeIdByDeveloperName('Re_Exam');
        String registeredStatus = getRegisteredStatusValue();

        Student_Service_Request__c ssr = buildSsr(
            reExamRtId,
            'Submitted',
            ids.courseOfferingId,
            ids.courseConnectionId,
            ids.requestApplicationId,
            ids.examId
        );
        insert ssr;

        ssr.Status__c = registeredStatus;
        Test.startTest();
        update ssr;
        Test.stopTest();

        Integer afterFirstUpdateCount = queryRetestConnections(
            ids.examId,
            ids.courseConnectionId,
            ids.studentId
        ).size();
        System.assertEquals(1, afterFirstUpdateCount, 'Status transition to Registered should create one connection.');

        update ssr;

        Integer afterSecondUpdateCount = queryRetestConnections(
            ids.examId,
            ids.courseConnectionId,
            ids.studentId
        ).size();
        System.assertEquals(
            1,
            afterSecondUpdateCount,
            'No additional connection should be created when status stays Registered.'
        );
    }

    @IsTest
    static void testNegativePathsNoQualifiedRequestsAndHandlerGuards() {
        StudentServiceRequestTriggerHandler.handleAfterInsert(null);
        StudentServiceRequestTriggerHandler.handleAfterInsert(new List<Student_Service_Request__c>());
        StudentServiceRequestTriggerHandler.handleAfterUpdate(
            new List<Student_Service_Request__c>(),
            new Map<Id, Student_Service_Request__c>()
        );

        SetupIds ids = getSetupIds();
        Id reExamRtId = getRecordTypeIdByDeveloperName('Re_Exam');
        Id nonReExamRtId = getAnyOtherRecordTypeId(reExamRtId);
        String registeredStatus = getRegisteredStatusValue();

        List<Student_Service_Request__c> negatives = new List<Student_Service_Request__c>{
            buildSsr(
                reExamRtId,
                'Submitted',
                ids.courseOfferingId,
                ids.courseConnectionId,
                ids.requestApplicationId,
                ids.examId
            )
        };

        if (nonReExamRtId != null) {
            negatives.add(
                buildSsr(
                    nonReExamRtId,
                    registeredStatus,
                    ids.courseOfferingId,
                    ids.courseConnectionId,
                    ids.requestApplicationId,
                    ids.examId
                )
            );
        }

        Test.startTest();
        insert negatives;
        Test.stopTest();

        Integer retestCount = queryRetestConnections(
            ids.examId,
            ids.courseConnectionId,
            ids.studentId
        ).size();
        System.assertEquals(0, retestCount, 'No retest connection should be created for non-qualified requests.');
    }

    private static SetupIds getSetupIds() {
        SetupIds ids = new SetupIds();

        hed__Course_Offering__c offering = [
            SELECT Id
            FROM hed__Course_Offering__c
            LIMIT 1
        ];
        ids.courseOfferingId = offering.Id;

        hed__Course_Enrollment__c courseConnection = [
            SELECT Id, hed__Contact__c
            FROM hed__Course_Enrollment__c
            LIMIT 1
        ];
        ids.courseConnectionId = courseConnection.Id;
        ids.studentId = courseConnection.hed__Contact__c;

        Exam__c exam = [
            SELECT Id
            FROM Exam__c
            LIMIT 1
        ];
        ids.examId = exam.Id;

        Student_Service_Request_Application__c requestApp = [
            SELECT Id
            FROM Student_Service_Request_Application__c
            LIMIT 1
        ];
        ids.requestApplicationId = requestApp.Id;

        return ids;
    }

    private static Student_Service_Request__c buildSsr(
        Id recordTypeId,
        String status,
        Id courseOfferingId,
        Id courseConnectionId,
        Id requestApplicationId,
        Id examId
    ) {
        return new Student_Service_Request__c(
            RecordTypeId = recordTypeId,
            Status__c = status,
            Course_Offering__c = courseOfferingId,
            Course_Connection__c = courseConnectionId,
            Student_Request_Application__c = requestApplicationId,
            Exam__c = examId
        );
    }

    private static Id getRecordTypeIdByDeveloperName(String developerName) {
        for (RecordType rt : [
            SELECT Id, DeveloperName
            FROM RecordType
            WHERE SObjectType = 'Student_Service_Request__c'
              AND DeveloperName = :developerName
            LIMIT 1
        ]) {
            return rt.Id;
        }
        System.assert(false, 'Missing required Student_Service_Request__c RecordType: ' + developerName);
        return null;
    }

    private static Id getAnyOtherRecordTypeId(Id excludedRecordTypeId) {
        for (RecordType rt : [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Student_Service_Request__c'
        ]) {
            if (rt.Id != excludedRecordTypeId) {
                return rt.Id;
            }
        }
        return null;
    }

    private static List<Exam_Connections__c> queryRetestConnections(
        Id examId,
        Id courseConnectionId,
        Id studentId
    ) {
        return [
            SELECT Id, Eligibility__c, Exam_Type__c, Exam_Name__c, Course_Connection_ID__c, Student_Name__c
            FROM Exam_Connections__c
            WHERE Eligibility__c = 'Eligible'
              AND Exam_Type__c = 'Retest'
              AND Exam_Name__c = :examId
              AND Course_Connection_ID__c = :courseConnectionId
              AND Student_Name__c = :studentId
        ];
    }

    private static String getRegisteredStatusValue() {
        // The "Fee Paid" value is labelled differently in the UI; match on the API value.
        List<Schema.PicklistEntry> values =
            Student_Service_Request__c.Status__c.getDescribe().getPicklistValues();
        for (Schema.PicklistEntry entry : values) {
            if (entry.getValue() == 'Fee Paid') {
                return entry.getValue();
            }
        }
        return 'Fee Paid';
    }
}