@RestResource(urlMapping='/SessionData/*')
global class RestApi_GetSession {
    @HttpGet
    global static void doGetSessionData(){
        String facultyId=RestContext.request.params.get('facultyId');
        system.debug('facultyId'+RestContext.request.params.get('facultyId'));
        String courseOfferingId=RestContext.request.params.get('courseOfferingId');
        String termId=RestContext.request.params.get('termId');
        String facilityId = RestContext.request.params.get('facilityId');
        String contactId = RestContext.request.params.get('contactId');
        system.debug('contactId'+contactId);
        String startDate=RestContext.request.params.get('startDate');
        system.debug('startDate'+startDate);
        String endDate=RestContext.request.params.get('endDate');
        system.debug('endDate'+endDate);
        String attendance=RestContext.request.params.get('attendance');
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');
        String response = '';
        string jsonResponse;
        String jsonResponses;
        string query='';
        try{
            DateTime startDateVal;
            DateTime endDateVal;
            
            Map<String,Object> app=new Map<String,Object>();
            List<Object> appObj = new List<Object>();
            
            List<hed__Course_Enrollment__c> courseContact=new List<hed__Course_Enrollment__c>();
            Set<Id> courseOfferingSet=new Set<Id>();
            
            if(!String.isBlank(contactId))
            {
                courseContact=[SELECT Id,hed__Course_Offering__c FROM hed__Course_Enrollment__c WHERE hed__Contact__c=:contactId AND hed__Program_Enrollment__r.hed__Affiliation__r.hed__Status__c='Current'];
                if(courseContact.isEmpty()){
                    res.responseBody = Blob.valueOf( '{ "success": "false" , "message": "No Data Found"}' );
                	return;
                }
                
                for(hed__Course_Enrollment__c connection:courseContact)
                {
                    courseOfferingSet.add(connection.hed__Course_Offering__c);
                }
            }
            
            query='SELECT Id,Name,Attendance_Marked__c,Facility__c,Facility__r.Name,Faculty__c,Faculty__r.Name,Contact__c,Contact__r.Name,Type_of_Activity__c,Start_Date_Time__c,End_Date_Time__c,Course_Offering__c,Course_Offering__r.hed__Section_ID__c,Course_Offering__r.hed__Term__r.Name,Course_Offering__r.Course_Version__c,Course_Offering__r.hed__Course__r.Name,Facility_Booking__c,Facility_Booking__r.FacilityID__r.Name,Faculty_Booking__c,Faculty_Booking__r.Booked_By__c,Faculty_Booking__r.Booked_By__r.Name,Facility_Booking__r.FacilityID__c,Mode_of_Delivery__c,TimeZone__c,Session_StartTime__c,Session_EndTime__c FROM Session__c WHERE Faculty__c !=null';
            if(!String.isBlank(facultyId))
            {
                query+=' AND Faculty__c=\''+facultyId+'\'' ;
            }
    		if(!String.isBlank(courseOfferingId))
            {
                query+=' AND Course_Offering__c=\''+courseOfferingId+'\'' ;
            }
            if(!String.isBlank(termId))
            {
                query += ' AND Course_Offering__r.hed__Term__c=\''+termId+'\'';
            }
            if(!String.isBlank(facilityId))
            {
                query += ' AND Facility__c=\''+facilityId+'\'';
            }
            if(!courseOfferingSet.isEmpty())
            {
                query+=' AND Course_Offering__c IN: courseOfferingSet';
            }
            if(!String.isBlank(startDate) && !String.isBlank(endDate))
            {
				startDateVal=toDateTime(startDate);
                endDateVal=toDateTime(endDate);
                startDate=startDateVal.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
                endDateVal = endDateVal.addDays(1);
                endDate=endDateVal.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''); 
                query+=' AND Start_Date_Time__c>='+startDate+' AND  End_Date_Time__c<='+endDate;
                System.debug(endDate);
            }
            if(attendance=='true')
            {
                query+=' AND Attendance_Marked__c=true AND Start_Date_Time__c<=LAST_N_DAYS:0';
            }
            else if(attendance=='false')
            {
                 query+=' AND Attendance_Marked__c=false AND Start_Date_Time__c<=LAST_N_DAYS:0';
            }
            System.debug('Total Query'+query);
            system.debug('@@@query'+query.reverse());
            system.debug('@@@query'+query.substringAfter ('WHERE'));
           	List<Session__c> sessionsList = Database.query(query);
            System.debug('sessionsList::' + sessionsList);
            Map<Id,Session__c> mapOfallAttendanceRecords = new Map<Id,Session__c>([select id,Name,(Select id,Name,Attendance_Status__c from Attendance_Events__r) from Session__c where id IN: sessionsList]);
            Map<Id,Session__c> mapOfpresentAttendanceRecords = new Map<Id,Session__c>([select id,Name,(Select id,Name,Attendance_Status__c from Attendance_Events__r where Attendance_Status__c='Present') from Session__c where id IN: sessionsList]);
            for(Session__c session:sessionsList)
            {
                system.debug('The Session Data'+session.Name);
                responseSessionDataWrapper responseData=new responseSessionDataWrapper();
                responseData.id=session.Id;
                responseData.sessionName=session.Name;
                responseData.activityType=session.Type_of_Activity__c;
                responseData.contactId=session.Contact__c;
                responseData.contactName=session.Contact__r.Name;
                responseData.courseOfferingId=session.Course_Offering__c;
                responseData.courseOfferingSectionId=session.Course_Offering__r.hed__Section_ID__c;
                responseData.courseVersionId = session.Course_Offering__r.Course_Version__c;
                responseData.courseId=session.Course_Offering__r.hed__Course__c;
                responseData.termId=session.Course_Offering__r.hed__Term__c;
                responseData.termName=session.Course_Offering__r.hed__Term__r.Name;
                responseData.courseName=session.Course_Offering__r.hed__Course__r.Name;
                responseData.facilityId=session.Facility__c;
                responseData.facultyId=session.Faculty__c;
                responseData.facilityName=session.Facility__r.Name;
                responseData.facultyName=session.Faculty__r.Name;
                responseData.attendanceStatus=session.Attendance_Marked__c;
                responseData.totalAttendees = mapOfallAttendanceRecords.get(session.Id) !=null? mapOfallAttendanceRecords.get(session.Id).Attendance_Events__r.size():0;
                responseData.presentAttendees = mapOfpresentAttendanceRecords.get(session.Id) != null? mapOfpresentAttendanceRecords.get(session.Id).Attendance_Events__r.size():0;
                responseData.modeOfDelivery=session.Mode_of_Delivery__c;
                responseData.timeZone=session.TimeZone__c;
                responseData.startTimeWithTimezoneadded=session.Session_StartTime__c;
                responseData.endTimeWithTimezoneadded=session.Session_EndTime__c;
                //responseData.TotalAttendance=session.Total_Attendance__c	;
                if(session.Start_Date_Time__c!=null)
                {
                    responseData.startDate=session.Start_Date_Time__c;
                }
                if(session.End_Date_Time__c!=null)
                {
                    responseData.endDate=session.End_Date_Time__c;
                }
				if(!String.isBlank(session.Facility_Booking__c))
                {
                	responseFacilityBookingDataWrapper resFacility=new responseFacilityBookingDataWrapper();
                    resFacility.id=session.Facility_Booking__c;
                    resFacility.facilityName=session.Facility_Booking__r.FacilityID__r.Name ;
                    resFacility.facilityId=session.Facility_Booking__r.FacilityID__c ;
                    responseData.FacilityBooking=resFacility;
                }
				if(!String.isBlank(session.Faculty_Booking__c))
                {
                	responseFacultyBookingDataWrapper  resFaculty=new responseFacultyBookingDataWrapper();
                    resFaculty.id=session.Faculty_Booking__c;
                    resFaculty.facultyName=session.Faculty_Booking__r.Booked_By__r.Name;
                    resFaculty.facultyId=session.Faculty_Booking__r.Booked_By__c;
                    responseData.FacultyBooking=resFaculty;
                }
                
                app.put(session.Id,responseData);
                appObj.add(responseData);
            }
            List<RecessRecordsByRRule.requestWrapper> recessWrapper = new List<RecessRecordsByRRule.requestWrapper>();
            List<Session__c> recessSessionRecords = [Select Id,Name,Break_Session_Name__c,Start_Date_Time__c,End_Date_Time__c,Select_Days__c,Frequency__c,RRule_String__c,Term__c,Program_Plan__c,Institute__c from Session__c where RecordType.Name='Recess'];
            for(Session__c recessObj:recessSessionRecords){
                RecessRecordsByRRule.requestWrapper wrapObj = new RecessRecordsByRRule.requestWrapper();
                wrapObj.recordId=recessObj.Id;
                wrapObj.name=recessObj.Break_Session_Name__c;
                wrapObj.startDateTime=recessObj.Start_Date_Time__c;
                wrapObj.endDateTime=recessObj.End_Date_Time__c;
                wrapObj.selectedDays=recessObj.Select_Days__c;
                wrapObj.frequency=recessObj.Frequency__c;
                wrapObj.rRuleString=recessObj.RRule_String__c;
                app.put(recessObj.Id,wrapObj);
                appObj.add(wrapObj);
            }
            system.debug('The Map Data'+app);
            if(!app.keyset().isEmpty())
            {
                jsonResponse = JSON.serialize(appObj);
                if(jsonResponse!=null){    
                    res.responseBody=Blob.valueOf('{ "success": "true" ,"data":'+jsonResponse+'}'); 
                }
                else
                {
                    res.responseBody=Blob.valueOf('[]'); 
                } 
            }
            else
            {
                res.responseBody = Blob.valueOf( '{ "success": "false" , "message": "No Data Found"}' );
            }
            res.statusCode = 200;
    	}Catch(Exception e){
            res.statusCode = 400;
            res.responseBody = Blob.valueOf( '{ "success": "false" , "message": "bad request", "errors": "'+e.getMessage()+'at Line Number'+e.getLineNumber()+'" }' );
            //system.debug(+e.getMessage()+' at line number '+e.getLineNumber());
        }
    }
    
    public class responseSessionDataWrapper {
        public string id {get;set;}
        public string sessionName {get;set;}
        public string activityType {get;set;}
        public string contactId {get;set;}
        public string contactName {get;set;}
        public string courseOfferingId {get;set;}
        public string courseVersionId{get;set;}
        public string courseId {get;set;}
        public string termId {get;set;}
        public string termName {get;set;}
        public string courseName {get;set;}
        public DateTime startDate {get;set;}
        public DateTime endDate {get;set;}
        public string facilityId{get;set;}
        public string facultyId {get;set;}
        public string facilityName{get;set;}
        public string facultyName {get;set;}
        public decimal TotalAttendance{get;set;}
        public string courseOfferingSectionId {get;set;}
        public boolean attendanceStatus {get;set;}
        public Integer totalAttendees {get;set;}
        public Integer presentAttendees {get;set;}
        public String modeOfDelivery {get;set;}
        public String timeZone {get;set;}
        public String startTimeWithTimezoneadded {get;set;}
        public String endTimeWithTimeZoneadded {get;set;}
        public responseFacilityBookingDataWrapper FacilityBooking {get;set;}
        public responseFacultyBookingDataWrapper FacultyBooking {get;set;}
    }
    public class responseFacilityBookingDataWrapper {
        public string id {get;set;}
        public string facilityName {get;set;}
        public string facilityId {get;set;}
    }
    public class responseFacultyBookingDataWrapper {
        public string id {get;set;}
        public string facultyName {get;set;}
        public string facultyId {get;set;}
    }
    public static DateTime toDateTime(String DateTimevalue) {
        List<String> DateAndTimeList = DateTimevalue.split('T');
        system.debug('date list==>'+DateAndTimeList);
        List<String> dayList = DateAndTimeList[0].split('-');
        
        List<string> timeList = DateAndTimeList[1].split(':');
        DateTime dt = DateTime.newInstance(Integer.valueOf(dayList[0]), Integer.valueOf(dayList[1]),Integer.valueOf(dayList[2]), Integer.valueOf(timeList[0]), Integer.valueOf(timeList[1]),  Integer.valueOf(timeList[2].split('\\.')[0]));
    	return dt;
    } 
       
}