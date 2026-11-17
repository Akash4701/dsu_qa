@RestResource(urlMapping='/allCourseconnectionByContactId/*')
global with sharing class RestApi_AllCourseConnectionPerStudent {
    @httpGet
    global static void fetchingCourseConnction(){
    RestResponse res = RestContext.response;
    res.addHeader('Content-Type', 'application/json');
    string jsonResponse;
    RestRequest req = RestContext.request;
    String contactId=RestContext.request.params.get('contactId');
    system.debug('contactId==>'+contactId);
    
      list<hed__Program_Enrollment__c> programEnrolmentList = [select id,hed__Contact__c,Term__c,Term__r.Name,
                                                                  Name,hed__Affiliation__r.hed__Status__c from hed__Program_Enrollment__c
                                                                  where hed__Contact__c = :contactId];
        if(!programEnrolmentList.isEmpty()){
            List<hed__Course_Enrollment__c> courseEnrolments = [SELECT Id, hed__Account__c,ST__c, hed__Affiliation__c, hed__Contact__c, Term_Name__c, hed__Course_Offering__c,
                                                                hed__Credits_Attempted__c, hed__Credits_Earned__c, hed__Grade__c, hed__Program_Enrollment__c,
                                                                hed__Status__c, No_Of_Classes_Attended__c, Percentage_of_classes_attended__c ,hed__Course_Offering__r.Id,hed__Course_Offering__r.hed__Course__c,
                                                                hed__Course_Offering__r.hed__Course__r.hed__Course_ID__c,hed__Course_Offering__r.hed__Course__r.Name,
                                                                hed__Course_Offering__r.hed__Course__r.Credits__c,Attendacne__c,
                                                                hed__Course_Offering__r.hed__Course__r.hed__Credit_Hours__c,hed__Course_Offering__r.hed__Section_ID__c,hed__Program_Enrollment__r.hed__Affiliation__r.hed__Status__c
                                                                FROM hed__Course_Enrollment__c where hed__Contact__c =:contactId AND hed__Program_Enrollment__c=:programEnrolmentList AND hed__Program_Enrollment__r.Term__r.Term_Status__c = 'Ongoing'];
                
         
            Set<id>courseId=new Set<id>();
            Set<Id> courseOfferingIds = new Set<Id>();
            for(hed__Course_Enrollment__c c: courseEnrolments){
                courseOfferingIds.add(c.hed__Course_Offering__c);
                courseId.add(c.hed__Course_Offering__r.hed__Course__c);
            }
            system.debug('courseid'+courseId);
            system.debug(courseOfferingIds);
            Map<Id,List<hed__Attendance_Event__c>> mapOfCourseOfferingIdAndAllAttendanceEvents = new Map<Id,List<hed__Attendance_Event__c>>();
            Map<Id,List<hed__Attendance_Event__c>> mapOfCourseOfferingIdAndPresentAttendanceEvents = new Map<Id,List<hed__Attendance_Event__c>>();
            List<hed__Attendance_Event__c> attEvntList = [Select Id,Name,Attendance_Status__c,Session__c,Session__r.Course_Offering__c,Session__r.Course_Offering__r.Id from hed__Attendance_Event__c where hed__Contact__c=:contactId and Session__r.Course_Offering__c IN:courseOfferingIds];//'a0B1y000002VRsLEAW'];
            system.debug('attEvntList size...' + attEvntList.size());
            for(hed__Attendance_Event__c attEvntObj:attEvntList){
                system.debug('attEvnt cour off id:::' + attEvntObj.Session__r.Course_Offering__r.Id);
                if(mapOfCourseOfferingIdAndAllAttendanceEvents.containsKey(attEvntObj.Session__r.Course_Offering__r.Id)){
                    List<hed__Attendance_Event__c> attEvntsList = mapOfCourseOfferingIdAndAllAttendanceEvents.get(attEvntObj.Session__r.Course_Offering__r.Id);
                    attEvntsList.add(attEvntObj);
                    mapOfCourseOfferingIdAndAllAttendanceEvents.put(attEvntObj.Session__r.Course_Offering__r.Id,attEvntsList);
                    System.debug('if:::');
                }else{
                    System.debug('else:::');
                    mapOfCourseOfferingIdAndAllAttendanceEvents.put(attEvntObj.Session__r.Course_Offering__r.Id,new List<hed__Attendance_Event__c>{attEvntObj});
                }
                if(attEvntObj.Attendance_Status__c=='Present'){
                    if(mapOfCourseOfferingIdAndPresentAttendanceEvents.containsKey(attEvntObj.Session__r.Course_Offering__r.Id)){
                        List<hed__Attendance_Event__c> attEvntsList = mapOfCourseOfferingIdAndPresentAttendanceEvents.get(attEvntObj.Session__r.Course_Offering__r.Id);
                        attEvntsList.add(attEvntObj);
                        mapOfCourseOfferingIdAndPresentAttendanceEvents.put(attEvntObj.Session__r.Course_Offering__r.Id,attEvntsList);
                    }else{
                        mapOfCourseOfferingIdAndPresentAttendanceEvents.put(attEvntObj.Session__r.Course_Offering__r.Id,new List<hed__Attendance_Event__c>{attEvntObj});
                    }
                }
            }
            Set<id>mandatory=new Set<id>();
            Set<id>electives=new Set<id>();
            
            list<hed__Plan_Requirement__c> plan = [select id, hed__Category__c,Institute__r.Name,name, hed__Course__c,hed__Course__r.Name, hed__Course__r.hed__Course_ID__c, hed__Course__r.Credits__c FROM hed__Plan_Requirement__c where hed__Course__c IN :courseId and Recordtype.Name = 'Unit'];
            for(hed__Plan_Requirement__c cc:plan){
                if(cc.hed__Category__c== 'Mandatory'){
                  mandatory.add(cc.hed__Course__c);
                }else if(cc.hed__Category__c== 'Elective'){
                    electives.add(cc.hed__Course__c); 
                }
            }
            Map<String,List<CourseWrapper>> mapOfCatgeoryAndWrapper = new Map<String,List<CourseWrapper>>();
            List<CourseWrapper> mandatoryList = new List<CourseWrapper>();
            List<CourseWrapper> electiveList = new List<CourseWrapper>();
            for(hed__Course_Enrollment__c c: courseEnrolments){
                
                if(mandatory.contains(c.hed__Course_Offering__r.hed__Course__c)){
                    CourseWrapper obj = new CourseWrapper();
                    obj.CourseName =c.hed__Course_Offering__r.hed__Course__r.Name ;
                    obj.CourseCode = c.hed__Course_Offering__r.hed__Course__r.hed__Course_ID__c;
                    obj.credit =c.hed__Course_Offering__r.hed__Course__r.Credits__c;
                    obj.creditHours=c.hed__Course_Offering__r.hed__Course__r.hed__Credit_Hours__c;
                    obj.courseOfferingId =c.hed__Course_Offering__c;
                    obj.courseOfferingSectionId =c.hed__Course_Offering__r.hed__Section_ID__c;
                    obj.status=c.ST__c;
                    obj.id=c.Id;
                    obj.Attendence = c.Attendacne__c;
                    system.debug('mapOfCourseOfferingIdAndAllAttendanceEventsmandatory-->'+mapOfCourseOfferingIdAndAllAttendanceEvents);
                    System.debug('c.hed__Course_Offering__r.Id::::' + c.hed__Course_Offering__r.Id);
                    obj.totalnoOfclass = mapOfCourseOfferingIdAndAllAttendanceEvents.containsKey(c.hed__Course_Offering__r.Id)?mapOfCourseOfferingIdAndAllAttendanceEvents.get(c.hed__Course_Offering__r.Id).size():null;
                    obj.presentnoOfclass = mapOfCourseOfferingIdAndPresentAttendanceEvents.containsKey(c.hed__Course_Offering__r.Id)?mapOfCourseOfferingIdAndPresentAttendanceEvents.get(c.hed__Course_Offering__r.Id).size():null;
                    obj.affiliationStatus = c.hed__Program_Enrollment__r.hed__Affiliation__r.hed__Status__c;
                    obj.termName=c.Term_Name__c;
                    mandatoryList.add(obj);
                }
                else if(electives.contains(c.hed__Course_Offering__r.hed__Course__c)){
                    CourseWrapper obj = new CourseWrapper();
                    obj.CourseName =c.hed__Course_Offering__r.hed__Course__r.Name ;
                    obj.CourseCode = c.hed__Course_Offering__r.hed__Course__r.hed__Course_ID__c;
                    obj.credit =c.hed__Course_Offering__r.hed__Course__r.Credits__c;
                    obj.creditHours=c.hed__Course_Offering__r.hed__Course__r.hed__Credit_Hours__c;
                    obj.courseOfferingId =c.hed__Course_Offering__c;
                    obj.courseOfferingSectionId =c.hed__Course_Offering__r.hed__Section_ID__c;
                    obj.status=c.ST__c;
                    obj.id=c.Id;
                    obj.Attendence = c.Attendacne__c;
                    system.debug('mapOfCourseOfferingIdAndAllAttendanceEvents-->'+mapOfCourseOfferingIdAndAllAttendanceEvents);
                    obj.totalnoOfclass = mapOfCourseOfferingIdAndAllAttendanceEvents.containsKey(c.hed__Course_Offering__r.Id)?mapOfCourseOfferingIdAndAllAttendanceEvents.get(c.hed__Course_Offering__r.Id).size():null;
                    obj.presentnoOfclass = mapOfCourseOfferingIdAndPresentAttendanceEvents.containsKey(c.hed__Course_Offering__r.Id)?mapOfCourseOfferingIdAndPresentAttendanceEvents.get(c.hed__Course_Offering__r.Id).size():null;
                    obj.affiliationStatus = c.hed__Program_Enrollment__r.hed__Affiliation__r.hed__Status__c;
                    obj.termName=c.Term_Name__c;
                    electiveList.add(obj);
                }
            }
            if(!mandatoryList.isEmpty() || !electiveList.isEmpty()){
                CourseWrapperDetails CourseDetailWrapperWithAllDetailsData = new CourseWrapperDetails();
                CourseDetailWrapperWithAllDetailsData.mandatoryCourses = mandatoryList;
                CourseDetailWrapperWithAllDetailsData.electiveCourses = electiveList;
                jsonResponse = JSON.serialize(CourseDetailWrapperWithAllDetailsData);
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
                    res.responseBody = Blob.valueOf( '{ "success": "false" , "message": "No Data Found"}' );
            }
    	}
        else{
                    res.responseBody = Blob.valueOf( '{ "success": "true" , "message": "No Data Found"}' );
            }
        
    }
    
    public class CourseWrapperDetails{
        public List<CourseWrapper> mandatoryCourses{get;set;}
        public List<CourseWrapper> electiveCourses{get;set;}
    }
    
    public class CourseWrapper{
        public String CourseName{get;set;}     
        public String CourseCode{get;set;}  
        public Double credit {get;set;}
        public Double creditHours{get;set;}
        public String status{get;set;}
        public String id{get;set;}
        public string courseOfferingId {get;set;}
        public string courseOfferingSectionId {get;set;}
        public integer totalnoOfclass {get;set;}
        public integer presentnoOfclass {get;set;}
        public string affiliationStatus {get;set;}
        public string termName {get;set;}
        public Decimal Attendence {get;set;}
    }

   
}