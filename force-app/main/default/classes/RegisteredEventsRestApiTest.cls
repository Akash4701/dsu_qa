@isTest
private class RegisteredEventsRestApiTest {

    @testSetup
    static void setupData() {
        // Create Org Settings
        Alumni_Org_Parameters__c orgSettings = new Alumni_Org_Parameters__c(
            Name = 'Default',
            Event_data_limit_by_date__c = 30
        );
        insert orgSettings;

        // Create Contact
        Contact contact = new Contact(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'testuser@example.com'
        );
        insert contact;

        // Create Event Reference
        Event__c eventRef = new Event__c(
            Name = 'Test Event',
            Description__c = 'Test event description'
        );
        insert eventRef;

        // Create Questionnaire
        Alm_Questionnaire__c questionnaire = new Alm_Questionnaire__c();
        insert questionnaire;

        Alm_Questionnaire_Parameter__c question = new Alm_Questionnaire_Parameter__c(
          //  Name = 'Q1',
            Question_Label__c = 'Rate the event',
            Question_Type__c = 'Rating',
            Order__c = 1,
            Max_Grade__c = 5,
            Is_Required__c = true,
            Questionnaire__c = questionnaire.Id
        );
        insert question;

        // Create Session
        Session__c session = new Session__c(
        );
        insert session;
        Schedule_Sessions__c ss = new Schedule_Sessions__c();
        insert ss;

        // Create Booking
        Event_Booking__c booking = new Event_Booking__c(
            Contact__c = contact.Id,
            Booked_for_No_of_Attendees__c = 1,
            Type__c = 'Registered',
            Schedules_Sessions__c = ss.Id
        );
        insert booking;

        // Create a feedback response (simulate already submitted)
        Alm_Questionnaire_Parameter_Response__c response = new Alm_Questionnaire_Parameter_Response__c(
            //Session__c = session.Id,
            Respondent__c = contact.Id
        );
        insert response;
    }

    @isTest
    static void testDoGet() {
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/registeredEvents';
        req.params.put('contactId', con.Id);
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        RegisteredEventsRestApi.doGet();
        Test.stopTest();

    }

    @isTest
    static void testSubmitFeedback() {
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        Session__c session = [SELECT Id FROM Session__c LIMIT 1];
        Alm_Questionnaire_Parameter__c question = [SELECT Id FROM Alm_Questionnaire_Parameter__c LIMIT 1];

        Alm_Questionnaire_Parameter_Response__c feedback = new Alm_Questionnaire_Parameter_Response__c(
            Session__c = session.Id,
            Respondent__c = con.Id,
            Questionnaire_Parameter__c = question.Id
        );

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/registeredEvents/submitFeedback';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(new List<Alm_Questionnaire_Parameter_Response__c>{feedback}));
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        RegisteredEventsRestApi.doPost();
        Test.stopTest();

    }

    @isTest
    static void testDoPostInvalidURL() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/registeredEvents';
        req.httpMethod = 'POST';
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        RegisteredEventsRestApi.doPost();
        Test.stopTest();

    }
    @isTest
    static void testSubmitEventFeedback_success() {
        // Create test contact and session
        Contact testContact = new Contact(FirstName = 'Test', LastName = 'User', Email = 'testuser@example.com');
        insert testContact;
        
        Account acc = new Account(Name = 'Academic Program', RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Academic_Program').getRecordTypeId());
        insert acc;

        Alm_Questionnaire__c questionnaire = new Alm_Questionnaire__c();
        insert questionnaire;
        
        Schedule_Sessions__c session = new Schedule_Sessions__c();
        insert session;

        // Create test response
        Alm_Questionnaire_Parameter_Response__c testResponse = new Alm_Questionnaire_Parameter_Response__c(
            Session__c = session.Id,
            Respondent__c = testContact.Id,
            Response__c = 'Great'
        );

        List<Alm_Questionnaire_Parameter_Response__c> responseList = new List<Alm_Questionnaire_Parameter_Response__c>{ testResponse };
        String jsonBody = JSON.serialize(responseList);

        // Set mock REST request body
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf(jsonBody);
        RestContext.request = req;

        RestResponse res = new RestResponse();
        RestContext.response = res;

        // Call the method
        Test.startTest();
        RegisteredEventsRestApi.submitEventFeedback();
        Test.stopTest();

    }
    @isTest
    static void testRegisteredEventDetailsConstructor() {
        // Insert test Contact
        Contact testContact = new Contact(FirstName = 'John', LastName = 'Doe', Email = 'john.doe@example.com');
        insert testContact;

        // Insert test Event
        Event__c testEvent = new Event__c(
            Name = 'Tech Summit',
            Description__c = 'Tech event with sessions'
        );
        insert testEvent;

        // Insert test session
        Schedule_Sessions__c testSession = new Schedule_Sessions__c(
            Name = 'Session 1',
            Start_Date__c = Date.today().addDays(1),
            Start_Time__c = Time.newInstance(10, 0, 0, 0),
            End_Date__c = Date.today().addDays(1),
            End_Time__c = Time.newInstance(13, 0, 0, 0),
            Location_Type__c = 'Online',
            Session_Link__c = 'https://zoom.us/session'
           // Event_Reference__c = testEvent.Id
        );
        insert testSession;

        // Insert Event Booking
        Event_Booking__c booking = new Event_Booking__c(
            Contact__c = testContact.Id,
            Schedules_Sessions__c = testSession.Id,
            Booked_for_No_of_Attendees__c = 2,
            Type__c = 'Registered'
        );
        insert booking;

        // Call constructor
        Test.startTest();
        RegisteredEventsRestApi.RegisteredEventDetails details = new RegisteredEventsRestApi.RegisteredEventDetails(booking, true, false, false, true);
        Test.stopTest();

    }
     @isTest
    static void testDoGet_withQuestionnaire() {
        // Contact
        Contact testContact = new Contact(FirstName = 'Jane', LastName = 'Doe', Email = 'jane@example.com');
        insert testContact;

        // Questionnaire & Parameter
        Alm_Questionnaire__c q = new Alm_Questionnaire__c();
        insert q;

        Alm_Questionnaire_Parameter__c param = new Alm_Questionnaire_Parameter__c(
          //  Name = 'Q1',
            Question_Label__c = 'How was the event?',
            Question_Type__c = 'File Upload',
            Order__c = 1,
            Is_Required__c = true,
            Questionnaire__c = q.Id
        );
        insert param;

        // Event
        Event__c ev = new Event__c(
            Name = 'Event X'
        );
        insert ev;

        // Session
        Schedule_Sessions__c session = new Schedule_Sessions__c(
            Name = 'Session 1',
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addDays(1),
            Start_Time__c = Time.newInstance(9, 0, 0, 0),
            End_Time__c = Time.newInstance(11, 0, 0, 0),
            Questionnaire__c = q.Id
        );
        insert session;

        // Booking
        Event_Booking__c booking = new Event_Booking__c(
            Contact__c = testContact.Id,
            Schedules_Sessions__c = session.Id,
            Type__c = 'Registered',
            Booked_for_No_of_Attendees__c = 1
        );
        insert booking;

        // Feedback Response
        Alm_Questionnaire_Parameter_Response__c response = new Alm_Questionnaire_Parameter_Response__c(
          //  Name = 'Response 1',
            Respondent__c = testContact.Id,
            Session__c = session.Id
        );
        insert response;

        // Org Settings
       Alumni_Org_Parameters__c existing = [
    SELECT Id 
    FROM Alumni_Org_Parameters__c 
    WHERE Name = 'Default' 
    LIMIT 1
];

if (existing != null) {
    // Update existing
    Alumni_Org_Parameters__c updateSetting = new Alumni_Org_Parameters__c(Id = existing.Id, Name = 'Default', Event_data_limit_by_date__c = 30);
    update updateSetting;
} else {
    // Insert new
    Alumni_Org_Parameters__c newSetting = new Alumni_Org_Parameters__c(Name = 'Default', Event_data_limit_by_date__c = 30);
    insert newSetting;
}

        // Mock request param
        Test.startTest();
        RestRequest req = new RestRequest();
        req.httpMethod = 'GET';
        req.requestURI = '/services/apexrest/event/registered';
        req.params.put('contactId', testContact.Id);
        RestContext.request = req;

        RestResponse res = new RestResponse();
        RestContext.response = res;

        // Call your method
        RegisteredEventsRestApi.doGet(); // replace with your actual controller name
        Test.stopTest();
    }

}