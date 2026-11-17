@RestResource(urlMapping='/FeedBackScheduleDividedData/*')
global with sharing class RestApi_GetFeedBackScheduleDivided {
    @HttpGet
    global static void doGetFeedBackScheduleDividedData(){
        String contactId=RestContext.request.params.get('contactId');
        String feedBackScheduleId=RestContext.request.params.get('feedBackScheduleId');
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');
        String response = '';
        string jsonResponse;
        String jsonResponses;
        try{
            if(!String.isBlank(feedBackScheduleId) && !String.isBlank(contactId)){
                
                List<String>  checkStatusforAllList=new List<String>();
                List<hed__Course_Offering__c>  courseOfferingList=new List<hed__Course_Offering__c>();
                List<hed__Course_Enrollment__c> facultyList=new List<hed__Course_Enrollment__c>();
                //List<hed__Course_Enrollment__c> enrolledCourses=new List<hed__Course_Enrollment__c>();
                List<hed__Program_Enrollment__c> enrolledCourses=new List<hed__Program_Enrollment__c>();
                List<Collected_Feedback_Data__c> collFeedBackSetupList=new List<Collected_Feedback_Data__c>();
                Map<String,String>  checkStatusMap=new Map<String,String>();  
                
                Contact cont=[SELECT Id,Recordtype.Name FROM Contact WHERE Id=:contactId WITH SECURITY_ENFORCED];
                
                Feedback_Scheduler__c feedbackScheduler=[SELECT Id,Term__c,Term__r.Name,Feedback_Master__c,End_Date__c,
                                                         Feedback_Master__r.Feedback_Type__c,Term__r.Program_Plan__c,Term__r.Program_Plan__r.Name,Term__r.Campus__r.Name,Term__r.Campus__c,Term__r.hed__Account__r.Name
                                                         FROM Feedback_Scheduler__c WHERE Id=:feedBackScheduleId WITH SECURITY_ENFORCED];
                
                /*courseOfferingList=[SELECT Id,hed__Course__c,hed__Course__r.Name,hed__Course__r.hed__Course_ID__c 
										FROM hed__Course_Offering__c WHERE hed__Term__c=:feedbackScheduler.Term__c];*/
                
                enrolledCourses=[Select Id,(Select Id, hed__Course_Offering__c, hed__Course_Offering__r.hed__Course__c, hed__Course_Offering__r.hed__Course__r.Name, hed__Course_Offering__r.hed__Course__r.hed__Course_ID__c from hed__Course_Enrollments__r) from hed__Program_Enrollment__c where hed__Affiliation__r.hed__Status__c ='Current' AND Term__c=:feedbackScheduler.Term__c AND hed__Contact__c=:contactId WITH SECURITY_ENFORCED];
                
                facultyList=[SELECT Id,hed__Contact__c,hed__Contact__r.Name,
                             hed__Course_Offering__r.hed__Course__r.Name,hed__Course_Offering__r.hed__Course__c FROM hed__Course_Enrollment__c
                             WHERE hed__Course_Offering__r.hed__Term__c=:feedbackScheduler.Term__c
                             AND hed__Status__c='Current' AND hed__Contact__r.Recordtype.Name='Faculty' WITH SECURITY_ENFORCED];
                
                
                
                collFeedBackSetupList=[SELECT Id,Term__c,Contact__c,Feedback_Master__c,Feedback_Master__r.Feedback_Type__c,Faculty__c,Course_Name__c,Feedback_Master_Child__c
                                       FROM Collected_Feedback_Data__c WHERE Feedback_Master__c=:feedbackScheduler.Feedback_Master__c AND Contact__c=:contactId AND Term__c=:feedbackScheduler.Term__c WITH SECURITY_ENFORCED];
                system.debug(collFeedBackSetupList);
                if(!collFeedBackSetupList.isEmpty()){
                    for(Collected_Feedback_Data__c coll:collFeedBackSetupList){
                        if(!String.isBlank(coll.Course_Name__c) && String.isBlank(coll.Faculty__c)){
                            checkStatusforAllList.add(coll.Course_Name__c+'_'+coll.Contact__c+'_'+coll.Feedback_Master__r.Feedback_Type__c);
                        }
                        else if(!String.isBlank(coll.Faculty__c)){
                            checkStatusforAllList.add(coll.Faculty__c+'_'+coll.Contact__c+'_'+coll.Feedback_Master__r.Feedback_Type__c);
                        } 
                        else if(String.isBlank(coll.Faculty__c) && String.isBlank(coll.Course_Name__c)){
                            checkStatusforAllList.add(coll.Contact__c+'_'+coll.Feedback_Master__r.Feedback_Type__c);
                        }
                    }
                }
                system.debug(checkStatusforAllList);
                responseFeedBackScheduleWrapper responseFeedBackSch=new responseFeedBackScheduleWrapper();
                responseFeedBackSch.feedBackSchedulerId=feedbackScheduler.Id;
                responseFeedBackSch.termId=feedbackScheduler.Term__c;
                responseFeedBackSch.termName=feedbackScheduler.Term__r.Name;
                responseFeedBackSch.campusId=feedbackScheduler.Term__r.Campus__c;
                responseFeedBackSch.campusName=feedbackScheduler.Term__r.Campus__r.Name;
                responseFeedBackSch.programId=feedbackScheduler.Term__r.Program_Plan__c;
                responseFeedBackSch.programName=feedbackScheduler.Term__r.Program_Plan__r.Name;
                responseFeedBackSch.academicProgramName=feedbackScheduler.Term__r.hed__Account__r.Name;
                
                List<responseCourseFeedBackScheduleWrapper> responseFeedBackSchCourseList=new List<responseCourseFeedBackScheduleWrapper>(); 
                if(!enrolledCourses.isEmpty()){
                    for(hed__Program_Enrollment__c prgEnrollment:enrolledCourses){
                        for(hed__Course_Enrollment__c course:prgEnrollment.hed__Course_Enrollments__r){
                            responseCourseFeedBackScheduleWrapper responseFeedBackSchCourse=new responseCourseFeedBackScheduleWrapper();
                            responseFeedBackSchCourse.courseId=course.hed__Course_Offering__r.hed__Course__c;
                            responseFeedBackSchCourse.courseName=course.hed__Course_Offering__r.hed__Course__r.Name;
                            responseFeedBackSchCourse.courseCode=course.hed__Course_Offering__r.hed__Course__r.hed__Course_ID__c;
                            if(!checkStatusforAllList.isEmpty() && checkStatusforAllList.contains(course.hed__Course_Offering__r.hed__Course__c+'_'+contactId+'_'+feedbackScheduler.Feedback_Master__r.Feedback_Type__c)){
                                responseFeedBackSchCourse.status='Submitted';
                            }else{
                                responseFeedBackSchCourse.status='Pending';
                            }
                            responseFeedBackSchCourseList.add(responseFeedBackSchCourse);
                        } 
                    }
                }
                responseFeedBackSch.course=responseFeedBackSchCourseList;
                
                List<responseFacultyFeedBackScheduleWrapper> responseFeedBackSchFacultyList=new List<responseFacultyFeedBackScheduleWrapper>(); 
                if(!facultyList.isEmpty()){
                    for(hed__Course_Enrollment__c faculty:facultyList){
                        responseFacultyFeedBackScheduleWrapper responseFeedBackSchFaculty=new responseFacultyFeedBackScheduleWrapper();
                        responseFeedBackSchFaculty.facultyId=faculty.hed__Contact__c;
                        responseFeedBackSchFaculty.facultyName=faculty.hed__Contact__r.Name;
                        responseFeedBackSchFaculty.courseId=faculty.hed__Course_Offering__r.hed__Course__c;
                        responseFeedBackSchFaculty.courseName=faculty.hed__Course_Offering__r.hed__Course__r.Name;
                        if(!checkStatusforAllList.isEmpty() && checkStatusforAllList.contains(faculty.Id+'_'+contactId+'_'+feedbackScheduler.Feedback_Master__r.Feedback_Type__c)){
                            responseFeedBackSchFaculty.status='Submitted';
                        }else{
                            responseFeedBackSchFaculty.status='Pending';
                        }
                        responseFeedBackSchFacultyList.add(responseFeedBackSchFaculty);
                    }
                }
                responseFeedBackSch.faculty=responseFeedBackSchFacultyList;
                
                List<responseTechnologyFeedBackScheduleWrapper> responseFeedBackSchTechnologyList=new List<responseTechnologyFeedBackScheduleWrapper>();
                responseTechnologyFeedBackScheduleWrapper responseFeedBackSchTechnology=new responseTechnologyFeedBackScheduleWrapper();
                responseFeedBackSchTechnology.termId=feedbackScheduler.Term__c;
                responseFeedBackSchTechnology.termName=feedbackScheduler.Term__r.Name;
                responseFeedBackSchTechnology.bacthId=feedbackScheduler.Term__r.Program_Plan__c;
                responseFeedBackSchTechnology.bacthName=feedbackScheduler.Term__r.Program_Plan__r.Name;
                if(!checkStatusforAllList.isEmpty() && checkStatusforAllList.contains(contactId+'_'+feedbackScheduler.Feedback_Master__r.Feedback_Type__c)){
                    responseFeedBackSchTechnology.status='Submitted';
                }else{
                    responseFeedBackSchTechnology.status='Pending';
                }
                responseFeedBackSchTechnologyList.add(responseFeedBackSchTechnology);
                responseFeedBackSch.technology=responseFeedBackSchTechnologyList;
                
                
                jsonResponse = JSON.serialize(responseFeedBackSch);
                if(jsonResponse!=null){    
                    res.responseBody=Blob.valueOf(jsonResponse); 
                }
                else
                {
                    res.responseBody=Blob.valueOf('[]'); 
                }
            }
            else{
                res.responseBody = Blob.valueOf( '{ "success": "true" , "message": "No Data Found"}' );
            }
            res.statusCode = 200;
        }Catch(Exception e){
            res.statusCode = 400;
            res.responseBody = Blob.valueOf( '{ "success": "false" , "message": "bad request", "errors": "'+e.getMessage()+'at Line Number'+e.getLineNumber()+'" }' );
        }
    }
    
    public class responseFeedBackScheduleWrapper {
        public String feedBackSchedulerId {get;set;}
        public String termId {get;set;}
        public String termName {get;set;}
        public String campusId {get;set;}
        public String campusName {get;set;}
        public String programId {get;set;}
        public String programName {get;set;}
        public String academicProgramName {get;set;}
        public List<responseCourseFeedBackScheduleWrapper> course {get;set;}
        public List<responseFacultyFeedBackScheduleWrapper> faculty {get;set;}
        public List<responseTechnologyFeedBackScheduleWrapper> technology {get;set;}
    }
    public class responseCourseFeedBackScheduleWrapper {
        public String courseId {get;set;}
        public String courseName {get;set;}
        public String courseCode {get;set;}
        public string status {get;set;}
    }
    public class responseFacultyFeedBackScheduleWrapper {
        public String facultyId {get;set;}
        public String facultyName {get;set;}
        public String courseId {get;set;}
        public String courseName {get;set;}
        public string status {get;set;}
    }
    public class responseTechnologyFeedBackScheduleWrapper {
        public String termId {get;set;}
        public String termName {get;set;}
        public String bacthId {get;set;}
        public String bacthName {get;set;}
        public string status {get;set;}
    }
    
}