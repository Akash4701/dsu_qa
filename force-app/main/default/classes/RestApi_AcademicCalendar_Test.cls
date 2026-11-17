@istest
public class RestApi_AcademicCalendar_Test {
    @testSetup static void mainClass(){
        account acc= new account();
        acc.name='test1';
        insert acc;
        
        Campus__c campus = new Campus__c();
        campus.Name = 'India';
        campus.Campus_ID__c='SING';
        insert campus;
        
        hed__Term__c masterTerm = new hed__Term__c();
        masterTerm.hed__Account__c = acc.Id;
        masterTerm.Term_Reference__c = 'Term 2';
        insert masterTerm;
        
        hed__Term__c term = new hed__Term__c();
        term.name = '2022 second Semister';
        term.hed__Account__c = acc.id;
        term.hed__Start_Date__c = system.today()-10;
        term.hed__End_Date__c = system.today()+10;
        term.hed__Parent_Term__c = masterTerm.Id;
        term.Campus__c = campus.Id;
        term.Term_Reference__c='Term 1';
        insert term;
        
        Academic_Calendar__c cal= new Academic_Calendar__c();
        cal.Term__c = term.id;
        cal.name='test';
        cal.Week_Number__c =3;
        cal.Start_Date__c = system.today();
        cal.End_Date__c = system.today()+1;
        cal.Type_of_Activity__c ='Teaching';
        insert cal;
        
              Academic_Calendar__c call= new Academic_Calendar__c();
        call.Term__c = term.id;
        call.name='test1';
        call.Week_Number__c =3;
        call.Start_Date__c = system.today();
        call.End_Date__c = system.today()+1;
        call.Type_of_Activity__c ='Teaching';
        insert call;
        
    }
    
    
    testMethod static void academicCalender(){
        //  hed__Term__c termlist= [select id,name from hed__Term__c limit 1];
        list<Academic_Calendar__c> calList= [SELECT Term__c,Term__r.Name, Week_Number__c, Start_Date__c, End_Date__c, Type_of_Activity__c, Name, Id FROM Academic_Calendar__c];
        RestRequest req = new RestRequest(); 
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/AcademicCalendar';
        req.addParameter('termid', calList[0].Term__c);
        req.httpMethod = 'GET';
     RestContext.request = req;
        RestContext.response = res;
        Test.StartTest();
        RestApi_AcademicCalendar.getAcademicCalendar();
        Test.StopTest();
        system.assertEquals(200,res.statusCode);
    }
    
        testMethod static void academicCalender1(){
        //  hed__Term__c termlist= [select id,name from hed__Term__c limit 1];
        list<Academic_Calendar__c> calList= [SELECT Term__c,Term__r.Name, Week_Number__c, Start_Date__c, End_Date__c, Type_of_Activity__c, Name, Id FROM Academic_Calendar__c];
        RestRequest req = new RestRequest(); 
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/AcademicCalendar';
      //  req.addParameter('termid', calList[0].Term__c);
        req.httpMethod = 'GET';
     RestContext.request = req;
        RestContext.response = res;
        Test.StartTest();
        RestApi_AcademicCalendar.getAcademicCalendar();
        Test.StopTest();
    }
    
            testMethod static void academicCalender2(){
        //  hed__Term__c termlist= [select id,name from hed__Term__c limit 1];
        list<Academic_Calendar__c> calList= [SELECT Term__c,Term__r.Name, Week_Number__c, Start_Date__c, End_Date__c, Type_of_Activity__c, Name, Id FROM Academic_Calendar__c];
        RestRequest req = new RestRequest(); 
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/AcademicCalendar';
       req.addParameter('termid', '12345');
        req.httpMethod = 'GET';
     RestContext.request = req;
        RestContext.response = res;
        Test.StartTest();
        RestApi_AcademicCalendar.getAcademicCalendar();
        Test.StopTest();
    }
    


 static testMethod void  updateMethodTest(){
     
 list<Academic_Calendar__c> calList= [SELECT Term__c,Term__r.Name, Week_Number__c, Start_Date__c, End_Date__c, Type_of_Activity__c, Name, Id FROM Academic_Calendar__c];
  Test.StartTest();
     String RequestBody ='[{"academicCalenderId":"'+calList[0].id+'","academicCalenderName":"test1","startDate":"2022-06-01","endDate":"2022-06-30","weekNumber":"2","typeofActivity":"test","termid":"'+calList[0].Term__c+'"}, {"academicCalenderName":"test1","startDate":"2022-06-01","endDate":"2022-06-30","weekNumber":"2","typeofActivity":"test","termid":"'+calList[1].Term__c+'"}]';
        
            RestRequest req = new RestRequest(); 
            RestResponse res = new RestResponse();
            req.requestURI = '/services/apexrest/CreateActivities';
            req.httpMethod = 'POST';
            req.requestBody = Blob.valueof(RequestBody);
            RestContext.request = req;
            RestContext.response = res;
            RestApi_AcademicCalendar.insertingAcademicCalender();
        Test.StopTest();
     RestApi_AcademicCalendar.testCoverage();
   
    }
}