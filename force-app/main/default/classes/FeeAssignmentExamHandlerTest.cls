@IsTest
private with sharing class FeeAssignmentExamHandlerTest {
    private class SetupIds {
        Id contactId;
        Id affiliationId;
        Id feeTypeId;
        Id courseOfferingId;
        Id courseConnectionId;
        Id requestApplicationId;
        Id examId;
        Id ssrRecordTypeId;
    }

    @TestSetup
    static void setupData() {
        Account dept = new Account(Name = 'Fee Assignment Trigger Dept');
        insert dept;

        hed__Term__c term = new hed__Term__c(
            Name = 'Fee Assignment Trigger Term',
            hed__Account__c = dept.Id,
            Term_Reference__c = 'Term 1',
            hed__Start_Date__c = Date.today().addDays(-10),
            hed__End_Date__c = Date.today().addDays(100)
        );
        insert term;

        Contact student = new Contact(LastName = 'Fee Assignment Trigger Student');
        insert student;

        hed__Program_Plan__c plan = new hed__Program_Plan__c(
            Name = 'Fee Assignment Trigger Plan'
        );
        insert plan;

        hed__Affiliation__c affiliation = new hed__Affiliation__c(
            hed__Contact__c = student.Id,
            hed__Account__c = dept.Id,
            Program_Plan__c = plan.Id,
            Roll_Number__c = 'FA-TR-001'
        );
        insert affiliation;

        hed__Course__c course = new hed__Course__c(
            Name = 'Fee Assignment Trigger Course',
            hed__Account__c = dept.Id,
            Credits__c = 4
        );
        insert course;

        hed__Course_Offering__c offering = new hed__Course_Offering__c(
            Name = 'Fee Assignment Trigger Offering',
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
            Name = 'Fee Assignment Trigger Cycle',
            Exam_Name__c = 'SEE',
            Start_Date__c = Date.today().addDays(-1),
            End_Date__c = Date.today().addDays(10)
        );
        insert cycle;

        insert new Exam_Cycle_Term_Connection__c(
            Term__c = term.Id,
            Exam_Cycle__c = cycle.Id
        );

        Course_Evaluation_Component__c component = new Course_Evaluation_Component__c(
            Name = 'Fee Assignment Trigger Component',
            Course_Offering__c = offering.Id,
            Exam_Type__c = 'SEE',
            Maximum_Marks_for_the_Component__c = 100,
            Pass_Weightage__c = 40
        );
        insert component;

        Exam__c exam = new Exam__c(
            Course_Evaluation_Component__c = component.Id
        );
        insert exam;

        Fee_Type__c feeType = new Fee_Type__c(
            Amount__c = 500,
            Due_Date__c = Date.today().addDays(7),
            Program__c = dept.Id
        );
        insert feeType;

        Student_Service_Request_Application__c requestApplication = new Student_Service_Request_Application__c(
            Exam_Cycle__c = cycle.Id,
            Fee_Type__c = feeType.Id
        );
        insert requestApplication;
    }

    @IsTest
    static void testAfterUpdateBulkTransitionsToFeePaid() {
        SetupIds ids = getSetupIds();
        String feePaidStatus = getStatusValueByLabelOrValue('Fee Paid');
        String initialStatus = getAnyStatusExcept(feePaidStatus);
        System.assertNotEquals(
            feePaidStatus,
            initialStatus,
            'Student_Service_Request__c must have at least one status other than Fee Paid.'
        );

        Integer bulkCount = 320;
        List<Fee_Assignment__c> feeAssignments = new List<Fee_Assignment__c>();
        for (Integer i = 0; i < bulkCount; i++) {
            Decimal paidAmount = (i == 0) ? 500 : 0;
            feeAssignments.add(buildFeeAssignment(ids, 500, paidAmount));
        }
        insert feeAssignments;

        List<Student_Service_Request__c> requests = new List<Student_Service_Request__c>();
        for (Integer i = 0; i < feeAssignments.size(); i++) {
            String statusValue = (i == 0) ? feePaidStatus : initialStatus;
            requests.add(buildStudentServiceRequest(ids, feeAssignments[i].Id, statusValue));
        }
        insert requests;

        Set<Id> requestIds = new Set<Id>();
        for (Student_Service_Request__c requestRec : requests) {
            requestIds.add(requestRec.Id);
        }

        for (Integer i = 0; i < feeAssignments.size(); i++) {
            if (i == 1) {
                feeAssignments[i].Paid_Amount__c = 250;
            } else {
                feeAssignments[i].Paid_Amount__c = 500;
            }
        }

        Test.startTest();
        update feeAssignments;
        Test.stopTest();

        Integer feePaidCount = [
            SELECT COUNT()
            FROM Student_Service_Request__c
            WHERE Id IN :requestIds
              AND Status__c = :feePaidStatus
        ];
        Integer nonFeePaidCount = [
            SELECT COUNT()
            FROM Student_Service_Request__c
            WHERE Id IN :requestIds
              AND Status__c != :feePaidStatus
        ];

        System.assertEquals(319, feePaidCount, 'Only fully paid Fee_Assignment__c records should set status to Fee Paid.');
        System.assertEquals(1, nonFeePaidCount, 'One request should remain non Fee Paid for non-fully-paid assignment.');
    }

    @IsTest
    static void testAfterInsertHandlerUpdatesRequestStatus() {
        SetupIds ids = getSetupIds();
        String feePaidStatus = getStatusValueByLabelOrValue('Fee Paid');
        String initialStatus = getAnyStatusExcept(feePaidStatus);
        System.assertNotEquals(
            feePaidStatus,
            initialStatus,
            'Student_Service_Request__c must have at least one status other than Fee Paid.'
        );

        Fee_Assignment__c feeAssignment = buildFeeAssignment(ids, 300, 300);
        insert feeAssignment;

        Student_Service_Request__c requestRec = buildStudentServiceRequest(
            ids,
            feeAssignment.Id,
            initialStatus
        );
        insert requestRec;

        Fee_Assignment__c insertedFeeAssignment = [
            SELECT Id, Paid_Amount__c, Total_Amount_Payable__c
            FROM Fee_Assignment__c
            WHERE Id = :feeAssignment.Id
            LIMIT 1
        ];

        Test.startTest();
        FeeAssignmentExamHandler.handleAfterInsert(new List<Fee_Assignment__c>{ insertedFeeAssignment });
        Test.stopTest();

        Student_Service_Request__c updatedRequest = [
            SELECT Id, Status__c
            FROM Student_Service_Request__c
            WHERE Id = :requestRec.Id
            LIMIT 1
        ];
        System.assertEquals(
            feePaidStatus,
            updatedRequest.Status__c,
            'Handler insert path should set Student Service Request status to Fee Paid.'
        );
    }

    @IsTest
    static void testHandlerGuardsAndTransitionChecks() {
        FeeAssignmentExamHandler.handleAfterInsert(null);
        FeeAssignmentExamHandler.handleAfterInsert(new List<Fee_Assignment__c>());
        FeeAssignmentExamHandler.handleAfterUpdate(
            new List<Fee_Assignment__c>(),
            new Map<Id, Fee_Assignment__c>()
        );

        System.assertEquals(false, FeeAssignmentExamHandler.isFullyPaid(null));
        System.assertEquals(
            false,
            FeeAssignmentExamHandler.isFullyPaid(
                new Fee_Assignment__c(Paid_Amount__c = 10, Total_Amount_Payable__c = 20)
            )
        );
        System.assertEquals(
            true,
            FeeAssignmentExamHandler.isFullyPaid(
                new Fee_Assignment__c(Paid_Amount__c = 20, Total_Amount_Payable__c = 20)
            )
        );
    }

    @IsTest
    static void testAfterUpdateDoesNotReprocessAlreadyFullyPaidRecord() {
        SetupIds ids = getSetupIds();
        String feePaidStatus = getStatusValueByLabelOrValue('Fee Paid');
        String initialStatus = getAnyStatusExcept(feePaidStatus);
        System.assertNotEquals(
            feePaidStatus,
            initialStatus,
            'Student_Service_Request__c must have at least one status other than Fee Paid.'
        );

        Fee_Assignment__c feeAssignment = buildFeeAssignment(ids, 400, 100);
        insert feeAssignment;

        Student_Service_Request__c requestRec = buildStudentServiceRequest(ids, feeAssignment.Id, initialStatus);
        insert requestRec;

        feeAssignment.Paid_Amount__c = 400;
        update feeAssignment;

        requestRec.Status__c = initialStatus;
        update requestRec;

        feeAssignment.Remaining_Amount__c = 0;
        Test.startTest();
        update feeAssignment;
        Test.stopTest();

        Student_Service_Request__c afterSecondUpdate = [
            SELECT Id, Status__c
            FROM Student_Service_Request__c
            WHERE Id = :requestRec.Id
            LIMIT 1
        ];

        System.assertEquals(
            initialStatus,
            afterSecondUpdate.Status__c,
            'Already fully-paid fee assignment should not be reprocessed on later updates.'
        );
    }

    private static SetupIds getSetupIds() {
        SetupIds ids = new SetupIds();

        Contact student = [
            SELECT Id
            FROM Contact
            WHERE LastName = 'Fee Assignment Trigger Student'
            LIMIT 1
        ];
        ids.contactId = student.Id;

        hed__Affiliation__c affiliation = [
            SELECT Id
            FROM hed__Affiliation__c
            WHERE hed__Contact__c = :ids.contactId
            LIMIT 1
        ];
        ids.affiliationId = affiliation.Id;

        Fee_Type__c feeType = [
            SELECT Id
            FROM Fee_Type__c
            LIMIT 1
        ];
        ids.feeTypeId = feeType.Id;

        hed__Course_Offering__c offering = [
            SELECT Id
            FROM hed__Course_Offering__c
            LIMIT 1
        ];
        ids.courseOfferingId = offering.Id;

        hed__Course_Enrollment__c courseConnection = [
            SELECT Id
            FROM hed__Course_Enrollment__c
            LIMIT 1
        ];
        ids.courseConnectionId = courseConnection.Id;

        Student_Service_Request_Application__c requestApplication = [
            SELECT Id
            FROM Student_Service_Request_Application__c
            LIMIT 1
        ];
        ids.requestApplicationId = requestApplication.Id;

        Exam__c exam = [
            SELECT Id
            FROM Exam__c
            LIMIT 1
        ];
        ids.examId = exam.Id;

        ids.ssrRecordTypeId = getPreferredSsrRecordTypeId();
        return ids;
    }

    private static Fee_Assignment__c buildFeeAssignment(
        SetupIds ids,
        Decimal totalAmount,
        Decimal paidAmount
    ) {
        Decimal remainingAmount = totalAmount - (paidAmount == null ? 0 : paidAmount);
        if (remainingAmount < 0) {
            remainingAmount = 0;
        }

        return new Fee_Assignment__c(
            Fee_Type__c = ids.feeTypeId,
            Contact__c = ids.contactId,
            Affiliation__c = ids.affiliationId,
            Total_Amount_Payable__c = totalAmount,
            Paid_Amount__c = paidAmount,
            Remaining_Amount__c = remainingAmount,
            Fee_Preference__c = 'Semester-wise fee',
            Fee_Head__c = 'Backlog examination Fee',
            Is_Active__c = true
        );
    }

    private static Student_Service_Request__c buildStudentServiceRequest(
        SetupIds ids,
        Id feeAssignmentId,
        String statusValue
    ) {
        Student_Service_Request__c requestRec = new Student_Service_Request__c(
            Status__c = statusValue,
            Course_Offering__c = ids.courseOfferingId,
            Course_Connection__c = ids.courseConnectionId,
            Student_Request_Application__c = ids.requestApplicationId,
            Exam__c = ids.examId,
            Fee_Assignment__c = feeAssignmentId
        );

        if (ids.ssrRecordTypeId != null) {
            requestRec.RecordTypeId = ids.ssrRecordTypeId;
        }

        return requestRec;
    }

    private static Id getPreferredSsrRecordTypeId() {
        List<RecordType> recordTypes = [
            SELECT Id, DeveloperName
            FROM RecordType
            WHERE SObjectType = 'Student_Service_Request__c'
        ];

        for (RecordType rt : recordTypes) {
            if (rt.DeveloperName != 'Re_Exam') {
                return rt.Id;
            }
        }

        return recordTypes.isEmpty() ? null : recordTypes[0].Id;
    }

    private static String getStatusValueByLabelOrValue(String valueOrLabel) {
        List<Schema.PicklistEntry> picklistValues =
            Student_Service_Request__c.Status__c.getDescribe().getPicklistValues();
        for (Schema.PicklistEntry entry : picklistValues) {
            if (entry.getLabel() == valueOrLabel || entry.getValue() == valueOrLabel) {
                return entry.getValue();
            }
        }
        return valueOrLabel;
    }

    private static String getAnyStatusExcept(String excludedValue) {
        List<Schema.PicklistEntry> picklistValues =
            Student_Service_Request__c.Status__c.getDescribe().getPicklistValues();
        for (Schema.PicklistEntry entry : picklistValues) {
            if (entry.getValue() != excludedValue) {
                return entry.getValue();
            }
        }
        return excludedValue;
    }
}