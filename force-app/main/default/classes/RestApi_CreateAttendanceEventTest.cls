@IsTest
public class RestApi_CreateAttendanceEventTest {
    
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
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Contact'
        );
        insert testContact;
        hed__Facility__c facility = new hed__Facility__c(
            Name = 'Test'
        );
        insert facility;
Session__c testSession = new Session__c(
    Type_of_Activity__c = 'Teaching',
    Faculty__c = testContact.Id,
    Start_Date_Time__c = DateTime.now(),
    End_Date_Time__c = DateTime.now().addHours(1),
    Facility__c = facility.id,
    Mode_of_Delivery__c = 'Online'
);
insert testSession;

         
        hed__Attendance_Event__c testEvent = new hed__Attendance_Event__c(
            hed__Contact__c = testContact.Id,
            Attendance_Status__c = 'Present',
            Session__c = testSession.Id
        );
        insert testEvent;
    }

 @IsTest
static void testDoCreateAttendanceEvent() {
    Test.startTest();

    RestApi_CreateAttendanceEvent.requestAttendanceEventWrapper requestWrapper = new RestApi_CreateAttendanceEvent.requestAttendanceEventWrapper();
    requestWrapper.AttendanceEvent = new List<RestApi_CreateAttendanceEvent.requestAttendanceEventDataWrapper>();
    
    RestApi_CreateAttendanceEvent.requestAttendanceEventDataWrapper requestData = new RestApi_CreateAttendanceEvent.requestAttendanceEventDataWrapper();
    requestData.contactId = [SELECT Id FROM Contact LIMIT 1].Id;
    requestData.sessionId = [SELECT Id FROM Session__c LIMIT 1].Id;
    requestData.attendanceStatus = 'Absent';
    requestData.reasonType = 'Sick';
    requestData.reasonDescription = 'Flu';
    requestWrapper.AttendanceEvent.add(requestData);
    
    String jsonRequest = JSON.serialize(requestWrapper);
    
    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();
    req.requestUri = '/services/apexrest/createAttendanceEvent';
    req.httpMethod = 'POST';
    req.requestBody = Blob.valueOf(jsonRequest);
    RestContext.request = req;
    RestContext.response = res;
    
    RestApi_CreateAttendanceEvent.doCreateAttendanceEvent();
    Test.stopTest();
    
    System.assertEquals(200, res.statusCode);
    String jsonResponse = res.responseBody.toString();
    RestApi_CreateAttendanceEvent.responseAttendanceEventWrapper responseWrapper = (RestApi_CreateAttendanceEvent.responseAttendanceEventWrapper) JSON.deserialize(jsonResponse, RestApi_CreateAttendanceEvent.responseAttendanceEventWrapper.class);
    
    System.assertEquals('true', responseWrapper.AttendanceEvent[0].success);
    System.assertEquals('Data is Upserted', responseWrapper.AttendanceEvent[0].message);
}

    @IsTest
    static void testDoCreateAttendanceEventWithBadRequest() {
                Test.startTest();

        RestApi_CreateAttendanceEvent.requestAttendanceEventWrapper requestWrapper = new RestApi_CreateAttendanceEvent.requestAttendanceEventWrapper();
        requestWrapper.AttendanceEvent = new List<RestApi_CreateAttendanceEvent.requestAttendanceEventDataWrapper>();
        
        RestApi_CreateAttendanceEvent.requestAttendanceEventDataWrapper requestData = new RestApi_CreateAttendanceEvent.requestAttendanceEventDataWrapper();
        requestWrapper.AttendanceEvent.add(requestData);
        
        String jsonRequest = JSON.serialize(requestWrapper);
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/createAttendanceEvent';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(jsonRequest);
        RestContext.request = req;
        RestContext.response = res;
        
        RestApi_CreateAttendanceEvent.doCreateAttendanceEvent();
        Test.stopTest();
        
        System.assertEquals(200, res.statusCode);
        String jsonResponse = res.responseBody.toString();
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(jsonResponse);
        
        System.assertEquals(null, responseMap.get('success'));
        System.assertEquals(null, responseMap.get('message'));
    }

@IsTest
static void testDoCreateAttendanceEventWithPartialSuccess() {
        Test.startTest();

    RestApi_CreateAttendanceEvent.requestAttendanceEventWrapper requestWrapper = new RestApi_CreateAttendanceEvent.requestAttendanceEventWrapper();
    requestWrapper.AttendanceEvent = new List<RestApi_CreateAttendanceEvent.requestAttendanceEventDataWrapper>();
    
    RestApi_CreateAttendanceEvent.requestAttendanceEventDataWrapper validRequestData = new RestApi_CreateAttendanceEvent.requestAttendanceEventDataWrapper();
    validRequestData.contactId = [SELECT Id FROM Contact LIMIT 1].Id;
    validRequestData.sessionId = [SELECT Id FROM Session__c LIMIT 1].Id;
    validRequestData.attendanceStatus = 'Absent';
    validRequestData.reasonType = 'Sick';
    validRequestData.reasonDescription = 'Flu';
    requestWrapper.AttendanceEvent.add(validRequestData);
    
    RestApi_CreateAttendanceEvent.requestAttendanceEventDataWrapper invalidRequestData = new RestApi_CreateAttendanceEvent.requestAttendanceEventDataWrapper();
    invalidRequestData.contactId = 'InvalidContactId';
    invalidRequestData.sessionId = [SELECT Id FROM Session__c LIMIT 1].Id;
    invalidRequestData.attendanceStatus = 'Absent';
    invalidRequestData.reasonType = 'Sick';
    invalidRequestData.reasonDescription = 'Flu';
    requestWrapper.AttendanceEvent.add(invalidRequestData);
    
    String jsonRequest = JSON.serialize(requestWrapper);
    
    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();
    req.requestUri = '/services/apexrest/createAttendanceEvent';
    req.httpMethod = 'POST';
    req.requestBody = Blob.valueOf(jsonRequest);
    RestContext.request = req;
    RestContext.response = res;
    
    RestApi_CreateAttendanceEvent.doCreateAttendanceEvent();
    Test.stopTest();
    
    System.assertEquals(400, res.statusCode);
    String jsonResponse = res.responseBody.toString();
    RestApi_CreateAttendanceEvent.responseAttendanceEventWrapper responseWrapper = (RestApi_CreateAttendanceEvent.responseAttendanceEventWrapper) JSON.deserialize(jsonResponse, RestApi_CreateAttendanceEvent.responseAttendanceEventWrapper.class);
    

}}