@RestResource(urlMapping='/StudentAttendanceData/*')
global with sharing class RestApi_GetStudentAttendanceData {
    @httpGet
    global static void fetchingAttendance(){
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');
        string jsonResponse;
        RestRequest req = RestContext.request;
        String contactId=RestContext.request.params.get('contactId');
        String startDate=RestContext.request.params.get('StartDate');
        String endDate=RestContext.request.params.get('EndDate');
        system.debug('contactId==>'+contactId);


        if(String.isNotEmpty(contactId)){
            String query = 'select id,CreatedDate, hed__Arrival_Time__c, hed__Attendance_Type__c, hed__Contact__c, hed__Course_Connection__c, hed__Course_Name__c, hed__Date__c, hed__End_Time__c, hed__Reason_Description__c, hed__Reason__c, hed__Start_Time__c, hed__Unexcused__c, Attendance_Status__c, Session__c,   Course_Offering__c, Attendance_Marked__c, Start_Date_Time__c, End_Date_Time__c,Session__r.Course_Offering__r.hed__Course__c, Session__r.Course_Offering__r.hed__Course__r.hed__Course_ID__c, Session__r.Course_Offering__r.hed__Course__r.Name   from hed__Attendance_Event__c where hed__Contact__c = :contactId';
            if(String.isNotEmpty(startDate) && String.isNotEmpty(endDate)){
                system.debug('startDate-->'+startDate);
                                system.debug('endDate-->'+endDate);
                Datetime startDateVal=toDateTime(startDate);
                Datetime endDateVal=toDateTime(endDate);
                startDate=startDateVal.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
                endDate=endDateVal.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
                //Date startDateFormatted = Date.valueOf(startDate); //2022-07-29
                //Date endDateFormatted = Date.valueOf(endDate);
                //endDateFormatted = endDateFormatted +1;
                //query = query + ' AND CreatedDate >= :startDateFormatted AND CreatedDate< : endDateFormatted';
                System.debug('startDate '+startDate);
                System.debug('endDate '+endDate);
                query+=' AND Start_Date_Time__c>='+startDate+' AND  Start_Date_Time__c<='+endDate;
            }
            System.debug('query '+query);
            List<hed__Attendance_Event__c> attendanceEventList = Database.query(query);
            System.debug('attendanceEventList size '+attendanceEventList.size());
            Map<Id, List<hed__Attendance_Event__c>> mapOfCourseIOfferingdWithTotalAttendence = new Map<Id, List<hed__Attendance_Event__c>>();
            if(attendanceEventList.size()>0){
                List<hed__Attendance_Event__c> listOfTotalPresentAttendance = new List<hed__Attendance_Event__c>();
                List<hed__Attendance_Event__c> listOfTotalAbsentAttendance = new List<hed__Attendance_Event__c>(); 
                for(hed__Attendance_Event__c attEvent :attendanceEventList)
                {
                    if(attEvent.Attendance_Status__c=='Present'){
                        listOfTotalPresentAttendance.add(attEvent);
                    }
                    else  if(attEvent.Attendance_Status__c=='Absent'){
                        listOfTotalAbsentAttendance.add(attEvent);
                    }
                    if(!mapOfCourseIOfferingdWithTotalAttendence.containsKey(attEvent.Session__r.Course_Offering__c)){
                        mapOfCourseIOfferingdWithTotalAttendence.put(attEvent.Session__r.Course_Offering__c, new List<hed__Attendance_Event__c>());
                    }
                    mapOfCourseIOfferingdWithTotalAttendence.get(attEvent.Session__r.Course_Offering__c).add(attEvent);
                }


                Integer presentClassesForAll = listOfTotalPresentAttendance.size();
                Integer absentClassesForAll = listOfTotalAbsentAttendance.size();
                Integer totalClassesForAll = presentClassesForAll + absentClassesForAll;
                Integer attendancePercentageForAll = 0;
                if(totalClassesForAll>0)
                attendancePercentageForAll= (presentClassesForAll*100)/totalClassesForAll;
                AttendanceDetails obj = new AttendanceDetails();
                obj.TotalClassesForAll = totalClassesForAll;
                obj.AbsentClassesForAll = absentClassesForAll;
                obj.AttendancePercentageForAll = attendancePercentageForAll;


                Map<Id, hed__Course_Offering__c> mapOfCourseOffering = new Map<Id, hed__Course_Offering__c>([select Id,hed__Section_ID__c ,hed__Course__r.hed__Course_ID__c,hed__Course__r.Name from hed__Course_Offering__c where Id IN :mapOfCourseIOfferingdWithTotalAttendence.keySet()]);
                List<CourseLevelAttendance> listOfCourseLevelAttendance = new List<CourseLevelAttendance>(); 
                for(Id offeringId :mapOfCourseIOfferingdWithTotalAttendence.keySet()){
                    List<hed__Attendance_Event__c> listOfTotalPresentAttendanceForEachCourse = new List<hed__Attendance_Event__c>();
                    List<hed__Attendance_Event__c> listOfTotalAbsentAttendanceForEachCourse = new List<hed__Attendance_Event__c>();
                    for(hed__Attendance_Event__c attEvent :mapOfCourseIOfferingdWithTotalAttendence.get(offeringId)){
                        if(attEvent.Attendance_Status__c=='Present'){
                            listOfTotalPresentAttendanceForEachCourse.add(attEvent);
                        }
                        else  if(attEvent.Attendance_Status__c=='Absent'){
                            listOfTotalAbsentAttendanceForEachCourse.add(attEvent);
                        }
                    }
                    Integer presentClasses = listOfTotalPresentAttendanceForEachCourse.size();
                    Integer absentClasses = listOfTotalAbsentAttendanceForEachCourse.size();
                    Integer totalClasses = presentClasses + absentClasses;
                    Integer attendancePercentage = 0;
                    if(totalClasses>0)
                        attendancePercentage = (presentClasses*100)/totalClasses;

                    CourseLevelAttendance courseLevelAttendanceObj = new CourseLevelAttendance();
                    if(mapOfCourseOffering.containsKey(offeringId)){
                        courseLevelAttendanceObj.CourseName = mapOfCourseOffering.get(offeringId).hed__Course__r.Name;
                        courseLevelAttendanceObj.CourseCode = mapOfCourseOffering.get(offeringId).hed__Course__r.hed__Course_ID__c;
                        courseLevelAttendanceObj.CourseOfferingId = mapOfCourseOffering.get(offeringId).Id;
                        courseLevelAttendanceObj.SectionId = mapOfCourseOffering.get(offeringId).hed__Section_ID__c ;
                    }
                    courseLevelAttendanceObj.TotalClasses = totalClasses;
                    courseLevelAttendanceObj.AbsentClasses = absentClasses;
                    courseLevelAttendanceObj.AttendancePercentage = attendancePercentage;
                    listOfCourseLevelAttendance.add(courseLevelAttendanceObj);

                }
                obj.courseLevelAttendanceList = listOfCourseLevelAttendance;
                jsonResponse = JSON.serialize(obj);
                System.debug('jsonResponse '+jsonResponse);
                if(jsonResponse!=null){    
                    res.responseBody=Blob.valueOf(jsonResponse); 
                }
                else
                {
                    res.responseBody=Blob.valueOf('[]'); 
                } 
            }
            else{
                res.responseBody = Blob.valueOf( '{ "success": "true" , "message": "No attendance event found for this contact"}' );
            }

        }
        else{
            res.responseBody = Blob.valueOf( '{ "success": "true" , "message": "No match found for contact"}' );
        }  

    }
    
    public static DateTime toDateTime(String DateTimevalue) {
        List<String> DateAndTimeList = DateTimevalue.split('T');
        List<String> dayList = DateAndTimeList[0].split('-');
        List<string> timeList = DateAndTimeList[1].split(':');
        DateTime dt = DateTime.newInstance(Integer.valueOf(dayList[0]), Integer.valueOf(dayList[1]),Integer.valueOf(dayList[2]), Integer.valueOf(timeList[0]), Integer.valueOf(timeList[1]),  Integer.valueOf(timeList[2].split('\\.')[0]));
    	return dt;
    }

    public class AttendanceDetails{
        public Integer TotalClassesForAll {get;set;}
        public Integer AbsentClassesForAll {get;set;}
        public Integer AttendancePercentageForAll {get;set;}
        public List<CourseLevelAttendance> courseLevelAttendanceList{get;set;}
    }

    public class CourseLevelAttendance{
        public String CourseName{get;set;}     
        public String CourseCode{get;set;}
        public String SectionId{get;set;} 
        public String CourseOfferingId{get;set;}  
        public Integer TotalClasses {get;set;}
        public Integer AbsentClasses {get;set;}
        public Integer AttendancePercentage {get;set;}
    }

  
}