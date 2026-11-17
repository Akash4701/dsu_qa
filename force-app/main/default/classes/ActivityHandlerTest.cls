@isTest
public class ActivityHandlerTest {
    
    public class MockEnrollmentResp implements HttpCalloutMock {
  
    public HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        
        if (req.getEndpoint().contains('courses')) {
            // Mock response for course creation
            res.setBody('{"id": "mockCourseId"}');
            res.setStatusCode(200);
        } else if (req.getEndpoint().contains('contents')) {
            // Mock response for content creation
            res.setBody('{"id": "mockContentId"}');
            res.setStatusCode(200);
        } else {
            // Default response for other endpoints
            res.setBody('{"message": "success"}');
            res.setStatusCode(200);
        }
        
        return res;
    }
}

    @testSetup
    static void dataSetup() {
        Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());
        Test.setMock(HttpCalloutMock.class, new FailureHttpMock());
        LMS_URL__c URL = new LMS_URL__c(Name = 'course url',Bulk_Enroll__c = 'TestUrl');
        insert URL;
        LMS_URL__c URL1 = new LMS_URL__c(Name = 'course offering url',Bulk_Enroll__c = 'TestUrl');
        insert URL1;
        LMS_URL__c URL2 = new LMS_URL__c(Name = 'Bulk Enrollment',Bulk_Enroll__c = 'TestUrl');
        insert URL2;
        Account testAccount = new Account(Name = 'Test Account', LMS_Id__c = '12345');
        insert testAccount;
        Account acc = new Account();
        acc.Name = 'Institute';
        acc.RecordTypeId = Schema.SObjectType.Account.getRecordTypeinfosbyname().get('Academic Program').getRecordTypeId();
        insert acc;
        
        contact con = new contact();
        con.lastname = 'Student';
        con.email = 'faculty@gmail.com';
        con.RecordTypeId=schema.SObjectType.contact.getRecordTypeinfosbyname().get('Student').getRecordTypeId();
        insert con;
        
        hed__Program_Plan__c prgPlan = new hed__Program_Plan__c();
        prgPlan.name = 'Program plan';
        prgPlan.hed__Account__c = acc.id;
        prgPlan.hed__Start_Date__c = system.today()-15;
        prgPlan.hed__End_Date__c = system.today() + 15;
        prgPlan.hed__Status__c ='Current';
        prgPlan.Intake__c ='Jan';
        prgPlan.Batch__c = '2023';
        prgPlan.Working_Days__c = 'Monday;Tuesday;Wednesday;Thursday;Friday';
        insert prgPlan;
        
        hed__Term__c term = new hed__Term__c();
        term.hed__Account__c = acc.id;
        term.Program_Plan__c=prgPlan.id;
        term.hed__Start_Date__c = system.today();
        term.hed__End_Date__c = system.today() + 15;
        term.name = 'term';
        term.Term_Reference__c='Term 1';
        insert term;
        
        hed__Course__c course = new hed__Course__c();
        course.hed__Account__c = acc.id;
        course.Name = 'course Name';
        course.hed__Credit_Hours__c = 12;
        insert course;
        
        hed__Facility__c fac = new hed__Facility__c();
        fac.Name = 'ELO-1';
        fac.Number_of_Rows__c = 10;
        fac.Number_of_Rows_Per_Column__c = 10;
        insert fac;
        
       
    }
    @isTest
    static void method1(){
Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());
        Test.setMock(HttpCalloutMock.class, new FailureHttpMock());
        Account retrievedAccount = [SELECT Id, Name FROM Account WHERE Name = 'Institute' limit 1];
        Contact retrievedContact = [SELECT Id, LastName, Email FROM Contact limit 1];
        hed__Program_Plan__c retrievedProgramPlan = [SELECT Id, Name, hed__Account__c, hed__Start_Date__c, hed__End_Date__c, hed__Status__c, Intake__c, Batch__c, Working_Days__c FROM hed__Program_Plan__c limit 1];
        hed__Term__c retrievedTerm = [SELECT Id, Name, hed__Account__c, Program_Plan__c, hed__Start_Date__c, hed__End_Date__c, Term_Reference__c FROM hed__Term__c limit 1];
        hed__Course__c retrievedCourse = [SELECT Id, Name, hed__Account__c, hed__Credit_Hours__c FROM hed__Course__c limit 1];
        hed__Facility__c retrievedFacility = [SELECT Id, Name, Number_of_Rows__c, Number_of_Rows_Per_Column__c FROM hed__Facility__c limit 1];

        
        Course_Version__c version = new Course_Version__c();
        version.Course__c =retrievedCourse.id;
        version.Term__c = retrievedTerm.id;
        version.Program_Plan__c = retrievedProgramPlan.id;
        version.Start_Date__c = system.today();
        version.Facilities__c = retrievedFacility.Id;
        insert version;
        
        K42_Academic_Planner__c planner = new K42_Academic_Planner__c();
        planner.K42_Program__c = retrievedAccount.id;
        planner.Program_Plan__c = retrievedProgramPlan.id;
        planner.Term__c = retrievedTerm.id;
        planner.Name = 'Academic Planner Test';
        insert planner;
        
        Activity__c activity = new Activity__c();
        activity.Name = 'Activity Test';
        activity.Academic_Planner__c = planner.id;
        activity.Start_date__c = system.today()-10;
        activity.End_date__c = system.today()+10;
        activity.Activity_type__c ='Exam';
        activity.Subject__c = version.id;
        activity.Activity_Duration__c = 10;
        insert  activity;
        
        Activity__c activity1 = new Activity__c();
        activity1.Name = 'Activity Test1';
        activity1.Academic_Planner__c = planner.id;
        activity1.Activity_type__c ='Teaching';
        activity1.Start_date__c = system.today()-10;
        activity1.End_date__c = system.today()+10;
        activity1.Subject__c = version.id;
        activity1.Activity_Duration__c = 10;
        insert  activity1;
        
        K42_Holiday__c generalHoliday = new K42_Holiday__c();
        generalHoliday.Name ='General Holiday';
        generalHoliday.K42_Hol_Start_Date__c = system.Today();
        generalHoliday.K42_Hol_End_Date__c = system.today()+1;
        generalHoliday.Common_Holiday__c = 'Yes';
        generalHoliday.K42_Holiday_Type__c = 'National Holiday';
        insert generalHoliday;
        
        List<Activity__c> activityList = [Select id,Name,Subject__c from Activity__c];
        List<Course_Version__c> courseVersion = [Select id,Facilities__c from Course_Version__c];
        Map<Id,Course_Version__c> mapOfCV = new Map<Id,Course_Version__c>([Select id,Facilities__c from Course_Version__c]);
        
        Test.startTest();
        ActivityHandler.updateCourseVersionWithEndDate(activityList);
        ActivityHandler.updateCVendDateFromCVTrigger(courseVersion,mapOfCV);
       

        // Assert the result based on the mocked response
        //System.assertEquals(1, result, 'Expected successful update');
        Test.stopTest();
    }
   
     @IsTest
    static void testCreateCourse() {
        Test.setMock(HttpCalloutMock.class, new MockEnrollmentRespBBClass());
        
          Account acc=[Select Id,Name from Account limit 1];
      Contact con=[Select Id,Name,RecordTypeId,Email from Contact limit 1];
      hed__Program_Plan__c prgPlan=[Select Name,hed__Account__c,Intake__c,hed__End_Date__c,hed__Start_Date__c from hed__Program_Plan__c limit 1];
        hed__Term__c term = new hed__Term__c(
            hed__Account__c = acc.Id,
            Program_Plan__c = prgPlan.Id,
            hed__Start_Date__c = Date.today(),
            hed__End_Date__c = Date.today().addDays(15),
            Name = 'term',
            Term_Reference__c = 'Term 1'
        );
        insert term;

        hed__Course__c course = new hed__Course__c(
            hed__Account__c = acc.Id,
            Name = 'Course Name',
            hed__Credit_Hours__c = 12
        );
        insert course;
        
         List<hed__Course_Offering__c> courseOffList=new List<hed__Course_Offering__c>();
            hed__Course_Offering__c courseOff = new hed__Course_Offering__c(
                Name = 'CourseOff Test',
                hed__Start_Date__c = Date.today().addDays(2),
                hed__End_Date__c = Date.today().addDays(10),
               // BB_Id__c = '3423423',
                hed__Course__c = course.Id,
                hed__Term__c = term.Id
            );
            courseOffList.add(courseOff);
        
        insert courseOffList;
      

        

        // Perform additional assertions as needed to verify course creation logic
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