@istest
public class RestApi_GetActivities_Test {
	@testSetup static void mainClass(){  
        LMS_URL__c URL = new LMS_URL__c(Name = 'course url',Bulk_Enroll__c = 'TestUrl');
        insert URL;
        LMS_URL__c URL1 = new LMS_URL__c(Name = 'course offering url',Bulk_Enroll__c = 'TestUrl');
        insert URL1;
        LMS_URL__c URL2 = new LMS_URL__c(Name = 'Bulk Enrollment',Bulk_Enroll__c = 'TestUrl');
        insert URL2;
        Account testAccount = new Account(Name = 'Test Account', LMS_Id__c = '12345');
        insert testAccount;
        Account educInstitution= new Account();
        educInstitution.Name='SP Jain School of Global Management';
        educInstitution.RecordTypeId=schema.SObjectType.Account.getRecordTypeinfosbyname().get('Educational Institution').getRecordTypeId();
        insert educInstitution;
        
        Account UnivDepart= new Account();
        UnivDepart.Name='Postgraduate';
        UnivDepart.ParentId=educInstitution.id;
        UnivDepart.RecordTypeId=schema.SObjectType.Account.getRecordTypeinfosbyname().get('University Department').getRecordTypeId();
        insert UnivDepart;
        
        Account academicProg= new Account();
        academicProg.Name='Global MBA';
        academicProg.ParentId=UnivDepart.id;
        academicProg.RecordTypeId=schema.SObjectType.Account.getRecordTypeinfosbyname().get('Academic Program').getRecordTypeId();
        insert academicProg;
        
        Account prgSepcl = new Account();
        prgSepcl.Name = 'Test Special Course';
        prgSepcl.ParentId = academicProg.Id;
        prgSepcl.RecordTypeId = schema.SObjectType.Account.getRecordTypeinfosbyname().get('Program Specialization').getRecordTypeId();
        insert prgSepcl;
        
        Contact con = new Contact();
        con.LastName = 'Test Faculty';
        con.RecordTypeId = schema.SObjectType.Contact.getRecordTypeInfosByName().get('Faculty').getRecordTypeId();
        insert con;
        
       
    }

    @isTest
     static void method1(){
       Test.setMock(HttpCalloutMock.class, new MockEnrollmentRespBBClass());
        Account educInstitution=[Select Id from Account where Name='SP Jain School of Global Management' limit 1];
        Account UnivDepart=[Select Id from Account where Name='Postgraduate' limit 1];
        Account academicProg=[Select Id from Account where Name='Global MBA' limit 1];
        Account prgSepcl=[Select Id from Account  where Name='Test Special Course' limit 1];
        Contact con = [Select Id from Contact limit 1];
         hed__Program_Plan__c progPln = new hed__Program_Plan__c();//[SELECT Id,hed__Account__c,Name,hed__Start_Date__c,hed__End_Date__c FROM hed__Program_Plan__c Limit 1];
        progPln.Name='test';
        progPln.hed__Account__c = academicProg.Id;
        progPln.Batch__c='2040';
        progPln.Intake__c='Jul';
        progPln.hed__Status__c = 'Current';
        progPln.RecordTypeId = schema.SObjectType.hed__Program_Plan__c.getRecordTypeinfosbyname().get('Program Version').getRecordTypeId();
        progPln.Working_Days__c='Monday;Tuesday';
        insert progPln;
        //Create Campus
        Campus__c camp=new Campus__c();
        camp.Name='test';
        camp.Campus_ID__c='SNG';
        insert camp;
        //Create Terms
        hed__Term__c tr= new hed__Term__c();
        tr.Name='2040-NCECVR-PS-Term';
        tr.hed__Account__c=academicProg.Id;
        tr.hed__Start_Date__c=system.today()-1;
        tr.hed__End_Date__c=system.today()+7;
        tr.hed__Grading_Period_Sequence__c=10;
        tr.Campus__c=camp.Id;
        tr.hed__Type__c='School Year';
        tr.hed__Instructional_Days__c=20;
        tr.Program_Plan__c=progPln.Id;
        tr.RecordTypeId = Schema.SObjectType.hed__Term__c.getRecordTypeInfosByName().get('Default Record').getRecordTypeId();
        TR.Term_Reference__c='Term 1';
        insert tr;
        
        
        hed__Course__c course=new 	hed__Course__c();
        course.Name='test';
        course.hed__Course_ID__c='test';
        course.Credits__c=1;
        course.hed__Account__c=academicProg.Id;
        insert course;
        
        Course_Version__c courseVersion=new Course_Version__c();
        courseVersion.Course__c=course.Id;
        courseVersion.Term__c=tr.Id;
        courseVersion.Start_Date__c=system.today();
        courseVersion.End_Date__c=system.today()+1;
        insert courseVersion;
        
        
        K42_Academic_Planner__c acPlanner=new K42_Academic_Planner__c();
        acPlanner.Name='test';
        acPlanner.K42_Program__c=progPln.hed__Account__c;
        acPlanner.Program_Plan__c=progPln.Id;
        acPlanner.Term__c=tr.Id;
        acPlanner.RecordTypeId=Schema.SObjectType.K42_Academic_Planner__c.getRecordTypeInfosByName().get('Default').getRecordTypeId();
        insert acPlanner;
         
         hed__Facility__c facility = new hed__Facility__c();
        facility.Name = 'FacilityTest';
        facility.Number_of_Rows__c =5;
        facility.Number_of_Rows_Per_Column__c = 5;
        facility.CourseVersionId__c=courseVersion.id;
        insert facility;
        
        Activity__c activitie=new Activity__c();
        activitie.Academic_Planner__c=acPlanner.Id;
        activitie.Start_date__c=system.today()-1;
        activitie.End_date__c=system.today()+1;
        activitie.Activity_type__c = 'Exam';
        activitie.RecordTypeId = schema.SObjectType.Activity__c.getRecordTypeInfosByName().get('Default').getRecordTypeId();
        activitie.Faculty1__c = con.Id;
        activitie.Number_of_Sessions__c=3;
        activitie.Subject__c=courseVersion.id;
        activitie.Activity_type__c='Teaching';
        activitie.Facility__c=facility.id;
        insert activitie;
         
      
        acPlanner.K42_Program_Start_Date__c=system.today();
        acPlanner.K42_Program_End_Date__c=system.today()+1;
        acPlanner.AP_End_Day__c='Sunday';
        acPlanner.AP_Start_Day__c='Monday';
        acPlanner.Day_Start_Time__c=Time.newInstance(18, 0, 0, 0);
        acPlanner.K42_Day_End_Time__c=Time.newInstance(18, 0, 0, 0);
        acPlanner.Term_Start_Date__c=system.today();
        acPlanner.Term_End_Date__c=system.today()+1;
        acPlanner.Term_Weekly_BreakDays__c='Monday';
        update acPlanner;
        
        RestRequest req = new RestRequest(); 
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/ActivitiesData/?';
        req.httpMethod = 'GET';
        req.params.put('programName','Global MBA');
        req.params.put('intake','JUL');
        req.params.put('year','2040');
        req.params.put('term',tr.id);
        req.params.put('type','Exam');
        req.params.put('facultyId',con.Id);
        req.params.put('facilityId',facility.Id);
        req.params.put('type','Teaching'); 
        RestContext.request = req;
        RestContext.response = res;
        Test.startTest();
        RestApi_GetActivities.doGetActivitiesData();
        Test.stopTest();
         Assert.areEqual(200, res.statusCode);
    }
    @isTest
   static void method2(){
       Test.setMock(HttpCalloutMock.class, new MockEnrollmentRespBBClass());
        Account educInstitution=[Select Id from Account where Name='SP Jain School of Global Management' limit 1];
        Account UnivDepart=[Select Id from Account where Name='Postgraduate' limit 1];
        Account academicProg=[Select Id from Account where Name='Global MBA' limit 1];
        Account prgSepcl=[Select Id from Account  where Name='Test Special Course' limit 1];
        Contact con = [Select Id from Contact limit 1];
         hed__Program_Plan__c progPln = new hed__Program_Plan__c();//[SELECT Id,hed__Account__c,Name,hed__Start_Date__c,hed__End_Date__c FROM hed__Program_Plan__c Limit 1];
        progPln.Name='test';
        progPln.hed__Account__c = academicProg.Id;
        progPln.Batch__c='2040';
        progPln.Intake__c='Jul';
        progPln.hed__Status__c = 'Current';
        progPln.RecordTypeId = schema.SObjectType.hed__Program_Plan__c.getRecordTypeinfosbyname().get('Program Version').getRecordTypeId();
        progPln.Working_Days__c='Monday;Tuesday';
        insert progPln;
        //Create Campus
        Campus__c camp=new Campus__c();
        camp.Name='test';
        camp.Campus_ID__c='SNG';
        insert camp;
        //Create Terms
        hed__Term__c tr= new hed__Term__c();
        tr.Name='2040-NCECVR-PS-Term';
        tr.hed__Account__c=academicProg.Id;
        tr.hed__Start_Date__c=system.today()-1;
        tr.hed__End_Date__c=system.today()+7;
        tr.hed__Grading_Period_Sequence__c=10;
        tr.Campus__c=camp.Id;
        tr.hed__Type__c='School Year';
        tr.hed__Instructional_Days__c=20;
        tr.Program_Plan__c=progPln.Id;
        tr.RecordTypeId = Schema.SObjectType.hed__Term__c.getRecordTypeInfosByName().get('Default Record').getRecordTypeId();
        TR.Term_Reference__c='Term 1';
        insert tr;
        
        
        hed__Course__c course=new 	hed__Course__c();
        course.Name='test';
        course.hed__Course_ID__c='test';
        course.Credits__c=1;
        course.hed__Account__c=academicProg.Id;
        insert course;
        
        Course_Version__c courseVersion=new Course_Version__c();
        courseVersion.Course__c=course.Id;
        courseVersion.Term__c=tr.Id;
        courseVersion.Start_Date__c=system.today();
        courseVersion.End_Date__c=system.today()+1;
        insert courseVersion;
        
        
        K42_Academic_Planner__c acPlanner=new K42_Academic_Planner__c();
        acPlanner.Name='test';
        acPlanner.K42_Program__c=progPln.hed__Account__c;
        acPlanner.Program_Plan__c=progPln.Id;
        acPlanner.Term__c=tr.Id;
        acPlanner.RecordTypeId=Schema.SObjectType.K42_Academic_Planner__c.getRecordTypeInfosByName().get('Default').getRecordTypeId();
        insert acPlanner;
        
         hed__Facility__c facility = new hed__Facility__c();
        facility.Name = 'FacilityTest';
        facility.Number_of_Rows__c =5;
        facility.Number_of_Rows_Per_Column__c = 5;
        facility.CourseVersionId__c=courseVersion.id;
        insert facility;
        
        Activity__c activitie=new Activity__c();
        activitie.Academic_Planner__c=acPlanner.Id;
        activitie.Start_date__c=system.today()-1;
        activitie.End_date__c=system.today()+1;
        activitie.Activity_type__c = 'Exam';
        activitie.RecordTypeId = schema.SObjectType.Activity__c.getRecordTypeInfosByName().get('Default').getRecordTypeId();
        activitie.Faculty1__c = con.Id;
        activitie.Number_of_Sessions__c=3;
        activitie.Subject__c=courseVersion.id;
        activitie.Activity_type__c='Teaching';
        activitie.Facility__c=facility.id;
        insert activitie;
        
			
        
        acPlanner.K42_Program_Start_Date__c=system.today();
        acPlanner.K42_Program_End_Date__c=system.today()+1;
        acPlanner.AP_End_Day__c='Sunday';
        acPlanner.AP_Start_Day__c='Monday';
        acPlanner.Day_Start_Time__c=Time.newInstance(18, 0, 0, 0);
        acPlanner.K42_Day_End_Time__c=Time.newInstance(18, 0, 0, 0);
        acPlanner.Term_Start_Date__c=system.today();
        acPlanner.Term_End_Date__c=system.today()+1;
        acPlanner.Term_Weekly_BreakDays__c='Monday';
        update acPlanner;
        
        RestRequest req = new RestRequest(); 
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/ActivitiesData/?';
        req.httpMethod = 'GET';
        req.params.put('programName',null);
        req.params.put('intake',null);
        req.params.put('year',null);
        req.params.put('term',null);
        req.params.put('facultyId',null);
        req.params.put('facilityId',facility.Id);
        req.params.put('type','Teaching'); 
        RestContext.request = req;
        RestContext.response = res;
        Test.startTest();
        RestApi_GetActivities.doGetActivitiesData();
        Test.stopTest();
       Assert.areEqual(200, res.statusCode);
    }
    
     @isTest
   static void method3(){
       Test.setMock(HttpCalloutMock.class, new MockEnrollmentRespBBClass());
        Account educInstitution=[Select Id from Account where Name='SP Jain School of Global Management' limit 1];
        Account UnivDepart=[Select Id from Account where Name='Postgraduate' limit 1];
        Account academicProg=[Select Id from Account where Name='Global MBA' limit 1];
        Account prgSepcl=[Select Id from Account  where Name='Test Special Course' limit 1];
        Contact con = [Select Id from Contact limit 1];
         hed__Program_Plan__c progPln = new hed__Program_Plan__c();//[SELECT Id,hed__Account__c,Name,hed__Start_Date__c,hed__End_Date__c FROM hed__Program_Plan__c Limit 1];
        progPln.Name='test';
        progPln.hed__Account__c = academicProg.Id;
        progPln.Batch__c='2040';
        progPln.Intake__c='Jul';
        progPln.hed__Status__c = 'Current';
        progPln.RecordTypeId = schema.SObjectType.hed__Program_Plan__c.getRecordTypeinfosbyname().get('Program Version').getRecordTypeId();
        progPln.Working_Days__c='Monday;Tuesday';
        insert progPln;
        //Create Campus
        Campus__c camp=new Campus__c();
        camp.Name='test';
        camp.Campus_ID__c='SNG';
        insert camp;
        //Create Terms
        hed__Term__c tr= new hed__Term__c();
        tr.Name='2040-NCECVR-PS-Term';
        tr.hed__Account__c=academicProg.Id;
        tr.hed__Start_Date__c=system.today()-1;
        tr.hed__End_Date__c=system.today()+7;
        tr.hed__Grading_Period_Sequence__c=10;
        tr.Campus__c=camp.Id;
        tr.hed__Type__c='School Year';
        tr.hed__Instructional_Days__c=20;
        tr.Program_Plan__c=progPln.Id;
        tr.RecordTypeId = Schema.SObjectType.hed__Term__c.getRecordTypeInfosByName().get('Default Record').getRecordTypeId();
        TR.Term_Reference__c='Term 1';
        insert tr;
        
        
        hed__Course__c course=new 	hed__Course__c();
        course.Name='test';
        course.hed__Course_ID__c='test';
        course.Credits__c=1;
        course.hed__Account__c=academicProg.Id;
        insert course;
        
        Course_Version__c courseVersion=new Course_Version__c();
        courseVersion.Course__c=course.Id;
        courseVersion.Term__c=tr.Id;
        courseVersion.Start_Date__c=system.today();
        courseVersion.End_Date__c=system.today()+1;
        insert courseVersion;
        
        
        K42_Academic_Planner__c acPlanner=new K42_Academic_Planner__c();
        acPlanner.Name='test';
        acPlanner.K42_Program__c=progPln.hed__Account__c;
        acPlanner.Program_Plan__c=progPln.Id;
        acPlanner.Term__c=tr.Id;
        acPlanner.RecordTypeId=Schema.SObjectType.K42_Academic_Planner__c.getRecordTypeInfosByName().get('Default').getRecordTypeId();
        insert acPlanner;
        
         hed__Facility__c facility = new hed__Facility__c();
        facility.Name = 'FacilityTest';
        facility.Number_of_Rows__c =5;
        facility.Number_of_Rows_Per_Column__c = 5;
        facility.CourseVersionId__c=courseVersion.id;
        insert facility;
        
        Activity__c activitie=new Activity__c();
        activitie.Academic_Planner__c=acPlanner.Id;
        activitie.Start_date__c=system.today()-1;
        activitie.End_date__c=system.today()+1;
        activitie.Activity_type__c = 'Exam';
        activitie.RecordTypeId = schema.SObjectType.Activity__c.getRecordTypeInfosByName().get('Default').getRecordTypeId();
        activitie.Faculty1__c = con.Id;
        activitie.Number_of_Sessions__c=3;
        activitie.Subject__c=courseVersion.id;
        activitie.Activity_type__c='Teaching';
        activitie.Facility__c=facility.id;
        insert activitie;
        
			
        
        acPlanner.K42_Program_Start_Date__c=system.today();
        acPlanner.K42_Program_End_Date__c=system.today()+1;
        acPlanner.AP_End_Day__c='Sunday';
        acPlanner.AP_Start_Day__c='Monday';
        acPlanner.Day_Start_Time__c=Time.newInstance(18, 0, 0, 0);
        acPlanner.K42_Day_End_Time__c=Time.newInstance(18, 0, 0, 0);
        acPlanner.Term_Start_Date__c=system.today();
        acPlanner.Term_End_Date__c=system.today()+1;
        acPlanner.Term_Weekly_BreakDays__c='Monday';
        update acPlanner;
        
        RestRequest req = new RestRequest(); 
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/ActivitiesData/?';
        req.httpMethod = 'GET';
        req.params.put('programName',null);
        req.params.put('intake',null);
        req.params.put('year',null);
        req.params.put('term',tr.id);
        req.params.put('facultyId',null);
        req.params.put('facilityId',facility.Id);
        req.params.put('type','Teaching');      
        RestContext.request = req;
        RestContext.response = res;
        Test.startTest();
        RestApi_GetActivities.doGetActivitiesData();
        Test.stopTest();
       Assert.areEqual(200, res.statusCode);
    }
      @isTest
    static void method4(){
          Test.setMock(HttpCalloutMock.class, new MockEnrollmentRespBBClass());
        Account educInstitution=[Select Id from Account where Name='SP Jain School of Global Management' limit 1];
        Account UnivDepart=[Select Id from Account where Name='Postgraduate' limit 1];
        Account academicProg=[Select Id from Account where Name='Global MBA' limit 1];
        Account prgSepcl=[Select Id from Account  where Name='Test Special Course' limit 1];
        Contact con = [Select Id from Contact limit 1];
        
         hed__Program_Plan__c progPln = new hed__Program_Plan__c();//[SELECT Id,hed__Account__c,Name,hed__Start_Date__c,hed__End_Date__c FROM hed__Program_Plan__c Limit 1];
        progPln.Name='test';
        progPln.hed__Account__c = academicProg.Id;
        progPln.Batch__c='2040';
        progPln.Intake__c='Jul';
        progPln.hed__Status__c = 'Current';
        progPln.RecordTypeId = schema.SObjectType.hed__Program_Plan__c.getRecordTypeinfosbyname().get('Program Version').getRecordTypeId();
        progPln.Working_Days__c='Monday;Tuesday';
        insert progPln;
        //Create Campus
        Campus__c camp=new Campus__c();
        camp.Name='test';
        camp.Campus_ID__c='SNG';
        insert camp;
        //Create Terms
        hed__Term__c tr= new hed__Term__c();
        tr.Name='2040-NCECVR-PS-Term';
        tr.hed__Account__c=academicProg.Id;
        tr.hed__Start_Date__c=system.today()-1;
        tr.hed__End_Date__c=system.today()+7;
        tr.hed__Grading_Period_Sequence__c=10;
        tr.Campus__c=camp.Id;
        tr.hed__Type__c='School Year';
        tr.hed__Instructional_Days__c=20;
        tr.Program_Plan__c=progPln.Id;
        tr.RecordTypeId = Schema.SObjectType.hed__Term__c.getRecordTypeInfosByName().get('Default Record').getRecordTypeId();
        TR.Term_Reference__c='Term 1';
        insert tr;
        
        
        hed__Course__c course=new 	hed__Course__c();
        course.Name='test';
        course.hed__Course_ID__c='test';
        course.Credits__c=1;
        course.hed__Account__c=academicProg.Id;
        insert course;
        
        Course_Version__c courseVersion=new Course_Version__c();
        courseVersion.Course__c=course.Id;
        courseVersion.Term__c=tr.Id;
        courseVersion.Start_Date__c=system.today();
        courseVersion.End_Date__c=system.today()+1;
        insert courseVersion;
        
        
        K42_Academic_Planner__c acPlanner=new K42_Academic_Planner__c();
        acPlanner.Name='test';
        acPlanner.K42_Program__c=progPln.hed__Account__c;
        acPlanner.Program_Plan__c=progPln.Id;
        acPlanner.Term__c=tr.Id;
        acPlanner.RecordTypeId=Schema.SObjectType.K42_Academic_Planner__c.getRecordTypeInfosByName().get('Default').getRecordTypeId();
        insert acPlanner;
        
         hed__Facility__c facility = new hed__Facility__c();
        facility.Name = 'FacilityTest';
        facility.Number_of_Rows__c =5;
        facility.Number_of_Rows_Per_Column__c = 5;
        facility.CourseVersionId__c=courseVersion.id;
        insert facility;
        
        Activity__c activitie=new Activity__c();
        activitie.Academic_Planner__c=acPlanner.Id;
        activitie.Start_date__c=system.today()-1;
        activitie.End_date__c=system.today()+1;
        activitie.Activity_type__c = 'Exam';
        activitie.RecordTypeId = schema.SObjectType.Activity__c.getRecordTypeInfosByName().get('Default').getRecordTypeId();
        activitie.Faculty1__c = con.Id;
        activitie.Number_of_Sessions__c=3;
        activitie.Subject__c=courseVersion.id;
        activitie.Activity_type__c='Teaching';
        activitie.Facility__c=facility.id;
        activitie.isAccepted__c=true;
        insert activitie;
        
			
        
        acPlanner.K42_Program_Start_Date__c=system.today();
        acPlanner.K42_Program_End_Date__c=system.today()+1;
        acPlanner.AP_End_Day__c='Sunday';
        acPlanner.AP_Start_Day__c='Monday';
        acPlanner.Day_Start_Time__c=Time.newInstance(18, 0, 0, 0);
        acPlanner.K42_Day_End_Time__c=Time.newInstance(18, 0, 0, 0);
        acPlanner.Term_Start_Date__c=system.today();
        acPlanner.Term_End_Date__c=system.today()+1;
        acPlanner.Term_Weekly_BreakDays__c='Monday';
        update acPlanner;
        
         RestRequest req = new RestRequest(); 
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/ActivitiesData/?';
        req.httpMethod = 'GET';
        req.params.put('programName',null);
        req.params.put('intake',null);
        req.params.put('year',null);
        req.params.put('term',tr.id);
        req.params.put('facultyId',null);
        req.params.put('facilityId',null);
        req.params.put('type',null);      
        RestContext.request = req;
        RestContext.response = res;
        Test.startTest();
        RestApi_GetActivities.doGetActivitiesData();
        Test.stopTest();
       Assert.areEqual(200, res.statusCode);
    }
    
    
}