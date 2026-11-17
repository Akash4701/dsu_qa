@RestResource(urlMapping = '/courseConnectionsPerStudent/*')
global class RestApi_CourseConnPerCourseOffAndContact {
    
    @HttpGet
    global static void doGet(){
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');
        string contactId = RestContext.request.params.get('contactId'); 
        string courseOfferingId = RestContext.request.params.get('courseOfferingId');
        list<AttendanceWrapper> addDataAttendacne = new list <AttendanceWrapper>();
        AttendanceWrapper AffliaObj;
        try{
            Contact[] con = [Select id,Name from contact where Id=:contactId and recordtype.Name='Faculty'];
            System.debug('Message or variable: +++++++++++++++++++++++++++++++++++++++' +contactId);
            //Contact[] conlist =[Select id,Name,Status__c From Contact where Status__c='AT Risk'];
            
            if(!con.isEmpty()){
                List<hed__Course_Enrollment__c> allCourseConnList=new List<hed__Course_Enrollment__c>();
                List<hed__Course_Enrollment__c> courseConnList = [SELECT hed__Account__c, hed__Affiliation__c,hed__Affiliation__r.hed__Status__c, hed__Contact__c,hed__Contact__r.Name, hed__Course_Offering__c,hed__Course_Offering__r.hed__End_Date__c,hed__Course_Offering__r.hed__Start_Date__c,hed__Course_Offering__r.hed__Section_ID__c,hed__Course_Offering__r.hed__Term__c,hed__Course_Offering__r.hed__Term__r.Name, hed__Course_Offering__r.Course_Version__c,hed__Course_Offering__r.Name,hed__Credits_Attempted__c, hed__Credits_Earned__c, hed__Grade__c, hed__Primary__c, hed__Program_Enrollment__c, hed__Status__c, hed__Credentialing_Identifier__c, hed__Display_Grade__c, hed__Verification_Status_Date__c,hed__Verification_Status__c, Percentage_of_classes_attended__c, No_Of_Classes_Attended__c, Id, Name FROM hed__Course_Enrollment__c where hed__Contact__c=:contactId];
                Map<Id,Id> mapOfCourseOffAndCourseConn = new Map<Id,Id>();
                Map<String,List<Students>> mapOfWrap = new Map<String,List<Students>>();
                List<String> couOffList = new List<String>();
                Integer count;
                String couOffName;
                jsonWrapper wrapObj = new jsonWrapper();
                for(hed__Course_Enrollment__c courseConnObj:courseConnList){
                    mapOfCourseOffAndCourseConn.put(courseConnObj.hed__Course_Offering__c,courseConnObj.Id);
                }
                if(!mapOfCourseOffAndCourseConn.keyset().isEmpty())
                {
                    allCourseConnList = [SELECT hed__Account__c,Attendacne__c,Course_Name__c,Programe_Name__c, hed__Affiliation__c,hed__Contact__r.Status__c,hed__Affiliation__r.hed__Status__c,hed__Contact__r.Registration_Number__c, hed__Contact__c,hed__Contact__r.Name, hed__Course_Offering__c,hed__Course_Offering__r.hed__End_Date__c,hed__Course_Offering__r.hed__Start_Date__c,hed__Course_Offering__r.hed__Section_ID__c,hed__Course_Offering__r.hed__Term__c,hed__Course_Offering__r.hed__Term__r.Name, hed__Course_Offering__r.Course_Version__c,hed__Course_Offering__r.Name,hed__Credits_Attempted__c, hed__Credits_Earned__c, hed__Grade__c, hed__Primary__c, hed__Program_Enrollment__c, hed__Status__c, hed__Credentialing_Identifier__c, hed__Display_Grade__c, hed__Verification_Status_Date__c,hed__Verification_Status__c, Percentage_of_classes_attended__c, No_Of_Classes_Attended__c, Id, Name FROM hed__Course_Enrollment__c WHERE hed__Course_Offering__c IN: mapOfCourseOffAndCourseConn.keyset() and RecordType.Name='Student'];
                }
                
                Set<Id> setOfStudentsIds = new Set<Id>();
                system.debug('The MapKeys'+mapOfCourseOffAndCourseConn);
                for(Id courseOffId:mapOfCourseOffAndCourseConn.keyset()){
                    List<students> stuList = new List<students>();
                    // integer atRiskCount=0;
                    for(hed__Course_Enrollment__c courConObj:allCourseConnList){
                        if(courseOffId==courConObj.hed__Course_Offering__c){
                            students stuWrapObj = new students();
                            couOffName = courConObj.hed__Course_Offering__r.Name;
                            stuWrapObj.StudentName = courConObj.hed__Contact__r.Name;
                            stuWrapObj.StudentRegdNo = courConObj.hed__Contact__r.Registration_Number__c;
                            stuWrapObj.StudentStatus = courConObj.hed__Contact__r.Status__c;
                            stuWrapObj.Attendacne = courConObj.Attendacne__c;
                            stuWrapObj.ProgrameName = courConObj.Programe_Name__c;
                            stuWrapObj.CourseName = courConObj.Course_Name__c;
                            stuWrapObj.ContactID = courConObj.hed__Contact__c;
                            stuWrapObj.Section = courConObj.hed__Course_Offering__r.hed__Section_ID__c;
                            setOfStudentsIds.add(courConObj.hed__Contact__r.Id);
                           
                            //setOfStudentsIds.add(courConObj.hed__Contact__r.Status__c);
                            stuList.add(stuWrapObj);
                        }
                    }
                    integer atRiskCount;
                    list<aggregateresult> cc = [SELECT hed__Contact__c,count(id) atrisk FROM hed__Course_Enrollment__c WHERE hed__Contact__c in (select id from contact where Status__c='AT Risk') group by hed__Contact__c];
                    for(aggregateresult a:cc) atRiskCount = (integer)a.get('atrisk');
                    system.debug(cc);
                    Set<students> totalStudentCount = new Set<students>(stuList);
                    count = totalStudentCount.size();
                    system.debug(couOffName);
                    mapOfWrap.put(couOffName,stuList);
                    system.debug('map '+mapOfWrap);
                    wrapObj.studentCount = setOfStudentsIds.size();
                    wrapObj.RiskCount = atRiskCount;
                    wrapObj.courseOffering = mapOfWrap; 
                    system.debug('The SetData'+totalStudentCount);
                    system.debug('wrapper'+wrapObj);
                }
                system.debug('The Set'+count);
                res.responseBody = Blob.valueOf('{"success" : "true" , "data" : '+Json.serialize(wrapObj)+'}');
            }else{
                res.statusCode = 400;
                res.responseBody = Blob.valueOf('{"success" : "false" , "message" : "No Data Found"}');
            }
        }catch(Exception e){
            res.statusCode = 400;
            res.responseBody = Blob.valueOf('{"success" : "false" , "message" : "'+e.getMessage()+'"}');
        }
    }
    
    global class jsonWrapper{ 
        public Map<String,List<Students>> courseOffering;
        public Integer studentCount;
          public Integer RiskCount;
    }
    global class students{
        public string StudentName;
        public String StudentRegdNo;
        public String StudentStatus;
        Public decimal Attendacne;
        public String ProgrameName;
        public String CourseName;
        public String Section;
        public String ContactID;
    }
    global class AttendanceWrapper
    {        
        global hed__Attendance_Event__c add;
        global AttendanceWrapper(hed__Attendance_Event__c add){           
            this.add=add;
        }
    }
}