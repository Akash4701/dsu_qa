@RestResource(urlMapping='/courseVersionsByFacility/*')
global class RestApi_courseVersionsByFacilty {
    ///services/apexrest/courseVersionsByFacility/?facilityId=a0F1y000001wjrdEAA
    @HttpGet
    global static void getAttendance(){ 
        String facilityId =  RestContext.request.params.get('facilityId'); 
        RestResponse res = RestContext.response;
        system.debug('facilityId===>'+facilityId);
        res.addHeader('Content-Type','application/json');
        
        try{
            String Query='SELECT Course_Version_Capacity__c, Course_Version_Credits__c, Facilities__c,Facilities__r.Name,Course_Version_Id__c, Course__c,Course__r.Name, End_Date__c, Program_Plan__c, Start_Date__c, Term__c,Term__r.Name, Campus__c, Course_Credits__c, Exam_Required__c, Faculties__c, Offset__c, StartDate__c, Subject_Offset__c, Subject_Start_Date__c, Subject_End_Date__c, WeekNo__c, Id, Name FROM Course_Version__c';
            if(!String.isBlank(facilityId)){
                Query+=' where  Facilities__c=\''+facilityId+'\'' ;
                List<WrapperClass> courseVersionList = new List<WrapperClass>();
                for(Course_Version__c facility:Database.query(Query)){
                    WrapperClass wrapper = new WrapperClass();
                    wrapper.courseId = facility.Course__c;
                    wrapper.termId = facility.Term__c;
                    wrapper.courseName = facility.Course__r.Name;
                    wrapper.termName = facility.Term__r.Name;
                    wrapper.startDate = string.valueof(facility.Start_Date__c);
                    wrapper.EndDate = string.valueof(facility.Subject_End_Date__c);
                    wrapper.weekNumber = string.valueof(facility.WeekNo__c);
                    wrapper.subjectOffset = string.valueof(facility.Subject_Offset__c);
                    wrapper.facilityName = facility.Facilities__r.Name;
                    List<String> allFacultyNameswithIds = new List<String>();
                    if(String.isNotBlank(facility.Faculties__c) && facility.Faculties__c!=null){
                        allFacultyNameswithIds = facility.Faculties__c.split(',');
                    }
                    String onlyFacultyNames=null;
                    if(!allFacultyNameswithIds.isEmpty()){
                        for(String str:allFacultyNameswithIds){
                            system.debug(str.split('-'));
                            if(onlyFacultyNames!=null){
                                onlyFacultyNames += ', '+str.split('-').get(0);
                            }else{
                                onlyFacultyNames = str.split('-').get(0);
                            }
                        }
                    }
                    wrapper.facultyName = onlyFacultyNames;
                    courseVersionList.add(wrapper);
                }
                
                if(!courseVersionList.isEmpty()){
                    res.statusCode = 200;
                    res.responseBody = Blob.valueOf(Json.serialize(courseVersionList));
                }else{
                    res.statusCode = 200;
                    res.responseBody = Blob.valueOf('{"success":"true","message":"no data found..."}'); 
                }
            }else{
                res.statusCode = 200;
                res.responseBody = Blob.valueOf('{"success":"false","message":"enter facility Id.."}');  
            }
        }Catch(Exception e){
            res.statusCode = 400;
            res.responseBody = Blob.valueOf( '{ "success": "false" , "message": "bad request", "errors": "'+e.getMessage()+'at Line Number'+e.getLineNumber()+'" }' );
        }
    }
    global class WrapperClass{
        public string courseId;
        public string termId;
        public string courseName;
        public string termName;
        public string startDate;
        public string EndDate;
        public string weekNumber;
        public string subjectOffset;
        public string facultyName;
        public string facilityName;
    }
}