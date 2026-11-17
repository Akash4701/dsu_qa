@isTest
    public class RestApi_CampusHolidaysByStudentId_Test {
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
            acc.Name = 'Institute';
            insert acc;
            
            contact con = new contact();
            con.lastname = 'Student';
            con.email = 'Student@gmail.com';
            con.RecordTypeId=schema.SObjectType.contact.getRecordTypeinfosbyname().get('Student').getRecordTypeId();
            insert con;
            
            Campus__c campus = new Campus__c();
                campus.Name = 'test';
                campus.Campus_ID__c = 'testr2';
            
            insert campus;
         
        }
        
        @isTest 
        static void methodGet1(){
            try{
                    Account acc =  [Select id, Name From Account limit 1];

            Campus__c camp = [Select id,Name,Campus_ID__c from Campus__c limit 1];
            Contact con = [Select id from Contact limit 1];
            
               hed__Program_Plan__c prgPlan = new hed__Program_Plan__c();
            prgPlan.name = 'Program plan';
            prgPlan.hed__Account__c = acc.id;
            prgPlan.hed__Start_Date__c = system.today();
            prgPlan.hed__End_Date__c = system.today() + 15;
            prgPlan.hed__Status__c ='Current';
            prgPlan.Intake__c ='Jan';
            prgPlan.Batch__c = '2023';
            insert prgPlan;
            
            Campus__c campus = new Campus__c();
            campus.Name = 'TestingCampus';
            campus.Campus_ID__c ='test';
            insert campus;
            
            
            hed__Term__c term = new hed__Term__c(); 
            term.hed__Account__c = acc.id;
            term.Program_Plan__c=prgPlan.id;
            term.hed__Start_Date__c = system.today();
            term.hed__End_Date__c = system.today() + 15;
            term.name = 'term';
            term.Campus__c = campus.id;
            term.Term_Reference__c = 'test';
            insert term;
            
            hed__Course__c course = new hed__Course__c();
            course.hed__Account__c = acc.id;
            course.Name = 'course Name';
            course.hed__Credit_Hours__c = 12;
            insert course;
            
            Course_Version__c version = new Course_Version__c();
            version.Course__c =course.id;
            version.Term__c = term.id;
            version.Program_Plan__c = prgPlan.id;
            insert version;
            
             hed__Course_Offering__c couOfferingg = new hed__Course_Offering__c();
        couOfferingg.hed__Course__c = course.id;
        couOfferingg.Course_Version__c = version.id;
        couOfferingg.hed__Term__c = term.id;
        couOfferingg.hed__Section_ID__c = 'B';
        insert couOfferingg; 

            
            hed__Course_Offering__c couOffering = [select hed__Course__c,Course_Version__c,hed__Term__c,hed__Section_ID__c from hed__Course_Offering__c limit 1];
            
            hed__Affiliation__c aff = new hed__Affiliation__c();
            aff.hed__Account__c=acc.id;
            aff.hed__Contact__c = con.id;
            aff.hed__Role__c = 'Faculty';
            aff.hed__Status__c = 'Current';
            insert aff;
            
            hed__Plan_Requirement__c planReq = new hed__Plan_Requirement__c();
            planReq.Institute__c = acc.id;
            planReq.hed__Program_Plan__c = prgPlan.id;
            planReq.Term__c = term.id;
            planReq.hed__Course__c = course.id;
            planReq.hed__Category__c = 'Mandatory';
            planReq.RecordTypeId=Schema.SObjectType.hed__Plan_Requirement__c.getRecordTypeInfosByName().get('Unit').getRecordTypeId();
            insert planReq;
            
            hed__Plan_Requirement__c planReq1 = new hed__Plan_Requirement__c();
            planReq1.Institute__c = acc.id;
            planReq1.hed__Program_Plan__c = prgPlan.id;
            planReq1.Term__c = term.id;
            planReq1.hed__Course__c = course.id;
            planReq.hed__Category__c = 'Elective';
            planReq1.RecordTypeId=Schema.SObjectType.hed__Plan_Requirement__c.getRecordTypeInfosByName().get('Unit').getRecordTypeId();
            insert planReq1;
            
            
            hed__Program_Enrollment__c enroll = new hed__Program_Enrollment__c();
            enroll.hed__Account__c = acc.id;
            enroll.hed__Contact__c = con.id;
            enroll.Term__c = term.id;
            enroll.hed__Program_Plan__c = prgPlan.id;
            enroll.hed__Affiliation__c = aff.id;
            enroll.hed__Start_Date__c = system.today();
            enroll.hed__End_Date__c =  system.today()+15;
            insert enroll;
            
            K42_Holiday__c generalHoliday = new K42_Holiday__c();
            generalHoliday.K42_Holiday_Type__c = 'Public Holiday';
            generalHoliday.Name = 'Test General Holiday';
            generalHoliday.K42_Hol_End_Date__c = system.today() + 2;
            generalHoliday.Common_Holiday__c = 'Yes';
            generalHoliday.K42_Hol_Start_Date__c = system.today() + 1;
            insert generalHoliday;
            
            
            K42_Campus_Holiday__c campusHoliday = new K42_Campus_Holiday__c();
            campusHoliday.Campus__c = campus.id;
            campusHoliday.Campus_Name__c = acc.id;
            campusHoliday.K42_Holiday__c = generalHoliday.id;
            insert campusHoliday;
            
            RestRequest req = new RestRequest(); 
            RestResponse res = new RestResponse();
                    Test.setMock(HttpCalloutMock.class, new MockEnrollmentRespBBClass());

            req.requestURI = '/services/apexrest/campusHolidays/?';
            //  req.addParameter('campusId',+camp.id);   
            req.addParameter('studentId',+con.id);  
            req.httpMethod = 'GET';
            RestContext.request = req;
            RestContext.response = res;
            Test.startTest();
            RestApi_CampusHolidaysByStudentId.doGet();
            Test.stopTest();
            }
            catch(exception e){}
            //system.assert(res.statusCode==200);
            
        }
         @isTest
    static void testGetGeneralHoliday() {
        // Setting up the necessary data
        K42_Holiday__c generalHoliday1 = new K42_Holiday__c();
        generalHoliday1.K42_Holiday_Type__c = 'Public Holiday';
        generalHoliday1.Name = 'Test General Holiday 1';
        generalHoliday1.K42_Hol_End_Date__c = System.today() + 2;
        generalHoliday1.Common_Holiday__c = 'Yes';
        generalHoliday1.K42_Hol_Start_Date__c = System.today() + 1;
        insert generalHoliday1;
        
        K42_Holiday__c generalHoliday2 = new K42_Holiday__c();
        generalHoliday2.K42_Holiday_Type__c = 'Public Holiday';
        generalHoliday2.Name = 'Test General Holiday 2';
        generalHoliday2.K42_Hol_End_Date__c = System.today() + 4;
        generalHoliday2.Common_Holiday__c = 'Yes';
        generalHoliday2.K42_Hol_Start_Date__c = System.today() + 3;
        insert generalHoliday2;

        List<K42_Holiday__c> generalHolidayList = [SELECT Id, Name, K42_Holiday_Type__c, K42_Hol_Start_Date__c, K42_Hol_End_Date__c FROM K42_Holiday__c WHERE Common_Holiday__c = 'Yes'];
        List<String> campusGeneralHolidayList = new List<String>();
        campusGeneralHolidayList.add(generalHoliday1.Id); // Adding one holiday ID to the list

        // Calling the method directly
        List<RestApi_CampusHolidaysByStudentId.responseHolidayDataWrapper> result = RestApi_CampusHolidaysByStudentId.getGeneralHoliday(generalHolidayList, campusGeneralHolidayList, null);

        // Making assertions
        Assert.areEqual(1, result.size(), 'Expected only one general holiday to be returned');
Assert.areEqual(generalHoliday2.Id, result[0].holidayId, 'Expected the holiday ID to be that of the second general holiday');
    }
    }