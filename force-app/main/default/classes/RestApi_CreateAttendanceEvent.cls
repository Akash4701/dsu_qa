@RestResource(urlMapping='/createAttendanceEvent')
global class RestApi_CreateAttendanceEvent {
    @HttpPost
    global static void doCreateAttendanceEvent(){
        RestResponse res = RestContext.response;
        string jsonResponse='';
        try{
            requestAttendanceEventWrapper requestAll = (requestAttendanceEventWrapper) JSON.deserialize(RestContext.request.requestBody.toString(),requestAttendanceEventWrapper.class);
            responseAttendanceEventWrapper responseAll=new responseAttendanceEventWrapper();
            List<responseAttendanceEventDataWrapper> responseList=new List<responseAttendanceEventDataWrapper>();
            List<requestAttendanceEventDataWrapper> requestList=new List<requestAttendanceEventDataWrapper>();
            List<hed__Attendance_Event__c> eventAllList=new List<hed__Attendance_Event__c>();
            requestList=requestAll.AttendanceEvent;
            List<Id> sessionIds = new List<Id>();

            if(!requestList.isEmpty())
            {
                for(requestAttendanceEventDataWrapper request:requestList)
                {
                   
                    hed__Attendance_Event__c event=new hed__Attendance_Event__c();
                    if(!String.isBlank(request.eventId))
                    {
                        event.Id=request.eventId;
                    }
                    event.Attendance_Status__c=request.attendanceStatus;
                    if(!String.isBlank(request.sessionId))
                    {
                        event.Session__c=request.sessionId;
                        sessionIds.add(request.sessionId);
                    }
                   	if(!String.isBlank(request.contactId))
                    {
                        event.hed__Contact__c=request.contactId;
                    }
                  //  if(request.attendanceStatus != 'Present'){
                    if(!String.isBlank(request.reasonType))
                    {
                        event.hed__Reason__c=request.reasonType;
                    }
                    if(!String.isBlank(request.reasonDescription))
                    {
                        event.hed__Reason_Description__c=request.reasonDescription;
                    }
                 /*   }else{
                        event.hed__Reason_Description__c = null;
                        event.hed__Reason__c = null;
                    } */
                    eventAllList.add(event);
                }
                if(!eventAllList.isEmpty())
                {
                    try{
                        database.upsertResult[] myResult=database.upsert(eventAllList,false);
                        List<Session__c> sessionListToUpdate = new List<Session__c>();
                        List<Session__c> sessions = [SELECT Id, Name,Attendance_Marked__c FROM Session__c WHERE Id IN:sessionIds];
                        for(Session__c sess : sessions){
                            sess.Attendance_Marked__c = true;
                            sessionListToUpdate.add(sess);
                        }
                        
                        update sessionListToUpdate;
                        
                        Set<Id> allSuccessId=new Set<Id>();
                        for(database.upsertResult s:myResult){
                            responseAttendanceEventDataWrapper response=new responseAttendanceEventDataWrapper();
                            if(s.isSuccess()){
                                allSuccessId.add(s.getId());
                                response.eventId=s.getId();
                                response.success='true';
                                response.message='Data is Upserted';
                                res.statusCode = 200;
                                responseList.add(response);
                            }
                            else{
                                database.Error[] er=s.getErrors();
                                for(database.Error e:er){
                                    response.success='true';
                                    response.message='Data is Not Upserted';
                                    response.errors=e.getStatusCode() + ': ' + e.getMessage();
                                    res.statusCode = 200;
                                    responseList.add(response);
                                }
                            }
                        }
                    }
                    Catch(Exception e){
                        responseAttendanceEventDataWrapper response=new responseAttendanceEventDataWrapper();
                        res.statusCode = 400;
                        response.success='false';
                        response.message='bad request';
                        response.errors=e.getMessage()+'at Line Number'+e.getLineNumber();
                        responseList.add(response);
                    }
                }
            }

            responseAll.AttendanceEvent=responseList;
            jsonResponse=json.serialize(responseAll);
            res.responseBody=Blob.valueOf(jsonResponse);
        		
        }Catch(Exception e){
            res.statusCode = 400;
            res.responseBody = Blob.valueOf( '{ "success": "false" , "message": "bad request", "errors": "'+e.getMessage()+'at Line Number'+e.getLineNumber()+'" }' );
        }
    }
                                                        
    //Wrapper class for the request from API 
    public class requestAttendanceEventWrapper {
        public List<requestAttendanceEventDataWrapper> AttendanceEvent {get;set;}
        public string Operation {get;set;}
   
    }
    public class requestAttendanceEventDataWrapper {
        public String contactId {get;set;}
        public String eventId {get;set;}
        public String sessionId {get;set;}
        public String attendanceStatus {get;set;}
        public string reasonType {get;set;}
        public string reasonDescription {get;set;}
    }
    public class responseAttendanceEventWrapper {
       public List<responseAttendanceEventDataWrapper> AttendanceEvent {get;set;}
    }
    public class responseAttendanceEventDataWrapper {
        public string success='true';
        public string message='Data is Added';
        public string errors {get;set;}
        public String eventId {get;set;}
    }
}