@RestResource(urlMapping='/FeedBackScheduleData/*')
global with sharing class RestApi_GetFeedBackSchedule {
@HttpGet
    global static void doGetFeedBackScheduleData(){
        String termId=RestContext.request.params.get('termId');
        String contactId=RestContext.request.params.get('contactId');
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');
        String response = '';
        string jsonResponse;
        String jsonResponses;
        try{

            if(!String.isBlank(termId) && !String.isBlank(contactId)){
                boolean checkTechInterimData=false;
                boolean checkTechFinalData=false;
                boolean checkCourseInterimData=false;
                boolean checkCourseFinalData=false;
                boolean checkFacultyInterimData=false;
                boolean checkFacultyFinalData=false;
                
                List<String>  checkStatusforAllList=new List<String>();
                List<hed__Course_Offering__c>  courseOfferingList=new List<hed__Course_Offering__c>();
                List<hed__Course_Enrollment__c> facultyList=new List<hed__Course_Enrollment__c>();
                List<Feedback_Scheduler__c> feedBackSchList=new List<Feedback_Scheduler__c>();
                List<Collected_Feedback_Data__c> collFeedBackSetupList=new List<Collected_Feedback_Data__c>();
				Map<String,String>  checkStatusMap=new Map<String,String>();  
                 
                Contact cont=[SELECT Id,Recordtype.Name FROM Contact WHERE Id=:contactId WITH SECURITY_ENFORCED];
                
                courseOfferingList=[SELECT Id,hed__Course__c,hed__Course__r.Name FROM hed__Course_Offering__c WHERE hed__Term__c=:termId WITH SECURITY_ENFORCED];
                    
                facultyList=[SELECT Id,hed__Contact__c,hed__Contact__r.Name FROM hed__Course_Enrollment__c 
                             WHERE hed__Course_Offering__r.hed__Term__c=:termId 
                             AND hed__Status__c='Current' AND hed__Contact__r.Recordtype.Name='Faculty' WITH SECURITY_ENFORCED];
                
                feedBackSchList=[SELECT Id,Term__c,Term__r.Name,Feedback_Master__c,End_Date__c,Feedback_Master__r.Feedback_Type__c,Term__r.hed__Account__r.Name,Start_Date__c
                FROM Feedback_Scheduler__c WHERE Term__c=:termId AND Start_Date__c <=: System.today() AND End_Date__c >=: System.today() WITH SECURITY_ENFORCED];
                
                collFeedBackSetupList=[SELECT Id,Term__c,Contact__c,Feedback_Master__c,Feedback_Master__r.Feedback_Type__c,Faculty__c,Course__c
                FROM Collected_Feedback_Data__c WHERE Term__c=:termId AND Contact__c=:contactId WITH SECURITY_ENFORCED];
                
                if(!collFeedBackSetupList.isEmpty()){
                    for(Collected_Feedback_Data__c coll:collFeedBackSetupList){
                        if(coll.Feedback_Master__r.Feedback_Type__c=='Interim Feedback' || coll.Feedback_Master__r.Feedback_Type__c=='Final Feedback'){
                            if(!String.isBlank(coll.Course__c) && String.isBlank(coll.Faculty__c)){
                                checkStatusforAllList.add(coll.Course__c+'_'+coll.Contact__c+'_'+coll.Feedback_Master__r.Feedback_Type__c);
                            }
							else if(!String.isBlank(coll.Faculty__c)){
                                checkStatusforAllList.add(coll.Faculty__c+'_'+coll.Contact__c+'_'+coll.Feedback_Master__r.Feedback_Type__c);
                            } 
                            else if(String.isBlank(coll.Faculty__c) && String.isBlank(coll.Course__c)){
                                checkStatusforAllList.add(coll.Contact__c+'_'+coll.Feedback_Master__r.Feedback_Type__c);
                            }
                        }
                        else{
                            checkStatusMap.put(coll.Contact__c+'_'+coll.Feedback_Master__r.Feedback_Type__c,'Submitted');
                        }
                    }
                    
                    //check all Course Data present
                    if(!courseOfferingList.isEmpty()){
                        checkCourseInterimData=true;
                    	checkCourseFinalData=true;
                        for(hed__Course_Offering__c course:courseOfferingList){
                            if(checkStatusforAllList.isEmpty() || !checkStatusforAllList.contains(course.hed__Course__c+'_'+contactId+'_Interim Feedback')){
                                checkCourseInterimData=false;
                            }
                            if(checkStatusforAllList.isEmpty() || !checkStatusforAllList.contains(course.hed__Course__c+'_'+contactId+'_Final Feedback')){
                                checkCourseFinalData=false;
                            }
                        }
                    }
                    
                    //check all Faculty Data present
                    if(!facultyList.isEmpty()){
                        checkFacultyInterimData=true;
                    	checkFacultyFinalData=true;
                        for(hed__Course_Enrollment__c faculty:facultyList){
                            if(checkStatusforAllList.isEmpty() || !checkStatusforAllList.contains(faculty.hed__Contact__c+'_'+contactId+'_Interim Feedback')){
                                checkFacultyInterimData=false;
                            }
                            if(checkStatusforAllList.isEmpty() || !checkStatusforAllList.contains(faculty.hed__Contact__c+'_'+contactId+'_Final Feedback')){
                                checkFacultyFinalData=false;
                            }
                        }
                    }
                    
                    //check all Technology Data present
                    if(!checkStatusforAllList.isEmpty() && checkStatusforAllList.contains(contactId+'_Interim Feedback')){
                        checkTechInterimData=true;
                    }
                    if(!checkStatusforAllList.isEmpty() && checkStatusforAllList.contains(contactId+'_Final Feedback')){
                        checkTechFinalData=true;
                    }
                
                    
                }
                if(!feedBackSchList.isEmpty()){
                    List<responseFeedBackScheduleWrapper> responseFeedBackSchList=new List<responseFeedBackScheduleWrapper>();
                    for(Feedback_Scheduler__c feedBackSch:feedBackSchList){
                        if((cont.Recordtype.Name=='Faculty' && feedBackSch.Feedback_Master__r.Feedback_Type__c=='Faculty Feedback')
                          ||(cont.Recordtype.Name=='Student' && feedBackSch.Feedback_Master__r.Feedback_Type__c!='Faculty Feedback')){
                            responseFeedBackScheduleWrapper responseFeedBackSch=new responseFeedBackScheduleWrapper();
                            responseFeedBackSch.feedBackSchedulerId=feedBackSch.Id;
                            responseFeedBackSch.termId=feedBackSch.Term__c;
                            responseFeedBackSch.termName=feedBackSch.Term__r.Name;
                            responseFeedBackSch.academicProgramName=feedBackSch.Term__r.hed__Account__r.Name;
                            responseFeedBackSch.feedbackType=feedBackSch.Feedback_Master__r.Feedback_Type__c;
                            responseFeedBackSch.feedBackMasterId=feedBackSch.Feedback_Master__c;
                            if(feedBackSch.End_Date__c!=null)
                            {
                                responseFeedBackSch.dueDate=String.ValueOf(feedBackSch.End_Date__c);
                            }
                            if(feedBackSch.Feedback_Master__r.Feedback_Type__c=='Interim Feedback'){
                            	responseFeedBackSch.needSecondScreen=true;
                                if(checkCourseInterimData && checkFacultyInterimData && checkTechInterimData){
                                    responseFeedBackSch.status='Submitted';
                                }
                            }
                            if(feedBackSch.Feedback_Master__r.Feedback_Type__c=='Final Feedback'){
                            	responseFeedBackSch.needSecondScreen=true;
                                if(checkCourseFinalData && checkFacultyFinalData && checkTechFinalData){
                                    responseFeedBackSch.status='Submitted';
                                }
                            }
                            if(!checkStatusMap.keyset().isEmpty() && checkStatusMap.keyset().contains(contactId+'_'+feedBackSch.Feedback_Master__r.Feedback_Type__c)){
                            	responseFeedBackSch.status=checkStatusMap.get(contactId+'_'+feedBackSch.Feedback_Master__r.Feedback_Type__c);
                            }
                            responseFeedBackSchList.add(responseFeedBackSch);
                        }
                    }
                    jsonResponse = JSON.serialize(responseFeedBackSchList);
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
        public String feedBackMasterId {get;set;}
        public String termId {get;set;}
        public String termName {get;set;}
        public String academicProgramName {get;set;}
        public String feedbackType {get;set;}
        public string dueDate {get;set;}
        public string status='Pending';
        public boolean needSecondScreen=false;
    }
}