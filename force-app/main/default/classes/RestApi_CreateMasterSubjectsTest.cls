@isTest
public class RestApi_CreateMasterSubjectsTest {
    @testSetup
    static void dataSetup() {
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
        insert acc;
        
        Contact con = new Contact();
        con.lastname = 'Student';
        con.email = 'Student@gmail.com';
        con.RecordTypeId=Schema.SObjectType.Contact.getRecordTypeinfosbyname().get('Student').getRecordTypeId();
        insert con;
        
       
    }
    @isTest
    public static void deleteMethod1(){
         Test.setMock(HttpCalloutMock.class, new MockEnrollmentRespBBClass());
        
          Account acc = [SELECT Id, Name FROM Account limit 1];
          Contact con = [SELECT Id, LastName, Email, RecordTypeId FROM Contact limit 1];
 		hed__Program_Plan__c prgPlan = new hed__Program_Plan__c();
        prgPlan.name = 'Program plan';
        prgPlan.hed__Account__c = acc.id;
        prgPlan.hed__Start_Date__c = system.today();
        prgPlan.hed__End_Date__c = system.today() + 15;
        prgPlan.hed__Status__c ='Current';
        prgPlan.Intake__c ='Jan';
        prgPlan.Batch__c = '2023';
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
        
        Course_Version__c version = new Course_Version__c();
        version.Course__c =course.id;
        version.Term__c = term.id;
        version.Program_Plan__c = prgPlan.id;
        insert version;
        
        hed__Course_Offering__c couOffering1= new hed__Course_Offering__c();
        couOffering1.hed__Course__c = course.id;
        couOffering1.Course_Version__c = version.id;
        couOffering1.hed__Term__c = term.id;
        couOffering1.hed__Section_ID__c = 'B';
        insert couOffering1;    
        
        hed__Course_Offering__c couOffering = [select hed__Course__c,Course_Version__c,hed__Term__c,hed__Section_ID__c from hed__Course_Offering__c limit 1];
        
        K42_Program_Alias__c proAlias = new K42_Program_Alias__c();
        proAlias.Program__c = acc.id;
        proAlias.Name = 'Test';
        insert proAlias;
        
        
        hed__Affiliation__c aff = new hed__Affiliation__c();
        aff.hed__Account__c=acc.id;
        aff.hed__Contact__c = con.id;
        aff.hed__Role__c = 'Faculty';
        aff.hed__Status__c = 'Current';
        insert aff;
        
        hed__Plan_Requirement__c planReq = new hed__Plan_Requirement__c();
        planReq.Institute__c = acc.id;
        planReq.hed__Program_Plan__c = prgPlan.id;
        planReq.Term__c = term.id;
        planReq.hed__Course__c = course.id;
        planReq.hed__Category__c = 'Mandatory';
        planReq.RecordTypeId=Schema.SObjectType.hed__Plan_Requirement__c.getRecordTypeInfosByName().get('Unit').getRecordTypeId();
        insert planReq;
        
        hed__Plan_Requirement__c planReq1 = new hed__Plan_Requirement__c();
        planReq1.Institute__c = acc.id;
        planReq1.hed__Program_Plan__c = prgPlan.id;
        planReq1.Term__c = term.id;
        planReq1.hed__Course__c = course.id;
        planReq.hed__Category__c = 'Elective';
        planReq1.RecordTypeId=Schema.SObjectType.hed__Plan_Requirement__c.getRecordTypeInfosByName().get('Unit').getRecordTypeId();
        insert planReq1;
        
       
        
        RestRequest req = new RestRequest(); 
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/MasterSubjects/?';
        req.addParameter('recordId',planReq.id);                
        req.httpMethod = 'Delete';
        RestContext.request = req;
        RestContext.response = res;
        Test.startTest();
        RestApi_CreateMasterSubjects.doDelete();
        Test.stopTest();
        //system.assert(res.statusCode==200);
        
    }
    @isTest
    public static void deleteMethod2(){
         Test.setMock(HttpCalloutMock.class, new MockEnrollmentRespBBClass());
        
       
        
          Account acc = [SELECT Id, Name FROM Account limit 1];
          Contact con = [SELECT Id, LastName, Email, RecordTypeId FROM Contact limit 1];
 		hed__Program_Plan__c prgPlan = new hed__Program_Plan__c();
        prgPlan.name = 'Program plan';
        prgPlan.hed__Account__c = acc.id;
        prgPlan.hed__Start_Date__c = system.today();
        prgPlan.hed__End_Date__c = system.today() + 15;
        prgPlan.hed__Status__c ='Current';
        prgPlan.Intake__c ='Jan';
        prgPlan.Batch__c = '2023';
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
        
        Course_Version__c version = new Course_Version__c();
        version.Course__c =course.id;
        version.Term__c = term.id;
        version.Program_Plan__c = prgPlan.id;
        insert version;
        
        hed__Course_Offering__c couOffering1= new hed__Course_Offering__c();
        couOffering1.hed__Course__c = course.id;
        couOffering1.Course_Version__c = version.id;
        couOffering1.hed__Term__c = term.id;
        couOffering1.hed__Section_ID__c = 'B';
        insert couOffering1;    
        
        hed__Course_Offering__c couOffering = [select hed__Course__c,Course_Version__c,hed__Term__c,hed__Section_ID__c from hed__Course_Offering__c limit 1];
        
        K42_Program_Alias__c proAlias = new K42_Program_Alias__c();
        proAlias.Program__c = acc.id;
        proAlias.Name = 'Test';
        insert proAlias;
        
        
        hed__Affiliation__c aff = new hed__Affiliation__c();
        aff.hed__Account__c=acc.id;
        aff.hed__Contact__c = con.id;
        aff.hed__Role__c = 'Faculty';
        aff.hed__Status__c = 'Current';
        insert aff;
        
        hed__Plan_Requirement__c planReq = new hed__Plan_Requirement__c();
        planReq.Institute__c = acc.id;
        planReq.hed__Program_Plan__c = prgPlan.id;
        planReq.Term__c = term.id;
        planReq.hed__Course__c = course.id;
        planReq.hed__Category__c = 'Mandatory';
        planReq.RecordTypeId=Schema.SObjectType.hed__Plan_Requirement__c.getRecordTypeInfosByName().get('Unit').getRecordTypeId();
        insert planReq;
        
        hed__Plan_Requirement__c planReq1 = new hed__Plan_Requirement__c();
        planReq1.Institute__c = acc.id;
        planReq1.hed__Program_Plan__c = prgPlan.id;
        planReq1.Term__c = term.id;
        planReq1.hed__Course__c = course.id;
        planReq.hed__Category__c = 'Elective';
        planReq1.RecordTypeId=Schema.SObjectType.hed__Plan_Requirement__c.getRecordTypeInfosByName().get('Unit').getRecordTypeId();
        insert planReq1;
        
        RestRequest req = new RestRequest(); 
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/MasterSubjects/?';
        //  req.addParameter('recordId',planReqId.id);                
        req.httpMethod = 'Delete';
        RestContext.request = req;
        RestContext.response = res;
        Test.startTest();
        RestApi_CreateMasterSubjects.doDelete();
        Test.stopTest();
        //system.assert(res.statusCode==200);
        
    }
    @isTest
    public static void deleteMethod3(){
   
        
       Test.setMock(HttpCalloutMock.class, new MockEnrollmentRespBBClass());
        
          Account acc = [SELECT Id, Name FROM Account limit 1];
          Contact con = [SELECT Id, LastName, Email, RecordTypeId FROM Contact limit 1];
 		hed__Program_Plan__c prgPlan = new hed__Program_Plan__c();
        prgPlan.name = 'Program plan';
        prgPlan.hed__Account__c = acc.id;
        prgPlan.hed__Start_Date__c = system.today();
        prgPlan.hed__End_Date__c = system.today() + 15;
        prgPlan.hed__Status__c ='Current';
        prgPlan.Intake__c ='Jan';
        prgPlan.Batch__c = '2023';
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
        
        Course_Version__c version = new Course_Version__c();
        version.Course__c =course.id;
        version.Term__c = term.id;
        version.Program_Plan__c = prgPlan.id;
        insert version;
        
        hed__Course_Offering__c couOffering1= new hed__Course_Offering__c();
        couOffering1.hed__Course__c = course.id;
        couOffering1.Course_Version__c = version.id;
        couOffering1.hed__Term__c = term.id;
        couOffering1.hed__Section_ID__c = 'B';
        insert couOffering1;    
        
        hed__Course_Offering__c couOffering = [select hed__Course__c,Course_Version__c,hed__Term__c,hed__Section_ID__c from hed__Course_Offering__c limit 1];
        
        K42_Program_Alias__c proAlias = new K42_Program_Alias__c();
        proAlias.Program__c = acc.id;
        proAlias.Name = 'Test';
        insert proAlias;
        
        
        hed__Affiliation__c aff = new hed__Affiliation__c();
        aff.hed__Account__c=acc.id;
        aff.hed__Contact__c = con.id;
        aff.hed__Role__c = 'Faculty';
        aff.hed__Status__c = 'Current';
        insert aff;
        
        hed__Plan_Requirement__c planReq = new hed__Plan_Requirement__c();
        planReq.Institute__c = acc.id;
        planReq.hed__Program_Plan__c = prgPlan.id;
        planReq.Term__c = term.id;
        planReq.hed__Course__c = course.id;
        planReq.hed__Category__c = 'Mandatory';
        planReq.RecordTypeId=Schema.SObjectType.hed__Plan_Requirement__c.getRecordTypeInfosByName().get('Unit').getRecordTypeId();
        insert planReq;
        
        hed__Plan_Requirement__c planReq1 = new hed__Plan_Requirement__c();
        planReq1.Institute__c = acc.id;
        planReq1.hed__Program_Plan__c = prgPlan.id;
        planReq1.Term__c = term.id;
        planReq1.hed__Course__c = course.id;
        planReq.hed__Category__c = 'Elective';
        planReq1.RecordTypeId=Schema.SObjectType.hed__Plan_Requirement__c.getRecordTypeInfosByName().get('Unit').getRecordTypeId();
        insert planReq1;
        
        
        RestRequest req = new RestRequest(); 
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/MasterSubjects/?';
        req.addParameter('recordId','2345dfghj');                
        req.httpMethod = 'Delete';
        RestContext.request = req;
        RestContext.response = res;
        Test.startTest();
        RestApi_CreateMasterSubjects.doDelete();
        Test.stopTest();
        //system.assert(res.statusCode==200);
        
    }
    @isTest
    public static void postMethod1(){
        
      Test.setMock(HttpCalloutMock.class, new MockEnrollmentRespBBClass());
        
          Account acc = [SELECT Id, Name FROM Account limit 1];
          Contact con = [SELECT Id, LastName, Email, RecordTypeId FROM Contact limit 1];
 		hed__Program_Plan__c prgPlan = new hed__Program_Plan__c();
        prgPlan.name = 'Program plan';
        prgPlan.hed__Account__c = acc.id;
        prgPlan.hed__Start_Date__c = system.today();
        prgPlan.hed__End_Date__c = system.today() + 15;
        prgPlan.hed__Status__c ='Current';
        prgPlan.Intake__c ='Jan';
        prgPlan.Batch__c = '2023';
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
        
        Course_Version__c version = new Course_Version__c();
        version.Course__c =course.id;
        version.Term__c = term.id;
        version.Program_Plan__c = prgPlan.id;
        insert version;
        
        hed__Course_Offering__c couOffering1= new hed__Course_Offering__c();
        couOffering1.hed__Course__c = course.id;
        couOffering1.Course_Version__c = version.id;
        couOffering1.hed__Term__c = term.id;
        couOffering1.hed__Section_ID__c = 'B';
        insert couOffering1;    
        
        hed__Course_Offering__c couOffering = [select hed__Course__c,Course_Version__c,hed__Term__c,hed__Section_ID__c from hed__Course_Offering__c limit 1];
        
        K42_Program_Alias__c proAlias = new K42_Program_Alias__c();
        proAlias.Program__c = acc.id;
        proAlias.Name = 'Test';
        insert proAlias;
        
        
        hed__Affiliation__c aff = new hed__Affiliation__c();
        aff.hed__Account__c=acc.id;
        aff.hed__Contact__c = con.id;
        aff.hed__Role__c = 'Faculty';
        aff.hed__Status__c = 'Current';
        insert aff;
        
        hed__Plan_Requirement__c planReq = new hed__Plan_Requirement__c();
        planReq.Institute__c = acc.id;
        planReq.hed__Program_Plan__c = prgPlan.id;
        planReq.Term__c = term.id;
        planReq.hed__Course__c = course.id;
        planReq.hed__Category__c = 'Mandatory';
        planReq.RecordTypeId=Schema.SObjectType.hed__Plan_Requirement__c.getRecordTypeInfosByName().get('Unit').getRecordTypeId();
        insert planReq;
        
        hed__Plan_Requirement__c planReq1 = new hed__Plan_Requirement__c();
        planReq1.Institute__c = acc.id;
        planReq1.hed__Program_Plan__c = prgPlan.id;
        planReq1.Term__c = term.id;
        planReq1.hed__Course__c = course.id;
        planReq.hed__Category__c = 'Elective';
        planReq1.RecordTypeId=Schema.SObjectType.hed__Plan_Requirement__c.getRecordTypeInfosByName().get('Unit').getRecordTypeId();
        insert planReq1;
        
        
        string body = '[{"departmentId":"'+acc.id+'","courseId":"'+course.id+'","termNumber":"Term 1","specializationId":"'+acc.id+'","category":"Mandatory","preRequisitesCourseId1":"'+course.id+'","preRequisitesCourseId2":"","preRequisitesCourseId3":"","preRequisitesCourseId4":"","preRequisitesCourseId5":"","preRequisitesCourseId6":"","offset":"10","duration":"10"}]';
        
        RestRequest req = new RestRequest(); 
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/MasterSubjects/';
        req.requestBody =  Blob.valueof(body);            
        req.httpMethod = 'Post';
        RestContext.request = req;
        RestContext.response = res;
        Test.startTest();
        RestApi_CreateMasterSubjects.create();
        Test.stopTest();
        //system.assert(res.statusCode==200);
        
    }
    
}