@isTest
public class RestApi_AttendanceEvntsPerSessionTest {
    
    @testSetup
    static void dataSetup() {
        LMS_URL__c URL = new LMS_URL__c(Name = 'course url',Bulk_Enroll__c = 'TestUrl');
        insert URL;
        LMS_URL__c URL1 = new LMS_URL__c(Name = 'course offering url',Bulk_Enroll__c = 'TestUrl');
        insert URL1;
        LMS_URL__c URL2 = new LMS_URL__c(Name = 'Bulk Enrollment',Bulk_Enroll__c = 'TestUrl');
        insert URL2;
        Account testAccount = new Account(Name = 'Test Account', LMS_Id__c = '12345');
        insert testAccount;
        Account acc = new Account();
        acc.name = 'TestingClass';
        insert acc;
        
        contact con = new contact();
        con.lastname = 'contact';
        con.AccountId = acc.id;
        con.Email = 'testing@ken42.com';
        insert con;
        
    }
    
    @isTest
    public static void testMethodAttendencebySession1(){
        
          Account acc =  [Select id, Name From Account limit 1];
        Contact con = [Select id, LastName from Contact];
        
                hed__Course__c cou = new hed__Course__c();
        cou.name = 'courseName';
        cou.hed__Account__c = acc.id;
        insert cou;
        
        hed__Term__c t = new hed__Term__c();
        t.name= 'term';
        t.hed__Account__c = acc.id;
        t.Term_Reference__c ='test';
        insert t;
        
        hed__facility__c facility = new hed__facility__c();
        facility.Name ='test';
        insert facility;
        
        hed__Course_Offering__c couoff = new hed__Course_Offering__c();
        couoff.hed__Term__c = t.Id;
        couoff.Name = 'courseoffering';
        couoff.hed__Course__c = cou.id;
        couoff.hed__Section_ID__c = 'test';
        couoff.hed__Facility__c = facility.id;        
        insert couoff;
        
        hed__Course_Enrollment__c couen = new hed__Course_Enrollment__c();
        couen.hed__Account__c = acc.id;
        couen.hed__Contact__c = con.id;
        couen.hed__Course_Offering__c = couoff.id;
        insert couen;
        
        Session__c se = new Session__c();
        se.Contact__c = con.id;
        se.Course_Offering__c = couoff.id;
        se.Type_of_Activity__c = 'Lab';
          se.Start_Date_Time__c = DateTime.newInstance(2024, 7, 15, 12, 0, 0);
            se.End_Date_Time__c =  DateTime.newInstance(2024, 8, 15, 12, 0, 0);
        se.Faculty__c=con.id;
        se.Facility__c = facility.id;
        se.Mode_of_Delivery__c = 'Online'; 
        
        insert se;
        
        hed__Attendance_Event__c att = new hed__Attendance_Event__c();
        att.hed__Contact__c = con.Id;
        att.hed__Course_Connection__c = couen.id;
        att.hed__Date__c = Date.newInstance(2022, 07, 01);
        att.Attendance_Status__c = 'Absent';
        att.Session__c = se.Id;
        insert att;
        
        hed__Attendance_Event__c atte = new hed__Attendance_Event__c();
        atte.hed__Contact__c = con.Id;
        atte.hed__Course_Connection__c = couen.id;
        atte.hed__Date__c = Date.newInstance(2022, 07, 01);
        atte.Attendance_Status__c = 'Present';
        atte.Session__c = se.Id;
        insert atte;

        List<hed__Attendance_Event__c> attEvntList = [SELECT Id,Name,Attendance_Status__c,hed__Contact__c,hed__Contact__r.Name,hed__Course_Connection__c,hed__Course_Name__c,Course_Offering__c,hed__Date__c,Session__c from hed__Attendance_Event__c];
        system.debug('The attendanceList'+attEvntList);
        RestRequest req = new RestRequest(); 
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/attendancePerSession/?';
        Test.setMock(HttpCalloutMock.class, new MockEnrollmentRespBBClass());
        
        req.addParameter('sessionId',attEvntList[0].Session__c);                
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = res;
        Test.startTest();
        RestApi_AttendanceEvntsPerSession.getAttendance();
        Test.stopTest();
        system.assert(res.statusCode==200);
    }
    
    @isTest
    public static void testMethodAttendencebySession2(){
          Account acc =  [Select id, Name From Account limit 1];
        Contact con = [Select id, LastName from Contact];
        
                hed__Course__c cou = new hed__Course__c();
        cou.name = 'courseName';
        cou.hed__Account__c = acc.id;
        insert cou;
        
        hed__Term__c t = new hed__Term__c();
        t.name= 'term';
        t.hed__Account__c = acc.id;
        t.Term_Reference__c ='test';
        insert t;
        
        hed__facility__c facility = new hed__facility__c();
        facility.Name ='test';
        insert facility;
        
        hed__Course_Offering__c couoff = new hed__Course_Offering__c();
        couoff.hed__Term__c = t.Id;
        couoff.Name = 'courseoffering';
        couoff.hed__Course__c = cou.id;
        couoff.hed__Section_ID__c = 'test';
        couoff.hed__Facility__c = facility.id;        
        insert couoff;
        
        hed__Course_Enrollment__c couen = new hed__Course_Enrollment__c();
        couen.hed__Account__c = acc.id;
        couen.hed__Contact__c = con.id;
        couen.hed__Course_Offering__c = couoff.id;
        insert couen;
        
        Session__c se = new Session__c();
        se.Contact__c = con.id;
        se.Course_Offering__c = couoff.id;
        se.Type_of_Activity__c = 'Lab';
          se.Start_Date_Time__c = DateTime.newInstance(2024, 7, 15, 12, 0, 0);
            se.End_Date_Time__c =  DateTime.newInstance(2024, 8, 15, 12, 0, 0);
        se.Faculty__c=con.id;
        se.Facility__c = facility.id;
        se.Mode_of_Delivery__c = 'Online'; 
        
        insert se;
        
        hed__Attendance_Event__c att = new hed__Attendance_Event__c();
        att.hed__Contact__c = con.Id;
        att.hed__Course_Connection__c = couen.id;
        att.hed__Date__c = Date.newInstance(2022, 07, 01);
        att.Attendance_Status__c = 'Absent';
        att.Session__c = se.Id;
        insert att;
        
        hed__Attendance_Event__c atte = new hed__Attendance_Event__c();
        atte.hed__Contact__c = con.Id;
        atte.hed__Course_Connection__c = couen.id;
        atte.hed__Date__c = Date.newInstance(2022, 07, 01);
        atte.Attendance_Status__c = 'Present';
        atte.Session__c = se.Id;
        insert atte;

        
        List<hed__Attendance_Event__c> attEvntList = [SELECT Id,Name,Attendance_Status__c,hed__Contact__c,hed__Contact__r.Name,hed__Course_Connection__c,hed__Course_Name__c,Course_Offering__c,hed__Date__c,Session__c from hed__Attendance_Event__c];
        system.debug('The attendanceList'+attEvntList);
        RestRequest req = new RestRequest(); 
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/attendancePerSession/?';
           Test.setMock(HttpCalloutMock.class, new MockEnrollmentRespBBClass());
     
        req.addParameter('sesscionId',attEvntList[0].Session__c);                
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = res;
        Test.startTest();
        RestApi_AttendanceEvntsPerSession.getAttendance();
        Test.stopTest();
        system.assert(res.statusCode==400);
    }
    
    @isTest
    public static void testMethodAttendencebySession3(){
          Account acc =  [Select id, Name From Account limit 1];
        Contact con = [Select id, LastName from Contact];
        
                hed__Course__c cou = new hed__Course__c();
        cou.name = 'courseName';
        cou.hed__Account__c = acc.id;
        insert cou;
        
        hed__Term__c t = new hed__Term__c();
        t.name= 'term';
        t.hed__Account__c = acc.id;
        t.Term_Reference__c ='test';
        insert t;
        
        hed__facility__c facility = new hed__facility__c();
        facility.Name ='test';
        insert facility;
        
        hed__Course_Offering__c couoff = new hed__Course_Offering__c();
        couoff.hed__Term__c = t.Id;
        couoff.Name = 'courseoffering';
        couoff.hed__Course__c = cou.id;
        couoff.hed__Section_ID__c = 'test';
        couoff.hed__Facility__c = facility.id;        
        insert couoff;
        
        hed__Course_Enrollment__c couen = new hed__Course_Enrollment__c();
        couen.hed__Account__c = acc.id;
        couen.hed__Contact__c = con.id;
        couen.hed__Course_Offering__c = couoff.id;
        insert couen;
        
        Session__c se = new Session__c();
        se.Contact__c = con.id;
        se.Course_Offering__c = couoff.id;
        se.Type_of_Activity__c = 'Lab';
          se.Start_Date_Time__c = DateTime.newInstance(2024, 7, 15, 12, 0, 0);
            se.End_Date_Time__c =  DateTime.newInstance(2024, 8, 15, 12, 0, 0);
        se.Faculty__c=con.id;
        se.Facility__c = facility.id;
        se.Mode_of_Delivery__c = 'Online'; 
        
        insert se;
        
        hed__Attendance_Event__c att = new hed__Attendance_Event__c();
        att.hed__Contact__c = con.Id;
        att.hed__Course_Connection__c = couen.id;
        att.hed__Date__c = Date.newInstance(2022, 07, 01);
        att.Attendance_Status__c = 'Absent';
        att.Session__c = se.Id;
        insert att;
        
        hed__Attendance_Event__c atte = new hed__Attendance_Event__c();
        atte.hed__Contact__c = con.Id;
        atte.hed__Course_Connection__c = couen.id;
        atte.hed__Date__c = Date.newInstance(2022, 07, 01);
        atte.Attendance_Status__c = 'Present';
        atte.Session__c = se.Id;
        insert atte;

        List<hed__Attendance_Event__c> attEvntList = [SELECT Id,Name,Attendance_Status__c,hed__Contact__c,hed__Contact__r.Name,hed__Course_Connection__c,hed__Course_Name__c,Course_Offering__c,hed__Date__c,Session__c from hed__Attendance_Event__c];
        system.debug('The attendanceList'+attEvntList);
        RestRequest req = new RestRequest(); 
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/attendancePerSession/?';
         Test.setMock(HttpCalloutMock.class, new MockEnrollmentRespBBClass());
       
        req.addParameter('sessionId', '12345');                
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = res;
        Test.startTest();
        RestApi_AttendanceEvntsPerSession.getAttendance();
        Test.stopTest();
        system.assert(res.statusCode==400);
    }
}