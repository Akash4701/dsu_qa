@RestResource(urlMapping='/registeredEvents/*')
global without sharing class RegisteredEventsRestApi {
    
    private static final String URL_BASE = '/registeredEvents/';
    
    @httpGet
    global static void doGet(){
        Restrequest request = RestContext.request;
        Map<String,String> paramsMap = request.params;
        String contactId = paramsMap.get('contactId');
        
        Alumni_Org_Parameters__c orgSettings = Alumni_Org_Parameters__c.getInstance();
            
        if(orgSettings == null){
            RestApiUtility.addError(RestApiUtility.HTTP_INTERNAL_SERVER_ERROR, 'Signup Questionnaire Setup is not configured.');
            return;
        }

		Integer noOfDays = (Integer) orgSettings.Event_data_limit_by_date__c;
		Date pastDate = Date.today().addDays(-noOfDays);

        
        if(String.isBlank(contactId)){
            RestApiUtility.addError(RestApiUtility.HTTP_BAD_REQUEST,'Missing Contact Id.');
            return;
        }
        
        List<RegisteredEventDetails> responsewrapper = new List<RegisteredEventDetails>();
        
        List<Event_Booking__c> registeredEvents = [Select Id,Event_Booking_Id__c, Contact__c,Contact__r.Name,Contact__r.Email,Booked_for_No_of_Attendees__c,Type__c,
                                                   Schedules_Sessions__c,Schedules_Sessions__r.Name,Schedules_Sessions__r.Start_Date__c,Schedules_Sessions__r.Start_Time__c,
                                                   Schedules_Sessions__r.End_Time__c,Schedules_Sessions__r.End_Date__c,Schedules_Sessions__r.Location_Type__c,Schedules_Sessions__r.Session_Link__c,Schedules_Sessions__r.Questionnaire__c,
                                                   Schedules_Sessions__r.Event_Reference__c,Schedules_Sessions__r.Event_Reference__r.Name,Schedules_Sessions__r.Event_Reference__r.Start_Date__c,
                                                   Schedules_Sessions__r.Event_Reference__r.End_Date__c,Schedules_Sessions__r.Event_Reference__r.Start_Time__c,Schedules_Sessions__r.Event_Reference__r.End_Time__c,
                                                   Schedules_Sessions__r.Event_Reference__r.Description__c,Schedules_Sessions__r.Event_Reference__r.What_to_Expect_From_Event__c,
                                                   Schedules_Sessions__r.Event_Reference__r.Cover_Image_Title__c, Schedules_Sessions__r.Event_Reference__r.Event_banner__c,
                                                   Schedules_Sessions__r.Event_Reference__r.Broucher_Title__c, Schedules_Sessions__r.Event_Reference__r.Event_Broucher__c, Schedules_Sessions__r.Event_Reference__r.Event_Fee__c,Schedules_Sessions__r.Event_Reference__r.Event_Type__c from Event_Booking__c where Contact__c= :contactId AND Schedules_Sessions__r.End_Date__c >:pastDate ];
        
        if(registeredEvents.isEmpty()){
            return;
        }
        Set<Id> questionnaireIds = new Set<Id>();
        Set<Id>sessionIds = new Set<Id>();
        for(Event_Booking__c eb: registeredEvents){
            if(eb.Schedules_Sessions__r.Questionnaire__c!=null){
            questionnaireIds.add(eb.Schedules_Sessions__r.Questionnaire__c);
            sessionIds.add(eb.Schedules_Sessions__c);
            }
        }
        
        Map<Id,List<Alm_Questionnaire_Parameter__c>> questionnareMap = new Map<Id,List<Alm_Questionnaire_Parameter__c>>();
        for(Alm_Questionnaire__c questionnaire : [Select Id, Name, (Select Id, Name, Question_Label__c, Question_Type__c, Order__c, MCQ_Options__c, Max_Grade__c, Is_Required__c from Alm_Questionnaire_Parameters__r) from Alm_Questionnaire__c where Id IN :questionnaireIds]){
            if(questionnaire.Alm_Questionnaire_Parameters__r != null)
                questionnareMap.put(questionnaire.Id,questionnaire.Alm_Questionnaire_Parameters__r);
        }
        Set<Id> answeredSessionIds = new Set<Id>();
        for(Alm_Questionnaire_Parameter_Response__c response : [Select Id, Session__c from Alm_Questionnaire_Parameter_Response__c where Session__c!= null AND Session__c IN:sessionIds AND Respondent__c =:contactId]){
            answeredSessionIds.add(response.Session__c);
        }
        
        for(Event_Booking__c eb : registeredEvents){
            Boolean isUpcoming = false;
            Boolean isPast = false; 
            Boolean isInProgress = false;
            Boolean feedbackSubmitted = eb.Schedules_Sessions__c != null && answeredSessionIds.contains(eb.Schedules_Sessions__c) ? true:false;
            eb.Schedules_Sessions__r.Start_Time__c = eb.Schedules_Sessions__r.Start_Time__c!=null ? eb.Schedules_Sessions__r.Start_Time__c:Time.newInstance(0, 0, 0, 0);
            eb.Schedules_Sessions__r.End_Time__c = eb.Schedules_Sessions__r.End_Time__c!=null ? eb.Schedules_Sessions__r.End_Time__c:Time.newInstance(23, 59, 59, 0);
            Datetime startDateTime = eb.Schedules_Sessions__r.Start_Date__c != null ? Datetime.newInstance(eb.Schedules_Sessions__r.Start_Date__c, eb.Schedules_Sessions__r.Start_Time__c):null;
            Datetime endDateTime = eb.Schedules_Sessions__r.End_Date__c != null?Datetime.newInstance(eb.Schedules_Sessions__r.End_Date__c, eb.Schedules_Sessions__r.End_Time__c):null;
            Datetime currentDateTime = Datetime.now();
            
            if(currentDateTime < startDateTime){
                isUpcoming = true;
            }else if(startDateTime < currentDateTime && currentDateTime < endDateTime){
                isInProgress = true;
            }else if(currentDateTime > endDateTime){
                isPast = true;
            }
            
            RegisteredEventDetails eventbooking = new RegisteredEventDetails(eb,isUpcoming,isPast,isInProgress, feedbackSubmitted);
            eventbooking.questionnaire = questionnareMap.get(eb.Schedules_Sessions__r.Questionnaire__c);
            
            responsewrapper.add(eventbooking);
        }
        
        RestApiUtility.createSuccessGetResponse(responsewrapper);
        
    }
    
    @httpPost
    global static void doPost(){
        String requestURI = RestContext.request.requestURI;
        requestURI = requestURI.replace(URL_BASE,'');
        
        String[] urlParts = requestURI.split('/');
        
        if(urlParts.size() < 1){
            RestApiUtility.addError(RestApiUtility.HTTP_BAD_REQUEST,RestApiUtility.ERROR_URL_INVALID);
            return;
        }
        
        if(urlParts[0] == 'submitFeedback'){
            submitEventFeedback();
        }
    }
    
    @TestVisible
    private static void submitEventFeedback(){
        Restrequest request = RestContext.request;
        
        if (request.requestBody.size() == 0) {
            RestApiUtility.addError(RestApiUtility.HTTP_BAD_REQUEST,'Provide valid request body');
            return;
        }
		
        List<Alm_Questionnaire_Parameter_Response__c> responses = (List<Alm_Questionnaire_Parameter_Response__c>)JSON.deserialize(request.requestBody.toString(),List<Alm_Questionnaire_Parameter_Response__c>.class);
        
        Database.saveResult[] insertResults = Database.insert(responses, false);
        
        List<RestApiUtility.ErrorBody> errors = new List<RestApiUtility.ErrorBody>();
        
        for(Database.saveResult result : insertResults){
            if(!result.isSuccess()){
                errors.add(new RestApiUtility.ErrorBody('Questionnaire Response',String.join(result.getErrors()[0].getFields(), ', '),result.getErrors()[0].getMessage()));
            }
        }
        
        if (!errors.isEmpty()) {
            RestContext.response.statusCode = RestApiUtility.HTTP_BAD_REQUEST;
        	RestContext.response.headers.put('content-type', 'text/plain');
        	RestContext.response.responseBody = Blob.valueOf(JSON.serialize(errors));
            return;
        }
        
		 RestApiUtility.createSuccessPostResponse(responses);    
    }
    
    public class RegisteredEventDetails{
        public String bookingId;
        public String eventBookingId;
        public String applicantId;
        public String applicantName;
        public String applicantEmail;
        public Decimal bookingSize;
        public String bookingStatus;
        public String sessionId;
        public String sessionName;
        public Date sessionStartDate;
        public Time sessionStartTime;
        public Date sessionEndDate;
        public Time sessionEndTime;
        public String sessionLocationType;
        public String sessionLink;
        public String Id; //represents event Id
        public String eventTitle;
        public Date eventStartDate;
        public Date eventEndDate;
        public Time eventEndTime;
        public Time eventStartTime;
        public Decimal eventFee;
        public String description;
        public String agenda;
        public String eventStatus;
        public String coverImageURL;
        public String coverImageTitle;
        public String eventBroucher;
        public String broucherTitle;
        public String category;
        public Boolean isUpcoming;
        public Boolean ispast;
        public Boolean isInprogress;
        public Boolean feedbackSubmitted;
        public List<Alm_Questionnaire_Parameter__c> questionnaire;
        public RegisteredEventDetails(Event_Booking__c eventBooking, Boolean isUpcoming, Boolean ispast, Boolean isInprogress, Boolean feedbackSubmitted){
            this.bookingId = eventBooking.Id;
            this.eventBookingId = eventBooking.Event_Booking_Id__c;
            this.applicantId = eventBooking.Contact__c;
            this.applicantName = eventBooking.Contact__r.Name;
            this.applicantEmail = eventBooking.Contact__r.Email;
            this.bookingSize = eventBooking.Booked_for_No_of_Attendees__c;
            this.bookingStatus = eventBooking.Type__c;
            this.sessionId = eventBooking.Schedules_Sessions__c;
            this.sessionName = eventBooking.Schedules_Sessions__r.Name;
            this.sessionStartDate = eventBooking.Schedules_Sessions__r.Start_Date__c;
            this.sessionStartTime = eventBooking.Schedules_Sessions__r.Start_Time__c;
            this.sessionEndDate = eventBooking.Schedules_Sessions__r.End_Date__c;
            this.sessionEndTime = eventBooking.Schedules_Sessions__r.End_Time__c;
            this.sessionLocationType = eventBooking.Schedules_Sessions__r.Location_Type__c;
            this.sessionLink = eventBooking.Schedules_Sessions__r.Session_Link__c;
            this.Id = eventBooking.Schedules_Sessions__r.Event_Reference__c;
            this.eventTitle = eventBooking.Schedules_Sessions__r.Event_Reference__r.Name;
            this.eventStartDate = eventBooking.Schedules_Sessions__r.Event_Reference__r.Start_Date__c;
            this.eventEndDate = eventBooking.Schedules_Sessions__r.Event_Reference__r.End_Date__c;
            this.eventStartTime = eventBooking.Schedules_Sessions__r.Event_Reference__r.Start_Time__c;
            this.eventEndTime = eventBooking.Schedules_Sessions__r.Event_Reference__r.End_Time__c;
            this.description = eventBooking.Schedules_Sessions__r.Event_Reference__r.Description__c;
            this.agenda = eventBooking.Schedules_Sessions__r.Event_Reference__r.What_to_Expect_From_Event__c;
            this.coverImageURL = eventBooking.Schedules_Sessions__r.Event_Reference__r.Event_banner__c;
            this.coverImageTitle = eventBooking.Schedules_Sessions__r.Event_Reference__r.Cover_Image_Title__c;
            this.eventBroucher = eventBooking.Schedules_Sessions__r.Event_Reference__r.Event_Broucher__c;
            this.broucherTitle = eventBooking.Schedules_Sessions__r.Event_Reference__r.Broucher_Title__c;
            this.eventFee = eventBooking.Schedules_Sessions__r.Event_Reference__r.Event_Fee__c;
            this.category = eventBooking.Schedules_Sessions__r.Event_Reference__r.Event_Type__c;
            this.isUpcoming = isUpcoming;
            this.ispast = ispast;
            this.isInprogress = isInprogress;
            this.feedbackSubmitted = feedbackSubmitted;
        }
        
    }
}