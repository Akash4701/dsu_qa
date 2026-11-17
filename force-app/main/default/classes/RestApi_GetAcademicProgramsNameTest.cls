@isTest
public class RestApi_GetAcademicProgramsNameTest {
 @TestSetup
    static void setupTestData() {
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
        // Create Record Types
         Id academicProgramRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Academic_Program').getRecordTypeId();
        Id universityDepartmentRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('University_Department').getRecordTypeId();
        // Create Accounts (Academic Programs and University Departments)
        Account academicProgram = new Account(Name = 'Test Academic Program', RecordTypeId =academicProgramRtId, Number_of_Terms__c = '2', Course_duration__c = '1 years 6 months', Program_Duration_in_Weeks__c = 52, Duration_Per_Session__c = 3);
        Account universityDepartment = new Account(Name = 'Test University Department', RecordTypeId = universityDepartmentRtId);
        insert new List<Account>{academicProgram, universityDepartment};

        // Create Campus
        Campus__c campus = new Campus__c();
        campus.Name = 'Main Campus';
        campus.Campus_ID__c='SNG';
        insert campus;

        // Create Terms
        hed__Term__c term1 = new hed__Term__c();
        term1.Name = 'Fall 2023';
        term1.hed__Account__c = academicProgram.Id;
        term1.Term_Reference__c='Term 1';
        insert term1;

        // Create Program Alias
        K42_Program_Alias__c programAlias = new K42_Program_Alias__c(Name = 'Alias Program', Program__c = academicProgram.Id);
        insert programAlias;

        // Create Course
        hed__Course__c course = new hed__Course__c(Name = 'Test Course', hed__Account__c = academicProgram.Id, Credits__c = 3, hed__Course_ID__c = 'C101');
        insert course;

        // Create Program Campus Relationships
        Program_Campus_Relationship__c programCampus = new Program_Campus_Relationship__c(Program__c = academicProgram.Id, Combination_Name__c = 'Main Campus Combination');
        insert programCampus;
    }
    
    @IsTest
    static void testDoGetAcademicProgramsName() {
        // Mock the RestContext
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/AcademicProgramsName';
        RestContext.request = req;
        RestContext.response = res;

        // Call the method
        RestApi_GetAcademicProgramsName.doGetAcademicProgramsName();

        // Validate the response
        Assert.areEqual(200, res.statusCode);
        String jsonResponse = res.responseBody.toString();
        Assert.isTrue(jsonResponse.contains('Test Academic Program'), 'Response does not contain the expected Academic Program name.');
        Assert.isTrue(jsonResponse.contains('Test University Department'), 'Response does not contain the expected University Department name.');
        Assert.isTrue(jsonResponse.contains('Main Campus'), 'Response does not contain the expected Campus name.');
        Assert.isTrue(jsonResponse.contains('Test Course'), 'Response does not contain the expected Course name.');
        Assert.isTrue(jsonResponse.contains('Alias Program'), 'Response does not contain the expected Program Alias name.');
        //System.assert(jsonResponse.contains('Main Campus Combination'), 'Response does not contain the expected Program Campus Relationship name.');
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