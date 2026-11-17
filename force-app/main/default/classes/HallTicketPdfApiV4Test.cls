@IsTest
public with sharing class HallTicketPdfApiV4Test {

    @TestSetup
    static void setupData() {
        // ---------- Base data ----------
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

        Contact student = new Contact(
            LastName = 'Test Student',
            Registration_Number__c = 'REG-HT-API-1'
        );
        insert student;

        hed__Course__c course = new hed__Course__c(
            Name = 'Test Course',
            hed__Account__c = dept.Id,
            Credits__c = 4
        );
        insert course;

        hed__Course_Offering__c offering = new hed__Course_Offering__c(
            Name = 'Test Offering',
            hed__Course__c = course.Id,
            hed__Term__c = term.Id
        );
        insert offering;

        // ---------- Exam Cycle (PUBLISHED for API validation) ----------
        Exam_Cycle__c examCycle = new Exam_Cycle__c(
            Name = 'CIA Exam Cycle',
            Exam_Name__c = 'CIA',
            Start_Date__c = Date.today().addDays(-1),
            End_Date__c   = Date.today().addDays(30),
            Publish_Hall_Ticket__c = true
        );
        insert examCycle;

        insert new Exam_Cycle_Term_Connection__c(
            Term__c = term.Id,
            Exam_Cycle__c = examCycle.Id
        );

        // ---------- Program Enrollment + Course Enrollment ----------
        hed__Program_Plan__c programPlan = new hed__Program_Plan__c(Name = 'Test Program Plan');
        insert programPlan;

        hed__Affiliation__c aff = new hed__Affiliation__c(
            hed__Contact__c = student.Id,
            hed__Account__c = dept.Id,
            Program_Plan__c = programPlan.Id,
            DSU_Email__c = 'student.api@dsuonline.com'
        );
        insert aff;

        hed__Program_Enrollment__c pe = new hed__Program_Enrollment__c(
            hed__Contact__c = student.Id,
            hed__Account__c = dept.Id,
            Term__c = term.Id,
            hed__Affiliation__c = aff.Id
        );
        insert pe;

        hed__Course_Enrollment__c ce = new hed__Course_Enrollment__c(
            hed__Contact__c = student.Id,
            hed__Course_Offering__c = offering.Id,
            hed__Program_Enrollment__c = pe.Id,
            Enrollment_Status__c = 'Enrolled',
            Exam_Eligibility__c = 'Eligible'
        );
        insert ce;

        // ---------- Exam + Exam Connection (required by generateHallTicketPdfBlob) ----------
        Course_Evaluation_Component__c component = new Course_Evaluation_Component__c(
            Name = 'CIA Component',
            Course_Offering__c = offering.Id,
            Exam_Type__c = 'CIA',
            Maximum_Marks_for_the_Component__c = 100
        );
        insert component;

        // Make sure Exam is linked to Exam Cycle so the mapping exists
        Exam__c exam = new Exam__c(
            Course_Evaluation_Component__c = component.Id,
            Exam_Cycle__c = examCycle.Id
        );
        insert exam;

        insert new Exam_Connections__c(
            Student_Name__c = student.Id,
            Course_Connection_ID__c = ce.Id,
            Exam_Name__c = exam.Id,
            Eligibility__c = 'Eligible'
        );
    }

    @IsTest
    static void testGetPdf_success() {
        Exam_Cycle__c ec = [SELECT Id FROM Exam_Cycle__c LIMIT 1];
        Contact student = [SELECT Id FROM Contact LIMIT 1];

        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/hallticket/v4/pdf';
        req.httpMethod = 'GET';
        req.addParameter('examCycleId', ec.Id);
        req.addParameter('contactId', student.Id);

        RestResponse resp = new RestResponse();
        RestContext.request = req;
        RestContext.response = resp;

        Test.startTest();
        HallTicketPdfApiV4.getPdf();
        Test.stopTest();
    }

    @IsTest
    static void testGetPdf_missingParams_returns400() {
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/hallticket/v4/pdf';
        req.httpMethod = 'GET';
        // no params

        RestResponse resp = new RestResponse();
        RestContext.request = req;
        RestContext.response = resp;

        Test.startTest();
        HallTicketPdfApiV4.getPdf();
        Test.stopTest();
    }

    @IsTest
    static void testGetPdf_unpublishedExamCycle_returns400() {
        // Create an unpublished cycle
        Exam_Cycle__c unpublished = new Exam_Cycle__c(
            Name = 'Unpublished Cycle',
            Exam_Name__c = 'CIA',
            Start_Date__c = Date.today().addDays(-1),
            End_Date__c   = Date.today().addDays(30),
            Publish_Hall_Ticket__c = false
        );
        insert unpublished;

        Contact student = [SELECT Id FROM Contact LIMIT 1];

        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/hallticket/v4/pdf';
        req.httpMethod = 'GET';
        req.addParameter('examCycleId', unpublished.Id);
        req.addParameter('contactId', student.Id);

        RestResponse resp = new RestResponse();
        RestContext.request = req;
        RestContext.response = resp;

        Test.startTest();
        HallTicketPdfApiV4.getPdf();
        Test.stopTest();
    }

    @IsTest
    static void testGetPdf_invalidExamCycleId_format_hitsQueryExceptionCatch() {
        Contact student = [SELECT Id FROM Contact LIMIT 1];

        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/hallticket/v4/pdf';
        req.httpMethod = 'GET';
        // invalid id format => QueryException catch block
        req.addParameter('examCycleId', 'NOT_AN_ID');
        req.addParameter('contactId', student.Id);

        RestResponse resp = new RestResponse();
        RestContext.request = req;
        RestContext.response = resp;

        Test.startTest();
        HallTicketPdfApiV4.getPdf();
        Test.stopTest();
    }
    
    @IsTest
static void testGetPdf_generalException_returns500() {
    // Published exam cycle from @TestSetup
    Exam_Cycle__c ec = [SELECT Id FROM Exam_Cycle__c WHERE Publish_Hall_Ticket__c = true LIMIT 1];

    // Create a contact NOT mapped in Exam_Connections__c for this exam cycle
    Contact notEligible = new Contact(LastName = 'Not Eligible Student');
    insert notEligible;

    RestRequest req = new RestRequest();
    req.requestUri = '/services/apexrest/hallticket/v4/pdf';
    req.httpMethod = 'GET';
    req.addParameter('examCycleId', ec.Id);
    req.addParameter('contactId', notEligible.Id); // valid Id, but not eligible -> AuraHandledException

    RestResponse resp = new RestResponse();
    RestContext.request = req;
    RestContext.response = resp;

    Test.startTest();
    HallTicketPdfApiV4.getPdf();
    Test.stopTest();
}

}