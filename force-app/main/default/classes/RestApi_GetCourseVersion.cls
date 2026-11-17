@RestResource(urlMapping='/CourseVersionData/*')
global class RestApi_GetCourseVersion {
    @HttpGet
    global static void doGetCourseVersionData(){
        String programName=RestContext.request.params.get('programName');
        String intake=RestContext.request.params.get('intake');
        String year=RestContext.request.params.get('year');
        String course=RestContext.request.params.get('course');
        String termId=RestContext.request.params.get('term');
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');
        String response = '';
        string jsonResponse;
        String jsonResponses;
        try{
            
            Schema.DescribeFieldResult F = Facility_Booking__c.Activity_type__c.getDescribe();
            Schema.sObjectField T = F.getSObjectField();
            List<PicklistEntry> entries = T.getDescribe().getPicklistValues();
            
            Map<String,List<Object>> app=new Map<String,List<Object>>();
            if(!String.isBlank(termId))
            {
                List<hed__Term__c> termList=new List<hed__Term__c>([SELECT Id,Program_Plan__r.hed__Account__r.Name,
				Program_Plan__r.Intake__c,Program_Plan__r.Batch__c FROM hed__Term__c WHERE Program_Plan__c<> Null AND Id=:termId]);
                if(!termList.isEmpty())
                {
                    programName=termList[0].Program_Plan__r.hed__Account__r.Name;
                    intake=termList[0].Program_Plan__r.Intake__c;
                    year=termList[0].Program_Plan__r.Batch__c;
                }
            }
            if(!String.isBlank(programName) && !String.isBlank(intake) && !String.isBlank(year))
            {
                List<Account> accAllList =new List<Account>();
                accAllList =new List<Account>([SELECT Id,Name,RecordType.DeveloperName,(Select Id,Name from hed__Terms__r WHERE RecordType.Name = 'Default Record'  order by Name DESC) FROM Account WHERE Name=:programName AND RecordType.DeveloperName ='Academic_Program']);
                if(!accAllList.isEmpty())
                {
                    if(!accAllList[0].hed__Terms__r.isEmpty())
                    {
                        for(hed__Term__c term:accAllList[0].hed__Terms__r)
                        {
                            if((!String.isBlank(termId) && term.Id==termId)||String.isBlank(termId))
                            {
                                List<responseCourseVersionDataWrapper> responseDataList=new List<responseCourseVersionDataWrapper>();
                                for(Course_Version__c courseData:[SELECT Id,Course__c,Exam_Required__c,Course__r.Name,Course__r.hed__Course_ID__c,Course__r.Credits__c,Term__r.hed__Start_Date__c,Term__r.hed__End_Date__c, 
                                Start_Date__c,End_Date__c,Term__r.Program_Plan__r.Working_Days__c,(SELECT Id,Name,hed__Section_ID__c FROM Course_Offerings__r order by hed__Section_ID__c ),
                                (SELECT Id,Duration__c,Type_of_Activity__c FROM Subject_Activities__r),
                                (SELECT Id,Duration__c,Type_of_Activity__c,Course_Offering__c FROM Subject_Planners__r) FROM Course_Version__c WHERE Term__c =:term.Id])
                                {
                                    if((String.isBlank(termId) && term.Name.contains(intake) && term.Name.contains(year))||!String.isBlank(termId))
                                    {
                                        if(String.isBlank(course) || (!String.isBlank(course) && term.Name.contains(course)))
                                        {
                                            responseCourseVersionDataWrapper responseData=new responseCourseVersionDataWrapper();
                                            responseData.id=courseData.Id;
                                            responseData.courseName=courseData.Course__r.Name;
                                            responseData.courseId=courseData.Course__r.hed__Course_ID__c;
                                            responseData.workingDays=courseData.Term__r.Program_Plan__r.Working_Days__c;
                                            responseData.termStartDate=courseData.Term__r.hed__Start_Date__c;
                                            responseData.termEndDate=courseData.Term__r.hed__End_Date__c;
                                            if(courseData.Course__r.Credits__c!=null)
                                            {
                                                responseData.credit=String.ValueOf(courseData.Course__r.Credits__c);
                                            }
                                            if(courseData.Start_Date__c!=null)
                                            {
                                                responseData.startDate=String.ValueOf(courseData.Start_Date__c);
                                            }
                                            if(courseData.End_Date__c!=null)
                                            {
                                                responseData.endDate=String.ValueOf(courseData.End_Date__c);
                                            }
                                            if(courseData.Exam_Required__c!=null)
                                            {
                                                responseData.examRequired=courseData.Exam_Required__c;
                                            }
                                            
                                            List<responseCourseOfferingDataWrapper> responseCourseList=new List<responseCourseOfferingDataWrapper>();
                                            if(!courseData.Course_Offerings__r.isEmpty())
                                            {
                                                for(hed__Course_Offering__c courseOff:courseData.Course_Offerings__r)
                                                {
                                                    List<facultyWrapper> facultyList = new List<facultyWrapper>();
                                                    hed__Course_Enrollment__c[] courseEnrollmentList = [Select Id,Name,hed__Contact__c,hed__Contact__r.Name from hed__Course_Enrollment__c where recordType.Name='Faculty' and hed__Course_Offering__c=:courseOff.Id and hed__Status__c='Current'];
                                                    for(hed__Course_Enrollment__c courseEnrollObj:courseEnrollmentList){
                                                        facultyWrapper facWrapObj = new facultyWrapper();
                                                        facWrapObj.facultyName = courseEnrollObj.hed__Contact__r.Name;
                                                        facWrapObj.facultyContactId = courseEnrollObj.hed__Contact__c;
                                                        facultyList.add(facWrapObj);
                                                    }
                                                    responseCourseOfferingDataWrapper responseCourseData=new responseCourseOfferingDataWrapper();
                                                    responseCourseData.id=courseOff.Id;
                                                    responseCourseData.courseOfferingName=courseOff.Name;
                                                    responseCourseData.courseSectionId=courseOff.hed__Section_ID__c;
                                                    responseCourseData.faculty = facultyList;
                                                    RestApi_GetSubjectPlannerToActivity.responseSubjectPlannerToActivityDataWrapper  responseOfferPlan=new RestApi_GetSubjectPlannerToActivity.responseSubjectPlannerToActivityDataWrapper();
                        							responseOfferPlan=RestApi_GetSubjectPlannerToActivity.doWrapperForOffering(courseData,entries,courseOff.Id);
                                                    responseCourseData.Allocated=responseOfferPlan.Allocated;
                                                    responseCourseList.add(responseCourseData);
                                                }
                                            }
                                            responseData.courseOffering=responseCourseList;
                                            
                                            RestApi_GetSubjectPlannerToActivity.responseSubjectPlannerToActivityDataWrapper  responseDataPlan=new RestApi_GetSubjectPlannerToActivity.responseSubjectPlannerToActivityDataWrapper();
                        					responseDataPlan=RestApi_GetSubjectPlannerToActivity.doWrapper(courseData,entries);
                                            responseData.Required=responseDataPlan.Required;
                                            responseData.Allocated=responseDataPlan.Allocated;
                                            responseDataList.add(responseData);
                                        }
                                    }
                                }
                                if((term.Name.contains(intake) && term.Name.contains(year))||!String.isBlank(termId))
                                {
                                    if(String.isBlank(course) || (!String.isBlank(course) && term.Name.contains(course)))
                                    {
                                        app.put(term.Id,responseDataList);
                                    }
                                }
                            }
                        }
  						system.debug('@@@app'+app);
                        jsonResponse = JSON.serialize(app);
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
            }
            else{
                res.responseBody = Blob.valueOf( '{ "success": "true" , "message": "No Data Found"}' );
            }
            if(app.keyset().isEmpty())
            {
                res.responseBody = Blob.valueOf( '{ "success": "true" , "message": "No Data Found"}' );
            }
            res.statusCode = 200;
    	}Catch(Exception e){
            res.statusCode = 400;
            res.responseBody = Blob.valueOf( '{ "success": "false" , "message": "bad request", "errors": "'+e.getMessage()+'at Line Number'+e.getLineNumber()+'" }' );
        }
    }
    
    public class responseCourseVersionDataWrapper {
        public string id {get;set;}
        public string courseName {get;set;}
        public string courseId {get;set;}
        public string credit {get;set;}
        public Date termStartDate {get;set;}
        public Date termEndDate {get;set;}
        public string startDate {get;set;}
        public string endDate {get;set;}
        public boolean examRequired {get;set;}
        public string workingDays {get;set;}
        public List<responseCourseOfferingDataWrapper> courseOffering {get;set;}
        public Map<String,Decimal> Required {get;set;}
        public Map<String,Decimal> Allocated {get;set;}
    }
    public class responseCourseOfferingDataWrapper {
        public string id {get;set;}
        public string courseOfferingName {get;set;}
        public string courseSectionId {get;set;}
        public Map<String,Decimal> Allocated {get;set;}
        public List<facultyWrapper> faculty {get;set;}
    }
    public class facultyWrapper{
        public string facultyName{get;set;}
        public Id facultyContactId{get;set;}
    }
   
}