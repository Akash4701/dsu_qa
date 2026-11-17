@RestResource(urlMapping='/eventBookigRegistration/*')
global with sharing class eventSessionRegistration {
    @HttpGET
    global static void doGet(){
        
        RestRequest req = RestContext.request;
        Map<String,String> paramsMap = req.params;
        String eventId = paramsMap.get('eventId');
        String contactId = paramsMap.get('contactId');
        
        if(String.isBlank(contactId)){
            RestApiUtility.addError(RestApiUtility.HTTP_BAD_REQUEST,'Missing Contact Id.');
            return;
        }
        
        if(String.isBlank(eventId)){
            RestApiUtility.addError(RestApiUtility.HTTP_BAD_REQUEST,'Missing Event Id.');
            return;
        }
        
        List<Event_Booking__c> eventBookingList = [SELECT Id, Name, Account__c, Billing_Details__c, Booked_for_No_of_Attendees__c, Contact__c, Event_Booking_Id__c, Is_Active__c, Type__c, Schedules_Sessions__c,Schedules_Sessions__r.Name, Schedule_Sessions_Id__c FROM Event_Booking__c WHERE Schedules_Sessions__r.Event_Reference__c =:eventId AND Contact__c = :contactId];
        
        RestApiUtility.createSuccessGetResponse(eventBookingList);
    }
    
    @httpPatch
    global static void doPatch(){
        RestRequest req = RestContext.request;
        
        if (req.requestBody == null) {
            RestApiUtility.addError(RestApiUtility.HTTP_BAD_REQUEST, 'Missing request Body');
            return;
        }
        
        eventRegistrationIds registrationRecords = (eventRegistrationIds) JSON.deserialize(req.requestBody.toString(), eventRegistrationIds.class);
        List<Event_Booking__c> eventBookings = new List<Event_Booking__c>();
        
        if (registrationRecords.ids.isEmpty()) {
            RestApiUtility.addError(RestApiUtility.HTTP_BAD_REQUEST, 'Missing eventBooking Ids');
            return;
        }
        
        for(Event_Booking__c eb : [SELECT Id, Name, Account__c, Billing_Details__c, Booked_for_No_of_Attendees__c, Contact__c, Event_Booking_Id__c, Is_Active__c, Type__c,Schedules_Sessions__c, Schedule_Sessions_Id__c FROM Event_Booking__c WHERE Id IN :registrationRecords.ids]){
            eb.Type__c = 'Cancelled';
            eventBookings.add(eb);
        }
        
        if (eventBookings.isEmpty()) {
            RestApiUtility.addError(RestApiUtility.HTTP_BAD_REQUEST, 'No eventBookings Records found for the Ids.');
            return;
        }
        
        Database.saveResult[] updateResults = Database.update(eventBookings, false);
        List<RestApiUtility.ErrorBody> errors = new List<RestApiUtility.ErrorBody>();
        
        for(Database.saveResult result : updateResults){
            if(!result.isSuccess()){
                errors.add(new RestApiUtility.ErrorBody('Event Bookings',String.join(result.getErrors()[0].getFields(), ', '),result.getErrors()[0].getMessage()));
            }
        }
        
        if (!errors.isEmpty()) {
            RestContext.response.statusCode = RestApiUtility.HTTP_BAD_REQUEST;
        	RestContext.response.headers.put('content-type', 'text/plain');
        	RestContext.response.responseBody = Blob.valueOf(JSON.serialize(errors));
            return;
        }
        
        RestContext.response.statusCode = RestApiUtility.HTTP_SUCCESS;
        RestContext.response.headers.put('content-type', 'text/plain');
        RestContext.response.responseBody = Blob.valueOf('eventBookings Cancelled Successfully.'); 
    }
    
    @HttpPOST
    global static void eventBookingPostMethod(){
        
        registerEventSession(RestContext.request.requestBody.toString());
    }
    
    public static void registerEventSession(string bookingDetails){
        List<Event_Booking__c> eventBookingList = new List<Event_Booking__c>();
        List <registerEventSessionWrapper> responseList = new List<registerEventSessionWrapper>();
        List<Schedule_Sessions__c> sessionList = new List<Schedule_Sessions__c>();   
        List<registerEventSessionWrapper> request;
        try {
            request = (List<registerEventSessionWrapper>) JSON.deserialize(
                bookingDetails,
                List<registerEventSessionWrapper>.class
            );
        } catch (Exception e) {
            throw new IllegalArgumentException('Invalid JSON format: ' + e.getMessage());
        }
        
        for(registerEventSessionWrapper eachBooking:request){
            Event_Booking__c eventBooking = eachBooking.getRecord();
            eventBooking.Type__c = 'Registered';
            eventBookingList.add(eventBooking);
        }
        if(!eventBookingList.isEmpty()){
            insert eventBookingList;
        }
        for(Event_Booking__c eventBooking:eventBookingList){
            registerEventSessionWrapper response = new registerEventSessionWrapper();
            response.sessionId = eventBooking.Schedules_Sessions__c;
            response.numberOfAttendees = eventBooking.Booked_for_No_of_Attendees__c;
            response.accountId = eventBooking.Account__c;
            response.contactId = eventBooking.Contact__c;
            responseList.add(response);
        }
        RestApiUtility.createSuccessPostResponse(JSON.serialize(responseList));
    }
    
    public class registerEventSessionWrapper{
        public Decimal numberOfAttendees;
        public string sessionId;
        public string Id;
        public string AccountOrContactId;
        public string accountId;
        public string contactId;
        public registerEventSessionWrapper(){
            
        }
        
        public Event_Booking__c getRecord(){
            Event_Setting__mdt customSetting = [SELECT Id, DeveloperName, Label, Is_Account_Based__c FROM Event_Setting__mdt WHERE label ='EventRegistration' Limit 1];
            Event_Booking__c eventBooking = new Event_Booking__c();
            
            if(this.numberOfAttendees !=null){
                eventBooking.Booked_for_No_of_Attendees__c = this.numberOfAttendees;
            }
            if(string.isNotBlank(this.sessionId)){
                eventBooking.Schedules_Sessions__c = this.sessionId;
            }   
            if(string.isNotBlank(this.AccountOrContactId) && customSetting?.Is_Account_Based__c == true){
                eventBooking.Account__c = this.AccountOrContactId;
            }
            else if(string.isNotBlank(this.AccountOrContactId)){
                eventBooking.Contact__c = this.AccountOrContactId;
            } 
            return eventBooking;
        }
    }
    
    public class eventRegistrationIds {
        public List<String> ids;
    }
}