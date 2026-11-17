@RestResource(urlMapping='/eventManagementHandler/*')
global with sharing class ken42_EventManagementHandler {
    @HttpGET
    global static String eventGetMethod(){
        List<Event_Master__c> allEvents = [SELECT Id, Name,Event_Current_Step__c,Language__c,Target_Keywords__c,Event_Status__c,Event_Broucher__c,Description__c,createdDate,Event_Fee__c,No_Fee__c, RecordTypeId, End_Date__c, End_Time__c, Event_Group_Id__c, Event_Type__c, Event_banner__c, Evvent_Group__c, Is_Archived__c, Is_Scheduled__c, Is_Active__c, Location__c, Max_Allowed_Participants__c, Start_Date__c, Start_Time__c, Title__c, What_to_Expect_From_Event__c,Cover_Image_Title__c,Broucher_Title__c,Target_Audience_Applicable__c,Contact__c,Event_Pricing__c,Timezone__c,Reason_For_Rejection__c,(Select Id from Schedule_Sessions__r) FROM Event_Master__c];
        List<EventWrapper> eventWrappers = new List<EventWrapper>();
        String contact = Restcontext.request.params.get('contactId');
        Date today = Date.today();
        
        for (Event_Master__c event : allEvents) {
            Boolean isUpcoming = false;
            Boolean isPast = false;
            Boolean isApproved = false;
            Boolean isRejected = false;
            Boolean inReview = false;
            Boolean createdbyMe = (event.Contact__c!=null && contact!=null && event.Contact__c == contact) ? true : false;
            
            if (event.Event_Status__c == 'Pending Approval') {
                inReview = true;
            } else if (event.Event_Status__c == 'Approved') {
                isApproved = true;
            } else if (event.Event_Status__c == 'Rejected') {
                isRejected = true;
            } 
            
            if (event.Start_Date__c >= today) {
                isUpcoming = true;
            }
            
            if (event.Start_Date__c < today) {
                isPast = true;
            }
            
            EventWrapper eventWrapper = new EventWrapper(event, isUpcoming, isPast, inReview, isApproved, isRejected,createdbyMe);
            eventWrappers.add(eventWrapper);
        }
        
        return JSON.serialize(eventWrappers);
    }
    
    @HttpPOST
    global static void eventPostMethod(){
        eventHandler(RestContext.request.requestBody.toString());
    }
    public static void eventHandler(String eventWrapperDetails){
        String eventBroucherURL = ' ';
        String eventBannerURL =' ';
        
        eventWrapper request = (eventWrapper) JSON.deserialize(
            eventWrapperDetails,
            eventWrapper.class
        );

        request.isEventBroucher = true;
        if(request?.eventBroucher !=null && String.isNotBlank(request?.eventBroucher.imageUrl) && request?.isEventBroucher){
            eventBroucherURL = ken42_CreateContentVersion.createContentVersion(request.eventBroucher.fileName, request.eventBroucher.imageUrl);
        }
        if((request?.coverImage !=null && String.isNotBlank(request?.coverImage.imageUrl))){
            eventBannerURL = ken42_CreateContentVersion.createContentVersion(request.coverImage.fileName, request.coverImage.imageUrl);
        }
        
        Event_Master__c event = new Event_Master__c();
        if(request.eventTitle !=null && request.eventTitle !=''){
            event.Name = request.eventTitle;
        }
        if(request.category !=null && request.category !=''){
            event.Event_Type__c = request.category;
        }
        if(request.maximumNumberofParticipants !=null){
            event.Max_Allowed_Participants__c = request.maximumNumberofParticipants;
        }
        
        if(request.description !=null && request.description !=''){
            event.Description__c = request.description;
        }
        if(request.agenda !=null && request.agenda !=''){
            event.Target_Keywords__c = request.agenda;
        }
        if(request.suitablefor !=null && request.suitablefor !=''){
            event.Target_Audience_Applicable__c	 = request.suitablefor;
        }
        if(request.languageOfDelivery !=null && request.languageOfDelivery !=''){
            event.Language__c = request.languageOfDelivery;
        }
        if(request.startDate !=null){
            event.Start_Date__c = request.startDate;
        }
        
        if(request.endDate !=null){
            event.End_Date__c = request.endDate;
        }
        
        if(request.startTime !=null){
            event.Start_Time__c = request.startTime;
        }
        
        if(request.endTime !=null){
            event.End_Time__c = request.endTime;
        }
        
        if(eventBroucherURL !=null && string.isNotBlank(eventBroucherURL)){
            event.Event_Broucher__c = eventBroucherURL;
            event.Broucher_Title__c = request.eventBroucher.fileName;
        }
        
        if(eventBannerURL !=null && string.isNotBlank(eventBannerURL)){
            event.Event_banner__c = eventBannerURL;
            event.Cover_Image_Title__c = request.coverImage.fileName;
        }
        if(request.currentStep !=null){
            event.Event_Current_Step__c = request.currentStep;
        }
        
        if(request.targetKeyWords !=null && request.targetKeyWords !=''){
            event.What_to_Expect_From_Event__c = request.targetKeyWords;
        }
        if(String.isNotBlank(request.contactId)){
            event.Contact__c = request.contactId;
        }
        if(String.isNotBlank(request.eventPricingType)){
            event.Event_Pricing__c = request.eventPricingType;
        }
        if(String.isNotBlank(request.timezone)){
            event.Timezone__c = request.timezone;
        }
        
        event.RecordTypeId = [Select Id from RecordType where sObjectType='Event_Master__c' AND DeveloperName ='Event' LIMIT 1]?.Id;
        
        if(string.isNotBlank(request?.Id)){
            event.Id = request.Id;
            update event;
        }
        else{
            insert event;   
        }
        eventResponse response = new eventResponse();
        response.eventId=event.Id;
        response.name = event.Name;
        response.eventAgenda = event.Target_Keywords__c;
        response.eventTimezone = event.Timezone__c;
        response.coverImage = new imageWrapper(event.Cover_Image_Title__c,event.Event_banner__c);
        response.brochureImage = new imageWrapper(event.Broucher_Title__c, event.Event_Broucher__c);
        response.currentStep = event.Event_Current_Step__c;
        response.suitablefor = event.Target_Audience_Applicable__c;
        RestApiUtility.createSuccessPostResponse(response);
        
    }
    
    public class eventWrapper{
        public string Id;
        public string contactId;
        public string eventTitle;
        public String category;
        public Decimal maximumNumberofParticipants;
        public String description;
        public String agenda;
        public String targetKeyWords;
        public String suitablefor;
        public String languageOfDelivery;
        public String timezone;
        public imageWrapper eventBroucher;
        public Boolean isEventBroucher;
        public Date startDate;
        public Date endDate;
        public Time startTime;
        public Time endTime;
        public imageWrapper coverImage;
        public Decimal currentStep;
        public Boolean isUpcoming;
        public Boolean ispast;
        public Boolean inReview;
        public Boolean isApproved;
        public Boolean isRejected;
        private Boolean isActive;
        public Decimal eventFee;
        public String eventPricingType;
        public Boolean eventNoFee;
        public Datetime createdDate;
        public Boolean createdbyMe;
        public String reasonForRejection;
        
        public EventWrapper(Event_Master__c event, Boolean isUpcoming, Boolean isPast, Boolean inReview, Boolean isApproved, Boolean isRejected,Boolean createdbyMe){
            this.Id = event.Id;
            this.eventTitle = event.Name;
            this.category = event.Event_Type__c;
            this.startdate = event.Start_Date__c;
            this.enddate = event.End_Date__c;
            this.startTime = event.Start_Time__c;
            this.endTime = event.End_Time__c;
            this.description = event.Description__c;
            this.agenda =event.Target_Keywords__c;
            this.coverImage = new imageWrapper(event.Cover_Image_Title__c,event.Event_banner__c);
            this.eventBroucher = new imageWrapper(event.Broucher_Title__c,event.Event_Broucher__c);
            this.currentStep = event.Event_Current_Step__c;
            this.languageOfDelivery = event.Language__c;
            this.eventFee = event.Event_Fee__c;
            this.eventPricingType = event.Event_Pricing__c;
            this.eventNoFee = event.No_Fee__c;
            this.maximumNumberofParticipants = event.Max_Allowed_Participants__c;
            this.targetKeyWords = event.What_to_Expect_From_Event__c;
            this.suitablefor = event.Target_Audience_Applicable__c;
            this.createdDate = event.CreatedDate;   
            this.contactId = event.Contact__c;
            this.timezone = event.Timezone__c;
            this.reasonForRejection = event.Reason_For_Rejection__c;
            this.isActive = event.Is_Active__c;
            this.createdbyMe = createdbyMe;
            this.isUpcoming = isUpcoming;
            this.ispast = ispast;
            this.inReview = inReview;
            this.isApproved = isApproved; 
            this.isRejected = isRejected; 
        }
    }
    
    public class eventResponse{
        public Id eventId;
        public String name;
        public String eventAgenda;
        public imageWrapper coverImage;
        public imageWrapper brochureImage;
        public Decimal currentStep;
        public String suitablefor;
        public String eventTimezone;
    }
    
    public class imageWrapper{
        public String fileName;
        public String imageUrl; 
        
        public imageWrapper(String fileName, String imageUrl){
            this.fileName = fileName;
            this.imageUrl = imageUrl;
        }
    }
}