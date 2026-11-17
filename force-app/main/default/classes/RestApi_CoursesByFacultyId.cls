@RestResource(urlMapping = '/GetAllCoursesByFacultyId/*')
global with sharing class RestApi_CoursesByFacultyId {
    @HttpGet
    global static void doGet(){
        string facultyId = RestContext.request.params.get('facultyId');
        string termId = RestContext.request.params.get('termId');
        string courseId = RestContext.request.params.get('courseId');
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json'); 
        Set<Id> accountIds=new Set<Id>();
        Map<Id,Id> accPersonAccMap=new Map<Id,Id>(); 
        System.debug('faculty'+facultyId);
        System.debug('termId'+termId);
        System.debug('courseId'+courseId);
        
        try{
            if(String.isBlank(facultyId) && String.isBlank(termId) && String.isBlank(courseId)){
                addError(400,'invalid parameters');
                return;
            }
            
            
            string typeofData;
            string test;
            boolean onlyCourses = false;
            Id campusId;
            
            if(String.isNotBlank(termId)){
                hed__Term__c[] reqTerm = [Select Id,Campus__c from hed__Term__c where Id=:termId];
                System.debug('Hello'+reqTerm);
                if(reqTerm.isEmpty()){
                    addError(400,'invalid termId or no valid record found with that id');
                    return;
                }
                campusId=reqTerm[0].Campus__c;
                //query+=' and hed__Course_Offering__r.hed__Term__c=\''+termId+'\'';
            }
            
            //String query='SELECT Id,Name,Course__c,Course__r.Name,Campus__c,Faculties__c,(Select Id,Name,hed__Section_ID__c from Course_Offerings__r) from Course_Version__c where Term__c=\''+termId+'\'';
            //string query = 'SELECT Id, hed__Account__c,hed__Program_Enrollment__c,hed__Course_Offering__r.Course_Version__c, hed__Contact__c,hed__Contact__r.Name,hed__Course_Offering__c,hed__Course_Offering__r.hed__Section_ID__c, hed__Course_Offering__r.hed__Course__c,hed__Course_Offering__r.hed__Course__r.Name,hed__Course_Offering__r.hed__Term__c FROM hed__Course_Enrollment__c where RecordType.Name=\'Faculty\' AND hed__Course_Offering__r.hed__Term__c=\''+termId+'\'';
            string query = 'SELECT Id,(SELECT Id,Is_Active__c,hed__Program_Enrollment__c, Name,hed__Contact__c,hed__Contact__r.Name FROM hed__Course_Enrollment__r WHERE Is_Active__c= true AND  RecordType.Name=\'Faculty\'), Course_Version__c ,hed__Section_ID__c,Name, hed__Course__c,hed__Course__r.Name,hed__Term__c FROM hed__Course_Offering__c where hed__Term__c=\''+termId+'\'';
            if(!string.isEmpty(facultyId)){
               List<Account> accList = [SELECT Id, Name, PersonContactId 
                         FROM Account 
                         WHERE (Id = :facultyId OR PersonContactId = :facultyId)
                         AND RecordType.Name = 'Faculty'];
                
            
               /* if (accList.isEmpty()) {
                    addError(400, 'Invalid contactId or contact was not a faculty');
                    return;
                }*/
            }
            
            if(String.isNotBlank(courseId)){
                hed__Course__c[] reqCourse = [Select Id from hed__Course__c where Id=:courseId];
                if(reqCourse.isEmpty()){
                    addError(400,'invalid id or no valid record found with that id');
                    return;
                }
                typeofData = 'faculty data';
                query+=' and hed__Course__c=\''+courseId+'\'';
            }
            query += ' ORDER BY hed__Course__r.Name ASC';
            List<Course_Version__c> courseVersionList;
            if(String.isNotBlank(termId) && String.isBlank(facultyId) && String.isBlank(courseId)){
                Map<Id,hed__Plan_Requirement__c> mapOfplanReqAndCourse = new Map<Id,hed__Plan_Requirement__c>();//[Select Id,hed__Course__c,hed__Course__r.Name,hed__Category__c from hed__Plan_Requirement__c where Term__c=:termId];
                for(hed__Plan_Requirement__c planObj:[Select Id,hed__Course__c,hed__Course__r.Name,hed__Category__c from hed__Plan_Requirement__c where Term__c=:termId]){
                    mapOfplanReqAndCourse.put(planObj.hed__Course__c, planObj);
                }
                courseVersionList = [Select Id,Course__c,Course__r.Name,Term__c,Faculties__c,(Select id,Name,hed__Section_ID__c from Course_Offerings__r) from Course_Version__c where Course__c=:mapOfplanReqAndCourse.keySet() and Term__c=:termId];
                //test ='Select Id,hed__Course__c,hed__Course__r.Name,hed__Category__c from hed__Plan_Requirement__c where Term__c=:termId';
            }
            //system.debug(String.escapeSingleQuotes(test));
            system.debug(query);
            responseWrapper resWrapObj = new responseWrapper();
            
            List<courseWrapper> couWrapList = new List<courseWrapper>();
            for(hed__Course_Offering__c cvObj:DataBase.query(query)){
                courseWrapper couWrapObj = new courseWrapper();
                couWrapObj.courseId = cvObj.hed__Course__c;
                couWrapObj.courseName = cvObj.hed__Course__r.Name;
                couWrapObj.courseVersionId = cvObj.Course_Version__c;
                couWrapObj.courseOfferingId = cvObj.Id;
                couWrapObj.section = cvObj.hed__Section_ID__c;
                List<courseOfferingWrapper> couOffList = new List<courseOfferingWrapper>();
                for(hed__Course_Enrollment__c couOffObj:cvObj.hed__Course_Enrollment__r){
                    courseOfferingWrapper couOffWrapObj = new courseOfferingWrapper();
                     couOffWrapObj.facultyData=couOffObj.hed__Contact__c+'-'+couOffObj.hed__Contact__r.Name;

                    couOffList.add(couOffWrapObj);
                }
                couWrapObj.courseOfferings = couOffList;
                couWrapList.add(couWrapObj);
            }
            resWrapObj.coursesAndFaculities=couWrapList;
            List<FacilityWrapper> facilityList = new List<FacilityWrapper>();
            for(hed__Facility__c facilityObj:[Select Id,Name,Campus__c from hed__Facility__c where Campus__c =:campusId ORDER BY Name ASC]){
                FacilityWrapper facWrapObj = new FacilityWrapper();
                facWrapObj.facilityId = facilityObj.Id;
                facWrapObj.facilityName = facilityObj.Name;
                facilityList.add(facWrapObj);
            }
            resWrapObj.facilities=facilityList;
            if(resWrapObj!=null){
                res.statusCode = 200;
                res.responseBody = Blob.valueOf('{"success": true,"typeofData":"'+typeofData+'","data":'+json.serialize(resWrapObj)+'}');
            }else{
                addError(200,'No enrollment');
                return;
            }
        }catch(exception e){
            addError(400,e.getMessage()+' at line number '+e.getLineNumber());
            return;
        }
    }
    
    global class responseWrapper{
        public List<FacilityWrapper> facilities;
        public List<CourseWrapper> coursesAndFaculities;
    }
    global class FacilityWrapper{
        public Id facilityId;
        public String facilityName;
    }
    global class CourseWrapper{
        public string contactId;
        public string contactName; 
        public string courseName;
        public Id courseId;
        public Id courseVersionId;
        public String facultyData;
        public List<courseOfferingWrapper> courseOfferings;
        public string courseOfferingId;
        public string section;
    }
    global class CourseOfferingWrapper{
        public String facultyData;
    }
    private static void addError(Integer statusCode, String errorMessage) {
        errorResponseWrapper result = new errorResponseWrapper();
        result.success = false;
        result.errorMessage = errorMessage;
        
        RestContext.response.statusCode = statusCode;
        RestContext.response.headers.put('content-type', 'text/plain');
        RestContext.response.responseBody = Blob.valueOf(JSON.serialize(result));
    }
    
    public class errorResponseWrapper{
        public Boolean success;
        public string errorMessage;
    }  
}