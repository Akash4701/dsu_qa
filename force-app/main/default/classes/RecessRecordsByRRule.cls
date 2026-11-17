@RestResource(UrlMapping='/recessRecords/*')
global class RecessRecordsByRRule {
    
    @HttpPost
    global static void createRecessRecords(){
        RestResponse res = RestContext.response;
        mainWrapper mainRequest = (mainWrapper) json.deserialize(RestContext.request.requestBody.toString(), mainWrapper.class);
        String reqOperation = mainRequest.operation.toLowerCase();
        if(reqOperation == 'validate'){
            system.debug('from validate');
            List<requestWrapper> requestList = mainRequest.sessions;   //(List<requestWrapper>) json.deserialize(RestContext.request.requestBody.toString(), List<requestWrapper>.class);
            List<Session__c> sessionList = new List<Session__c>();
            List<String> error = new List<String>();
            Set<Date> datesBetween = new Set<Date>();
            Set<DateTime> startDates = new Set<DateTime>();
            Set<DateTime> endDates = new Set<DateTime>();
            for(requestWrapper request:requestList){
                Session__c sessionObj = new Session__c();
                if(request.recordId != null && String.isNotBlank(request.recordId)){
                    sessionObj.Id = request.recordId;
                }
                sessionObj.Break_Session_Name__c = request.name;
                for(Date dt:returnDatesBtwTwoDates(Date.valueOf(request.startDateTime),Date.valueOf(request.endDateTime))){
                    startDates.add(DateTime.newInstance(dt,request.startDateTime.time()));
                    endDates.add(DateTime.newInstance(dt,request.endDateTime.time()));
                }
                List<DateTime> conStList = new List<DateTime>(startDates);
                List<DateTime> conEdList = new List<DateTime>(endDates);
                system.debug('st'+conStList);
                system.debug('st'+conEdList);
                error=doValidate(conStList,conEdList);
                sessionObj.Start_Date_Time__c = request.startDateTime;
                sessionObj.End_Date_Time__c = request.endDateTime;
                sessionObj.Select_Days__c = request.selectedDays;
                sessionObj.Frequency__c = request.frequency;
                sessionObj.RRule_String__c = request.rRuleString;
                sessionObj.RecordTypeId = schema.SObjectType.Session__c.getRecordTypeInfosByName().get('Recess').getRecordTypeId();
                if(String.isNotBlank(request.termId)){
                    sessionObj.Term__c = request.termId;
                }
                if(String.isNotBlank(request.programPlanId)){
                    sessionObj.Program_Plan__c = request.programPlanId;
                }
                if(String.isNotBlank(request.academicProgramId)){
                    sessionObj.Institute__c = request.academicProgramId;
                }
            }
            
            System.debug(startDates);
            System.debug(endDates);
            system.debug(error);
            if(!error.isEmpty()){
                res.statusCode = 400;
                res.responseBody = Blob.valueOf('{ "success": "false" , "message":'+json.serialize(error)+' }');
            }else if(error.isEmpty()){
                res.statusCode = 200;
                res.responseBody = Blob.valueOf('{ "success": "true" , "message": "Session can be created" }' );
            }
        }
        else if(reqOperation == 'create'){
            system.debug('from create');
            List<requestWrapper> requestList = mainRequest.sessions;   //(List<requestWrapper>) json.deserialize(RestContext.request.requestBody.toString(), List<requestWrapper>.class);
            List<Session__c> sessionList = new List<Session__c>();
            List<String> error = new List<String>();
            Set<Date> datesBetween = new Set<Date>();
            Set<DateTime> startDates = new Set<DateTime>();
            Set<DateTime> endDates = new Set<DateTime>();
            for(requestWrapper request:requestList){
                Session__c sessionObj = new Session__c();
                if(request.recordId != null && String.isNotBlank(request.recordId)){
                    sessionObj.Id = request.recordId;
                }
                sessionObj.Break_Session_Name__c = request.name;
                for(Date dt:returnDatesBtwTwoDates(Date.valueOf(request.startDateTime),Date.valueOf(request.endDateTime))){
                    startDates.add(DateTime.newInstance(dt,request.startDateTime.time()));
                    endDates.add(DateTime.newInstance(dt,request.endDateTime.time()));
                }
                List<DateTime> conStList = new List<DateTime>(startDates);
                List<DateTime> conEdList = new List<DateTime>(endDates);
                error=doValidate(conStList,conEdList);
                //here the value "0.22916666666" was taken from 330/1440 for adjusting the timezone
                sessionObj.Start_Date_Time__c = request.startDateTime;
                sessionObj.End_Date_Time__c = request.endDateTime;
                if(String.isNotBlank(request.selectedDays)){
                    sessionObj.Select_Days__c = request.selectedDays;
                }
                if(String.isNotBlank(request.frequency)){
                    sessionObj.Frequency__c = request.frequency;
                }
                if(String.isNotBlank(request.rRuleString)){
                    sessionObj.RRule_String__c = request.rRuleString;
                }
                if(request.typeOfSession == 'Break'){
                    sessionObj.RecordTypeId = schema.SObjectType.Session__c.getRecordTypeInfosByName().get('Recess').getRecordTypeId();
                }else if(request.typeOfSession == 'AllSessions'){
                    sessionObj.RecordTypeId = schema.SObjectType.Session__c.getRecordTypeInfosByName().get('All Session').getRecordTypeId();
                }
                if(String.isNotBlank(request.termId)){
                    sessionObj.Term__c = request.termId;
                }
                if(String.isNotBlank(request.programPlanId)){
                    sessionObj.Program_Plan__c = request.programPlanId;
                }
                if(String.isNotBlank(request.academicProgramId)){
                    sessionObj.Institute__c = request.academicProgramId;
                }
                sessionList.add(sessionObj);
            }
            
            System.debug(startDates);
            System.debug(endDates);
            if(!error.isEmpty()){
                res.statusCode = 400;
                res.responseBody = Blob.valueOf('{ "success": "false" , "message":'+json.serialize(error)+' }');
            }else if(!sessionList.isEmpty() && error.isEmpty()){
                upsert sessionList;
                res.statusCode = 201;
                res.responseBody = Blob.valueOf('{ "success": "true" , "message": "Data Created" }' );
            }
        } 
        else{
            res.statusCode = 400;
            res.responseBody = Blob.valueOf('{ "success": "false" , "message":"something went wrong, Please check the operation once" }');
        }
    }
    public class mainWrapper{
        public string operation;
        public List<requestWrapper> sessions;
    }
    public class requestWrapper{
        public Id recordId;
        public String name;
        public DateTime startDateTime;
        public DateTime endDateTime;
        public String selectedDays;
        public String frequency;
        public String rRuleString;
        public String typeOfSession;
        public Id termId;
        public Id programPlanId;
        public Id academicProgramId;
    }
    public static List<String> doValidate(List<DateTime> startDateTimes,List<DateTime> endDateTimes){
        List<String> error = new List<String>();
        List<Session__c> sessionsList = [Select Id,Start_Date_Time__c,End_Date_Time__c from Session__c];
        for(Session__c sesObj:[Select Id,Start_Date_Time__c,End_Date_Time__c from Session__c]){
            for(integer i=0;i<startDateTimes.size();i++){
                if((sesObj.Start_Date_Time__c >= startDateTimes[i] && sesObj.Start_Date_Time__c < endDateTimes[i]) || (sesObj.End_Date_Time__c > startDateTimes[i] && sesObj.End_Date_Time__c <= endDateTimes[i]))  {
                    error.add(sesObj.id+' these session was overlapping with break time');
                    
                }
            }
        }
        return error;
    }
    public static set<Date> returnDatesBtwTwoDates(Date stDate,Date endDate){
        set<Date> datesBtwTwoDates = new set<Date>();
        for(integer i=0;i<=stDate.daysBetween(endDate);i++){
            Date addingDAte = stDate.addDays(i);
            Integer year_p = addingDate.year();
            Integer month_p = addingDate.month();
            Integer day_p = addingDate.day();
            Date myDT = Date.newInstance(year_p, month_p, day_p);
            datesBtwTwoDates.add(myDT);
        }
        return datesBtwTwoDates;
    }
    
  
}