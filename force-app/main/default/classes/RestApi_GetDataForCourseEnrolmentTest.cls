@isTest
private class RestApi_GetDataForCourseEnrolmentTest {
    
    @TestSetup
    static void setup() {
        LMS_URL__c URL = new LMS_URL__c(Name = 'course url',Bulk_Enroll__c = 'TestUrl');
        insert URL;
        LMS_URL__c URL1 = new LMS_URL__c(Name = 'course offering url',Bulk_Enroll__c = 'TestUrl');
        insert URL1;
        LMS_URL__c URL2 = new LMS_URL__c(Name = 'Bulk Enrollment',Bulk_Enroll__c = 'TestUrl');
        insert URL2;
        Account testAccount = new Account(Name = 'Test Account', LMS_Id__c = '12345');
        insert testAccount;
        Account acc=new Account();
        acc.Name='Test Institute';
        acc.RecordTypeId=schema.SObjectType.Account.getRecordTypeinfosbyname().get('Academic Program').getRecordTypeId();
        insert acc;
            
        
         Account UnivDepart= new Account();
        UnivDepart.Name='Economics and Finance';
        UnivDepart.ParentId=acc.id;
        UnivDepart.RecordTypeId=schema.SObjectType.Account.getRecordTypeinfosbyname().get('University Department').getRecordTypeId();
        insert UnivDepart;
       

        Account academicProg= new Account();
        academicProg.Name='The First Principle Thinking';
        academicProg.ParentId=UnivDepart.id;
        academicProg.RecordTypeId=schema.SObjectType.Account.getRecordTypeinfosbyname().get('Academic Program').getRecordTypeId();
        insert academicProg;        
        
        Account progSpec= new Account();
        progSpec.Name='Test Program Specialization';
        progSpec.ParentId=academicProg.id;
        progSpec.RecordTypeId=schema.SObjectType.Account.getRecordTypeinfosbyname().get('Program Specialization').getRecordTypeId();
        insert progSpec;     
        
        
        
    }
    
    @isTest
    static void testGetDataForCourseEnrolment() {
        			
	 Test.setMock(HttpCalloutMock.class, new MockEnrollmentRespBBClass());
       Account inst=[Select Id,Name,RecordTypeId from Account where Name='Test Institute' limit 1];
        Account univDep=[Select Id,Name,RecordTypeId from Account where Name='Economics and Finance' limit 1];
        Account academPgm=[Select Id,Name,RecordTypeId from Account where Name='The First Principle Thinking' limit 1];
       Account progSpec=[Select Id,Name,RecordTypeId from Account where Name='Test Program Specialization' limit 1];
        Campus__c camp = new Campus__c();
        camp.Name = 'test';
        camp.Campus_ID__c='SNG';
        insert camp;
        
        hed__Program_Plan__c progPln = new hed__Program_Plan__c();
        progPln.Name = 'test';
        progPln.hed__Account__c = academPgm.Id;
        progPln.Batch__c = '2040';
        progPln.Intake__c = 'Jul';
        progPln.RecordTypeId = Schema.SObjectType.hed__Program_Plan__c.getRecordTypeInfosByName().get('Program Version').getRecordTypeId();
        insert progPln;
        
        // Create Terms
        hed__Term__c tr = new hed__Term__c();
        tr.Name = '2040-Jul-PS-Term';
        tr.hed__Account__c = academPgm.Id;
        tr.hed__Start_Date__c = System.today();
        tr.hed__End_Date__c = System.today() + 7;
        tr.hed__Grading_Period_Sequence__c = 10;
        tr.Campus__c = camp.Id;
        tr.Program_Plan__c = progPln.Id;
        tr.RecordTypeId = Schema.SObjectType.hed__Term__c.getRecordTypeInfosByName().get('Default Record').getRecordTypeId();
        tr.Term_Reference__c='Term 1';
        insert tr;
        
        hed__Course__c course = new hed__Course__c();
        course.Name = 'test';
        course.hed__Course_ID__c = 'test';
        course.Credits__c = 1;
        course.hed__Account__c = academPgm.Id;
        insert course;
        
        Course_Version__c courseVersion = new Course_Version__c();
        courseVersion.Course__c = course.Id;
        courseVersion.Program_Plan__c = progPln.Id;
        courseVersion.Term__c = tr.Id;
        courseVersion.Start_Date__c = System.today();
        courseVersion.End_Date__c = System.today() + 1;
        insert courseVersion;
        
        hed__Course_Offering__c courseOffering = new hed__Course_Offering__c();
        courseOffering.Name = 'test';
        courseOffering.hed__Section_ID__c = 'B';
        courseOffering.hed__Course__c = course.Id;
        courseOffering.hed__Term__c = tr.Id;
        courseOffering.Course_Version__c = courseVersion.Id;
        insert courseOffering;
        
        RestRequest req = new RestRequest(); 
        RestResponse res = new RestResponse();  
        
        req.requestURI = '/services/apexrest/getDataForCourseEnrolment/';
        req.httpMethod = 'GET';
        req.addParameter('instituteId',inst.Id);
        RestContext.request = req;
        RestContext.response= res;
        
   		Test.startTest();
        RestApi_GetDataForCourseEnrolment.doGetDataForCourseEnrolment();
        Test.stopTest();
       	Assert.areEqual(200, res.statusCode);       
    }
}