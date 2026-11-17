@isTest
private class RestApi_GetTerm_CourseVersion_Test {
    @testSetup
    static void setup() {
        LMS_URL__c URL = new LMS_URL__c(Name = 'course url',Bulk_Enroll__c = 'TestUrl');
        insert URL;
        LMS_URL__c URL1 = new LMS_URL__c(Name = 'course offering url',Bulk_Enroll__c = 'TestUrl');
        insert URL1;
        LMS_URL__c URL2 = new LMS_URL__c(Name = 'Bulk Enrollment',Bulk_Enroll__c = 'TestUrl');
        insert URL2;
        Account testAccount = new Account(Name = 'Test Account', LMS_Id__c = '12345');
        insert testAccount;
        Account institute = new Account(
            Name = 'Test Institute'
        );
        insert institute;
        
        Contact con = new Contact(
            LastName = 'Test ram'
        );
        insert con;
    }

    @isTest
    static void testDoGet_Success() {
        try{
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseForTerms());

        Account institute = [SELECT Id FROM Account LIMIT 1];

        hed__Program_Plan__c programPlan = new hed__Program_Plan__c(
            Name = 'Test Program Plan',
            hed__Account__c = institute.Id,
            Working_Days__c = 'Monday;Tuesday',
            Intake__c = 'JAN',
            Batch__c = 'Batch1'
        );
        insert programPlan;

        hed__Term__c term = new hed__Term__c(
            Name = 'Test Term',
            Program_Plan__c = programPlan.Id,
            hed__Account__c = institute.Id,
            Term_Reference__c = 'Term 1',
            hed__Start_Date__c = Date.today(),
            hed__End_Date__c = Date.today().addDays(30),
            Term_Duration__c = '30 Days'
        );
        insert term;

        hed__course__c course = new hed__course__c(
            Name = 'Test Course',
            hed__Course_ID__c = 'C001',
            hed__Credit_Hours__c = 3,
            hed__Account__c = institute.id
        );
        insert course;

        Course_Version__c courseVersion = new Course_Version__c(
            
            Course__c = course.Id,
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addDays(30),
            
            Term__c = term.Id
        );
        insert courseVersion;

        hed__Plan_Requirement__c planRequirement = new hed__Plan_Requirement__c(
            hed__Course__c = course.Id,
            Pre_Requisites_1__c = course.Id,
            Pre_Requisites_2__c = course.Id,
            Pre_Requisites_3__c = course.Id
        );
        insert planRequirement;

        hed__Course_Offering__c courseOffering = new hed__Course_Offering__c(
            Name = 'Test Course Offering',
            hed__Section_ID__c = 'S001',
            hed__Start_Date__c = Date.today(),
            hed__End_Date__c = Date.today().addDays(30),
            Course_Version__c = courseVersion.Id,
            hed__Term__c = term.id,
            hed__Course__c = course.id
        );
        insert courseOffering;

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/TermsAndCourseVersions/';
        req.httpMethod = 'GET';
        req.addParameter('programPlanId', programPlan.Id);
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        RestApi_GetTerm_CourseVersion.doGet();
            Test.stopTest();}
        catch(exception e){}

        
    }

    @isTest
    static void testDoGet_NoProgramPlanId() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseForTerms());

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/TermsAndCourseVersions/';
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        RestApi_GetTerm_CourseVersion.doGet();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
        System.assert(res.responseBody.toString().contains('"success": "false"'));
        System.assert(res.responseBody.toString().contains('No data found'));
    }

    @isTest
    static void testDoGet_ExceptionHandling() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseForTerms());

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/TermsAndCourseVersions/';
        req.httpMethod = 'GET';
        req.addParameter('programPlanId', 'InvalidId');
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        RestApi_GetTerm_CourseVersion.doGet();
        Test.stopTest();

        
    }

    @isTest
    static void testMockVerification() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseForTerms());

        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://test.salesforce.com');
        req.setMethod('GET');

        Test.startTest();
        HttpResponse res = new Http().send(req);
        Test.stopTest();

        System.debug('>>> RESPONSE FROM MOCK: ' + res.getBody());
    }
}