@RestResource(urlMapping='/attendancePerSession/*')
global class RestApi_AttendanceEvntsPerSession {
    @HttpGet
    global static void getAttendance(){
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');
        String sessionId = req.params.get('sessionId');
        system.debug('The sesscionId'+sessionId);
        String response = '';
        string jsonResponse;
        String jsonResponses;
        string query='';
        
        try{
            if(!String.isBlank(sessionId)){
                //query='SELECT Id,Name,Attendance_Status__c,hed__Contact__c,hed__Course_Connection__c,hed__Course_Name__c,Course_Offering__c,hed__Date__c,Session__c from hed__Attendance_Event__c where ';
                //query+=' Session__c=\''+sesscionId+'\'' ;
                system.debug('sesscionId====>'+sessionId);
                system.debug('@@@query'+query);
                List<Session__c> sessionList = [Select id,Name from Session__c where Id=:sessionId];
                if(!sessionList.isEmpty()){
                    List<hed__Attendance_Event__c> attEvntList = [SELECT Id,Name,Attendance_Status__c,hed__Contact__c,hed__Contact__r.Name,hed__Course_Connection__c,hed__Course_Name__c,Course_Offering__c,hed__Date__c,Session__c,hed__Reason__c,hed__Reason_Description__c,hed__Contact__r.Registration_Number__c,hed__Contact__r.Account.Student_Code__c from hed__Attendance_Event__c where Session__c=:sessionId];
                    List<hed__Attendance_Event__c> presentAttEvntList = [SELECT Id,Name,Attendance_Status__c,hed__Contact__c,hed__Course_Connection__c,hed__Course_Name__c,Course_Offering__c,hed__Date__c,Session__c,hed__Contact__r.Registration_Number__c,hed__Contact__r.Account.Student_Code__c from hed__Attendance_Event__c where Session__c=:sessionId and Attendance_Status__c='Present'];
                    List<responseWapper> wapperList = new List<responseWapper>();
                    List<attendanceWapper> attenWapperList = new List<attendanceWapper>();
                    for(hed__Attendance_Event__c attensEvnt:attEvntList){
                        attendanceWapper wapperObj = new attendanceWapper();
                        
                        wapperObj.attendanceEventId = attensEvnt.Id;
                        wapperObj.attendanceStatus = attensEvnt.Attendance_Status__c;
                        wapperObj.contactId = attensEvnt.hed__Contact__c;
                        wapperObj.contactName = attensEvnt.hed__Contact__r.Name;
                        wapperObj.courseConnectionId = attensEvnt.hed__Course_Connection__c;
                        wapperObj.courseName = attensEvnt.hed__Course_Name__c;
                        wapperObj.eventDate = String.valueOf(attensEvnt.hed__Date__c);
                        wapperObj.sessionId = attensEvnt.Session__c;
                        wapperObj.reasonType = attensEvnt.hed__Reason__c;
                        wapperObj.reasonDescription = attensEvnt.hed__Reason_Description__c;
                        wapperObj.registrationNumber=attensEvnt.hed__Contact__r.Registration_Number__c;
                        wapperObj.studentCode=attensEvnt.hed__Contact__r.Account.Student_Code__c;
                        
                        
                        attenWapperList.add(wapperObj);
                    }
                    List<String> pickListValuesList= new List<String>();
                    Schema.DescribeFieldResult fieldResult = hed__Attendance_Event__c.hed__Reason__c.getDescribe();
                    List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
                    for( Schema.PicklistEntry pickListVal : ple){
                        pickListValuesList.add(pickListVal.getLabel());
                    }
                    responseWapper resWaprObj = new responseWapper();
                    resWaprObj.totalCount = attEvntList.size();
                    resWaprObj.noOfPresent = presentAttEvntList.size();
                    resWaprObj.noOfAbsent = attEvntList.size() - presentAttEvntList.size();
                    resWaprObj.reasonDropdownValues = pickListValuesList;
                    resWaprObj.attendance = attenWapperList;
                    wapperList.add(resWaprObj);
                    
                    jsonResponse = JSON.serialize(wapperList);
                    if(jsonResponse!=null){ 
                        res.statusCode = 200;
                        res.responseBody=Blob.valueOf('{ "success": "true" ,"data":'+jsonResponse+'}'); 
                    }
                    else
                    {
                        res.responseBody=Blob.valueOf('[]'); 
                    }
                }else{
                    res.statusCode = 400;
                    res.responseBody=Blob.valueOf('{ "success": "false" ,"message":"Please check session Id"}');
                }
            }else{
                res.statusCode = 400;
                res.responseBody=Blob.valueOf('{ "success": "false" ,"message":"Invalid Parameters"}');
            }
            
        }Catch(Exception e){
            res.statusCode = 400;
            res.responseBody = Blob.valueOf( '{ "success": "false" , "message": "bad request", "errors": "'+e.getMessage()+'at Line Number'+e.getLineNumber()+'" }' );
        }
    }
    
    global class responseWapper{
        public integer totalCount;
        public integer noOfPresent;
        public integer noOfAbsent;
        public List<string> reasonDropdownValues;
        public List<attendanceWapper> attendance; 
    }
    global class attendanceWapper{
        public string attendanceEventId;
        public string attendanceStatus;
        public string contactId;
        public string contactName;
        public string courseConnectionId;
        public string courseName;
        public string eventDate;
        public string sessionId;
        public string reasonType;
        public string reasonDescription;
        public string registrationNumber;
        public string studentCode;

    }
}