@RestResource(urlMapping='/attendancebyStudent/*')
global class RestApi_AttendanceByStudent {
    @httpGet
    Global static void gettingAttendanceEvents(){
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');
        String contactId = RestContext.request.params.get('contactId');
        String courseOfferingId = RestContext.request.params.get('courseOfferingId');
        String startDate = RestContext.request.params.get('startDate');
        String endDate = RestContext.request.params.get('endDate');
        //system.debug('The date'+evntDate);
        system.debug('contactId===>'+contactId);
        system.debug('courseOfferingId===>'+courseOfferingId);
        system.debug('The startDate'+startDate);
        system.debug('The endDate'+endDate);
        String response = '';
        string jsonResponse;
        String jsonResponses;
        string query='';
        try{
            //Date reqDate;
            DateTime startDateVal;
            DateTime endDateVal;
          if(!string.isEmpty(contactId)){
            query = 'SELECT hed__Arrival_Time__c, Attendance_Status__c,hed__Attendance_Type__c, hed__Contact__c, hed__Course_Connection__c,Session__r.Course_Offering__c,Course_Offering__c, hed__Course_Name__c, hed__Date__c, hed__End_Time__c, End_Date_Time__c, hed__Reason_Description__c, hed__Reason__c,hed__Start_Time__c,Start_Date_Time__c, hed__Unexcused__c, Name, Id, Subject_Name__c  FROM hed__Attendance_Event__c where hed__Contact__c =:contactId';
    		if(!String.isBlank(courseOfferingId))
            {
                //String convert18To15 = courseOfferingId.substring(0,15);
                query+=' AND Session__r.Course_Offering__c=\''+courseOfferingId+'\'' ;
            }
            if(!String.isBlank(startDate) && !String.isBlank(endDate))
            {
				startDateVal=toDateTime(startDate);
                endDateVal=toDateTime(endDate);
                startDate=startDateVal.formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
                endDate=endDateVal.formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
                system.debug('The startDate'+startDate);
        		system.debug('The endDate'+endDate);
                query+=' AND Start_Date_Time__c>='+startDate+' AND  End_Date_Time__c<='+endDate;
            }
            List<hed__Attendance_Event__c> stdAttendanceEvents= [SELECT hed__Arrival_Time__c, Attendance_Status__c,hed__Attendance_Type__c, hed__Contact__c, hed__Course_Connection__c, 
                                                                hed__Course_Name__c, hed__Date__c, hed__End_Time__c, hed__Reason_Description__c, hed__Reason__c,
                                                                hed__Start_Time__c, hed__Unexcused__c, Name, Id FROM hed__Attendance_Event__c where hed__Contact__c =:contactId]; 
            system.debug('stdAttendanceEvents===>'+stdAttendanceEvents);
            List<dataClass> dataClassList = new List<dataClass>();
            if(!stdAttendanceEvents.isEmpty()){
               system.debug('The eventsList'+Database.query(query));
                for(hed__Attendance_Event__c eventsList: Database.query(query)){
                    
                    system.debug('eventsList===>'+eventsList);
                    dataClass wrapper= new dataClass();
                    wrapper.status = eventsList.Attendance_Status__c;
                    wrapper.arrivalTime = string.ValueOf(eventsList.hed__Arrival_Time__c);
                    wrapper.attendanceType = eventsList.hed__Attendance_Type__c;
                    wrapper.contact = eventsList.hed__Contact__c;
                    wrapper.courseConnection = eventsList.hed__Course_Connection__c;
                    wrapper.courseName = eventsList.Subject_Name__c ;
                    wrapper.evntDate = string.ValueOf(eventsList.hed__Date__c);
                    wrapper.startTime = string.ValueOf(eventsList.hed__Start_Time__c);
                    wrapper.endtime = string.ValueOf(eventsList.hed__End_Time__c);
                    wrapper.resonDescription = eventsList.hed__Reason_Description__c;
                    wrapper.reason = eventsList.hed__Reason__c;
                    wrapper.sessionStartDate = String.valueOf(eventsList.Start_Date_Time__c);
                    wrapper.sessionEndDate = String.valueOf(eventsList.End_Date_Time__c);
                    dataClassList.add(wrapper);  
                }
                system.debug('The DataClass'+dataClassList);
                jsonResponse = Json.serialize(dataClassList);
                if(jsonResponse!=null){    
                    res.responseBody=Blob.valueOf('{ "success": "true" ,"data":'+jsonResponse+'}'); 
                }
                else
                {
                    res.responseBody=Blob.valueOf('[]'); 
                }
                
            }else{
                res.responseBody =  Blob.valueOf('{"success": "false" ,"message" : "No Data Found"}'); 
            }
        }else{
            res.responseBody =  Blob.valueOf('{"success": "false" ,"message" : "Invalid Parameters"}');
        }   
        }catch(exception e){
            res.responseBody = Blob.valueOf('The following error has been Occured '+e.getMessage()+' at line number'+e.getLineNumber());
        }
       
    }
        
    global class dataClass{
        public string status;
       
        public string arrivalTime;
        public string attendanceType;
        public string contact;
        public string courseConnection;
        public string courseName;
        public string evntDate;
        public string endtime;
        public string resonDescription;
        public string reason;
        public string startTime; 
        public string sessionStartDate;
        public string sessionEndDate;
    }
    public static DateTime toDateTime(String DateTimevalue) {
        List<String> DateAndTimeList = DateTimevalue.split('T');
        List<String> dayList = DateAndTimeList[0].split('-');
        List<string> timeList = DateAndTimeList[1].split(':');
        DateTime dt = DateTime.newInstance(Integer.valueOf(dayList[0]), Integer.valueOf(dayList[1]),Integer.valueOf(dayList[2]), Integer.valueOf(timeList[0]), Integer.valueOf(timeList[1]),  Integer.valueOf(timeList[2].split('\\.')[0]));
    	return dt;
    }
    
}