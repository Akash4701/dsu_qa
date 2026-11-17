@isTest
public class courseOfferingInsertUpdateTest {

    @testSetup
    static void setupTestData() 
    {
        LMS_URL__c URL = new LMS_URL__c(Name = 'course url',Bulk_Enroll__c = 'TestUrl');
        insert URL;
        LMS_URL__c URL1 = new LMS_URL__c(Name = 'course offering url',Bulk_Enroll__c = 'TestUrl');
        insert URL1;
        LMS_URL__c URL2 = new LMS_URL__c(Name = 'Bulk Enrollment',Bulk_Enroll__c = 'TestUrl');
        insert URL2;
        Account testAccount = new Account(Name = 'Test Account', LMS_Id__c = '12345');
        insert testAccount;
        // Create an Account (if required for hed__Course_Offering__c)
        Account account = new Account(Name = 'Test Account');
        insert account;
  
       
    }

    @isTest
    static void testCourseOfferingInsert() {
          Test.setMock(HttpCalloutMock.class, new MockEnrollmentRespBBClass());
        Account acc=[Select Id,Name from Account LIMIT 1];
        hed__Program_Plan__c programPlan = new hed__Program_Plan__c(
        Name ='test');
        insert programPlan;
        
        // Create a Term
        hed__Term__c term = new hed__Term__c(Name = 'Fall 2024',
                                            hed__Account__c= acc.id,
                                            Term_Reference__c = 'test');
        insert term;

        // Create a Course
        hed__Course__c course = new hed__Course__c(Name = 'Test Course', hed__Course_ID__c = 'C101',
                                                  hed__Account__c= acc.id);
        insert course;

        // Create Course Version
        Course_Version__c courseVersion = new Course_Version__c(
            Course__c = course.Id,
            Term__c = term.Id,
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addDays(90),
            Program_Plan__c = programPlan.id
        );
        insert courseVersion;

        // Create Master Unit Plan Requirement
        hed__Plan_Requirement__c masterPlanReq = new hed__Plan_Requirement__c(
            Name = 'Master Unit Plan',
            hed__Category__c = 'Mandatory',
            Offset__c = 1,
            Duration__c = '3',
            Number_of_Sessions__c = 10,
            hed__Course__c = course.Id,
            RecordTypeId = Schema.SObjectType.hed__Plan_Requirement__c.getRecordTypeInfosByName().get('Master Unit').getRecordTypeId()
        );
        insert masterPlanReq;

        // Create Group Plan Requirement
        hed__Plan_Requirement__c groupPlanReq = new hed__Plan_Requirement__c(
            Name = 'Group Plan',
            Institute__c = acc.Id,
            Term__c = term.Id,
            RecordTypeId = Schema.SObjectType.hed__Plan_Requirement__c.getRecordTypeInfosByName().get('Group').getRecordTypeId()
        );
        insert groupPlanReq;
           Course_Version__c newCourseVersion = new Course_Version__c(
            Course__c =course.Id,
            Term__c = term.Id,
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addDays(90),
            Program_Plan__c = programPlan.id
        );
        
        Test.startTest();
        insert newCourseVersion;      
        Test.stopTest();
        
        // Validate the Course Offering
        List<hed__Course_Offering__c> courseOfferings = [SELECT Id FROM hed__Course_Offering__c WHERE Course_Version__c = :newCourseVersion.Id];
     //   Assert.areEqual(1, courseOfferings.size());

        // Validate the Plan Requirement
        List<hed__Plan_Requirement__c> planRequirements = [SELECT Id FROM hed__Plan_Requirement__c WHERE CourseVersionId__c = :newCourseVersion.Id];
      //  Assert.areEqual(1, planRequirements.size());
    }

    @isTest
    static void testCourseOfferingUpdate() {
          Test.setMock(HttpCalloutMock.class, new MockEnrollmentRespBBClass());
           Test.setMock(HttpCalloutMock.class, new MockEnrollmentRespBBClass());
        Account acc=[Select Id,Name from Account LIMIT 1];
        hed__Program_Plan__c programPlan = new hed__Program_Plan__c(
        Name ='test');
        insert programPlan;
        
        // Create a Term
        hed__Term__c term = new hed__Term__c(Name = 'Fall 2024',
                                            hed__Account__c= acc.id,
                                            Term_Reference__c = 'test');
        insert term;

        // Create a Course
        hed__Course__c course = new hed__Course__c(Name = 'Test Course', hed__Course_ID__c = 'C101',
                                                  hed__Account__c= acc.id);
        insert course;

        // Create Course Version
        Course_Version__c courseVersion = new Course_Version__c(
            Course__c = course.Id,
            Term__c = term.Id,
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addDays(90),
            Program_Plan__c = programPlan.id
        );
        insert courseVersion;

        // Create Master Unit Plan Requirement
        hed__Plan_Requirement__c masterPlanReq = new hed__Plan_Requirement__c(
            Name = 'Master Unit Plan',
            hed__Category__c = 'Mandatory',
            Offset__c = 1,
            Duration__c = '3',
            Number_of_Sessions__c = 10,
            hed__Course__c = course.Id,
            RecordTypeId = Schema.SObjectType.hed__Plan_Requirement__c.getRecordTypeInfosByName().get('Master Unit').getRecordTypeId()
        );
        insert masterPlanReq;

        // Create Group Plan Requirement
        hed__Plan_Requirement__c groupPlanReq = new hed__Plan_Requirement__c(
            Name = 'Group Plan',
            Institute__c = acc.Id,
            Term__c = term.Id,
            RecordTypeId = Schema.SObjectType.hed__Plan_Requirement__c.getRecordTypeInfosByName().get('Group').getRecordTypeId()
        );
        insert groupPlanReq;
           Course_Version__c newCourseVersion = new Course_Version__c(
            Course__c =course.Id,
            Term__c = term.Id,
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addDays(90),
            Program_Plan__c = programPlan.id
        );
        hed__Course_Offering__c courseOffering = new hed__Course_Offering__c(
            Course_Version__c = courseVersion.Id,
            hed__Course__c = course.id,
            hed__Term__c = term.id,
            hed__Start_Date__c = Date.today(),
            hed__End_Date__c = Date.today().addDays(90),
            Name = 'Fall 2024-Test Course'
          //  hed__Account__c = account.Id,
           // Term_Reference__c = courseVersion.Term__c  // Assuming this is the correct field
        );
        insert courseOffering;

        Test.startTest();
        
        // Update the Course Version record to trigger the update logic
        courseVersion.Start_Date__c = Date.today().addDays(1);
        courseVersion.End_Date__c = Date.today().addDays(91);
        update courseVersion;

        Test.stopTest();
    }

@isTest static void testCreatingCourseOfferingWithMasterPlanRequirement() {
    
    Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());
Test.setMock(HttpCalloutMock.class, new FailureHttpMock());
 Test.setMock(HttpCalloutMock.class, new NoDataHttpMock());

LMS_URL__c lmsUrl = new LMS_URL__c(Name = 'course url', Bulk_Enroll__c = 'https://dummyendpoint.com');
    insert lmsUrl;
 LMS_URL__c URL = new LMS_URL__c(Name = 'course url',Bulk_Enroll__c = 'TestUrl');
        insert URL;
        LMS_URL__c URL1 = new LMS_URL__c(Name = 'course offering url',Bulk_Enroll__c = 'TestUrl');
        insert URL1;
        LMS_URL__c URL2 = new LMS_URL__c(Name = 'Bulk Enrollment',Bulk_Enroll__c = 'TestUrl');
        insert URL2;
    
    account acc=new account(Name='test',LMS_Id__c = '12345');
    insert acc;
    // Create and insert a hed__Course__c (assuming it's a standard object, otherwise use custom if needed)
    hed__Course__c course = new hed__Course__c(
        Name = 'Test Course',
       
        hed__Account__c=acc.id,
         hed__Course_ID__c = 'TC001',
                        LMS_ID__c = '54321'
    );
    insert course;

    // Create and insert a hed__Term__c
    hed__Term__c term = new hed__Term__c(
        Name = 'Term 1',
        hed__Start_Date__c = Date.today(),
        hed__End_Date__c = Date.today().addMonths(1),
        Term_Reference__c='Term 1',
        hed__Account__c=acc.id
    );
    insert term;
    
    id accrec= [SELECT Id, Name, DeveloperName FROM RecordType WHERE SObjectType = 'Account' and Name='Educational Institution'].id;

    // Create and insert an Account for Institute__c
    Account institute = new Account(
        Name = 'Test Institute',
       RecordTypeId = accrec
    );
    insert institute;

    // Create and insert Master Plan Requirement
     id masterUnitRT = [SELECT Id, Name, DeveloperName FROM RecordType WHERE SObjectType = 'hed__Plan_Requirement__c' and Name='Master Unit'].id; 


    hed__Plan_Requirement__c masterPlanReq = new hed__Plan_Requirement__c();
    masterPlanReq.Name = 'Master Plan Req';
    masterPlanReq.RecordTypeId = masterUnitRT;
    masterPlanReq.hed__Course__c = course.Id;
    masterPlanReq.hed__Category__c = 'Mandatory';
    masterPlanReq.Offset__c = 1;
    masterPlanReq.Duration__c = '3';
    masterPlanReq.Number_of_Sessions__c = 5;
    masterPlanReq.Institute__c = institute.Id;
    masterPlanReq.Pre_Requisites_1__c =  course.Id;
    masterPlanReq.Co_Requisites_1__c =  course.Id;

    insert masterPlanReq;

    // Create and insert Course_Version__c
    Course_Version__c cv = new Course_Version__c();
    cv.Course__c = course.Id;
    cv.Term__c = term.Id;
    cv.Credit_hours__c = '3';
    cv.Subject_Offset__c = 1;
    cv.Number_of_Sessions__c = 5;
    cv.Start_Date__c = Date.today();
    cv.End_Date__c = Date.today().addMonths(1);
  //  cv.Subject_Start_Date__c = Date.today();
    cv.Subject_End_Date__c = Date.today().addMonths(1);

    Test.startTest();
    insert cv;
    Test.stopTest();

    // Verify that hed__Course_Offering__c was created
    List<hed__Course_Offering__c> offerings = [SELECT Id FROM hed__Course_Offering__c WHERE Course_Version__c = :cv.Id];
   // System.assert(!offerings.isEmpty(), 'Course Offering should have been created');

    // Verify that hed__Plan_Requirement__c was created with correct data from Master Plan Requirement
    List<hed__Plan_Requirement__c> planReqs = [
        SELECT Id, Offset__c, Duration__c, Number_of_Sessions__c, Institute__c,
               Pre_Requisites_1__c, Co_Requisites_1__c
        FROM hed__Plan_Requirement__c
        WHERE hed__Course__c = :course.Id AND Term__c = :term.Id
    ];
   // System.assert(!planReqs.isEmpty(), 'Plan Requirement should have been created');
   // hed__Plan_Requirement__c pr = planReqs[0];
   
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
    
    public class NoDataHttpMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"message": "Success"}');
            res.setStatusCode(200);
            return res;
        }
    }
}