@RestResource(urlMapping='/createCourseOffering/*')
global class RestApi_CreateCourseOffering {
    @HttpPost
    global static void doCourseOffering(){
        RestResponse res = RestContext.response;
        string jsonResponse='';
        Set<Id> accountIds=new Set<Id>();
        Map<Id,Id> accPersonAccMap=new Map<Id,Id>(); 
        try{
            requestCourseOfferingWrapper request = (requestCourseOfferingWrapper) JSON.deserialize(RestContext.request.requestBody.toString(),requestCourseOfferingWrapper.class);
            responseCourseOfferingyWrapper response=new responseCourseOfferingyWrapper();
            accountIds.add(request.CourseOffering.coursePrimaryFaculty);
            List<Account> accList=new List<Account>();
            accList=[SELECT Id, Name, PersonContactId FROM Account WHERE Id IN :accountIds];
            for(Account acc:accList){
                accPersonAccMap.put(acc.id,acc.PersonContactId);
            }
            if(request.Operation=='Delete')
            {
                List<String> courseOfferingIds = request.CourseOffering.courseOfferingIds;
    			if(courseOfferingIds != null && !courseOfferingIds.isEmpty()) 
                //if(!String.isBlank(request.CourseOffering.courseOfferingId))
                { 
                    List<hed__Course_Offering__c> coursesToDelete = new List<hed__Course_Offering__c>();
        			//List<Exam_Connections__c> examConnListToDelete = new List<Exam_Connections__c>();
                    //hed__Course_Offering__c course=new hed__Course_Offering__c();
                    //course.Id=request.CourseOffering.courseOfferingId;
                    coursesToDelete = [SELECT Id FROM hed__Course_Offering__c WHERE Id IN :courseOfferingIds];
                    List<Exam_Connections__c> examConnList = [Select Id,Course_Name__c from Exam_Connections__c where Course_Name__c IN :courseOfferingIds];
                    if(!examConnList.isEmpty()){
                        delete examConnList;
                    }
                    delete coursesToDelete;
                    res.statusCode = 200;
                    res.responseBody = Blob.valueOf( '{ "success": "true" , "message": "Data is Deleted"}' );
                }
                else 
                {
                    res.responseBody = Blob.valueOf( '{ "success": "true" , "message": "No Data Found"}' );
                }
            }
            else 
            {
                if(!String.isBlank(request.CourseOffering.courseVersionId) || !String.isBlank(request.CourseOffering.courseOfferingId))
                {
                    if(!String.isBlank(request.CourseOffering.courseOfferingId))
                    {
                        List<hed__Course_Offering__c> courseOff=new List<hed__Course_Offering__c>([SELECT Id,Course_Version__c FROM hed__Course_Offering__c WHERE Id=:request.CourseOffering.courseOfferingId]);
                        if(!courseOff.isEmpty())
                        {
                            request.CourseOffering.courseVersionId=courseOff[0].Course_Version__c;
                        }
                    }
                  	if(String.isBlank(request.CourseOffering.courseOfferingId) && !String.isBlank(request.CourseOffering.courseVersionId) && !String.isBlank(request.CourseOffering.courseOfferingSectionId))
                    {
                        List<hed__Course_Offering__c> courseOff=new List<hed__Course_Offering__c>([SELECT Id,Course_Version__c FROM hed__Course_Offering__c WHERE Course_Version__c=:request.CourseOffering.courseVersionId AND hed__Section_ID__c=:request.CourseOffering.courseOfferingSectionId]);
                        system.debug('REq Section'+request.CourseOffering.courseOfferingSectionId);
                        if(!courseOff.isEmpty())
                        {
                            request.CourseOffering.courseOfferingId=courseOff[0].Id;
                        }
                    }
                    if(!String.isBlank(request.CourseOffering.courseVersionId))
                    {
                        List<Course_Version__c> courseVersion=new List<Course_Version__c>([SELECT Id,Term__c,Course__c,Course__r.Name,Term__r.Name ,Subject_End_Date__c,Start_Date__c,End_Date__c FROM Course_Version__c WHERE Id=:request.CourseOffering.courseVersionId]);
                        if(!courseVersion.isEmpty())
                        {
                            hed__Course_Offering__c course=new hed__Course_Offering__c();
                            course.hed__Term__c=courseVersion[0].Term__c;
                            course.Course_Version__c=request.CourseOffering.courseVersionId;
                            course.hed__Faculty__c = accPersonAccMap.get(request.CourseOffering.coursePrimaryFaculty);
                            course.hed__Course__c=courseVersion[0].Course__c;
                            course.hed__Section_ID__c=request.CourseOffering.courseOfferingSectionId;
                            course.Name = courseVersion[0].Term__r.Name +'-' + courseVersion[0].Course__r.Name.substringBefore('-')+'-'+request.CourseOffering.courseOfferingSectionId;
                            if(!String.isBlank(request.CourseOffering.courseOfferingId))
                            {
                                course.Id=request.CourseOffering.courseOfferingId;
                            } 
                            if(!String.isBlank(request.CourseOffering.courseOfferingCapacity))
                            {
                                course.hed__Capacity__c=decimal.valueOf(request.CourseOffering.courseOfferingCapacity);
                            }
                            if(courseVersion[0].Start_Date__c!=null)
                            {
                                course.hed__Start_Date__c=courseVersion[0].Start_Date__c;
                            }
                            if(courseVersion[0].Subject_End_Date__c!=null)
                            {
                                course.hed__End_Date__c=courseVersion[0].Subject_End_Date__c;
                            }
                            upsert course;
                            response.courseOfferingId=course.Id;
                            res.statusCode = 200;
                            if(!String.isBlank(response.courseOfferingId))
                            {
                                jsonResponse=json.serialize(response);
                                res.responseBody=Blob.valueOf(jsonResponse); 
                            }
                            else 
                            {
                                res.responseBody = Blob.valueOf( '{ "success": "true" , "message": "No Data Found"}' );
                            } 
                        }
                        else 
                        {
                            res.responseBody = Blob.valueOf( '{ "success": "true" , "message": "No Data Found"}' );
                        }
                    }
                    else 
                    {
                        res.responseBody = Blob.valueOf( '{ "success": "true" , "message": "No Data Found"}' );
                    }       
                }
                else 
                {
                    res.responseBody = Blob.valueOf( '{ "success": "true" , "message": "No Data Found"}' );
                }
            }
            
        }Catch(Exception e){
            res.statusCode = 400;
            res.responseBody = Blob.valueOf( '{ "success": "false" , "message": "bad request", "errors": "'+e.getMessage()+'at Line Number'+e.getLineNumber()+'" }' );
        }
    }
    //Wrapper class for the request from API 
    public class requestCourseOfferingWrapper {
        public requestCourseOfferingDataWrapper CourseOffering {get;set;}
        public string Operation {get;set;}
    }
    public class requestCourseOfferingDataWrapper {
        public String courseOfferingId {get;set;}
        public String courseOfferingCapacity {get;set;}
        public String courseOfferingSectionId {get;set;}
        public String courseVersionId {get;set;}
        public string coursePrimaryFaculty {get;set;}
        public List<String> courseOfferingIds {get;set;}
    }
    public class responseCourseOfferingyWrapper {
        public string success='true';
        public string message='Data is Added';
        public String courseOfferingId {get;set;}
    } 
    
  
}