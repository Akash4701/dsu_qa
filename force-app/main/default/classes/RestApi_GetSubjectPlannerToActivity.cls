@RestResource(urlMapping='/SubjectPlannerToActivityData/*')
global class RestApi_GetSubjectPlannerToActivity {
    @HttpGet
    global static void doGetSubjectPlannerToActivityData(){
        String term=RestContext.request.params.get('term');
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');
        String response = '';
        string jsonResponse;
        String jsonResponses;
        try{
            Map<String,Object> app=new Map<String,Object>();
			if(!String.isBlank(term))
            {
                Schema.DescribeFieldResult F = Facility_Booking__c.Activity_type__c.getDescribe();
                Schema.sObjectField T = F.getSObjectField();
                List<PicklistEntry> entries = T.getDescribe().getPicklistValues();
                    
                List<Course_Version__c> courseData=new List<Course_Version__c>([SELECT Id,Course__c,Course__r.Name,Name,
                                                  (SELECT Id,Duration__c,Type_of_Activity__c FROM Subject_Activities__r),
                                                  (SELECT Id,Duration__c,Type_of_Activity__c FROM Subject_Planners__r) FROM Course_Version__c WHERE Term__c =:term]);
                if(!courseData.isEmpty())
                {
                    for(Course_Version__c course:courseData)
                    {
                        responseSubjectPlannerToActivityDataWrapper  responseData=new responseSubjectPlannerToActivityDataWrapper();
                        responseData=doWrapper(course,entries);
                        app.put(course.Course__r.Name,responseData);
                    }
                    if(!app.keyset().isEmpty()){
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
            res.statusCode = 200;
    	}Catch(Exception e){
            res.statusCode = 400;
            res.responseBody = Blob.valueOf( '{ "success": "false" , "message": "bad request", "errors": "'+e.getMessage()+'at Line Number'+e.getLineNumber()+'" }' );
        }
    }
    
    public class responseSubjectPlannerToActivityDataWrapper {
        public String courseVersionId {get;set;}
        public Map<String,Decimal> Required {get;set;}
        public Map<String,Decimal> Allocated {get;set;}
    }
    public static responseSubjectPlannerToActivityDataWrapper doWrapper(Course_Version__c course,List<PicklistEntry> entries){
        responseSubjectPlannerToActivityDataWrapper  responseData=new responseSubjectPlannerToActivityDataWrapper();
        Map<String,Decimal> subjectActivityDataMap=new  Map<String,Decimal>();
        Map<String,Decimal> subjectPlannerDataMap=new  Map<String,Decimal>();
        Decimal activityTotal=0;
        Decimal plannerTotal=0;
        if(!course.Subject_Activities__r.isEmpty())
        {
            for(Subject_Activity__c subjectActivity:course.Subject_Activities__r)
            {
                if(String.isBlank(subjectActivity.Type_of_Activity__c))
                {
                    subjectActivity.Type_of_Activity__c='Other';
                }
                if(!subjectActivityDataMap.keyset().contains(subjectActivity.Type_of_Activity__c))
                {
                    subjectActivityDataMap.put(subjectActivity.Type_of_Activity__c,subjectActivity.Duration__c);
                }
                else
                {
                     subjectActivityDataMap.put(subjectActivity.Type_of_Activity__c,subjectActivityDataMap.get(subjectActivity.Type_of_Activity__c)+subjectActivity.Duration__c);
                }
                activityTotal=activityTotal+subjectActivity.Duration__c;
            }
            subjectActivityDataMap.put('Total',activityTotal);
            for(Subject_Planner__c subjectPlanner:course.Subject_Planners__r)
            {
                if(String.isBlank(subjectPlanner.Type_of_Activity__c))
                {
                    subjectPlanner.Type_of_Activity__c='Other';
                }
                if(!subjectPlannerDataMap.keyset().contains(subjectPlanner.Type_of_Activity__c))
                { 
                    subjectPlannerDataMap.put(subjectPlanner.Type_of_Activity__c,subjectPlanner.Duration__c);
                }
                else
                {
                     subjectPlannerDataMap.put(subjectPlanner.Type_of_Activity__c,subjectPlannerDataMap.get(subjectPlanner.Type_of_Activity__c)+subjectPlanner.Duration__c);
                }
                plannerTotal=plannerTotal+subjectPlanner.Duration__c;
            }
            subjectPlannerDataMap.put('Total',plannerTotal);
        }
        for(PicklistEntry pickListVal:entries)
        {
             if(!subjectActivityDataMap.keyset().contains(String.ValueOf(pickListVal.getLabel())))
             { 
                 subjectActivityDataMap.put(String.ValueOf(pickListVal.getLabel()),0);
             }
             if(!subjectPlannerDataMap.keyset().contains(String.ValueOf(pickListVal.getLabel())))
             { 
                 subjectPlannerDataMap.put(String.ValueOf(pickListVal.getLabel()),0);
             }
             
        }
        if(!subjectActivityDataMap.keyset().contains('Total'))
        { 
            subjectActivityDataMap.put('Total',0);
        }
        if(!subjectPlannerDataMap.keyset().contains('Total'))
        { 
            subjectPlannerDataMap.put('Total',0);
        }
        responseData.Required=subjectActivityDataMap;
        responseData.Allocated=subjectPlannerDataMap;
        responseData.courseVersionId=course.Id;
        return responseData;
    }
    
    public static responseSubjectPlannerToActivityDataWrapper doWrapperForOffering(Course_Version__c course,List<PicklistEntry> entries,Id CourseOfferingId){
        responseSubjectPlannerToActivityDataWrapper  responseData=new responseSubjectPlannerToActivityDataWrapper();
        Map<String,Decimal> subjectPlannerDataMap=new  Map<String,Decimal>();
        Decimal activityTotal=0;
        Decimal plannerTotal=0;
        if(!course.Subject_Activities__r.isEmpty())
        {
            for(Subject_Planner__c subjectPlanner:course.Subject_Planners__r)
            {
                if(CourseOfferingId==subjectPlanner.Course_Offering__c)
                {
                    if(String.isBlank(subjectPlanner.Type_of_Activity__c))
                    {
                        subjectPlanner.Type_of_Activity__c='Other';
                    }
                    if(!subjectPlannerDataMap.keyset().contains(subjectPlanner.Type_of_Activity__c))
                    {
                        subjectPlannerDataMap.put(subjectPlanner.Type_of_Activity__c,subjectPlanner.Duration__c);
                    }
                    else
                    {
                         subjectPlannerDataMap.put(subjectPlanner.Type_of_Activity__c,subjectPlannerDataMap.get(subjectPlanner.Type_of_Activity__c)+subjectPlanner.Duration__c);
                    }
                    plannerTotal=plannerTotal+subjectPlanner.Duration__c;
                }
               
            }
            subjectPlannerDataMap.put('Total',plannerTotal);
        }
        for(PicklistEntry pickListVal:entries)
        {
             if(!subjectPlannerDataMap.keyset().contains(String.ValueOf(pickListVal.getLabel())))
             { 
                 subjectPlannerDataMap.put(String.ValueOf(pickListVal.getLabel()),0);
             }
             
        }
        if(!subjectPlannerDataMap.keyset().contains('Total'))
        { 
            subjectPlannerDataMap.put('Total',0);
        }
        responseData.Allocated=subjectPlannerDataMap;
        responseData.courseVersionId=course.Id;
        return responseData;
    }
       
}