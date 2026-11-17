@RestResource(urlMapping='/courseConnectionsPerStudents/*')
global with sharing class RestApi_CoursesForFacultyAndRelatedStud {
  @HttpGet
  global static void doGet() {
    RestResponse res = RestContext.response;
    if (res != null) {
      res.addHeader('Content-Type', 'application/json');
    }
    string contactId;
    contactId = RestContext.request.params.get('contactId');

    try {
      system.debug('contactId: ' + contactId);
      list<Contact> con = [
        SELECT id, Name
        FROM contact
        WHERE Id = :contactId AND recordtype.Name = 'Faculty'
      ];
      system.debug('con: ' + con);
        
        System.debug('hed__Contact__c '+[SELECT hed__Contact__c FROM hed__Program_Enrollment__c LIMIT 1].hed__Contact__c + '    ' + contactId);
        System.debug('hed__Affiliation__r.hed__Status__c '+[SELECT hed__Affiliation__r.hed__Status__c FROM hed__Program_Enrollment__c LIMIT 1].hed__Affiliation__r.hed__Status__c);
      list<hed__Program_Enrollment__c> programEnrolmentList = [
        SELECT
          id,
          hed__Contact__c,
          Term__c,
          Term__r.Name,
          Name,
          hed__Affiliation__r.hed__Status__c
        FROM hed__Program_Enrollment__c
        WHERE
          hed__Contact__c = :contactId
          AND hed__Affiliation__r.hed__Status__c = 'Current'
      ];
      system.debug('programEnrolmentList: ' + programEnrolmentList);
        
        System.debug([SELECT hed__Contact__c FROM hed__Course_Enrollment__c LIMIT 1].hed__Contact__c + '  ' + contactId);
        System.debug([SELECT hed__Program_Enrollment__c FROM hed__Course_Enrollment__c LIMIT 1].hed__Program_Enrollment__c + '  ' + programEnrolmentList);
        System.debug([SELECT hed__Program_Enrollment__r.Term__r.Term_Status__c FROM hed__Course_Enrollment__c LIMIT 1].hed__Program_Enrollment__r.Term__r.Term_Status__c + ' Upcoming or ongoing ');
      List<hed__Course_Enrollment__c> courseEnrolments = [
        SELECT
          Id,
          hed__Account__c,
          ST__c,
          hed__Affiliation__c,
          hed__Contact__c,
          hed__Contact__r.Name,
          hed__Course_Offering__c,
          hed__Course_Offering__r.Name,
          Programe_Name__c,
          Course_Name__c,
          hed__Credits_Attempted__c,
          hed__Credits_Earned__c,
          hed__Grade__c,
          hed__Program_Enrollment__c,
          hed__Status__c,
          No_Of_Classes_Attended__c,
          Percentage_of_classes_attended__c,
          hed__Course_Offering__r.hed__Course__c,
          hed__Course_Offering__r.hed__Term__r.Name,
          hed__Course_Offering__r.hed__Course__r.hed__Course_ID__c,
          hed__Course_Offering__r.hed__Course__r.Name,
          hed__Course_Offering__r.hed__Course__r.Credits__c,
          hed__Course_Offering__r.hed__Section_ID__c
        FROM hed__Course_Enrollment__c
        WHERE
          hed__Contact__c = :contactId AND (hed__Program_Enrollment__r.Term__r.Term_Status__c = 'Upcoming' OR hed__Program_Enrollment__r.Term__r.Term_Status__c = 'Ongoing')
          AND hed__Program_Enrollment__c = :programEnrolmentList
      ];
      system.debug('courseEnrolments: ' + courseEnrolments);
      List<String> couEnrollList = new List<String>();
      Set<Id> courseOfferingIdsOfFaculty = new Set<Id>();
      Map<String, List<students>> mapOfCourseOfferingAndStudents = new Map<String, List<students>>();
      for (hed__Course_Enrollment__c courseEnrollObj : courseEnrolments) {
        system.debug(
          'Course Enrollment Contact Name: ' +
          courseEnrollObj.hed__Contact__r.Name
        );
        /*List<students> stuList = new List<students>();
        students stuObj = new students();
        stuObj.ProgrameName = courseEnrollObj.Programe_Name__c;
        stuObj.CourseName = courseEnrollObj.Course_Name__c;
        stuList.add(stuObj);*/

        courseOfferingIdsOfFaculty.add(
          courseEnrollObj.hed__Course_Offering__r.Id
        );
        mapOfCourseOfferingAndStudents.put(
          courseEnrollObj.hed__Course_Offering__r.Id +
            '_' +
            courseEnrollObj.hed__Course_Offering__r.Name +
            '_' +
            courseEnrollObj.hed__Course_Offering__r.hed__Term__r.Name +
            '_' +
            courseEnrollObj.Course_Name__c +
            '_' +
            courseEnrollObj.hed__Course_Offering__r.hed__Section_ID__c +
            '_' +
            courseEnrollObj.hed__Course_Offering__r.hed__Course__r.hed__Course_ID__c,
          null
        );
        couEnrollList.add(courseEnrollObj.hed__Contact__r.Name);
      }
      system.debug(
        'Map of Course Offering and Students size: ' +
        mapOfCourseOfferingAndStudents.size()
      );

      Map<String, List<hed__Attendance_Event__c>> mapOfContactAndCouOffWithPresentEvent = new Map<String, List<hed__Attendance_Event__c>>();
      system.debug(
        'Map of Contact and Course with Present Event: ' +
        mapOfContactAndCouOffWithPresentEvent
      );
      Map<String, List<hed__Attendance_Event__c>> mapOfContactAndCouOffWithAbsentEvent = new Map<String, List<hed__Attendance_Event__c>>();
      system.debug(
        'Map of Contact and Course with Absent Event: ' +
        mapOfContactAndCouOffWithAbsentEvent
      );
      List<hed__Attendance_Event__c> listOfreqEvnts = [
        SELECT
          id,
          Name,
          hed__Attendance_Type__c,
          hed__Contact__c,
          hed__Contact__r.Id,
          hed__Date__c,
          hed__Reason_Description__c,
          hed__Reason__c,
          hed__Start_Time__c,
          Attendance_Status__c,
          Session__c,
          Attendance_Marked__c,
          Start_Date_Time__c,
          End_Date_Time__c,
          Session__r.Course_Offering__c
        FROM hed__Attendance_Event__c
        WHERE Session__r.Course_Offering__c IN :courseOfferingIdsOfFaculty
      ];
      system.debug('List of Required Events: ' + listOfreqEvnts);
      for (hed__Attendance_Event__c eventsObj : listOfreqEvnts) {
        if (eventsObj.Attendance_Status__c == 'Present') {
          if (
            !mapOfContactAndCouOffWithPresentEvent.containsKey(
              eventsObj.hed__Contact__r.Id +
                '-' +
                eventsObj.Session__r.Course_Offering__c
            )
          ) {
            mapOfContactAndCouOffWithPresentEvent.put(
              eventsObj.hed__Contact__r.Id +
                '-' +
                eventsObj.Session__r.Course_Offering__c,
              new List<hed__Attendance_Event__c>{}
            );
          }
          mapOfContactAndCouOffWithPresentEvent.get(
              eventsObj.hed__Contact__r.Id +
                '-' +
                eventsObj.Session__r.Course_Offering__c
            )
            .add(eventsObj);
          system.debug('New Present Event Added to List: ' + eventsObj);
        } else if (eventsObj.Attendance_Status__c == 'Absent') {
          if (
            !mapOfContactAndCouOffWithAbsentEvent.containsKey(
              eventsObj.hed__Contact__r.Id +
                '-' +
                eventsObj.Session__r.Course_Offering__c
            )
          ) {
            mapOfContactAndCouOffWithAbsentEvent.put(
              eventsObj.hed__Contact__r.Id +
                '-' +
                eventsObj.Session__r.Course_Offering__c,
              new List<hed__Attendance_Event__c>{}
            );
          }
          mapOfContactAndCouOffWithAbsentEvent.get(
              eventsObj.hed__Contact__r.Id +
                '-' +
                eventsObj.Session__r.Course_Offering__c
            )
            .add(eventsObj);
          system.debug('New Absent Event Added to List: ' + eventsObj);
        }
      }
      Set<Id> setOfStudentsIds = new Set<Id>();
      jsonWrapper wrapObj = new jsonWrapper();
        System.debug([SELECT hed__Course_Offering__c FROM hed__Course_Enrollment__c LIMIT 1].hed__Course_Offering__c + '       courseOfferingIdsOfFaculty  ---+++' + courseOfferingIdsOfFaculty);
        // System.debug([SELECT RecordType.Name FROM hed__Course_Enrollment__c WHERE RecordType.Name = 'Student' LIMIT 1].RecordType.Name + '  ' + 'Student?');
        System.debug('=================================================> recordtype'+[SELECT Id, Name, DeveloperName FROM RecordType WHERE SObjectType = 'hed__Course_Enrollment__c' and DeveloperName ='Student']);

        System.debug([SELECT hed__Course_Offering__r.hed__Term__r.Term_Status__c FROM hed__Course_Enrollment__c LIMIT 1].hed__Course_Offering__r.hed__Term__r.Term_Status__c + '  ' + 'Completed?');
      for (hed__Course_Enrollment__c courseEnrollObj : [
        SELECT
          Id,
          hed__Account__c,
          ST__c,
          hed__Affiliation__c,
          hed__Contact__c,
          hed__Course_Offering__c,
          hed__Contact__r.Registration_Number__c,
          hed__Contact__r.Account.Student_Code__c,          
          hed__Contact__r.Name,
          hed__Contact__r.Status__c,
          Attendacne__c,
          Programe_Name__c,
          Course_Name__c,
          hed__Credits_Attempted__c,
          hed__Credits_Earned__c,
          hed__Grade__c,
          hed__Program_Enrollment__c,
          hed__Course_Offering__r.hed__Term__r.Name,
          hed__Status__c,
          No_Of_Classes_Attended__c,
          Percentage_of_classes_attended__c,
          hed__Course_Offering__r.Name,
          hed__Course_Offering__r.hed__Course__c,
          hed__Course_Offering__r.hed__Course__r.hed__Course_ID__c,
          hed__Course_Offering__r.hed__Course__r.Name,
          hed__Course_Offering__r.hed__Course__r.Credits__c,
          hed__Course_Offering__r.hed__Section_ID__c
        FROM hed__Course_Enrollment__c
        WHERE
          hed__Course_Offering__c IN :courseOfferingIdsOfFaculty
          AND RecordType.Name = 'Student' AND hed__Course_Offering__r.hed__Term__r.Term_Status__c != 'Completed'
      ]) {
        system.debug('Course Enrollment Object: ' + courseEnrollObj);
        students stuWrapObj = new students();

        stuWrapObj.StudentName = courseEnrollObj.hed__Contact__r.Name;
        stuWrapObj.StudentRegdNo = courseEnrollObj.hed__Contact__r.Registration_Number__c;
        stuWrapObj.studentCode = courseEnrollObj.hed__Contact__r.Account.Student_Code__c;
          
        stuWrapObj.StudentStatus = courseEnrollObj.hed__Contact__r.Status__c;
        stuWrapObj.classesPresent = mapOfContactAndCouOffWithPresentEvent.containsKey(
            courseEnrollObj.hed__Contact__r.Id +
              '-' +
              courseEnrollObj.hed__Course_Offering__c
          )
          ? mapOfContactAndCouOffWithPresentEvent.get(
                courseEnrollObj.hed__Contact__r.Id +
                  '-' +
                  courseEnrollObj.hed__Course_Offering__c
              )
              .size()
          : 0;
        stuWrapObj.classesAbsent = mapOfContactAndCouOffWithAbsentEvent.containsKey(
            courseEnrollObj.hed__Contact__r.Id +
              '-' +
              courseEnrollObj.hed__Course_Offering__c
          )
          ? mapOfContactAndCouOffWithAbsentEvent.get(
                courseEnrollObj.hed__Contact__r.Id +
                  '-' +
                  courseEnrollObj.hed__Course_Offering__c
              )
              .size()
          : 0;
        stuWrapObj.Attendacne = calculateAttendancepercentage(
          stuWrapObj.classesPresent,
          stuWrapObj.classesAbsent
        );
        stuWrapObj.ProgrameName = courseEnrollObj.Programe_Name__c;
        stuWrapObj.TermName = courseEnrollObj.hed__Course_Offering__r.hed__Term__r.Name;
        stuWrapObj.CourseName = courseEnrollObj.Course_Name__c;
        stuWrapObj.ContactID = courseEnrollObj.hed__Contact__c;
        stuWrapObj.Section = courseEnrollObj.hed__Course_Offering__r.hed__Section_ID__c;
        setOfStudentsIds.add(courseEnrollObj.hed__Contact__r.Id);
        system.debug('Student Wrapper Object: ' + stuWrapObj);
        if (
          mapOfCourseOfferingAndStudents.ContainsKey(
            courseEnrollObj.hed__Course_Offering__r.Id +
              '_' +
              courseEnrollObj.hed__Course_Offering__r.Name +
              '_' +
              courseEnrollObj.hed__Course_Offering__r.hed__Term__r.Name +
              '_' +
              courseEnrollObj.Course_Name__c +
              '_' +
              courseEnrollObj.hed__Course_Offering__r.hed__Section_ID__c +
              '_' +
              courseEnrollObj.hed__Course_Offering__r.hed__Course__r.hed__Course_ID__c
          ) &&
          mapOfCourseOfferingAndStudents.get(
            courseEnrollObj.hed__Course_Offering__r.Id +
              '_' +
              courseEnrollObj.hed__Course_Offering__r.Name +
              '_' +
              courseEnrollObj.hed__Course_Offering__r.hed__Term__r.Name +
              '_' +
              courseEnrollObj.Course_Name__c +
              '_' +
              courseEnrollObj.hed__Course_Offering__r.hed__Section_ID__c +
              '_' +
              courseEnrollObj.hed__Course_Offering__r.hed__Course__r.hed__Course_ID__c
          ) != null
        ) {
          List<students> listOfStudents = mapOfCourseOfferingAndStudents.get(
            courseEnrollObj.hed__Course_Offering__r.Id +
              '_' +
              courseEnrollObj.hed__Course_Offering__r.Name +
              '_' +
              courseEnrollObj.hed__Course_Offering__r.hed__Term__r.Name +
              '_' +
              courseEnrollObj.Course_Name__c +
              '_' +
              courseEnrollObj.hed__Course_Offering__r.hed__Section_ID__c +
              '_' +
              courseEnrollObj.hed__Course_Offering__r.hed__Course__r.hed__Course_ID__c
          );
          listOfStudents.add(stuWrapObj);
          mapOfCourseOfferingAndStudents.put(
            courseEnrollObj.hed__Course_Offering__r.Id +
              '_' +
              courseEnrollObj.hed__Course_Offering__r.Name +
              '_' +
              courseEnrollObj.hed__Course_Offering__r.hed__Term__r.Name +
              '_' +
              courseEnrollObj.Course_Name__c +
              '_' +
              courseEnrollObj.hed__Course_Offering__r.hed__Section_ID__c +
              '_' +
              courseEnrollObj.hed__Course_Offering__r.hed__Course__r.hed__Course_ID__c,
            listOfStudents
          );
        } else {
          mapOfCourseOfferingAndStudents.put(
            courseEnrollObj.hed__Course_Offering__r.Id +
              '_' +
              courseEnrollObj.hed__Course_Offering__r.Name +
              '_' +
              courseEnrollObj.hed__Course_Offering__r.hed__Term__r.Name +
              '_' +
              courseEnrollObj.Course_Name__c +
              '_' +
              courseEnrollObj.hed__Course_Offering__r.hed__Section_ID__c +
              '_' +
              courseEnrollObj.hed__Course_Offering__r.hed__Course__r.hed__Course_ID__c,
            new List<students>{ stuWrapObj }
          );
        }
      }
      wrapObj.studentCount = setOfStudentsIds.size();
      wrapObj.courseOffering = mapOfCourseOfferingAndStudents;

      if (json.serialize(wrapObj) != null) {
        res.statusCode = 200;
        res.responseBody = Blob.valueOf(
          '{"success" : true , "data" : ' + Json.serialize(wrapObj) + '}'
        );
      } else {
        res.responseBody = Blob.valueOf('[]');
      }
    } catch (Exception e) {
      if (res != null) {
        res.statusCode = 400;
        res.responseBody = Blob.valueOf(
          '{"success" : false , "message" : "' +
            e.getMessage() +
            '----' +
            e.getLineNumber() +
            '"}'
        );
      }
    }
  }

  global class JsonWrapper {
    public Map<String, List<Students>> courseOffering { get; set; }
    public Integer studentCount { get; set; }
  }
    @testvisible
  global class Students {
    public string StudentName { get; set; }
    public String StudentRegdNo { get; set; }
    public String studentCode { get; set; }
    public String StudentStatus { get; set; }
    public decimal Attendacne { get; set; }
    public integer classesPresent { get; set; }
    public integer classesAbsent { get; set; }
    public String ProgrameName { get; set; }
    public String TermName { get; set; }
    public String CourseName { get; set; }
    public String Section { get; set; }
    public Id ContactID { get; set; }
  }

  public static Decimal calculateAttendancepercentage(
    double present,
    double absent
  ) {
    double totalClasses = present + absent;
    double percenatge;
    if (totalClasses != 0) {
      percenatge = (present * 100 / totalClasses);
    }
    return percenatge;
  }
}
/*@RestResource(urlMapping = '/courseConnectionsPerStudents/*')
global with sharing class RestApi_CoursesForFacultyAndRelatedStud {
    @HttpGet
    global static void doGet(){
        RestResponse res = RestContext.response;
        if(res!=null){
            res.addHeader('Content-Type', 'application/json');
        }
        string contactId;
		contactId = RestContext.request.params.get('contactId');

        try{
            system.debug('contactId: ' + contactId);
            list<Contact> con = [Select id,Name from contact where Id=:contactId and recordtype.Name='Faculty'];
            system.debug('con: ' + con);
            list<hed__Program_Enrollment__c> programEnrolmentList = [select id,hed__Contact__c,Term__c,Term__r.Name,
                                                                     Name,hed__Affiliation__r.hed__Status__c from hed__Program_Enrollment__c
                                                                     where hed__Contact__c = :contactId and hed__Affiliation__r.hed__Status__c = 'Current'];
            system.debug('programEnrolmentList: ' + programEnrolmentList);
            List<hed__Course_Enrollment__c> courseEnrolments = [SELECT Id, hed__Contact__c, hed__Contact__r.Name,hed__Course_Offering__c,hed__Course_Offering__r.Name,Programe_Name__c,Course_Name__c,
                                                                hed__Program_Enrollment__c,
                                                                hed__Course_Offering__r.hed__Course__c,hed__Course_Offering__r.hed__Term__r.Name,
                                                                hed__Course_Offering__r.hed__Course__r.hed__Course_ID__c,hed__Course_Offering__r.hed__Course__r.Name,
                                                                hed__Course_Offering__r.hed__Course__r.Credits__c,hed__Course_Offering__r.hed__Section_ID__c
                                                                FROM hed__Course_Enrollment__c where hed__Contact__c =:contactId AND hed__Program_Enrollment__c=:programEnrolmentList];

            List<String> couEnrollList = new List<String>();
            Set<Id> courseOfferingIdsOfFaculty = new Set<Id>();

            Map<String,List<students>> mapOfCourseOfferingAndStudents = new Map<String,List<students>>();
            for(hed__Course_Enrollment__c courseEnrollObj:courseEnrolments){
                courseOfferingIdsOfFaculty.add(courseEnrollObj.hed__Course_Offering__r.Id);
                mapOfCourseOfferingAndStudents.put(courseEnrollObj.hed__Course_Offering__r.Id+'_'+courseEnrollObj.hed__Course_Offering__r.Name+'_'+courseEnrollObj.hed__Course_Offering__r.hed__Term__r.Name+'_'+courseEnrollObj.Course_Name__c+'_'+courseEnrollObj.hed__Course_Offering__r.hed__Section_ID__c+'_'+courseEnrollObj.hed__Course_Offering__r.hed__Course__r.hed__Course_ID__c,null);
                couEnrollList.add(courseEnrollObj.hed__Contact__r.Name);
            }
            
            Set<Id> setOfStudentsIds = new Set<Id>();
            jsonWrapper wrapObj = new jsonWrapper();
            //for(hed__Course_Offering__c courseOfferingObj:[Select Id,Name,hed__Term__c,hed__Term__r.Name,hed__Course__c,hed__Course__r.Name,hed__Section_ID__c,(Select Id from hed__Course_Enrollment__r where RecordType.Name='Student') from hed__Course_Offering__c where Id IN:courseOfferingIdsOfFaculty]){
                
            //}
            for(hed__Course_Enrollment__c courseEnrollObj:[SELECT Id, hed__Contact__c, hed__Course_Offering__c,
                                                           hed__Contact__r.Registration_Number__c,hed__Contact__r.Name,hed__Contact__r.Status__c,Attendacne__c,Programe_Name__c,Course_Name__c,
                                                           hed__Course_Offering__r.hed__Term__r.Name,
                                                           hed__Course_Offering__r.Name,hed__Course_Offering__r.hed__Course__c,
                                                           hed__Course_Offering__r.hed__Course__r.hed__Course_ID__c,hed__Course_Offering__r.hed__Course__r.Name,
                                                           hed__Course_Offering__r.hed__Course__r.Credits__c,hed__Course_Offering__r.hed__Section_ID__c
                                                           FROM hed__Course_Enrollment__c where hed__Course_Offering__c IN: courseOfferingIdsOfFaculty and RecordType.Name='Student'])
            
            {
                setOfStudentsIds.add(courseEnrollObj.hed__Contact__r.Id);
                //mapOfCourseOfferingAndStudents.put(courseEnrollObj.hed__Course_Offering__r.Id+'_'+courseEnrollObj.hed__Course_Offering__r.Name+'_'+courseEnrollObj.hed__Course_Offering__r.hed__Term__r.Name+'_'+courseEnrollObj.Course_Name__c+'_'+courseEnrollObj.hed__Course_Offering__r.hed__Section_ID__c,null);
                
            }
            wrapObj.studentCount = setOfStudentsIds.size();
            wrapObj.courseOffering = mapOfCourseOfferingAndStudents;
            
            if(json.serialize(wrapObj) != null){
                res.statusCode = 200;
                res.responseBody = Blob.valueOf('{"success" : true , "data" : '+Json.serialize(wrapObj)+'}');
            }else{
                res.responseBody = Blob.valueOf('[]');
            }
            
            
        }catch(Exception e){
            if(res!=null){
                res.statusCode = 400;
                res.responseBody = Blob.valueOf('{"success" : false , "message" : "'+e.getMessage()+'----'+e.getLineNumber()+'"}');
            }
        }
    }
    
    
    global class jsonWrapper{ 
        public Map<String,List<students>> courseOffering{get;set;}
        public Integer studentCount{get;set;}
    }
    global class students{
        public string StudentName{get;set;}
        public String StudentRegdNo{get;set;}
        public String StudentStatus{get;set;}
        Public decimal Attendacne{get;set;}
        public integer classesPresent{get;set;}
        public integer classesAbsent{get;set;}
        public String ProgrameName{get;set;}
        public String TermName{get;set;}
        public String CourseName{get;set;}
        public String Section{get;set;}
        public Id ContactID{get;set;}
    }
    
    public static Decimal calculateAttendancepercentage(double present,double absent){
        double totalClasses = present+absent;
        double percenatge;
        if(totalClasses !=0)
            percenatge = (present *100/ totalClasses);
        
        return percenatge;
    }
}*/