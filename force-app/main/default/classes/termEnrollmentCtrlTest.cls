@isTest
private class termEnrollmentCtrlTest {

    @testSetup
    static void setupTestData() {
        Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());
        Test.setMock(HttpCalloutMock.class, new FailureHttpMock());
        // Create Account (Institution)
        Account acc = new Account(Name = 'Test Institution',LMS_Id__c='12345');
        insert acc;
		LMS_URL__c lmsUrl = new LMS_URL__c(Name = 'course url', Bulk_Enroll__c = 'https://dummyendpoint.com');
         LMS_URL__c URL1 = new LMS_URL__c(Name = 'course offering url',Bulk_Enroll__c = 'TestUrl');
        insert URL1;
        LMS_URL__c URL2 = new LMS_URL__c(Name = 'Bulk Enrollment',Bulk_Enroll__c = 'TestUrl');
        insert URL2;
    insert lmsUrl;
        // Create Contact (Student)
        Contact con = new Contact(
            FirstName = 'Test',
            LastName = 'Student',
            Email = 'student@example.com',
            Phone = '1234567890',
            Registration_Number__c = 'REG001',
            RecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByName().get('Student').getRecordTypeId()
        );
        insert con;

        // Create Term (Previous and Next)
        hed__Term__c prevTerm = new hed__Term__c(
            Name = 'Previous Term', 
            hed__Start_Date__c = Date.today().addMonths(-6), 
            hed__End_Date__c = Date.today().addMonths(-3),
            Term_Reference__c='Semester 1',
			hed__Account__c=acc.Id
			
            
            
        );
        hed__Term__c nextTerm = new hed__Term__c(
            Name = 'Next Term', 
            hed__Start_Date__c = Date.today().addDays(1), 
            hed__End_Date__c = Date.today().addMonths(3),
             Term_Reference__c='Semester 2',
			hed__Account__c=acc.Id
        );
        insert new List<hed__Term__c>{prevTerm, nextTerm};

        // Create Program Plan
        hed__Program_Plan__c programPlan = new hed__Program_Plan__c(Name = 'Test Program Plan');
        insert programPlan;

        // Create Affiliation
        hed__Affiliation__c aff = new hed__Affiliation__c(
            hed__Contact__c = con.Id,
            hed__Account__c = acc.Id,
            hed__Status__c = 'Current'
        );
        insert aff;

        // Create Program Enrollment (Previous)
        hed__Program_Enrollment__c pe = new hed__Program_Enrollment__c(
            hed__Contact__c = con.Id,
            Term__c = prevTerm.Id,
           // hed__Program_Plan__c = programPlan.Id,
            hed__Account__c = acc.Id,
            RecordTypeId = Schema.SObjectType.hed__Program_Enrollment__c.getRecordTypeInfosByName().get('Student').getRecordTypeId(),
           // Affiliation_Status__c = 'Current',
            hed__Affiliation__c = aff.Id,
            Is_Active__c = true
        );
        insert pe;

        // Create Course
        hed__Course__c course = new hed__Course__c(Name = 'Test Course',hed__Account__c=acc.Id, LMS_ID__c = '54321');
        insert course;

        // Create Course Offering
        hed__Course_Offering__c co = new hed__Course_Offering__c(
            Name = 'Test Offering',
            hed__Course__c = course.Id,
            hed__Section_ID__c = 'SEC-A',
            hed__Term__c = nextTerm.Id
        );
        insert co;

        // Create Course Enrollment
        hed__Course_Enrollment__c ce = new hed__Course_Enrollment__c(
            hed__Contact__c = con.Id,
            hed__Course_Offering__c = co.Id,
            hed__Program_Enrollment__c = pe.Id,
            RecordTypeId = Schema.SObjectType.hed__Course_Enrollment__c.getRecordTypeInfosByName().get('Student').getRecordTypeId()
        );
        insert ce;

        // Create Plan Requirement
        hed__Plan_Requirement__c pr = new hed__Plan_Requirement__c(
            hed__Course__c = course.Id,
            hed__Category__c = 'Mandatory',
            hed__Program_Plan__c = programPlan.Id
            //hed__Term__c = nextTerm.Id
        );
        insert pr;
    }

      @isTest
    static void testUpdateExistingProgramEnrollment() {
        // Fetch test data
        Contact con = [SELECT Id FROM Contact WHERE FirstName = 'Test' LIMIT 1];
        hed__Term__c prevTerm = [SELECT Id FROM hed__Term__c WHERE Name = 'Previous Term' LIMIT 1];
        hed__Term__c nextTerm = [SELECT Id FROM hed__Term__c WHERE Name = 'Next Term' LIMIT 1];
        hed__Program_Enrollment__c prevPE = [SELECT Id, hed__Program_Plan__c, Program_Campus_Combination__c, hed__Account__c, 
                                             hed__Affiliation__c, RecordTypeId FROM hed__Program_Enrollment__c 
                                             WHERE hed__Contact__c = :con.Id AND Term__c = :prevTerm.Id LIMIT 1];
        hed__Course_Offering__c courseOffering = [SELECT Id FROM hed__Course_Offering__c WHERE Name = 'Test Offering' LIMIT 1];

        // Pre-create a Program Enrollment for the "nextTerm" to simulate an update
        hed__Program_Enrollment__c existingPE = new hed__Program_Enrollment__c(
            hed__Contact__c = con.Id,
            Term__c = nextTerm.Id,
            hed__Program_Plan__c = prevPE.hed__Program_Plan__c,
            Program_Campus_Combination__c = prevPE.Program_Campus_Combination__c,
            hed__Account__c = prevPE.hed__Account__c,
            hed__Affiliation__c = prevPE.hed__Affiliation__c,
            RecordTypeId = prevPE.RecordTypeId,
            Is_Active__c = false,
            hed__Enrollment_Status__c = 'Withdrawn'
        );
        insert existingPE;

        // Call the method under test
        Test.startTest();
        termEnrollmentCtrl.createProgramEnrollments(
            new List<String>{con.Id},
            nextTerm.Id,
            null, // no specialization
            new List<String>{courseOffering.Id},
            prevTerm.Id
        );
        Test.stopTest();

    }
    
    @isTest
    static void testFetchRecords() {
        // Get IDs
        Contact con = [SELECT Id FROM Contact WHERE Email = 'student@example.com' LIMIT 1];
        hed__Program_Plan__c programPlan = [SELECT Id FROM hed__Program_Plan__c LIMIT 1];
        hed__Term__c nextTerm = [SELECT Id FROM hed__Term__c WHERE Name = 'Next Term' LIMIT 1];

        Test.startTest();
        termEnrollmentCtrl.ApplicationWrapper result = termEnrollmentCtrl.fetchRecords(
            programPlan.Id,
            nextTerm.Id,
            'SEC-A',
            null,
            nextTerm.Id
        );
        Test.stopTest();

       
    }

    @isTest
static void testCreateProgramEnrollments_InsertNewCourseEnrollment() {
    // Get test data
    Contact student = [SELECT Id FROM Contact WHERE FirstName = 'Test' LIMIT 1];
    hed__Term__c nextTerm = [SELECT Id FROM hed__Term__c WHERE Name = 'Next Term' LIMIT 1];
    hed__Term__c prevTerm = [SELECT Id FROM hed__Term__c WHERE Name = 'Previous Term' LIMIT 1];
    hed__Program_Enrollment__c prevPE = [SELECT Id, hed__Contact__c FROM hed__Program_Enrollment__c WHERE Term__c = :prevTerm.Id LIMIT 1];
    hed__Course_Offering__c co = [SELECT Id FROM hed__Course_Offering__c WHERE Name = 'Test Offering' LIMIT 1];

    // Delete existing course enrollment so that the method creates a new one
    List<hed__Course_Enrollment__c> existingEnrollments = [
        SELECT Id FROM hed__Course_Enrollment__c 
        WHERE hed__Contact__c = :student.Id AND hed__Course_Offering__c = :co.Id
    ];
    if (!existingEnrollments.isEmpty()) {
        delete existingEnrollments;
    }

    // Run the method - this should trigger the "else" block and insert new course enrollment
    Test.startTest();
    termEnrollmentCtrl.createProgramEnrollments(
        new List<String>{student.Id},
        nextTerm.Id,
        null, // no specialization
        new List<String>{co.Id},
        prevTerm.Id
    );
    Test.stopTest();

}
    /*@isTest
static void testFetchRecords_StudentDetailsPopulated() {
    Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());
        Test.setMock(HttpCalloutMock.class, new FailureHttpMock());
    // Create required records
    RecordType studentRT = [SELECT Id FROM RecordType WHERE SObjectType = 'hed__Program_Enrollment__c' AND Name = 'Student' LIMIT 1];
    RecordType courseEnrollRT = [SELECT Id FROM RecordType WHERE SObjectType = 'hed__Course_Enrollment__c' AND Name = 'Student' LIMIT 1];

    Account acc = new Account(Name = 'Test Account');
    insert acc;

    Contact student = new Contact(
        FirstName = 'John',
        LastName = 'Doe',
        Email = 'john.doe@example.com',
        Phone = '1234567890',
        Registration_Number__c = 'REG123',
        AccountId = acc.Id
    );
    insert student;

    // Term setup
    hed__Term__c prevTerm = new hed__Term__c(Name = 'Current Term',  
                                             Term_Reference__c='Semester 1',
												hed__Account__c=acc.Id);
    hed__Term__c nextTerm = new hed__Term__c(Name = 'Next Term',
                                               Term_Reference__c='Semester 2',
												hed__Account__c=acc.Id);
    insert new List<hed__Term__c>{ prevTerm, nextTerm };

    // Program Plan
    hed__Program_Plan__c programPlan = new hed__Program_Plan__c(Name = 'B.Sc Computer Science');
    insert programPlan;

    // Course
    hed__Course__c course = new hed__Course__c(Name = 'Math',hed__Account__c=acc.Id);
    insert course;

    // Course Offering (with Section ID)
    hed__Course_Offering__c offering = new hed__Course_Offering__c(
        Name = 'Math - Section A',
        hed__Course__c = course.Id,
        hed__Term__c = prevTerm.Id,
        hed__Section_ID__c = 'Section-A'
    );
    insert offering;

    // Course Enrollment
    hed__Course_Enrollment__c enrollment = new hed__Course_Enrollment__c(
        RecordTypeId = courseEnrollRT.Id,
        hed__Contact__c = student.Id,
        hed__Course_Offering__c = offering.Id
    );
    insert enrollment;

    // Program Enrollment
    hed__Program_Enrollment__c pe = new hed__Program_Enrollment__c(
        RecordTypeId = studentRT.Id,
        hed__Contact__c = student.Id,
        hed__Program_Plan__c = programPlan.Id,
        Term__c = prevTerm.Id,
        Is_Active__c = true
      //  Affiliation_Status__c = 'Current'
    );
    insert pe;

    // Plan Requirement
    hed__Plan_Requirement__c planReq = new hed__Plan_Requirement__c(
        hed__Course__c = course.Id,
        hed__Program_Plan__c = programPlan.Id,
        hed__Category__c = 'Mandatory'
    );
    insert planReq;

    // Course Offering for Next Term
    hed__Course_Offering__c nextTermOffering = new hed__Course_Offering__c(
        Name = 'Math - Next Term',
        hed__Course__c = course.Id,
        hed__Term__c = nextTerm.Id,
        hed__Section_ID__c = 'Section-A'
    );
    insert nextTermOffering;

    // Call the method
    Test.startTest();
    termEnrollmentCtrl.ApplicationWrapper result = termEnrollmentCtrl.fetchRecords(
        programPlan.Id,
        prevTerm.Id,
        'Section-A',
        null,
        nextTerm.Id
    );
    Test.stopTest();

  
}*/

     @isTest
    static void testStudentDetailProperties() {
        // Create an instance of StudentDetail
        termEnrollmentCtrl.StudentDetail detail = new termEnrollmentCtrl.StudentDetail();

        // Set values
        detail.studentName = 'Jane Doe';
        detail.studentEmail = 'jane.doe@example.com';
        detail.registrationNumber = 'REG456';
        detail.studentPhone = '9876543210';
        detail.applicationRecordId = '003XXXXXXXXXXXX';

      
    }
    
    @isTest
    static void testCreateProgramEnrollments() {
        Contact con = [SELECT Id FROM Contact WHERE Email = 'student@example.com' LIMIT 1];
        hed__Term__c prevTerm = [SELECT Id FROM hed__Term__c WHERE Name = 'Previous Term' LIMIT 1];
        hed__Term__c nextTerm = [SELECT Id FROM hed__Term__c WHERE Name = 'Next Term' LIMIT 1];
        hed__Course_Offering__c co = [SELECT Id FROM hed__Course_Offering__c LIMIT 1];

        List<String> contactIds = new List<String>{con.Id};
        List<String> courseOfferingIds = new List<String>{co.Id};

        Test.startTest();
        termEnrollmentCtrl.createProgramEnrollments(contactIds, nextTerm.Id, null, courseOfferingIds, prevTerm.Id);
        Test.stopTest();

    }
    
      public class SuccessHttpMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(' {"success": "true","data": {"Identifier": "98765","Code": "Ken BBA-01","Name": "Ken - BBA Template","Path": "/content/enforced/6887-KenBBA-01"}}');
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
    
}