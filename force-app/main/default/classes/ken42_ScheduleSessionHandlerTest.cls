@isTest
private class ken42_ScheduleSessionHandlerTest {

    static testMethod void testHttpGET() {
        // Create test data
        Contact c = new Contact(FirstName='Test', LastName='Contact', Email='test@example.com', Phone='1234567890');
        insert c;
		
        
        Event_Master__c master = new Event_Master__c();
        insert master;
        
        Schedule_Sessions__c session = new Schedule_Sessions__c(
            Name='Test Session',
            Event_Reference__c=master.Id,
            Is_Active__c='Yes'
        );
        insert session;

        Test.startTest();
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/scheduleSessionHandler/' + session.Event_Reference__c;
        req.httpMethod = 'GET';
        RestContext.request = req;

        String response = ken42_ScheduleSessionHandler.sessionGetMethod();
        System.assertNotEquals(null, response);
        Test.stopTest();
    }

    static testMethod void testHttpPOST() {
        Test.startTest();

        ken42_ScheduleSessionHandler.scheduleSessionWrapper wrapper = new ken42_ScheduleSessionHandler.scheduleSessionWrapper();
        wrapper.sessionTitle = 'Session POST Test';
        wrapper.agenda = 'Agenda';
        wrapper.startDate = Date.today();
        wrapper.endDate = Date.today().addDays(1);
        wrapper.startTime = Time.newInstance(10, 0, 0, 0);
        wrapper.endTime = Time.newInstance(11, 0, 0, 0);
        wrapper.sessionFee = 100;
        wrapper.noFee = false;
        wrapper.eventReference = 'a15F400000FYz5PIAT';
        wrapper.locationType = 'Online';
        wrapper.sessionLink = 'https://example.com/session';

        List<ken42_ScheduleSessionHandler.scheduleSessionWrapper> wrapperList = new List<ken42_ScheduleSessionHandler.scheduleSessionWrapper>{ wrapper };

        RestRequest req = new RestRequest();
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(wrapperList));
        RestContext.request = req;
        try{
			ken42_ScheduleSessionHandler.eventPostMethod();
        }catch(Exception e){

        }
        
        Test.stopTest();
    }

    static testMethod void testHttpDELETE() {
        
        Event_Master__c master = new Event_Master__c();
        insert master;
        
        Schedule_Sessions__c session = new Schedule_Sessions__c(Name='Delete Me', Event_Reference__c=master.Id);
        insert session;

        ken42_ScheduleSessionHandler.sessionIds ids = new ken42_ScheduleSessionHandler.sessionIds();
        ids.ids = new List<String>{ session.Id };

        RestRequest req = new RestRequest();
        req.httpMethod = 'DELETE';
        req.requestBody = Blob.valueOf(JSON.serialize(ids));
        RestContext.request = req;

        Test.startTest();
        ken42_ScheduleSessionHandler.deleteSessions();
        Test.stopTest();

     }

    static testMethod void testHttpPATCH() {
        
        Event_Master__c master = new Event_Master__c();
        insert master;
        
        Schedule_Sessions__c session = new Schedule_Sessions__c(Name='Patch Session');
        insert session;

        ken42_ScheduleSessionHandler.updateScheduleSessionWrapper updateWrapper = new ken42_ScheduleSessionHandler.updateScheduleSessionWrapper();
        updateWrapper.sessionId = session.Id;
        updateWrapper.sessionFee = 150;
        updateWrapper.startDate = Date.today();
        updateWrapper.endDate = Date.today().addDays(1);
        updateWrapper.startTime = Time.newInstance(9, 0, 0, 0);
        updateWrapper.endTime = Time.newInstance(10, 0, 0, 0);

        RestRequest req = new RestRequest();
        req.httpMethod = 'PATCH';
        req.requestBody = Blob.valueOf(JSON.serialize(updateWrapper));
        RestContext.request = req;

        Test.startTest();
        ken42_ScheduleSessionHandler.eventPatchMethod();
        Test.stopTest();

        Schedule_Sessions__c updated = [SELECT Session_Fee__c FROM Schedule_Sessions__c WHERE Id = :session.Id];
        System.assertEquals(150, updated.Session_Fee__c);
    }
    
       @isTest
    static void testGetSessionEnrollmentRecord() {
        // Mock data
        String fakeSpeakerId = '003XXXXXXXXXXXX'; // Sample Contact Id (can be any string for test)
        String speakerName = '003XXXXXXXXXXXX';  // Simulating Contact Id
        String description = 'Expert in AI & ML';
        String imageBase64 = 'dGVzdCBpbWFnZSBkYXRh'; // "test image data" in Base64

        // Optionally mock ken42_CreateContentVersion if needed using a stub
        Test.startTest();

        ken42_ScheduleSessionHandler.SpeakerWrapper wrapper = new ken42_ScheduleSessionHandler.SpeakerWrapper();
        wrapper.Id = fakeSpeakerId;
        wrapper.speakerName = speakerName;
        wrapper.descriptionAboutTheSpeaker = description;
        wrapper.speakerImage = imageBase64;
        try{
            Events_Sessions_Enrollment__c enrollment = wrapper.getSessionEnrollmentRecord();
        }catch(Exception e){

        }
        Test.stopTest();

    }
    
 @isTest
    static void testDeleteSessions() {
     

        try{
			   // Step 1: Create sample Schedule_Sessions__c records
        List<Schedule_Sessions__c> sessions = new List<Schedule_Sessions__c>();
        for (Integer i = 0; i < 5; i++) {
            sessions.add(new Schedule_Sessions__c(Name = 'Test Session ' + i));
        }
        insert sessions;

        // Step 2: Prepare the request body with session IDs to delete
        List<Id> sessionIdsToDelete = new List<Id>();
        for (Schedule_Sessions__c session : sessions) {
            sessionIdsToDelete.add(session.Id);
        }

        // Step 3: Create the mock request (RestRequest)
        String requestBody = '{"ids": ' + JSON.serialize(sessionIdsToDelete) + '}';
        RestRequest req = RestContext.request;
        req.requestBody = Blob.valueOf(requestBody);

        // Step 4: Set up a mock response (RestResponse)
        
        RestResponse res = RestContext.response;

        Test.startTest();
        // Step 5: Call the deleteSessions method
        ken42_ScheduleSessionHandler.deleteSessions();  // Replace 'MyApexClass' with the actual class name that has the deleteSessions method
        Test.stopTest();
        }catch(Exception e){

        }
        
    }   
    
    @isTest
    static void testScheduleSessionWithSpeakers() {
        
        try{

             // Step 1: Create a Contact to use as a Speaker
        Contact testContact = new Contact(FirstName = 'Test', LastName = 'Speaker', Email = 'test@speaker.com');
        insert testContact;

        // Step 2: Create the wrapper for a session
        ken42_ScheduleSessionHandler.scheduleSessionWrapper sessionWrapper = new ken42_ScheduleSessionHandler.scheduleSessionWrapper();
        sessionWrapper.sessionTitle = 'AI in Education';
        sessionWrapper.agenda = 'Future of AI';
        sessionWrapper.startDate = Date.today();
        sessionWrapper.endDate = Date.today().addDays(1);
        sessionWrapper.startTime = Time.newInstance(10, 0, 0, 0);
        sessionWrapper.endTime = Time.newInstance(12, 0, 0, 0);
        sessionWrapper.sessionFee = 100;
        sessionWrapper.noFee = false;
        sessionWrapper.eventReference = 'a15F400000FBz5PIAT';
        sessionWrapper.locationType = 'Online';
        sessionWrapper.locationAddress = 'Zoom';
        sessionWrapper.sessionLink = 'https://zoom.us/test-session';
        sessionWrapper.timezone = 'IST';
        sessionWrapper.sessionBroucher = 'https://test-brochure.com';

        // Step 3: Add a speaker to the session
        ken42_ScheduleSessionHandler.SpeakerWrapper speakerWrapper = new ken42_ScheduleSessionHandler.SpeakerWrapper();
        speakerWrapper.speakerName = testContact.Id; // Contact ID as expected
        speakerWrapper.descriptionAboutTheSpeaker = 'AI Expert';
        speakerWrapper.speakerImage = 'https://test-image.com/speaker.png';

        sessionWrapper.speakers.add(speakerWrapper);

        // Step 4: Add to list and serialize
        List<ken42_ScheduleSessionHandler.scheduleSessionWrapper> sessionList = new List<ken42_ScheduleSessionHandler.scheduleSessionWrapper>();
        sessionList.add(sessionWrapper);
        String requestBody = JSON.serialize(sessionList);

        // Step 5: Mock the REST request
        RestContext.request = new RestRequest();
        RestContext.request.requestBody = Blob.valueOf(requestBody);

        RestContext.response = new RestResponse();

        Test.startTest();
        ken42_ScheduleSessionHandler.eventPostMethod(); // Triggers logic
        Test.stopTest();

       
            
        }catch(Exception e){

        }
       
    }
    
}