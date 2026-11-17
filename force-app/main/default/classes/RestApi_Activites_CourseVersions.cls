@RestResource(urlMapping='/activitesWithCourseVersion/*')
global class RestApi_Activites_CourseVersions {
    
    @HttpGet
    global static void doGet(){
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');
        String courseVersionId = RestContext.request.params.get('courseVersionId');
        String facilityId = RestContext.request.params.get('facilityId');
        String query;
        try{
            if(String.isBlank(courseVersionId) && String.isBlank(facilityId)){
                addError(false,400,'Invalid parameter');
                return;
            }
            List<Activity__c> activitesList = new List<Activity__c>();
            if(String.isNotBlank(courseVersionId) && String.isBlank(facilityId)){
                activitesList = [Select Id,Name, Number_of_hours_session__c , Activity_type__c,Week_No__c,Start_date__c,End_date__c,Faculty1__c,Faculty1__r.Name,Faculty2__c,Faculty2__r.Name,Faculty3__c,Faculty3__r.Name,Subject__r.Course__r.Name,Activity_Duration__c,Working_Days__c,Subject__r.Facilities__c,Subject__r.Facilities__r.Name,Course_Offering__r.hed__Section_ID__c,Course_Offering__c,Number_of_Sessions__c from Activity__c where Subject__c=:courseVersionId ORDER BY Start_date__c ASC];
            }
            if(String.isBlank(courseVersionId) && String.isNotBlank(facilityId)){
                activitesList = [Select Id,Name, Number_of_hours_session__c ,Activity_type__c,Week_No__c,Start_date__c,End_date__c,Faculty1__c,Faculty1__r.Name,Faculty2__c,Faculty2__r.Name,Faculty3__c,Faculty3__r.Name,Subject__r.Course__r.Name,Activity_Duration__c,Working_Days__c,Subject__r.Facilities__c,Subject__r.Facilities__r.Name,Course_Offering__r.hed__Section_ID__c,Course_Offering__c,Number_of_Sessions__c from Activity__c where Subject__r.Facilities__c=:facilityId ORDER BY Start_date__c ASC];
            }
            if(String.isNotBlank(courseVersionId) && String.isNotBlank(facilityId)){
                activitesList = [Select Id,Name,Number_of_hours_session__c ,Activity_type__c,Week_No__c,Start_date__c,End_date__c,Faculty1__c,Faculty1__r.Name,Faculty2__c,Faculty2__r.Name,Faculty3__c,Faculty3__r.Name,Subject__r.Course__r.Name,Activity_Duration__c,Working_Days__c,Subject__r.Facilities__c,Subject__r.Facilities__r.Name,Course_Offering__r.hed__Section_ID__c,Course_Offering__c,Number_of_Sessions__c from Activity__c where Subject__c=:courseVersionId and Subject__r.Facilities__c=:facilityId ORDER BY Start_date__c ASC];
            }
            if(activitesList.isEmpty()){
                addError(false,200,'No Data found');
                return;
            }
            
            List<jsonWrapper> wrapList = new List<jsonWrapper>();
            for(Activity__c actObj:activitesList){
                jsonWrapper wrapObj = new jsonWrapper();
                List<facultylisting> AllFacultiesList = new List<facultylisting>();
                
                wrapObj.activiteId = actObj.Id;
                wrapObj.activiteName = actObj.Name;
                wrapObj.activiteType = actObj.Activity_type__c;
                wrapObj.startDate = actObj.Start_date__c;
                wrapObj.endDate = actObj.End_date__c;
                wrapObj.weekNo = actObj.Week_No__c;
                wrapObj.activityDuration = actObj.Activity_Duration__c;
                wrapObj.workingDays = actObj.Working_Days__c;
                wrapObj.subjectName = actObj.Subject__r.Course__r.Name;
                wrapObj.courseOfferingSection = actObj.Course_Offering__r.hed__Section_ID__c;
                wrapObj.courseOfferingId = actObj.Course_Offering__c;
                wrapObj.numberOfSessions = actObj.Number_of_Sessions__c;
                wrapObj.numberOfhoursSessions = actObj.Number_of_hours_session__c;
                if(String.isNotBlank(actObj.Subject__r.Facilities__r.Name))
                	wrapObj.facilityName = actObj.Subject__r.Facilities__r.Name;
                if(!string.isEmpty(actObj.Faculty1__c)){
                    facultylisting facultyList1 = new facultylisting();
                    facultyList1.title = actObj.Faculty1__r.Name;
                    facultyList1.value = actObj.Faculty1__c; 
                    AllFacultiesList.add(facultyList1);
                }
                if(!string.isEmpty(actObj.Faculty2__c)){
                    facultylisting facultyList2 = new facultylisting();
                    facultyList2.title = actObj.Faculty2__r.Name;
                    facultyList2.value = actObj.Faculty2__c;
                    AllFacultiesList.add(facultyList2);
                }
                if(!string.isEmpty(actObj.Faculty3__c)){
                    facultylisting facultyList3 = new facultylisting();
                    facultyList3.title = actObj.Faculty3__r.Name;
                    facultyList3.value = actObj.Faculty3__c; 
                    AllFacultiesList.add(facultyList3);
                }
                wrapObj.facultyList = AllFacultiesList;
                wrapList.add(wrapObj);
            }
            if(!wrapList.isEmpty()){
                res.statusCode = 200;
                res.responseBody = Blob.valueOf('{ "success": true ,"data":'+json.serialize(wrapList)+'}');
            }        
        }catch(Exception e){
            addError(false,400,e.getMessage()+'at Line Number'+e.getLineNumber());
            return;
        }
    }
    
    private static void addError(Boolean success, Integer statusCode, String message) {
        ErrorWrapper result = new ErrorWrapper();
        result.success = success;
        result.message = message;
        
        RestContext.response.statusCode = statusCode;
        RestContext.response.headers.put('content-type', 'text/plain');
        RestContext.response.responseBody = Blob.valueOf(JSON.serialize(result));
    }
    
    private virtual class ErrorWrapper {
        public Boolean success;
        public String message;
    }
    
    global class jsonWrapper{
        public Id activiteId;
        public string activiteName;
        public string activiteType;
        public Date startDate;
        public Date endDate;
        public string subjectName;
        public String courseOfferingSection;
        public Id courseOfferingId;
        public Decimal activityDuration;
        public String workingDays; 
        public decimal weekNo;
        public Decimal numberOfhoursSessions;
        public String facilityName;
        public Decimal numberOfSessions;
        public List<facultylisting> facultyList;
    }
    global class facultylisting{
        public string title;
        public string value;
        
    }
    
}