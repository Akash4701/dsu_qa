@RestResource(urlMapping='/ActivitiesData/*')
global class RestApi_GetActivities {
    @HttpGet
    global static void doGetActivitiesData(){
        String programName=RestContext.request.params.get('programName');
        String intake=RestContext.request.params.get('intake');
        String year=RestContext.request.params.get('year');
        String termId=RestContext.request.params.get('term');
        String typeOfActivity = RestContext.request.params.get('type');
        String facultyId = RestContext.request.params.get('facultyId');
        String facilityId = RestContext.request.params.get('facilityId');
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');
        String response = '';
        string jsonResponse;
        String jsonResponses;
        try{
            Map<String,List<Object>> app=new Map<String,List<Object>>();
            if(String.isNotBlank(facilityId)&&String.isBlank(termId)&&String.isBlank(programName) && String.isBlank(intake) && String.isBlank(year)){
                List<Activity__c> actList = [SELECT Id,Academic_Planner__r.Name,Name,Term__c,Academic_Planner__r.Term__r.Name,Activity_type__c,Facility__c,Facility__r.Name,Subject__c,Start_date__c,End_date__c,Week_No__c,Faculty1__c,Faculty2__c,Faculty3__c,Subject__r.Course__r.Id,Subject__r.Course__r.Name,Faculty1__r.Name,Faculty2__r.Name,Faculty3__r.Name,Academic_Planner__r.Program_Plan__c,Academic_Planner__r.Program_Plan__r.Name,Activity_Start_Date__c,Activity_End_Date__c,Course_Offering__c,Course_Offering__r.hed__Section_ID__c,Number_of_Sessions__c FROM Activity__c WHERE RecordType.Name='Default' and Activity_type__c='Teaching' and Facility__c=:facilityId];
                for(Activity__c activity:actList){
                    List<responseActivitiesDataWrapper> responseDataList=new List<responseActivitiesDataWrapper>();
                    //responseActivitiesDataWrapper responseDataVal=new responseActivitiesDataWrapper();
                    //responseDataVal=getActivityData(activity);
                    responseDataList.add(getActivityData(activity));
                    app.put(activity.Term__c,responseDataList);
                }
                jsonResponse = JSON.serialize(app);
                if(jsonResponse!=null){    
                    res.responseBody=Blob.valueOf(jsonResponse); 
                }
                else
                {
                    res.responseBody=Blob.valueOf('[]'); 
                }
            }
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
            if((!String.isBlank(programName) && !String.isBlank(intake) && !String.isBlank(year)) || !String.isBlank(facultyId))
            {
                system.debug('@@@enter1');
                List<Account> accAllList =new List<Account>();
                if(String.isBlank(facultyId))
                {
                    accAllList =new List<Account>([SELECT Id,Name,RecordType.DeveloperName,(SELECT Id,Name FROM hed__Terms__r where RecordType.Name = 'Default Record' order by Name DESC) FROM Account WHERE Name=:programName AND RecordType.DeveloperName ='Academic_Program']);
                }
                
                if(!accAllList.isEmpty() || !String.isBlank(facultyId))
                {
                    system.debug('@@@enter2');
                    if((String.isBlank(facultyId) && !accAllList[0].hed__Terms__r.isEmpty()) || !String.isBlank(facultyId))
                    {
                        Map<Id,List<Activity__c>> termToActivityMap=new Map<Id,List<Activity__c>>();
                        List<K42_Academic_Planner__c> academicList=new List<K42_Academic_Planner__c>();
                        List<Activity__c> activtyList=new List<Activity__c>();
                        if(String.isBlank(facultyId))
                        {
                            if(!String.isBlank(termId) )
                            {
                                if(!String.isBlank(typeOfActivity)){
                                    if(String.isNotBlank(facilityId)){
                                        academicList=new List<K42_Academic_Planner__c> ([SELECT Id,Name,Term__c,Term__r.Name,(SELECT Id,Academic_Planner__r.Name,Name,Term__c,Academic_Planner__r.Term__r.Name,Activity_type__c,                                                                                                        
                                                                                                                      Facility__c,Facility__r.Name,Subject__c,Start_date__c,End_date__c,Week_No__c,Faculty1__c,Faculty2__c,Faculty3__c,Subject__r.Course__r.Id,Subject__r.Course__r.Name,Faculty1__r.Name,Faculty2__r.Name,Faculty3__r.Name,Academic_Planner__r.Program_Plan__c,Academic_Planner__r.Program_Plan__r.Name,Activity_Start_Date__c,Activity_End_Date__c,Course_Offering__c,Course_Offering__r.hed__Section_ID__c,Number_of_Sessions__c FROM Activities__r WHERE RecordType.Name='Default' and Activity_type__c=:typeOfActivity AND isAccepted__c=true) FROM K42_Academic_Planner__c WHERE Term__c =:termId AND Recordtype.Name = 'Default']);
                                    }else{
                                        academicList=new List<K42_Academic_Planner__c> ([SELECT Id,Name,Term__c,Term__r.Name,(SELECT Id,Academic_Planner__r.Name,Name,Term__c,Academic_Planner__r.Term__r.Name,Activity_type__c,                                                                                                        
                                                                                                                      Facility__c,Facility__r.Name,Subject__c,Start_date__c,End_date__c,Week_No__c,Faculty1__c,Faculty2__c,Faculty3__c,Subject__r.Course__r.Id,Subject__r.Course__r.Name,Faculty1__r.Name,Faculty2__r.Name,Faculty3__r.Name,Academic_Planner__r.Program_Plan__c,Academic_Planner__r.Program_Plan__r.Name,Activity_Start_Date__c,Activity_End_Date__c,Course_Offering__c,Course_Offering__r.hed__Section_ID__c,Number_of_Sessions__c FROM Activities__r WHERE RecordType.Name='Default' and Activity_type__c=:typeOfActivity and Facility__c=:facilityId AND isAccepted__c=true) FROM K42_Academic_Planner__c WHERE Term__c =:termId AND Recordtype.Name = 'Default']);
                                    }
                                    
                                }else{
                                    if(String.isNotBlank(facilityId)){
                                        academicList=new List<K42_Academic_Planner__c> ([SELECT Id,Name,Term__c,Term__r.Name,(SELECT Id,Academic_Planner__r.Name,Name,Term__c,Academic_Planner__r.Term__r.Name,Activity_type__c,                                                                                                        
                                                                                                                      Facility__c,Facility__r.Name,Subject__c,Start_date__c,End_date__c,Week_No__c,Faculty1__c,Faculty2__c,Faculty3__c,Subject__r.Course__r.Id,Subject__r.Course__r.Name,Faculty1__r.Name,Faculty2__r.Name,Faculty3__r.Name,Academic_Planner__r.Program_Plan__c,Academic_Planner__r.Program_Plan__r.Name,Activity_Start_Date__c,Activity_End_Date__c,Course_Offering__c,Course_Offering__r.hed__Section_ID__c,Number_of_Sessions__c FROM Activities__r WHERE RecordType.Name='Default' and Facility__c=:facilityId AND isAccepted__c=true) FROM K42_Academic_Planner__c WHERE Term__c =:termId AND Recordtype.Name = 'Default']);
                                    }else{
                                        academicList=new List<K42_Academic_Planner__c> ([SELECT Id,Name,Term__c,Term__r.Name,(SELECT Id,Academic_Planner__r.Name,Name,Term__c,Academic_Planner__r.Term__r.Name,Activity_type__c,                                                                                                        
                                                                                                                      Facility__c,Facility__r.Name,Subject__c,Start_date__c,End_date__c,Week_No__c,Faculty1__c,Faculty2__c,Faculty3__c,Subject__r.Course__r.Id,Subject__r.Course__r.Name,Faculty1__r.Name,Faculty2__r.Name,Faculty3__r.Name,Academic_Planner__r.Program_Plan__c,Academic_Planner__r.Program_Plan__r.Name,Activity_Start_Date__c,Activity_End_Date__c,Course_Offering__c,Course_Offering__r.hed__Section_ID__c,Number_of_Sessions__c FROM Activities__r WHERE RecordType.Name='Default' AND isAccepted__c=true) FROM K42_Academic_Planner__c WHERE Term__c =:termId AND Recordtype.Name = 'Default']);
                                    }
                                    
                                }                                                                                      
                            }
                            else
                            {
                                if(!String.isBlank(typeOfActivity)){
                                    if(String.isNotBlank(facilityId)){
                                        academicList=new List<K42_Academic_Planner__c> ([SELECT Id,Name,Term__c,Term__r.Name,(SELECT Id,Academic_Planner__r.Name,Name,Term__c,Academic_Planner__r.Term__r.Name,Activity_type__c,                                                                                                        
                                                                                                                          Facility__c,Facility__r.Name,Subject__c,Start_date__c,End_date__c,Week_No__c,Faculty1__c,Faculty2__c,Faculty3__c,Subject__r.Course__r.Id,Subject__r.Course__r.Name,Faculty1__r.Name,Faculty2__r.Name,Faculty3__r.Name,Academic_Planner__r.Program_Plan__c,Academic_Planner__r.Program_Plan__r.Name,Activity_Start_Date__c,Activity_End_Date__c,Course_Offering__c,Course_Offering__r.hed__Section_ID__c,Number_of_Sessions__c FROM Activities__r  WHERE RecordType.Name='Default' and Activity_type__c=:typeOfActivity and Facility__c=:facilityId AND isAccepted__c=true) FROM K42_Academic_Planner__c WHERE Term__c IN:accAllList[0].hed__Terms__r AND Recordtype.Name = 'Default']);
                                    }else{
                                        academicList=new List<K42_Academic_Planner__c> ([SELECT Id,Name,Term__c,Term__r.Name,(SELECT Id,Academic_Planner__r.Name,Name,Term__c,Academic_Planner__r.Term__r.Name,Activity_type__c,                                                                                                        
                                                                                                                          Facility__c,Facility__r.Name,Subject__c,Start_date__c,End_date__c,Week_No__c,Faculty1__c,Faculty2__c,Faculty3__c,Subject__r.Course__r.Id,Subject__r.Course__r.Name,Faculty1__r.Name,Faculty2__r.Name,Faculty3__r.Name,Academic_Planner__r.Program_Plan__c,Academic_Planner__r.Program_Plan__r.Name,Activity_Start_Date__c,Activity_End_Date__c,Course_Offering__c,Course_Offering__r.hed__Section_ID__c,Number_of_Sessions__c FROM Activities__r  WHERE RecordType.Name='Default' and Activity_type__c=:typeOfActivity AND isAccepted__c=true) FROM K42_Academic_Planner__c WHERE Term__c IN:accAllList[0].hed__Terms__r AND Recordtype.Name = 'Default']);
                                    }
                                    
                                }else{
                                    if(String.isNotBlank(facilityId)){
                                        academicList=new List<K42_Academic_Planner__c> ([SELECT Id,Name,Term__c,Term__r.Name,(SELECT Id,Academic_Planner__r.Name,Name,Term__c,Academic_Planner__r.Term__r.Name,Activity_type__c,                                                                                                        
                                                                                                                          Facility__c,Facility__r.Name,Subject__c,Start_date__c,End_date__c,Week_No__c,Faculty1__c,Faculty2__c,Faculty3__c,Subject__r.Course__r.Id,Subject__r.Course__r.Name,Faculty1__r.Name,Faculty2__r.Name,Faculty3__r.Name,Academic_Planner__r.Program_Plan__c,Academic_Planner__r.Program_Plan__r.Name,Activity_Start_Date__c,Activity_End_Date__c,Course_Offering__c,Course_Offering__r.hed__Section_ID__c,Number_of_Sessions__c FROM Activities__r  WHERE RecordType.Name='Default' and Facility__c=:facilityId AND isAccepted__c=true) FROM K42_Academic_Planner__c WHERE Term__c IN:accAllList[0].hed__Terms__r AND Recordtype.Name = 'Default']);
                                    }else{
                                        academicList=new List<K42_Academic_Planner__c> ([SELECT Id,Name,Term__c,Term__r.Name,(SELECT Id,Academic_Planner__r.Name,Name,Term__c,Academic_Planner__r.Term__r.Name,Activity_type__c,                                                                                                        
                                                                                                                          Facility__c,Facility__r.Name,Subject__c,Start_date__c,End_date__c,Week_No__c,Faculty1__c,Faculty2__c,Faculty3__c,Subject__r.Course__r.Id,Subject__r.Course__r.Name,Faculty1__r.Name,Faculty2__r.Name,Faculty3__r.Name,Academic_Planner__r.Program_Plan__c,Academic_Planner__r.Program_Plan__r.Name,Activity_Start_Date__c,Activity_End_Date__c,Course_Offering__c,Course_Offering__r.hed__Section_ID__c,Number_of_Sessions__c FROM Activities__r  WHERE RecordType.Name='Default' AND isAccepted__c=true) FROM K42_Academic_Planner__c WHERE Term__c IN:accAllList[0].hed__Terms__r AND Recordtype.Name = 'Default']);
                                    }
                                    
                                }
                            }
                        }
                        else {
                            system.debug('@@@enter3');
                            if(String.isNotBlank(facilityId)){
                                activtyList=new List<Activity__c> ([SELECT Id,Academic_Planner__r.Name,Name,Term__c,Academic_Planner__r.Term__r.Name,Activity_type__c,Academic_Planner__r.Program_Plan__c,Academic_Planner__r.Program_Plan__r.Name,                                                                                                      
                                                                                                                      Facility__c,Facility__r.Name,Subject__c,Start_date__c,End_date__c,Week_No__c,Faculty1__c,Faculty2__c,Faculty3__c,Subject__r.Course__r.Id,Subject__r.Course__r.Name,Faculty1__r.Name,Faculty2__r.Name,Faculty3__r.Name,Activity_Start_Date__c,Activity_End_Date__c,Course_Offering__c,Course_Offering__r.hed__Section_ID__c,Number_of_Sessions__c FROM Activity__c  WHERE RecordType.Name='Default' AND isAccepted__c=true and Facility__c=:facilityId AND (Faculty1__c=:facultyId OR Faculty2__c=:facultyId  OR Faculty3__c=:facultyId ) order by Term__c Limit 1]);
                            }else{
                                activtyList=new List<Activity__c> ([SELECT Id,Academic_Planner__r.Name,Name,Term__c,Academic_Planner__r.Term__r.Name,Activity_type__c,Academic_Planner__r.Program_Plan__c,Academic_Planner__r.Program_Plan__r.Name,                                                                                                      
                                                                                                                      Facility__c,Facility__r.Name,Subject__c,Start_date__c,End_date__c,Week_No__c,Faculty1__c,Faculty2__c,Faculty3__c,Subject__r.Course__r.Id,Subject__r.Course__r.Name,Faculty1__r.Name,Faculty2__r.Name,Faculty3__r.Name,Activity_Start_Date__c,Activity_End_Date__c,Course_Offering__c,Course_Offering__r.hed__Section_ID__c,Number_of_Sessions__c FROM Activity__c  WHERE RecordType.Name='Default' AND isAccepted__c=true AND (Faculty1__c=:facultyId OR Faculty2__c=:facultyId  OR Faculty3__c=:facultyId ) order by Term__c Limit 1]);
                            }
							 
                        }
                        system.debug('@@@activtyList'+activtyList);
                        if(!String.isBlank(facultyId))
                        {
                            Map<Id,List<responseActivitiesDataWrapper>> termToActivityResponseMap=new Map<Id,List<responseActivitiesDataWrapper>>();
                            for(Activity__c activity:activtyList)
                            {
                                List<responseActivitiesDataWrapper> responseDataList=new List<responseActivitiesDataWrapper>();
                                responseActivitiesDataWrapper responseDataVal=new responseActivitiesDataWrapper();
                                responseDataVal=getActivityData(activity);
                                if(!termToActivityResponseMap.keyset().contains(activity.Term__c))
                                {
                                    responseDataList.add(responseDataVal);
                                	termToActivityResponseMap.put(activity.Term__c,responseDataList);
                                }
                                else
                                {
                                    responseDataList.addAll(termToActivityResponseMap.get(activity.Term__c));
                                    responseDataList.add(responseDataVal);
                                    termToActivityResponseMap.put(activity.Term__c,responseDataList);
                                }
                                
                            }
                            if(!termToActivityResponseMap.keyset().isEmpty())
                            {
                                for(Id termValId:termToActivityResponseMap.keyset())
                            	{
                                    app.put(termValId,termToActivityResponseMap.get(termValId));
                                }
                            }
                        }
                        else
                        {
                            for(K42_Academic_Planner__c plan:academicList)
                            {
                                List<responseActivitiesDataWrapper> responseDataList=new List<responseActivitiesDataWrapper>();
                                for(Activity__c activity:plan.Activities__r)
        						{
                                    responseActivitiesDataWrapper responseDataVal=new responseActivitiesDataWrapper();
                                	responseDataVal=getActivityData(activity);
                                    responseDataList.add(responseDataVal);
                                }
                                app.put(plan.Term__c,responseDataList);
                            }
                        }
                        
                    }
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
            }else if(String.isNotBlank(facilityId)&&String.isBlank(termId)&&String.isBlank(programName) && String.isBlank(intake) && String.isBlank(year)){
                List<Activity__c> actList = [SELECT Id,Academic_Planner__r.Name,Name,Term__c,Academic_Planner__r.Term__r.Name,Activity_type__c,Facility__c,Facility__r.Name,Subject__c,Start_date__c,End_date__c,Week_No__c,Faculty1__c,Faculty2__c,Faculty3__c,Subject__r.Course__r.Id,Subject__r.Course__r.Name,Faculty1__r.Name,Faculty2__r.Name,Faculty3__r.Name,Academic_Planner__r.Program_Plan__c,Academic_Planner__r.Program_Plan__r.Name,Activity_Start_Date__c,Activity_End_Date__c,Course_Offering__c,Course_Offering__r.hed__Section_ID__c,Number_of_Sessions__c FROM Activity__c WHERE RecordType.Name='Default' and Activity_type__c='Teaching' and Facility__c=:facilityId limit 49999];
                for(Activity__c activity:actList){
                    List<responseActivitiesDataWrapper> responseDataList=new List<responseActivitiesDataWrapper>();
                    //responseActivitiesDataWrapper responseDataVal=new responseActivitiesDataWrapper();
                    //responseDataVal=getActivityData(activity);
                    responseDataList.add(getActivityData(activity));
                    app.put(activity.Term__c,responseDataList);
                }
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
            if(app.keyset().isEmpty())
            {
                res.responseBody = Blob.valueOf( '{ "success": "true" , "message": "No Data Found"}' );
            }
            res.statusCode = 200;
        }Catch(Exception e){
            system.debug(e.getMessage()+'at Line Number'+e.getLineNumber());
            res.statusCode = 400;
            res.responseBody = Blob.valueOf( '{ "success": "false" , "message": "bad request", "errors": "'+e.getMessage()+'at Line Number'+e.getLineNumber()+'" }' );
        }
    }
    
    public class responseActivitiesDataWrapper {
        public string id {get;set;}
        public string academicPlannerId {get;set;}
        public string termId {get;set;}
        public string activityType {get;set;}
        public string durationInWeeks {get;set;}
        public string startDate {get;set;}
        public string endDate {get;set;}
        public string subjectId {get;set;}
        public Id courseId {get;set;}
        public string subjectCourseName {get;set;}
        public string faculty1Id {get;set;}
        public string faculty2Id {get;set;}
        public string faculty3Id {get;set;}
        public string faculty1Name {get;set;}
        public string faculty2Name {get;set;}
        public string faculty3Name {get;set;}
        public string facilityId {get;set;}
        public string facilityName {get;set;}
        public string programPlanId {get;set;}
        public string programPlanName {get;set;}
        public String section {get;set;}
        public Id courseOfferingId {get;set;}
        public Decimal noOfSessions {get;set;}
    }
    
    public static responseActivitiesDataWrapper getActivityData(Activity__c activity) {
        responseActivitiesDataWrapper responseDataVal=new responseActivitiesDataWrapper();
        responseDataVal.id=activity.Id;
        responseDataVal.academicPlannerId=activity.Academic_Planner__c;
        responseDataVal.termId=activity.Academic_Planner__r.Term__c;
        responseDataVal.activityType=activity.Activity_type__c;
        responseDataVal.subjectId=activity.Subject__c;
        responseDataVal.courseId=activity.Subject__r.Course__r.Id;
        responseDataVal.subjectCourseName=activity.Subject__r.Course__r.Name;
        responseDataVal.faculty1Id=activity.Faculty1__c;
        responseDataVal.faculty2Id=activity.Faculty2__c;
        responseDataVal.faculty3Id=activity.Faculty3__c;
        responseDataVal.faculty1Name=activity.Faculty1__r.Name;
        responseDataVal.faculty2Name=activity.Faculty2__r.Name;
        responseDataVal.faculty3Name=activity.Faculty3__r.Name;
        responseDataVal.facilityId=activity.Facility__c;
        responseDataVal.facilityName=activity.Facility__r.Name;
        responseDataVal.programPlanId=activity.Academic_Planner__r.Program_Plan__c;
        responseDataVal.programPlanName=activity.Academic_Planner__r.Program_Plan__r.Name;
        responseDataVal.section=activity.Course_Offering__r.hed__Section_ID__c;
        responseDataVal.courseOfferingId=activity.Course_Offering__c;
        responseDataVal.noOfSessions=activity.Number_of_Sessions__c;
    
        if(activity.Week_No__c!=null)
        {
            responseDataVal.durationInWeeks=String.ValueOf(activity.Week_No__c);
        }
        if(activity.Start_date__c!=null)
        {
            responseDataVal.startDate=String.ValueOf(activity.Start_date__c);
        }
        if(activity.End_date__c!=null)
        {
            responseDataVal.endDate=String.ValueOf(activity.End_date__c);
        }
        return responseDataVal;
    }
     
}