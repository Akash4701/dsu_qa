@IsTest
public class RestApi_GetMasterSubjectsWithTermTest {
    
    @TestSetup
    static void setup() {
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
       Account academicProg= new Account();
        academicProg.Name='The First Principle Thinking';
        academicProg.RecordTypeId=schema.SObjectType.Account.getRecordTypeinfosbyname().get('Academic Program').getRecordTypeId();
        insert academicProg;

        
        // Create a mock Term
        hed__Term__c term = new hed__Term__c(
            Name = 'Test Term',
            hed__Account__c = academicProg.Id,
            Term_Reference__c = 'Term 1',
          RecordTypeId = Schema.SObjectType.hed__Term__c.getRecordTypeInfosByName().get('Master Record').getRecordTypeId()
        );
        insert term;
        
        // Create a mock Plan Requirement
        hed__Plan_Requirement__c planRequirement = new hed__Plan_Requirement__c(
            Name = 'Test Plan Requirement',
            Term__c = term.Id,
            RecordTypeId = Schema.SObjectType.hed__Plan_Requirement__c.getRecordTypeInfosByName().get('Master Group').getRecordTypeId(),
            Institute__c= academicProg.id
        );
        insert planRequirement;
        
        hed__Course__c course = new hed__Course__c(
            Name = 'Test Course', hed__Course_ID__c = 'C001', Credits__c = 3.0, hed__Credit_Hours__c = 3.0,hed__Account__c = academicProg.id
        );
        insert course;
        
        // Create a mock child Plan Requirement
        hed__Plan_Requirement__c childPlanRequirement = new hed__Plan_Requirement__c();
        childPlanRequirement.Name = 'Test Child Plan Requirement';
        childPlanRequirement.hed__Plan_Requirement__r = planRequirement;
        childPlanRequirement.RecordTypeId = Schema.SObjectType.hed__Plan_Requirement__c.getRecordTypeInfosByName().get('Master Unit').getRecordTypeId();
        childPlanRequirement.hed__Course__c = course.id;
        childPlanRequirement.hed__Plan_Requirement__c=planRequirement.id;
        childPlanRequirement.Offset__c=2;
        childPlanRequirement.hed__Category__c='Mandatory';
        childPlanRequirement.Exam_Required__c=true;
        childPlanRequirement.Number_of_Sessions__c=2;
        insert childPlanRequirement;
        
        
        // Create mock Activities
        Activity__c activity = new Activity__c(
            Name = 'Test Activity',
            Activity_type__c = 'Teaching',
            Course__r = childPlanRequirement.hed__Course__r,
          //  Week_No__c = 1,
            Offset__c = 0.0,
            RecordTypeId = Schema.SObjectType.Activity__c.getRecordTypeInfosByName().get('Master Record').getRecordTypeId(),
            Activity_Duration__c = 2.0
        );
        insert activity;
    }
    
    @IsTest
    static void testDoGetActivityDataWithAcademicProgramIdAndTermNumber() {
        LMS_URL__c URL = new LMS_URL__c(Name = 'course url',Bulk_Enroll__c = 'TestUrl');
        insert URL;
        LMS_URL__c URL1 = new LMS_URL__c(Name = 'course offering url',Bulk_Enroll__c = 'TestUrl');
        insert URL1;
        LMS_URL__c URL2 = new LMS_URL__c(Name = 'Bulk Enrollment',Bulk_Enroll__c = 'TestUrl');
        insert URL2;
        Account testAccount = new Account(Name = 'Test Account', LMS_Id__c = '12345');
        insert testAccount;
        // Set the request parameters
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/MasterSubjectsWithTermData/';
        req.httpMethod = 'GET';
        req.params.put('academicProgramId', [SELECT Id,RecordTypeId FROM Account WHERE Name = 'The First Principle Thinking' LIMIT 1].Id);
        req.params.put('termNumber', '1');
        RestContext.request = req;
        
        // Set the response
        RestResponse res = new RestResponse();
        RestContext.response = res;
        
        // Call the method
        RestApi_GetMasterSubjectsWithTerm.doGetActivityData();
        
       
        
        // Additional assertions to verify the response content can be added here
    }
    
    @IsTest
    static void testDoGetActivityDataWithoutAcademicProgramId() {
        LMS_URL__c URL = new LMS_URL__c(Name = 'course url',Bulk_Enroll__c = 'TestUrl');
        insert URL;
        LMS_URL__c URL1 = new LMS_URL__c(Name = 'course offering url',Bulk_Enroll__c = 'TestUrl');
        insert URL1;
        LMS_URL__c URL2 = new LMS_URL__c(Name = 'Bulk Enrollment',Bulk_Enroll__c = 'TestUrl');
        insert URL2;
        Account testAccount = new Account(Name = 'Test Account', LMS_Id__c = '12345');
        insert testAccount;
        // Set the request parameters
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/MasterSubjectsWithTermData/';
        req.httpMethod = 'GET';
        req.params.put('academicProgramId', [SELECT Id FROM hed__Term__c LIMIT 1].Id);
        RestContext.request = req;
        
        // Set the response
        RestResponse res = new RestResponse();
        RestContext.response = res;
        
        // Call the method
        RestApi_GetMasterSubjectsWithTerm.doGetActivityData();
      
    }
    
    @IsTest
    static void testDoGetActivityDataWithNoTermsFound() {
        LMS_URL__c URL = new LMS_URL__c(Name = 'course url',Bulk_Enroll__c = 'TestUrl');
        insert URL;
        LMS_URL__c URL1 = new LMS_URL__c(Name = 'course offering url',Bulk_Enroll__c = 'TestUrl');
        insert URL1;
        LMS_URL__c URL2 = new LMS_URL__c(Name = 'Bulk Enrollment',Bulk_Enroll__c = 'TestUrl');
        insert URL2;
        Account testAccount = new Account(Name = 'Test Account', LMS_Id__c = '12345');
        insert testAccount;
        // Set the request parameters
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/MasterSubjectsWithTermData/';
        req.httpMethod = 'GET';
        req.addParameter('academicProgramId', 'invalidid'); // Invalid Id to simulate no terms found
        req.addParameter('termNumber', 'invalidnumber');
        RestContext.request = req;
        
        // Set the response
        RestResponse res = new RestResponse();
        RestContext.response = res;
        
        // Call the method
        RestApi_GetMasterSubjectsWithTerm.doGetActivityData();
        
      // RestApi_GetMasterSubjectsWithTerm.testCoverage();
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