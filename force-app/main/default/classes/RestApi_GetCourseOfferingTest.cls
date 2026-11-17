@isTest
public class RestApi_GetCourseOfferingTest {
    @testSetup 
    static void mainClass() {  
        LMS_URL__c URL = new LMS_URL__c(Name = 'course url',Bulk_Enroll__c = 'TestUrl');
        insert URL;
        LMS_URL__c URL1 = new LMS_URL__c(Name = 'course offering url',Bulk_Enroll__c = 'TestUrl');
        insert URL1;
        LMS_URL__c URL2 = new LMS_URL__c(Name = 'Bulk Enrollment',Bulk_Enroll__c = 'TestUrl');
        insert URL2;
        Account testAccount = new Account(Name = 'Test Account', LMS_Id__c = '12345');
        insert testAccount;
        Account acc = new Account();
        acc.Name = 'test';
        insert acc;

        Contact con = new Contact();
        con.lastname = 'Test Raja';
        insert con;
    }

    @IsTest
    static void testGetCourseOfferingData() {
        Test.setMock(HttpCalloutMock.class, new MockEnrollmentRespBBClass());
        
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Contact con = [SELECT Id, Name FROM Contact LIMIT 1];
        
        Campus__c camp = new Campus__c();
        camp.Name = 'test';
        camp.Campus_ID__c = 'SNG';
        insert camp;
        
        // Create Terms
        hed__Term__c tr = new hed__Term__c();
        tr.Name = '2040-Jul-PS-Term';
        tr.hed__Account__c = acc.Id;
        tr.hed__Start_Date__c = System.today();
        tr.hed__End_Date__c = System.today().addDays(7);
        tr.hed__Grading_Period_Sequence__c = 10;
        tr.Campus__c = camp.Id;
        tr.hed__Type__c = 'School Year';
        tr.hed__Instructional_Days__c = 20;
        tr.RecordTypeId = Schema.SObjectType.hed__Term__c.getRecordTypeInfosByName().get('Default Record').getRecordTypeId();
        tr.Term_Reference__c = 'Term 1';
        insert tr;
        
        hed__Course__c course = new hed__Course__c();
        course.Name = 'test';
        course.hed__Course_ID__c = 'test';
        course.Credits__c = 1;
        course.hed__Account__c = acc.Id;
        insert course;
        
        Course_Version__c courseVersion = new Course_Version__c();
        courseVersion.Course__c = course.Id;
        courseVersion.Term__c = tr.Id;
        courseVersion.Start_Date__c = System.today();
        courseVersion.End_Date__c = System.today().addDays(1);
        insert courseVersion;
        
        hed__Course_Offering__c courseOffering = new hed__Course_Offering__c();
        courseOffering.Course_Version__c = courseVersion.Id;
        courseOffering.hed__Course__c = course.Id;
        courseOffering.hed__Term__c = tr.Id;
        courseOffering.Name = 'Test CourseOffering';
        courseOffering.hed__Section_ID__c = 'A';
        courseOffering.Course_Specialisation__c = acc.Id;
        courseOffering.hed__Start_Date__c = Date.today();
        courseOffering.hed__End_Date__c = Date.today().addMonths(3); 
        courseOffering.hed__Faculty__c=con.id;
        insert courseOffering;
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/CourseOfferingData/';
        req.addParameter('courseVersionId', String.valueOf(courseVersion.Id));
        req.addParameter('courseOfferingName', courseOffering.Name);
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = res;

        // Call the method
        Test.startTest();
        RestApi_GetCourseOffering.doGetGetCourseOfferingData();
        Test.stopTest();

        // Verify the response
        String response = res.responseBody.toString();
        System.assertEquals(200, res.statusCode);

        // Deserialize the response
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(response);
        
        // Verify the response data
        System.assert(responseMap.containsKey(courseOffering.Name));
        
        Map<String, Object> responseDataMap = (Map<String, Object>) responseMap.get(courseOffering.Name);
        RestApi_GetCourseOffering.responseCourseOfferingDataWrapper responseData = new RestApi_GetCourseOffering.responseCourseOfferingDataWrapper();
        responseData.id = (String) responseDataMap.get('id');
        responseData.courseOfferingID = (String) responseDataMap.get('courseOfferingID');
        responseData.courseName = (String) responseDataMap.get('courseName');
        responseData.courseId = (String) responseDataMap.get('courseId');
        responseData.courseSpecialisationId = (String) responseDataMap.get('courseSpecialisationId');
        responseData.courseSpecialisationName = (String) responseDataMap.get('courseSpecialisationName');
        responseData.courseVersionId = (String) responseDataMap.get('courseVersionId');
        responseData.termId = (String) responseDataMap.get('termId');
        responseData.courseOfferingSectionId = (String) responseDataMap.get('courseOfferingSectionId');
        responseData.courseOfferingCapacity = (Decimal) responseDataMap.get('courseOfferingCapacity');
        responseData.facultyName = (String) responseDataMap.get('facultyName');
        responseData.facultyId = (String) responseDataMap.get('facultyId');
        responseData.startDate = (String) responseDataMap.get('startDate');
        responseData.endDate = (String) responseDataMap.get('endDate');

        
    }

    @IsTest
    static void testGetCourseOfferingData_NoParams() {
        Test.setMock(HttpCalloutMock.class, new MockEnrollmentRespBBClass());

        // Set the parameters for the request with no filters
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/CourseOfferingData/';
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = res;

        // Call the method
        Test.startTest();
        RestApi_GetCourseOffering.doGetGetCourseOfferingData();
        Test.stopTest();

        // Verify the response
        String response = res.responseBody.toString();
        System.assertEquals(200, res.statusCode);

        // Deserialize the response
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(response);
        
        // Verify the response data
        System.assert(!responseMap.isEmpty());
    }
}