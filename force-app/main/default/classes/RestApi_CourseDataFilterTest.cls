@isTest
private class RestApi_CourseDataFilterTest {

    @testSetup
    static void setupTestData() {
        LMS_URL__c URL = new LMS_URL__c(Name = 'course url',Bulk_Enroll__c = 'TestUrl');
        insert URL;
        LMS_URL__c URL1 = new LMS_URL__c(Name = 'course offering url',Bulk_Enroll__c = 'TestUrl');
        insert URL1;
        LMS_URL__c URL2 = new LMS_URL__c(Name = 'Bulk Enrollment',Bulk_Enroll__c = 'TestUrl');
        insert URL2;
        Account testAccount = new Account(Name = 'Test Account', LMS_Id__c = '12345');
        insert testAccount;
        Account institute = new Account(Name = 'Test Institute');
        insert institute;     
    }

    @isTest
    static void testDoGetCourseData() {
         Test.setMock(HttpCalloutMock.class, new MockEnrollmentRespBBClass());
        Account institute=[Select Id from Account Limit 1];
        
        hed__Course__c course = new hed__Course__c(Name = 'Test Course 1', hed__Account__c = institute.Id);
        insert course;

        Contact facultyContact = new Contact(
            LastName = 'Faculty',
            RecordTypeId = [SELECT Id FROM RecordType WHERE SObjectType = 'Contact' AND Name = 'Faculty' LIMIT 1].Id
        );
        insert facultyContact;

        hed__Facility__c facility = new hed__Facility__c(Name = 'Test Facility');
        insert facility;

        hed__Term__c term = new hed__Term__c(
            Name = 'Test Term',
            hed__End_Date__c = Date.today().addMonths(1),
            hed__Account__c = institute.Id,
            Term_Reference__c = 'TermRef 1'
        );
        insert term;

        hed__Course_Offering__c courseOffering = new hed__Course_Offering__c(
            Name = 'Test Course Offering',
            hed__Course__c = course.Id,
            hed__Faculty__c = facultyContact.Id,
            hed__Facility__c = facility.Id,
            hed__Start_Date__c = Date.today(),
            hed__End_Date__c = Date.today().addMonths(1),
            hed__Term__c = term.Id
        );
        insert courseOffering;

      
        hed__Course_Offering__c courseOfferingNoRelations = new hed__Course_Offering__c(
            Name = 'Test Course Offering No Relations',
            hed__Course__c = course.Id,
            hed__Start_Date__c = Date.today(),
            hed__End_Date__c = Date.today().addMonths(1),
            hed__Term__c = term.Id
        );
        insert courseOfferingNoRelations;
        
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/SubjectPageFilter';
        req.httpMethod = 'GET';
        RestContext.request = req;
        
        RestResponse res = new RestResponse();
        RestContext.response = res;

        Test.startTest();
        RestApi_CourseDataFilter.doGetCourseData();
        Test.stopTest();

        res = RestContext.response;
        Assert.areEqual(200, res.statusCode, 'Status code should be 200');
        
        String responseBody = res.responseBody.toString();
      Assert.isTrue(responseBody.contains('CourseOfferingRecordId'), 'Response should contain CourseOfferingRecordId');
      Assert.isTrue(responseBody.contains('Course 1'), 'Response should contain Course 1');
           }

    @isTest
    static void testDoGetCourseDataNoData() {
         Test.setMock(HttpCalloutMock.class, new MockEnrollmentRespBBClass());
          Account institute=[Select Id from Account Limit 1];
        hed__Course__c course = new hed__Course__c(Name = 'Test Course 1', hed__Account__c = institute.Id);
        insert course;

        Contact facultyContact = new Contact(
            LastName = 'Faculty',
            RecordTypeId = [SELECT Id FROM RecordType WHERE SObjectType = 'Contact' AND Name = 'Faculty' LIMIT 1].Id
        );
        insert facultyContact;

        hed__Facility__c facility = new hed__Facility__c(Name = 'Test Facility');
        insert facility;

        hed__Term__c term = new hed__Term__c(
            Name = 'Test Term',
            hed__End_Date__c = Date.today().addMonths(1),
            hed__Account__c = institute.Id,
            Term_Reference__c = 'TermRef 1'
        );
        insert term;

        hed__Course_Offering__c courseOffering = new hed__Course_Offering__c(
            Name = 'Test Course Offering',
            hed__Course__c = course.Id,
            hed__Faculty__c = facultyContact.Id,
            hed__Facility__c = facility.Id,
            hed__Start_Date__c = Date.today(),
            hed__End_Date__c = Date.today().addMonths(1),
            hed__Term__c = term.Id
        );
        insert courseOffering;

        hed__Course_Offering__c courseOfferingNoRelations = new hed__Course_Offering__c(
            Name = 'Test Course Offering No Relations',
            hed__Course__c = course.Id,
            hed__Start_Date__c = Date.today(),
            hed__End_Date__c = Date.today().addMonths(1),
            hed__Term__c = term.Id
        );
        insert courseOfferingNoRelations;
        
        delete courseOfferingNoRelations;

        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/SubjectPageFilter';
        req.httpMethod = 'GET';
        RestContext.request = req;
        
        RestResponse res = new RestResponse();
        RestContext.response = res;

        Test.startTest();
        RestApi_CourseDataFilter.doGetCourseData();
        Test.stopTest();

        // Assert the response
        res = RestContext.response;
        Assert.areEqual(200, res.statusCode, 'Status code should be 200');
       
        String responseBody = res.responseBody.toString();
      
    }
}