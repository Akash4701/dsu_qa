public with sharing class EventFormController {
    
    @AuraEnabled(cacheable=true)
    public static List<Contact> searchContact(String searchKey) {
        String query = '%' + searchKey + '%';
        return [SELECT Id, Name FROM Contact WHERE Name LIKE :query LIMIT 10];
    }
    
    @AuraEnabled
    public static Contact getContactDetails(Id contactId){
        try {
            return [SELECT Id, Name, Email FROM Contact WHERE Id = :contactId LIMIT 1];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static Contact createContact(String name) {
        Contact newContact = new Contact();
        newContact.LastName = name;
        insert newContact;
        return newContact;
    }
    
    @AuraEnabled
    public static void deleteSpeaker(String recordId) {
        delete [select Id from Events_Sessions_Enrollment__c WHERE Id=:recordId];
    }
    
    @AuraEnabled
    public static void deleteEventSession(String recordId) {
        try {
            
            if(String.isBlank(recordId)){
                throw new AuraHandledException('Record Id is required');
            }
            
            fflib_SObjectUnitOfWork uow = new fflib_SObjectUnitOfWork(new Schema.SObjectType[] {
                Schedule_Sessions__c.SObjectType,
                    Events_Sessions_Enrollment__c.SObjectType
                    });
            
            Schedule_Sessions__c sessionToDelete = [SELECT Id FROM Schedule_Sessions__c WHERE Id = :recordId LIMIT 1];
            List<Events_Sessions_Enrollment__c> enrollmentsToDelete= [SELECT Id FROM Events_Sessions_Enrollment__c WHERE Schedule_Sessions__c = :recordId];
            
            uow.registerDeleted(sessionToDelete);
            uow.registerDeleted(enrollmentsToDelete);
            
            uow.commitWork();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static List<EventScheduleWrapper> getEventSchedule(String recordId) {
        try {
            
            List<Schedule_Sessions__c> eventSchedule = [
                SELECT
                Id,
                What_to_Expect_From_Event__c,
                Name,(SELECT Id, Contact__r.Name,Contact__c, Description__c,Speaker_Image__c,Schedule_Sessions__c FROM Event_Session_Account_Associations__r),
                Session_Broucher__c,
                Event_Reference__c,
                Start_Date__c,
                Start_Time__c,
                End_Time__c,
                Location_Type__c,
                Session_Link__c,
                Location__c,
                End_Date__c,
                Session_Fee__c,
                No_Fee__c,
                Broucher_Type__c,
                Broucher_Name__c
                FROM Schedule_Sessions__c
                WHERE Event_Reference__c = :recordId
            ];
            
            List<EventScheduleWrapper> eventScheduleList = new List<EventScheduleWrapper>();
            if(!eventSchedule.isEmpty()){
                for (Schedule_Sessions__c eachSchedule : eventSchedule) {
                    EventScheduleWrapper eventSc = new EventScheduleWrapper(eachSchedule);
                    eventScheduleList.add(eventSc);
                }
            }
            
            return eventScheduleList;
            
        } catch (Exception ex) {
            System.debug('Error in getEventSchedule: ' + ex.getMessage()+'at line '+ex.getLineNumber());
            throw new AuraHandledException(ex.getMessage());
        }
    }
    
    @AuraEnabled
    public static void createEventSchedule(String records) {
        
        try{
            
            if(String.isBlank(records)){
                throw new AuraHandledException('Records are required');
            }
            
            List<EventScheduleWrapper> requestBody = (List<EventScheduleWrapper>) JSON.deserialize(
                records,
                List<EventScheduleWrapper>.class
            );
            
            if (requestBody.isEmpty()) {
                return;
            }
            
            // Extract the eventId from the first record
            String eventId = requestBody[0].eventId;
            if (String.isBlank(eventId)) {
                throw new AuraHandledException('Event ID is required');
            }
            
            Set<Id> incomingSessionIds = new Set<Id>();
            Set<Id> sessionSpeakerEnrollmentIds = new Set<Id>();
            
            // Create an instance of UnitOfWork
            fflib_SObjectUnitOfWork uow = new fflib_SObjectUnitOfWork(new Schema.SObjectType[] {
                Schedule_Sessions__c.SObjectType,
                    Events_Sessions_Enrollment__c.SObjectType
                    });
            
            
            for (EventScheduleWrapper eachEventSchedule : requestBody) {
                
                Schedule_Sessions__c session = eachEventSchedule.getRecord();
                
                if (String.isNotBlank(session?.Id)) {
                    uow.registerDirty(session);
                    incomingSessionIds.add(session.Id);
                } else {
                    uow.registerNew(session);
                }
                
                for (SpeakerWrapper speaker : eachEventSchedule.speakers) {
                    Events_Sessions_Enrollment__c sessionSpeakerEnrollment = speaker.getSessionEnrollmentRecord();
                    
                    if (String.isNotBlank(session?.Id)) {
                        sessionSpeakerEnrollment.Schedule_Sessions__c = session?.Id;
                    } 
                    
                    if (String.isNotBlank(sessionSpeakerEnrollment?.Id)) {
                        uow.registerDirty(sessionSpeakerEnrollment);
                        sessionSpeakerEnrollmentIds.add(sessionSpeakerEnrollment.Id);
                    } else {
                        uow.registerNew(sessionSpeakerEnrollment, Events_Sessions_Enrollment__c.Schedule_Sessions__c, session);
                    }
                }
            }
            
            // Query existing enrollments for this event
            List<Events_Sessions_Enrollment__c> enrollmentsToDelete = [
                SELECT Id
                FROM Events_Sessions_Enrollment__c 
                WHERE Schedule_Sessions__r.Event_Reference__c = :eventId
                AND Id NOT IN :sessionSpeakerEnrollmentIds
            ];
            
            // Query existing sessions for this event that are not in the incoming data
            List<Schedule_Sessions__c> sessionsToDelete = [
                SELECT Id
                FROM Schedule_Sessions__c
                WHERE Event_Reference__c = :eventId
                AND Id NOT IN :incomingSessionIds
            ];
            
            // Register objects for deletion in the unit of work
            for (Events_Sessions_Enrollment__c enrollment : enrollmentsToDelete) {
                uow.registerDeleted(enrollment);
            }
            
            for (Schedule_Sessions__c session : sessionsToDelete) {
                uow.registerDeleted(session);
            }
            
            // Commit all changes in a single transaction
            uow.commitWork();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**********insert Speakers************************/
    @AuraEnabled
    public static void insertSpeaker(String records){
        System.debug('records------'+records);
        List<Events_Sessions_Enrollment__c> requestBody = (List<Events_Sessions_Enrollment__c>) JSON.deserialize(
            records,
            List<Events_Sessions_Enrollment__c>.class
        );
        System.debug('requestBody===='+requestBody);
        upsert requestBody;
    }
    
    /********** Fetch event details***************/
    @AuraEnabled(cacheable=true)
    public static EventWrapper getEvent(String recordId){
        Event_Master__c event = [SELECT Id, Name,Event_Current_Step__c,Language__c,Event_Status__c,Target_Keywords__c,Event_Broucher__c,Description__c,createdDate,Event_Fee__c,No_Fee__c, RecordTypeId, End_Date__c, End_Time__c, Event_Group_Id__c, Event_Type__c, Event_banner__c, Evvent_Group__c, Is_Archived__c, Is_Scheduled__c, Is_Active__c, Location__c, Max_Allowed_Participants__c, Start_Date__c, Start_Time__c, Title__c, What_to_Expect_From_Event__c FROM Event_Master__c WHERE Id=:recordId];
        
        EventWrapper eventWrapper = new EventWrapper(event);
        return eventWrapper;
    } 
    
    @AuraEnabled(cacheable=true)
    public static Map<String,String> getFileUploadSettings(String allowedFileTypes, String maxFileSize){
        
        Map<String,String> eventFileUploadSettings = new Map<String,String>();
        Alumni_Org_Parameters__c orgSettings = Alumni_Org_Parameters__c.getInstance();
        
        
        if(orgSettings != null){
            eventFileUploadSettings.put('allowedFileTypes',String.valueOf(orgSettings.get(allowedFileTypes)));
            eventFileUploadSettings.put('maxFileSize',String.valueOf(orgSettings.get(maxFileSize)));
        }
        
        return eventFileUploadSettings;
    }
    
    @AuraEnabled
    public static void updateEvent(string eventData){
        System.debug('records===='+eventData);
        EventWrapper requestBody = (EventWrapper) JSON.deserialize(
            eventData,
            EventWrapper.class
        );
        Event_Master__c updateEvent = requestBody.getRecord();
        update updateEvent;
    }    
    
    /********** Fee Setup******************************/    
    
    @AuraEnabled
    public static void updateFee(Boolean isEventWise, Id eventId, Integer eventFee, Boolean isNoFee, List<Schedule_Sessions__c> sessionsMap) {
        // If event-wise fee update
        if (isEventWise) {
            // Fetch the event record
            Event_Master__c eventRecord = [SELECT Id, Event_Fee__c, No_Fee__c FROM Event_Master__c WHERE Id = :eventId LIMIT 1];
            
            // Set the event-level fee or no-fee values
            eventRecord.Event_Fee__c = eventFee;
            eventRecord.No_Fee__c = isNoFee;
            
            // Update the event record
            update eventRecord;
        }
        else {
            List<Schedule_Sessions__c> sessionsToUpdate = new List<Schedule_Sessions__c>();
            for (Schedule_Sessions__c eachSession: sessionsMap) {
                Schedule_Sessions__c session = new Schedule_Sessions__c(Id=eachSession.Id);
                session.Session_Fee__c = eachSession.Session_Fee__c;
                session.No_Fee__c = eachSession.No_Fee__c;
                sessionsToUpdate.add(session);
            }
            if (!sessionsToUpdate.isEmpty()) {
                update sessionsToUpdate;
            }
        }
    }    
    
    @AuraEnabled(cacheable=true)
    public static List<Contact> searchContacts() {
        return [
            SELECT Id, Name
            FROM Contact
            
        ];
    }
    //GET SESSIONS    
    @AuraEnabled
    public static List<Schedule_Sessions__c> getEventSessions(string eventId) {
        System.debug('eventId--'+eventId);
        
        return  [SELECT Id, Name, 
                 Session_Broucher__c,End_Time__c,
                 Start_Date__c,Location_Type__c,Session_Link__c,
                 Event_Reference__c,Event_Reference__r.Event_Broucher__c,
                 Event_Reference__r.Event_banner__c,Event_Reference__r.Name,
                 Event_Reference__r.Event_Fee__c,Event_Reference__r.No_Fee__c,
                 Event_Reference__r.Event_Type__c, 
                 Event_Reference__r.Start_Date__c,
                 Event_Reference__r.End_Date__c,
                 Event_Reference__r.Max_Allowed_Participants__c,
                 Event_Reference__r.Description__c,
                 Start_Time__c, Session_Fee__c,What_to_Expect_From_Event__c, No_Fee__c, Location__c
                 FROM Schedule_Sessions__c WHERE Event_Reference__c =:eventId ORDER BY Start_Date__c];
    }
    
    @AuraEnabled(cacheable=true)
    public static list<sObject> fetchLookupData(string searchKey , string sObjectApiName) {    
        List < sObject > returnList = new List < sObject > ();
        string sWildCardText = '%' + searchKey + '%';
        String sQuery = 'SELECT Id, Name ' +
            'FROM ' + sObjectApiName + ' ' +
            'WHERE Name LIKE :sWildCardText ' +
            'AND RecordType.DeveloperName = \'Event_Group\' ' +
            'ORDER BY CreatedDate DESC ' +
            'LIMIT 5';
        for (sObject obj: database.query(sQuery)) {
            returnList.add(obj);
        }
        return returnList;
    }
    
    @AuraEnabled(cacheable=true)
    public static Map<String, List<Map<String, String>>> getPicklistValues(String objectName, List<String> fieldNames) {
        Map<String,List<Map<String,String>>> picklictValuesByField = new Map<String,List<Map<String,String>>>();
        try{
            Schema.SObjectType objectType = Schema.getGlobalDescribe().get(objectName);
            if (objectType == null) {
                throw new AuraHandledException('Object ' + objectName + ' not found');
            }
            
            Schema.DescribeSObjectResult describeObjResult = objectType.getDescribe();
            
            Map<String, Schema.SObjectField> fieldMap = describeObjResult.fields.getMap();
            for(String field : fieldNames){
                if(!fieldMap.containsKey(field)){
                    continue;
                }
                
                Schema.DescribeFieldResult fieldResult = fieldMap.get(field).getDescribe();
                List<Map<String,String>> picklistValues = new List<Map<String,String>>();
                for (Schema.PicklistEntry entry : fieldResult.getPicklistValues()) {
                    picklistValues.add(new Map<String,String>{'label' => entry.getLabel(), 'value' => entry.getValue()});
                }
                picklictValuesByField.put(field,picklistValues);
            }
            
            return picklictValuesByField;
        }catch(Exception e){
            throw new AuraHandledException('Error retrieving picklist values: ' + e.getMessage());
        }
    }
    @AuraEnabled
    public static String saveData(String eventData) {
        EventWrapper wrapper = (EventWrapper) JSON.deserialize(eventData, EventWrapper.class);
        
        Id recordTypeId = Schema.SObjectType.Event_Master__c.getRecordTypeInfosByName().get('Event Group').getRecordTypeId();
        
        Event_Master__c record = new Event_Master__c();
        record.Id =  String.isNotBlank(wrapper.Id) ? wrapper.Id : null;
        record.Name = (wrapper.eventGroupTitle != null && wrapper.eventGroupTitle != '') ? wrapper.eventGroupTitle : wrapper.eventTitle;
        
        if (wrapper.isEventGroup) {
            record.RecordTypeId = recordTypeId;
        }
        if (wrapper.eventGroupId != null && wrapper.eventGroupId != '') {
            record.Evvent_Group__c = wrapper.eventGroupId;
        }
        if (wrapper.startdate != null) {
            record.Start_Date__c = wrapper.startdate;
        }
        if (wrapper.enddate != null) {
            record.End_Date__c = wrapper.enddate;
        }
        
        record.Event_Type__c = wrapper.eventTypes;
        record.Description__c = wrapper.description;
        record.Target_Keywords__c = wrapper.agenda;
        record.Event_banner__c = String.isNotBlank(wrapper.image) ? ken42_CreateContentVersion.createContentVersion(wrapper.imageFileName, wrapper.image) : null;
        record.Max_Allowed_Participants__c = wrapper.maximumNumberOfParticipants;
        upsert record;
        
        return record.Id;
    }
    
    public class EventWrapper {
        @AuraEnabled
        public String Id { get; set; }
        @AuraEnabled
        public String contentDocumentId { get; set; }
        @AuraEnabled
        public Boolean isEventGroup { get; set; }
        @AuraEnabled
        public String eventTitle { get; set; }
        @AuraEnabled
        public String eventGroupId { get; set; }
        @AuraEnabled
        public String eventGroupTitle { get; set; }
        @AuraEnabled
        public String eventTypes { get; set; }
        @AuraEnabled
        public String description { get; set; }
        @AuraEnabled
        public String agenda { get; set; }
        @AuraEnabled
        public Date startdate { get; set; }
        @AuraEnabled
        public Date enddate { get; set; }
        @AuraEnabled
        public String image { get; set; }
        @AuraEnabled
        public String imageFileName { get; set; }
        @AuraEnabled
        public Decimal maximumNumberOfParticipants { get; set; }
        @AuraEnabled
        public String targetKeywords { get; set; }
        @AuraEnabled
        public String eventLanguages { get; set; }
        @AuraEnabled
        public String eventExpectations { get; set; }
        
        public EventWrapper(Event_Master__c event){
            this.Id = event.Id;
            this.eventTitle = event.Name;
            this.eventTypes = event.Event_Type__c;
            this.startdate = event.Start_Date__c;
            this.enddate = event.End_Date__c;
            this.description = event.Description__c;
            this.agenda =event.Target_Keywords__c;
            this.eventExpectations = event.What_to_Expect_From_Event__c;
            this.targetKeyWords = event.Target_Keywords__c;
            this.maximumNumberOfParticipants = event.Max_Allowed_Participants__c;
            this.image = event.Event_banner__c;
            this.eventLanguages = event.Language__c;
        }
        public Event_Master__c getRecord(){
            Event_Master__c updateEvent = new Event_Master__c();
            updateEvent.Id = this.Id;
            if(this.eventTitle !=null && this.eventTitle !=''){
                updateEvent.Name = this.eventTitle;
            }  
            if(this.eventTypes !=null && this.eventTypes !=''){
                updateEvent.Event_Type__c = this.eventTypes;
            }  
            if(this.eventLanguages !=null && this.eventLanguages !=''){
                updateEvent.Language__c = this.eventLanguages;
            }    
            if(this.startdate !=null){
                updateEvent.Start_Date__c = this.startdate;
            }   
            if(this.enddate !=null){
                updateEvent.End_Date__c = this.enddate;
            }   
            if(this.description !=null && this.description !=''){
                updateEvent.Description__c =  this.description;
            }   
            if(this.agenda !=null && this.agenda !=''){
                updateEvent.Target_Keywords__c = this.agenda;
            } 
            if(this.eventExpectations !=null && this.eventExpectations !=''){
                updateEvent.What_to_Expect_From_Event__c = this.eventExpectations;
            } 
            if(this.maximumNumberOfParticipants !=null){
                updateEvent.Max_Allowed_Participants__c = this.maximumNumberOfParticipants;
            } 
            if(this.image !=null && this.image !=''){
                updateEvent.Event_banner__c = ken42_CreateContentVersion.createContentVersion(this.imageFileName, this.image);
            } 
            
            return updateEvent;
        }
    }
    
    public class EventScheduleWrapper {
        @AuraEnabled
        public String Id;
        @AuraEnabled
        public String agenda;
        @AuraEnabled
        public Date startDate;
        @AuraEnabled
        public Time startTime;
        @AuraEnabled
        public Time endTime;
        @AuraEnabled
        public Date endDate;
        @AuraEnabled
        public String eventId;
        @AuraEnabled
        public String locationType;
        @AuraEnabled
        public String locationAddress;
        @AuraEnabled
        public String sessionLink;
        @AuraEnabled
        public String name;
        @AuraEnabled
        public String sessionBroucher;
        @AuraEnabled
        public String broucherFileType;
        @AuraEnabled
        public String sessionBroucherBase64;
        @AuraEnabled
        public String brochureFileName;
        @AuraEnabled
        public List<SpeakerWrapper> speakers;
        
        public EventScheduleWrapper() {
            this.speakers = new List<SpeakerWrapper>();
        }
        
        public EventScheduleWrapper(Schedule_Sessions__c eventSchedule) {
            this.Id = eventSchedule?.Id != null?eventSchedule.Id:'';
            this.agenda = eventSchedule.What_to_Expect_From_Event__c;
            this.startTime = eventSchedule.Start_Time__c;
            this.endTime = eventSchedule.End_Time__c;
            this.startDate = eventSchedule.Start_Date__c!=null?eventSchedule.Start_Date__c:null;
            this.eventId = eventSchedule.Event_Reference__c;
            this.sessionBroucher = eventSchedule.Session_Broucher__c;
            this.name = eventSchedule.Name;
            this.locationType = eventSchedule.Location_Type__c;
            this.locationAddress = eventSchedule.Location__c;
            this.sessionLink = eventSchedule.Session_Link__c;
            this.broucherFileType = eventSchedule.Broucher_Type__c;
            this.brochureFileName = eventSchedule.Broucher_Name__c;
            
            // If there are speaker child records, map them to the SpeakerWrapper
            this.speakers = new List<SpeakerWrapper>();
            if (eventSchedule.Event_Session_Account_Associations__r != null) {
                for (Events_Sessions_Enrollment__c speakerRecord : eventSchedule.Event_Session_Account_Associations__r) {
                    this.speakers.add(new SpeakerWrapper(speakerRecord));
                }
            }
        }
        
        public Schedule_Sessions__c getRecord() {
            
            Schedule_Sessions__c es = new Schedule_Sessions__c();
            
            if (this.Id != null && this.Id !='')
                es.Id = this.Id;
            
            if (this.agenda != null && this.agenda !='')
                es.What_to_Expect_From_Event__c = this.agenda;
            
            if (this.startDate != null)
                es.Start_Date__c = this.startDate;
            
            if (this.startTime != null)
                es.Start_Time__c = this.startTime.addHours(5).addMinutes(30);
            
            if (this.endTime != null)
                es.End_Time__c = this.endTime.addHours(5).addMinutes(30);
            
            if (this.eventId != null && this.eventId !=' ')
                es.Event_Reference__c = this.eventId;
            
            if (this.name != null && this.name !='')
                es.Name = this.name;
            
            if (this.locationType != null && this.locationType !='')
                es.Location_Type__c = this.locationType;
            
            if (this.locationAddress != null && this.locationAddress !='')
                es.Location__c = this.locationAddress;
            
            if (this.broucherFileType != null && this.broucherFileType !='')
                es.Broucher_Type__c = this.broucherFileType;
            
            if (this.sessionLink != null && this.sessionLink !='')
                es.Session_Link__c = this.sessionLink;
            
            if (this.brochureFileName != null && this.brochureFileName !='')
                es.Broucher_Name__c = this.brochureFileName;
            
            if (this.sessionBroucher!= null && this.sessionBroucher !=''){
                if(!this.sessionBroucher.startsWith('http')){
                    Integer Index = this.sessionBroucher.indexOf(',');
                    if( Index != -1){
                        String  base64Content= this.sessionBroucher.substring(Index + 1);
                        string publicurl = ken42_CreateContentVersion.createContentVersion(this.brochureFileName, base64Content);
                        es.Session_Broucher__c = publicurl;
                    }
                }
            }else{
                es.Session_Broucher__c = this.sessionBroucher;
            }
            
            return es;
        }
    }
    
    public class SpeakerWrapper {
        @AuraEnabled
        public String Id { get; set; }
        @AuraEnabled
        public String name { get; set; }       
        @AuraEnabled
        public String description { get; set; }
        
        @AuraEnabled
        public String contactId { get; set; }
        @AuraEnabled
        public String speakerImage { get; set; }
        @AuraEnabled
        public String speakerImageBase64 { get; set; }
        
        // Default Constructor
        public SpeakerWrapper() {}
        
        // Constructor to initialize the name and description from the related record
        public SpeakerWrapper(Events_Sessions_Enrollment__c speakerRecord) {
            this.name = speakerRecord.Contact__c != null ? speakerRecord.Contact__r.Name : '';
            this.description = speakerRecord.Description__c != null ? speakerRecord.Description__c : '';
            this.Id = speakerRecord.Id != null ? speakerRecord.Id : null;
            this.contactId = speakerRecord.Contact__c != null ? speakerRecord.Contact__c : null;
            this.speakerImage = speakerRecord.Speaker_Image__c != null ? speakerRecord.Speaker_Image__c : null;
        }
        public Events_Sessions_Enrollment__c getSessionEnrollmentRecord(){
            Events_Sessions_Enrollment__c speakerRecord = new Events_Sessions_Enrollment__c();
            if (this.description != null && this.description != '') {
                speakerRecord.Description__c = this.description;
            }
            if (this.Id != null && this.Id != '') {
                speakerRecord.Id = this.Id;
            }
            if (this.contactId != null && this.contactId!= '') {
                speakerRecord.Contact__c = this.contactId;
            }
            if (this.speakerImage != null && this.speakerImage!= '') {
                if(!this.speakerImage.startsWith('http')){
                    Integer Index = this.speakerImage.indexOf(',');
                    if( Index != -1){
                        String  base64Content= this.speakerImage.substring(Index + 1);
                        string publicurl = ken42_CreateContentVersion.createContentVersion('speakerImage.PNG', base64Content);
                        speakerRecord.Speaker_Image__c = publicurl;
                    }
                }
            }else{
                speakerRecord.Speaker_Image__c = this.speakerImage;
            }
            return speakerRecord;
        }
    }
    
    public class feeWrapper{
        @AuraEnabled
        public Decimal sessionFee{ get; set; }
        @AuraEnabled
        public Boolean noFee{ get; set; }  
    }
}