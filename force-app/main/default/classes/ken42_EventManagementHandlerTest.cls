@isTest
private class ken42_EventManagementHandlerTest {

    @TestSetup
    static void setupTestData() {
        // Create a Contact record for testing
        Contact testContact = new Contact(LastName = 'Test User', Email = 'test@example.com');
        insert testContact;
        
        // Get RecordType Id for Event
        Id eventRecordTypeId;
        try {
            eventRecordTypeId = Schema.SObjectType.Event_Master__c.getRecordTypeInfosByDeveloperName().get('Event').getRecordTypeId();
        } catch (Exception e) {
            // Default RecordTypeId if not found
            eventRecordTypeId = null;
        }
        
        // Create sample Event_Master__c records
        List<Event_Master__c> events = new List<Event_Master__c>{
            // Upcoming event with Pending Approval status - assigned to contact
            new Event_Master__c(
                Name = 'Test Event 1',
                Event_Current_Step__c = 1,
                Language__c = 'English',
                Target_Keywords__c = 'Test, Event',
                Event_Status__c = 'Pending Approval',
                Event_Fee__c = 100.0,
                No_Fee__c = false,
                Start_Date__c = Date.today().addDays(1),
                End_Date__c = Date.today().addDays(2),
                Start_Time__c = Time.newInstance(10, 0, 0, 0),
                End_Time__c = Time.newInstance(12, 0, 0, 0),
                Description__c = 'Sample Event Description',
                Contact__c = testContact.Id,
                Is_Active__c = true,
                RecordTypeId = eventRecordTypeId,
                What_to_Expect_From_Event__c = 'Learning outcomes',
                Target_Audience_Applicable__c = 'Students',
                Event_Type__c = 'Seminar',
                Event_Pricing__c = 'Paid'
            ),
            // Past event with Approved status - not assigned to contact
            new Event_Master__c(
                Name = 'Test Event 2',
                Event_Status__c = 'Approved',
                Start_Date__c = Date.today().addDays(-3),
                End_Date__c = Date.today().addDays(-2),
                Is_Active__c = true,
                RecordTypeId = eventRecordTypeId,
                Event_Type__c = 'Workshop'
            ),
            // Upcoming event with Rejected status
            new Event_Master__c(
                Name = 'Test Event 3',
                Event_Status__c = 'Rejected',
                Start_Date__c = Date.today().addDays(5),
                End_Date__c = Date.today().addDays(6),
                Is_Active__c = true,
                RecordTypeId = eventRecordTypeId,
                Reason_For_Rejection__c = 'Invalid content',
                Event_Type__c = 'Conference'
            )
        };
        insert events;
    }

    @isTest
    static void testEventGetMethod_NoContactId() {
        // Setup RestContext with no query parameters
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/eventManagementHandler'; // No query string
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = res;
    
        Test.startTest();
        String responseBody = ken42_EventManagementHandler.eventGetMethod();
        Test.stopTest();
    }


    @isTest
    static void testEventGetMethod_WithContactId() {
        Contact testContact = [SELECT Id FROM Contact WHERE LastName = 'Test User' LIMIT 1];
        
        // Encode the contactId as a query parameter in the request URI
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/eventManagementHandler?contactId=' + testContact.Id;
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = res;
    
        Test.startTest();
        String responseBody = ken42_EventManagementHandler.eventGetMethod();
        Test.stopTest();
    }

    @isTest
    static void testEventPostMethod_UpdateEvent() {
        // Mock HTTP callout for content version creation
        Test.setMock(HttpCalloutMock.class, new MockContentVersionResponse());
        
        // Get an existing event
        Event_Master__c existingEvent = [SELECT Id FROM Event_Master__c WHERE Name = 'Test Event 1' LIMIT 1];
        
        // Create request body for updating event
        Map<String, Object> requestMap = new Map<String, Object>{
            'Id' => existingEvent.Id,
            'eventTitle' => 'Updated Event Title',
            'category' => 'Conference',
            'description' => 'Updated description',
            'agenda' => 'Updated agenda',
            'currentStep' => 3,
            'isEventBroucher' => true,
            'coverImage' => new Map<String, String>{
                'fileName' => 'updated_cover.jpg',
                'imageUrl' => 'https://example.com/images/updated_cover.jpg'
            },
            'eventBroucher' => new Map<String, String>{
                'fileName' => 'updated_brochure.pdf',
                'imageUrl' => 'https://example.com/docs/updated_brochure.pdf'
            }
        };
        
        // Setup RestContext for POST
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/eventManagementHandler';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(requestMap));
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        ken42_EventManagementHandler.eventPostMethod();
        Test.stopTest();
    }

    // Mock class for simulating ContentVersion creation
    private class MockContentVersionResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('https://example.com/content-version-id');
            return res;
        }
    }
}