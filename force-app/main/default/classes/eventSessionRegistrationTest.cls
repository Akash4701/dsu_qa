@isTest
private class eventSessionRegistrationTest {

    static testMethod void testDoGet_Success() {
        Contact con = new Contact(LastName = 'Test Contact');
        insert con;

        Schedule_Sessions__c session = new Schedule_Sessions__c(Name = 'Test Session');
        insert session;
		
        Event_Master__c master = new Event_Master__c();
        insert master;
        
        Event_Booking__c booking = new Event_Booking__c(
            Contact__c = con.Id,
            Schedules_Sessions__c = session.Id,
            Booked_for_No_of_Attendees__c = 2,
            Type__c = 'Registered'
        );
        insert booking;

        session.Event_Reference__c = master.Id; // Mimicking expected query relationship
        update session;

        Test.startTest();
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/eventBookigRegistration/';
        req.httpMethod = 'GET';
        req.addParameter('eventId', session.Event_Reference__c);
        req.addParameter('contactId', con.Id);

        RestContext.request = req;
        RestContext.response = res;

        eventSessionRegistration.doGet();
        Test.stopTest();
    }

    static testMethod void testDoPatch_Success() {
        Contact con = new Contact(LastName = 'Test');
        insert con;

        Schedule_Sessions__c session = new Schedule_Sessions__c(Name = 'Session');
        insert session;

        Event_Booking__c booking = new Event_Booking__c(
            Contact__c = con.Id,
            Schedules_Sessions__c = session.Id,
            Type__c = 'Registered',
            Booked_for_No_of_Attendees__c = 1
        );
        insert booking;

        eventSessionRegistration.eventRegistrationIds patchBody = new eventSessionRegistration.eventRegistrationIds();
        patchBody.ids = new List<String>{booking.Id};

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/eventBookigRegistration/';
        req.httpMethod = 'PATCH';
        req.requestBody = Blob.valueOf(JSON.serialize(patchBody));
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        eventSessionRegistration.doPatch();
        Test.stopTest();
    }

    static testMethod void testEventBookingPostMethod_Success() {
       /* Event_Setting__mdt setting = new Event_Setting__mdt(
            DeveloperName = 'EventRegistration',
            Label = 'EventRegistration',
            Is_Account_Based__c = false
        );
        insert setting;*/

        Contact con = new Contact(LastName = 'Test');
        insert con;

        Schedule_Sessions__c session = new Schedule_Sessions__c(Name = 'Session');
        insert session;

        eventSessionRegistration.registerEventSessionWrapper wrapper = new eventSessionRegistration.registerEventSessionWrapper();
        wrapper.numberOfAttendees = 2;
        wrapper.sessionId = session.Id;
        wrapper.AccountOrContactId = con.Id;

        String jsonBody = JSON.serialize(new List<eventSessionRegistration.registerEventSessionWrapper>{wrapper});

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/eventBookigRegistration/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(jsonBody);
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        eventSessionRegistration.eventBookingPostMethod();
        Test.stopTest();
    }

    static testMethod void testDoGet_MissingParams() {
        Test.startTest();
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/eventBookigRegistration/';
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = new RestResponse();

        eventSessionRegistration.doGet();
        Test.stopTest();
    }

    static testMethod void testDoPatch_EmptyIds() {
        RestRequest req = new RestRequest();
        req.httpMethod = 'PATCH';
        req.requestBody = Blob.valueOf(JSON.serialize(new eventSessionRegistration.eventRegistrationIds()));
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        try{
            eventSessionRegistration.doPatch();
        }catch(Exception e){

        }
        
        Test.stopTest();
    }

    static testMethod void testEventBookingPostMethod_InvalidJSON() {
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/eventBookigRegistration/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('invalid json');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        try {
            eventSessionRegistration.eventBookingPostMethod();
        } catch (Exception e) {
            System.assert(e.getMessage().contains('Invalid JSON format'));
        }
        Test.stopTest();
    }
    
    @isTest
static void testDoGet_MissingEventId() {
    
    Contact con = new Contact(LastName = 'test');
    insert con;

    RestRequest req = new RestRequest();
    req.requestUri = '/services/apexrest/eventBookigRegistration/';
    req.httpMethod = 'GET';
    req.addParameter('contactId', con.Id); // provide only contactId, skip eventId

    RestContext.request = req;
    RestContext.response = new RestResponse();

    eventSessionRegistration.doGet();

    System.assertEquals(RestApiUtility.HTTP_BAD_REQUEST, RestContext.response.statusCode);
    System.assert(RestContext.response.responseBody.toString().contains('Missing Event Id.'));
}

    @isTest
static void testDoPatch_MissingRequestBody() {
    RestRequest req = new RestRequest();
    req.requestUri = '/services/apexrest/eventBookigRegistration/';
    req.httpMethod = 'PATCH';
    req.requestBody = null; 

    RestContext.request = req;
    RestContext.response = new RestResponse();

    eventSessionRegistration.doPatch();

    System.assertEquals(RestApiUtility.HTTP_BAD_REQUEST, RestContext.response.statusCode);
    System.assert(RestContext.response.responseBody.toString().contains('Missing request Body'));
}

    @isTest
static void testDoPatch_MissingIds() {
    eventSessionRegistration.eventRegistrationIds requestBody = new eventSessionRegistration.eventRegistrationIds();
    requestBody.ids = new List<String>(); // empty list

    RestRequest req = new RestRequest();
    req.requestUri = '/services/apexrest/eventBookigRegistration/';
    req.httpMethod = 'PATCH';
    req.requestBody = Blob.valueOf(JSON.serialize(requestBody));

    RestContext.request = req;
    RestContext.response = new RestResponse();

    eventSessionRegistration.doPatch();

    System.assertEquals(RestApiUtility.HTTP_BAD_REQUEST, RestContext.response.statusCode);
    System.assert(RestContext.response.responseBody.toString().contains('Missing eventBooking Ids'));
}
@isTest
static void testDoPatch_NoRecordsFound() {
    eventSessionRegistration.eventRegistrationIds requestBody = new eventSessionRegistration.eventRegistrationIds();
    requestBody.ids = new List<String>{ 'a0ZFakeId000000AAA' }; // ID that doesn't exist

    RestRequest req = new RestRequest();
    req.requestUri = '/services/apexrest/eventBookigRegistration/';
    req.httpMethod = 'PATCH';
    req.requestBody = Blob.valueOf(JSON.serialize(requestBody));

    RestContext.request = req;
    RestContext.response = new RestResponse();

    eventSessionRegistration.doPatch();

    System.assertEquals(RestApiUtility.HTTP_BAD_REQUEST, RestContext.response.statusCode);
    System.assert(RestContext.response.responseBody.toString().contains('No eventBookings Records found for the Ids.'));
}

}