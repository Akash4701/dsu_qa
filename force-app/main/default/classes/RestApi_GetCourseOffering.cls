@RestResource(urlMapping='/CourseOfferingData/*')
global class RestApi_GetCourseOffering {
    @HttpGet
    global static void doGetGetCourseOfferingData(){
        String courseVersionId=RestContext.request.params.get('courseVersionId');
        String courseOfferingName=RestContext.request.params.get('courseOfferingName');
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
            query='SELECT Id,Name,Course_Version__c,hed__Faculty__c,hed__Course__c,hed__Faculty__r.Name,hed__Course__r.Name,Course_Specialisation__c,hed__Section_ID__c,hed__Capacity__c,Course_Specialisation__r.Name,Campus__c,Campus__r.Name,hed__Term__c,hed__Start_Date__c,hed__End_Date__c FROM hed__Course_Offering__c WHERE Course_Version__c !=null';
            if(!String.isBlank(courseVersionId))
            {
                query+=' AND Course_Version__c=\''+courseVersionId+'\'' ;
            }
    		if(!String.isBlank(courseOfferingName))
            {
                query+=' AND Name=\''+courseOfferingName+'\'' ;
            }
            List<hed__Course_Offering__c> couList = Database.query(query);
            system.debug('Size'+couList.size());
            for(hed__Course_Offering__c course:Database.query(query))
            {
                responseCourseOfferingDataWrapper responseData=new responseCourseOfferingDataWrapper();
                responseData.id=course.Id;
                responseData.courseOfferingID=course.Name;
                responseData.courseName=course.hed__Course__r.Name;
                responseData.courseId=course.hed__Course__c;
                responseData.courseSpecialisationId=course.Course_Specialisation__c;
                responseData.courseSpecialisationName=course.Course_Specialisation__r.Name;
                responseData.courseVersionId=course.Course_Version__c;
                responseData.termId=course.hed__Term__c;
                responseData.courseOfferingSectionId=course.hed__Section_ID__c;
                responseData.courseOfferingCapacity=course.hed__Capacity__c;
                responseData.facultyName=course.hed__Faculty__r.Name;
                responseData.facultyId=course.hed__Faculty__c;                
                if(course.hed__Start_Date__c!=null)
                {
                    responseData.startDate=String.ValueOf(course.hed__Start_Date__c);
                }
                if(course.hed__End_Date__c!=null)
                {
                    responseData.endDate=String.ValueOf(course.hed__End_Date__c);
                }
                app.put(course.Name,responseData);
            }
            system.debug('appSize'+app.size());
            if(!app.keyset().isEmpty())
            {
                jsonResponse = JSON.serialize(app);
                if(jsonResponse!=null){    
                    res.responseBody=Blob.valueOf(jsonResponse); 
                }
                else
                {
                    res.responseBody=Blob.valueOf('[]'); 
                } 
            }
            else
            {
                res.responseBody = Blob.valueOf( '{ "success": "true" , "message": "No Data Found"}' );
            }
            res.statusCode = 200;
    	}Catch(Exception e){
            res.statusCode = 400;
            res.responseBody = Blob.valueOf( '{ "success": "false" , "message": "bad request", "errors": "'+e.getMessage()+'at Line Number'+e.getLineNumber()+'" }' );
        }
    }
    
    public class responseCourseOfferingDataWrapper {
        public string id {get;set;}
        public string courseOfferingID {get;set;}
        public string courseName {get;set;}
        public string courseId {get;set;}
        public string courseSpecialisationId {get;set;}
        public string courseSpecialisationName {get;set;}
        public string courseVersionId {get;set;}
        public string courseOfferingSectionId {get;set;}
        public decimal courseOfferingCapacity {get;set;}
        public string termId {get;set;}
        public string startDate {get;set;}
        public string endDate {get;set;}
        public string facultyName {get;set;}
        public string facultyId {get;set;}
    }
   
}