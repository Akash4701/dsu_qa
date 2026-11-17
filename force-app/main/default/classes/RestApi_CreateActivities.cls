@RestResource(urlMapping='/createActivities')
global class RestApi_CreateActivities {
    @HttpPost
    global static void doCreateActivities(){
        RestResponse res = RestContext.response;
        string jsonResponse='';
         Set<Id> accountIds=new Set<Id>();
        Map<Id,Id> accPersonAccMap=new Map<Id,Id>(); 
        try{
            requestActivitiesWrapper request = (requestActivitiesWrapper) JSON.deserialize(RestContext.request.requestBody.toString(),requestActivitiesWrapper.class);
            responseActivitiesWrapper response=new responseActivitiesWrapper();
            accountIds.add(request.Activity.facultyIds);
            List<Account> accList=new List<Account>();
            accList=[SELECT Id, Name, PersonContactId FROM Account WHERE Id IN :accountIds];
            for(Account acc:accList){
                accPersonAccMap.put(acc.id,acc.PersonContactId);
            }
            if(request.Operation=='Delete')
            {
				if(!String.isBlank(request.Activity.activityId))
				{ 
                    Activity__c activityVal=new Activity__c();
                    activityVal.Id=request.Activity.activityId;
                    delete activityVal;
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
                if(!String.isBlank(request.Activity.termId))
                {
                    Date termStartDate;
                    Date termEndDate;
                    Map<Id,Course_Version__c> mapOfRequestedCourseVersions = new Map<Id,Course_Version__c>([Select id,Name,Start_Date__c from Course_Version__c where Id =:request.Activity.courseVersionId]);
                    List<K42_Academic_Planner__c> academicPlan=new List<K42_Academic_Planner__c>([SELECT Id,Name FROM K42_Academic_Planner__c WHERE Term__c=:request.Activity.termId AND RecordType.Name='Default']);
                    List<hed__Term__c> termVal=new List<hed__Term__c>([SELECT Id,Name,hed__Account__c,Program_Plan__c,hed__Start_Date__c,hed__End_Date__c FROM hed__Term__c WHERE Id=:request.Activity.termId AND RecordType.Name='Default Record']);
                    termStartDate=termVal[0].hed__Start_Date__c;
                    termEndDate=termVal[0].hed__End_Date__c;
                    if(academicPlan.isEmpty() )
                    {
                        if(!termVal.isEmpty() )
                        {
                            K42_Academic_Planner__c academic=new K42_Academic_Planner__c();
                            academic.Name=termVal[0].Name+'-Planner';
                            academic.K42_Program__c=termVal[0].hed__Account__c;
                            academic.Program_Plan__c=termVal[0].Program_Plan__c;
                            academic.Term__c=termVal[0].Id;
                            academic.RecordTypeId=Schema.SObjectType.K42_Academic_Planner__c.getRecordTypeInfosByName().get('Default').getRecordTypeId();
                            insert academic;
                            academicPlan.add(academic);
                        } 
                    }
                    if(academicPlan.isEmpty() )
                    {
                        addError(true,200,'No Data Found');
                        return;
                    }
                        List<Activity__c> activitie=new List<Activity__c>();
                        if(!String.isBlank(request.Activity.activityId))
                        {
                            activitie=new List<Activity__c>([SELECT Id,Name FROM Activity__c 
                            WHERE Id =:request.Activity.activityId]);
                        }
                        Activity__c activity=new Activity__c();
                        Date activityStartDate;
                        Date activityEndDate;
                        Date cvStartDate;
                        if(!activitie.isEmpty())
                        {
                            activity.Id=activitie[0].Id; 
                        }
                        activity.RecordTypeId=Schema.SObjectType.Activity__c.getRecordTypeInfosByName().get('Default').getRecordTypeId();
                        activity.Name=academicPlan[0].Name+'-Activity';
                        activity.Academic_Planner__c=academicPlan[0].Id; 
                        activity.Activity_type__c=request.Activity.activityType;
                    	activity.Number_of_hours_session__c=request.Activity.numberOfhoursSessions;
                        if(request.Activity.duration != null)
                        	activity.Activity_Duration__c = request.Activity.duration;
                        if(!String.isBlank(request.Activity.courseVersionId))
                        {
                            activity.Subject__c=request.Activity.courseVersionId;
                        }
                        cvStartDate=mapOfRequestedCourseVersions.get(request.Activity.courseVersionId).Start_Date__c;
                        if(!String.isBlank(request.Activity.activityStartDate))
                        {
                            activityStartDate=toDate(request.Activity.activityStartDate);
                            activity.Start_date__c=activityStartDate;
                            if(activityStartDate < cvStartDate){
                                addError(false,200,'activity start date was beyond the subject start date');
                                return;
                            }
                        }
                        if(!String.isBlank(request.Activity.activityEndDate))
                        {
                            activityEndDate=toDate(request.Activity.activityEndDate);
                            activity.End_date__c=activityEndDate;
 
                        }
                    	activity.Course_Offering__c=request.Activity.courseOfferingId;
                    	activity.Number_of_Sessions__c=request.Activity.numberOfSessions!=null?request.Activity.numberOfSessions:0;
                        activity.Offset__c=cvStartDate.daysBetween(activityStartDate);
                        if(!String.isBlank(request.Activity.facilityId))
                        {
                            activity.Facility__c=request.Activity.facilityId;
                        }
    				    if(!String.isBlank(accPersonAccMap.get(request.Activity.facultyIds)))
                        {
                           
                            String facultyIdsString = accPersonAccMap.get(request.Activity.facultyIds);             
                             List<String> allFaculty = new List<String>(facultyIdsString.split(';'));
                          
                            if(allFaculty.size()>=1)
                            {
                               activity.Faculty1__c=allFaculty[0]; 
                               activity.Faculty2__c=null; 
                               activity.Faculty3__c=null; 
                            }
                            if(allFaculty.size()>=2)
                            {
                                activity.Faculty2__c=allFaculty[1];
                                activity.Faculty3__c=null; 
                            }
                            if(allFaculty.size()>=3)
                            {
                                activity.Faculty3__c=allFaculty[2];
                            }
                        }
                        else
                        {
                             activity.Faculty1__c=null; 
                             activity.Faculty2__c=null; 
                             activity.Faculty3__c=null; 
                        }
                        if(activity<> null)
                        {
                            upsert activity;
                            /*List<Activity__c> facultyRelatedActivities = [
                                SELECT Id, Name, Activity_type__c, Start_date__c, End_date__c, Working_Days__c,
                                    Subject__c, Subject__r.Term__c, Subject__r.Course__c, Subject__r.Course__r.Name,(Select Id,Name,Faculty__c,Mode_of_delivery__c FROM Faculty_Onboardings__r),
                                    Faculty1__c, Faculty1__r.Name, Faculty1__r.Email, Faculty1__r.Phone,
                                    Faculty1__r.Type_Of_Faculty__c, Subject__r.Number_of_Sessions__c,Subject__r.Course__r.Credits__c,
                                    Subject__r.Course__r.hed__Credit_Hours__c, Course_Offering__r.hed__Section_ID__c
                                FROM Activity__c
                                WHERE Id =:activity.Id
                            ];
                            //List<Faculty_Onboarding__c> facOnboarding = [Select Id,Name,Faculty__c,Mode_of_delivery__c FROM Faculty_Onboarding__c WHERE Activity__c =: activity.Id];
                            if(facultyRelatedActivities[0].Faculty_Onboardings__r.size() == 0){
                                Faculty_Onboarding__c facOnboardingRec = new Faculty_Onboarding__c();
                                facOnboardingRec.Activity__c = activity.Id;
                                facOnboardingRec.Course__c = activity.Subject__r.Course__c;
                                facOnboardingRec.Faculty__c = activity.Faculty1__c;
                                facOnboardingRec.Credit_Hours__c = activity.Subject__r.Course__r.hed__Credit_Hours__c;
                                facOnboardingRec.Start_Date__c = activity.Start_date__c;
                                facOnboardingRec.End_Date__c = activity.End_date__c;
                                facOnboardingRec.Working_Days__c = activity.Working_Days__c;
                                //facOnboardingRec.Mode_of_delivery__c = activity.
                                facOnboardingRec.Email_Status__c = '	Not Send';
                                insert facOnboardingRec;
                                
                            }*/
                            response.activityId=activity.Id;
                        }
                        res.statusCode = 200;
                        if(!String.isBlank(response.activityId))
                        {
                            jsonResponse=json.serialize(response);
                            res.responseBody=Blob.valueOf(jsonResponse); 
                        }
                        else 
                        {
                            addError(true,200,'No Data Found');
                            return;
                        }
                }
                else 
                {
                    addError(true,200,'No Data Found');
                    return;
                }
            }
        }Catch(Exception e){
            addError(false,400,e.getMessage()+'at Line Number'+e.getLineNumber());
            return;
        }
    }
                                                        
    public static Date toDate(String DateTimevalue) {
        List<String> DateAndTimeList = DateTimevalue.split('T');
        List<String> dayList = DateAndTimeList[0].split('-');
        List<string> timeList = DateAndTimeList[1].split(':');
        Date dt = Date.newInstance(Integer.valueOf(dayList[0]), Integer.valueOf(dayList[1]),Integer.valueOf(dayList[2]));
    	return dt;
    }  
    
    private static void addError(Boolean success, Integer statusCode, String message) {
        wrapper result = new wrapper();
        result.success = success;
        result.message = message;
        
        RestContext.response.statusCode = statusCode;
        RestContext.response.headers.put('content-type', 'text/plain');
        RestContext.response.responseBody = Blob.valueOf(JSON.serialize(result));
    }
    public virtual class wrapper {
        public Boolean success;
        public String message;
    }
    //Wrapper class for the request from API 
    public class requestActivitiesWrapper {
        public requestActivityWrapper Activity {get;set;}
        public string Operation {get;set;}
   
    }
    public class requestActivityWrapper {
        public String termId {get;set;}
        public String courseVersionId {get;set;}
        public Id courseOfferingId {get;set;}
        public String activityId {get;set;}
        public String activityType {get;set;}
        public String activityStartDate {get;set;}
        public String activityEndDate {get;set;}
        public Integer duration {get;set;}
        public Decimal numberOfhoursSessions{get;set;}
		public String facultyIds {get;set;}  
        public String facilityId {get;set;}
        public Decimal numberOfSessions {get;set;}
    }
    public class responseActivitiesWrapper {
        public string success='true';
        public string message='Data is Added';
        public String activityId {get;set;}
    }
      
    
}