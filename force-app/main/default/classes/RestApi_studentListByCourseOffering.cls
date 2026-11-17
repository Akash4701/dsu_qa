@RestResource(urlMapping='/studentsByCourseOffering/*')
global class RestApi_studentListByCourseOffering {
    @httpGet
    global static void doGet(){
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');
        String jsonResponse;
        String course_OfferingId = req.params.get('CourseOfferingId');
        try{
            if(String.isNotBlank(course_OfferingId)){
                List<responseDataWrapper> wapperList = new List<responseDataWrapper>();
                List<hed__Course_Enrollment__c> courseConnectionList = [select id,hed__Contact__c,hed__Contact__r.Name,hed__Contact__r.Email,hed__Contact__r.Registration_Number__c,hed__Contact__r.Account.Student_Code__c,RecordTypeId,hed__Course_Offering__c,No_Of_Classes_Attended__c from hed__Course_Enrollment__c where hed__Course_Offering__c =: course_OfferingId  AND hed__Status__c='Current' AND RecordType.Name='Student'];
                for(hed__Course_Enrollment__c courseConnections: courseConnectionList){
                    system.debug('courseConnections:'+courseConnections);
                    responseDataWrapper wrapperObj = new responseDataWrapper();
                    
                    wrapperObj.courseOfferingId = courseConnections.hed__Course_Offering__c;
                    wrapperObj.contactId = courseConnections.hed__Contact__c;
                    wrapperObj.contactName = courseConnections.hed__Contact__r.Name;
                    wrapperObj.contactEmail = courseConnections.hed__Contact__r.Email;
                    wrapperObj.contactRegNumber = courseConnections.hed__Contact__r.Registration_Number__c;
                    wrapperObj.studentCode = courseConnections.hed__Contact__r.Account.Student_Code__c;
                    
                    wrapperObj.courseConnectionId = courseConnections.Id;
                    
                    wapperList.add(wrapperObj);
                }
                List<String> pickListValuesList= new List<String>();
                Schema.DescribeFieldResult fieldResult = hed__Attendance_Event__c.hed__Reason__c.getDescribe();
                List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
                for( Schema.PicklistEntry pickListVal : ple){
                    pickListValuesList.add(pickListVal.getLabel());
                }
                reasonDataWrapper resnWrapObj = new reasonDataWrapper();
                resnWrapObj.reasonDropdownValues = pickListValuesList;
                resnWrapObj.studentsList = wapperList;
                jsonResponse = Json.serialize(resnWrapObj);
                if(jsonResponse!=null){    
                    res.responseBody=Blob.valueOf('{ "success": "true" ,"data":'+jsonResponse+'}'); 
                }
                else
                {
                    res.responseBody=Blob.valueOf('[]'); 
                }
            }else{
                res.responseBody =  Blob.valueOf('{"success": "false" ,"message" : "Invalid Parameters"}');
            }
            
        }catch(Exception e){
            res.responseBody = Blob.valueOf('The following error has been Occured '+e.getMessage()+' at line number'+e.getLineNumber());
        }
        
    }
    global class reasonDataWrapper{
        public List<string> reasonDropdownValues;
        public List<responseDataWrapper> studentsList;
    }
    global class responseDataWrapper{
        public string courseOfferingId;
        public string contactId;
        public string contactName;
        public string contactEmail;
        public string contactRegNumber;
                public string studentCode;

        public string courseConnectionId;
    }
        
}