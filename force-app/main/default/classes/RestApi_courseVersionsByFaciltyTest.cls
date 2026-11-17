@IsTest
public class RestApi_courseVersionsByFaciltyTest {
    @testSetup()
    static void testDataSetup(){
        LMS_URL__c URL = new LMS_URL__c(Name = 'course url',Bulk_Enroll__c = 'TestUrl');
        insert URL;
        LMS_URL__c URL1 = new LMS_URL__c(Name = 'course offering url',Bulk_Enroll__c = 'TestUrl');
        insert URL1;
        LMS_URL__c URL2 = new LMS_URL__c(Name = 'Bulk Enrollment',Bulk_Enroll__c = 'TestUrl');
        insert URL2;
        Account testAccount = new Account(Name = 'Test Account', LMS_Id__c = '12345');
        insert testAccount;
         
        
        Contact testContact = new Contact(FirstName = 'John', LastName = 'Doe', AccountId = testAccount.Id);
        insert testContact;
    }
    
    @IsTest
    static void testGetAttendanceWithFacilityId() {
        Test.setMock(HttpCalloutMock.class, new MockEnrollmentRespBBClass());
       Account testAccount=[Select Id from Account LIMIT 1];
	  Contact testContact=[Select Id,FirstName,LastName,AccountId from Contact LIMIT 1];
        hed__Facility__c testFacility = new hed__Facility__c(Name = 'Test Facility');
        insert testFacility;

        hed__Term__c testTerm = new hed__Term__c(
            Name = 'Test Term',
                                                 hed__Account__c = testAccount.id,
            Term_Reference__c ='test');
        insert testTerm;

        hed__Course__c testCourse = new hed__Course__c(
            Name = 'Test Course',
            hed__Account__c = testAccount.id
           
        );
        insert testCourse;

        Course_Version__c testCourseVersion = new Course_Version__c(
            Course__c = testCourse.Id,
            Term__c = testTerm.Id,
            Facilities__c = testFacility.Id,
            Start_Date__c = Date.today(),
            Subject_End_Date__c = Date.today().addDays(30),
           // WeekNo__c = 1,
            Subject_Offset__c = 0,
            Faculties__c = testContact.FirstName + '-' + testContact.Id
        );
        insert testCourseVersion;

        // Set up the REST request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/courseVersionsByFacility/';
        req.params.put('facilityId', testFacility.Id);
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = res;
        
        // Test the REST method
        Test.startTest();
        RestApi_courseVersionsByFacilty.getAttendance();
        Test.stopTest();

        // Verify the response
        System.assertEquals(200, res.statusCode);
        String jsonResponse = res.responseBody.toString();
        System.assert(jsonResponse.contains(testCourse.Name), 'Response does not contain course name');
        System.assert(jsonResponse.contains(testTerm.Name), 'Response does not contain term name');
        System.assert(jsonResponse.contains(testFacility.Name), 'Response does not contain facility name');
    }
    
    @IsTest
    static void testGetAttendanceWithoutFacilityId() {
        // Set up the REST request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/courseVersionsByFacility/';
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = res;
        
        // Test the REST method
        Test.startTest();
        RestApi_courseVersionsByFacilty.getAttendance();
        Test.stopTest();

        // Verify the response
        Assert.areEqual(200, res.statusCode);
        String jsonResponse = res.responseBody.toString();
        Assert.isTrue(jsonResponse.contains('"success":"false"'), 'Response should indicate failure');
        Assert.isTrue(jsonResponse.contains('"message":"enter facility Id.."'), 'Response should prompt for facility ID');
    }
    
   
}