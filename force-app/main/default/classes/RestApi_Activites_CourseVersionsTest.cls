@isTest
public class RestApi_Activites_CourseVersionsTest {

    @testsetup
    static void setup() {
        LMS_URL__c URL = new LMS_URL__c(Name = 'course url',Bulk_Enroll__c = 'TestUrl');
        insert URL;
        LMS_URL__c URL1 = new LMS_URL__c(Name = 'course offering url',Bulk_Enroll__c = 'TestUrl');
        insert URL1;
        LMS_URL__c URL2 = new LMS_URL__c(Name = 'Bulk Enrollment',Bulk_Enroll__c = 'TestUrl');
        insert URL2;
        Account testAccount = new Account(Name = 'Test Account', LMS_Id__c = '12345');
        insert testAccount;
        // Create test data
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        Contact con=new Contact();
        con.LastName='Test ram1';
        insert con;
        
        Contact con1=new Contact();
        con1.LastName='Test ram2';
        insert con1;
        
         Contact con2=new Contact();
        con2.LastName='Test ram3';
        insert con2;

        // Create a course offering

    }

    @isTest
    static void testDoGetBothId(){
       			
 		Test.setMock(HttpCalloutMock.class, new MockEnrollmentRespBBClass());
        Account acc=[Select Id,Name from Account limit 1];
        Contact con=[Select Id,Name from Contact limit 1];
        Contact con1=[Select Id,Name from Contact limit 1];
        Contact con2=[Select Id,Name from Contact limit 1];
                hed__Course__c course = new hed__Course__c(
            hed__Account__c = acc.Id,
            Name = 'Test Course'
        );
        insert course;

        // Create a program plan
        hed__Program_Plan__c programPlan = new hed__Program_Plan__c(
            Name = 'Test Program Plan',
            hed__Account__c = acc.Id,
            Working_Days__c='Monday;Tuesday'
        );
        insert programPlan;

        // Create a term
        hed__Term__c term = new hed__Term__c(
            hed__Account__c = acc.Id,
            Program_Plan__c = programPlan.Id,
            Name = 'Test Term',
            Term_Reference__c='Term 1'
        );
        insert term;

        // Create a course version
        Course_Version__c courseVersion = new Course_Version__c(
            Course__c = course.Id,
            Term__c = term.Id,
            Program_Plan__c = programPlan.Id
        );
        insert courseVersion;
        
           hed__Course_Offering__c couOffering1 = new hed__Course_Offering__c(
            hed__Course__c = course.Id,
            Course_Version__c = courseVersion.Id,
            hed__Term__c = term.Id,
            hed__Section_ID__c = 'B'
        );
        insert couOffering1;

         hed__Facility__c facility = new hed__Facility__c();
        facility.Name = 'FacilityTest';
        facility.Number_of_Rows__c =5;
        facility.Number_of_Rows_Per_Column__c = 5;
        insert facility;
        
        // Create an activity related to the course version
        Activity__c activity = new Activity__c(
            Subject__c = courseVersion.Id,
            Name = 'Test Activity',
            Activity_type__c = 'Teaching',
            Start_date__c = Date.today(),
            End_date__c = Date.today().addDays(7),
            Number_of_hours_session__c = 2,
            Course_Offering__c = couOffering1.Id,
            Faculty1__c = con.Id,
            Faculty2__c = con1.Id,
            Faculty3__c = con2.Id,
            Number_of_Sessions__c=3,
            Facility__c=facility.id
        );
        insert activity;
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/activitesWithCourseVersion/';
        req.httpMethod = 'GET';

        // Set parameters for the request
        req.addParameter('courseVersionId',courseVersion.Id ); 
        req.addParameter('facilityId',facility.id ); 

        // Assign the request and response to RestContext
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        RestApi_Activites_CourseVersions.doGet();
        Test.stopTest();

        // Assert the response
        System.assertEquals(200, res.statusCode, 'Expected status code 200');
        
    }
     @isTest
    static void testDoGetCourseVersionId()  {
       			
 		Test.setMock(HttpCalloutMock.class, new MockEnrollmentRespBBClass());
        Account acc=[Select Id,Name from Account limit 1];
        Contact con=[Select Id,Name from Contact limit 1];
        Contact con1=[Select Id,Name from Contact limit 1];
        Contact con2=[Select Id,Name from Contact limit 1];
                hed__Course__c course = new hed__Course__c(
            hed__Account__c = acc.Id,
            Name = 'Test Course'
        );
        insert course;

        // Create a program plan
        hed__Program_Plan__c programPlan = new hed__Program_Plan__c(
            Name = 'Test Program Plan',
            hed__Account__c = acc.Id,
            Working_Days__c='Monday;Tuesday'
        );
        insert programPlan;

        // Create a term
        hed__Term__c term = new hed__Term__c(
            hed__Account__c = acc.Id,
            Program_Plan__c = programPlan.Id,
            Name = 'Test Term',
            Term_Reference__c='Term 1'
        );
        insert term;

        // Create a course version
        Course_Version__c courseVersion = new Course_Version__c(
            Course__c = course.Id,
            Term__c = term.Id,
            Program_Plan__c = programPlan.Id
        );
        insert courseVersion;
        
           hed__Course_Offering__c couOffering1 = new hed__Course_Offering__c(
            hed__Course__c = course.Id,
            Course_Version__c = courseVersion.Id,
            hed__Term__c = term.Id,
            hed__Section_ID__c = 'B'
        );
        insert couOffering1;

         hed__Facility__c facility = new hed__Facility__c();
        facility.Name = 'FacilityTest';
        facility.Number_of_Rows__c =5;
        facility.Number_of_Rows_Per_Column__c = 5;
        insert facility;
        
        // Create an activity related to the course version
        Activity__c activity = new Activity__c(
            Subject__c = courseVersion.Id,
            Name = 'Test Activity',
            Activity_type__c = 'Teaching',
            Start_date__c = Date.today(),
            End_date__c = Date.today().addDays(7),
            Number_of_hours_session__c = 2,
            Course_Offering__c = couOffering1.Id,
            Faculty1__c = con.Id,
            Faculty2__c = con1.Id,
            Faculty3__c = con2.Id,
            Number_of_Sessions__c=3,
            Facility__c=facility.id
        );
        insert activity;
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/activitesWithCourseVersion/';
        req.httpMethod = 'GET';

        // Set parameters for the request
        req.addParameter('courseVersionId',courseVersion.Id ); 
        req.addParameter('facilityId',null ); 

        // Assign the request and response to RestContext
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        RestApi_Activites_CourseVersions.doGet();
        Test.stopTest();

        // Assert the response
        System.assertEquals(200, res.statusCode, 'Expected status code 200');
        
    }
     @isTest
    static void testDoGetFacilityId()  {
       			
 		Test.setMock(HttpCalloutMock.class, new MockEnrollmentRespBBClass());
        Account acc=[Select Id,Name from Account limit 1];
        Contact con=[Select Id,Name from Contact limit 1];
        Contact con1=[Select Id,Name from Contact limit 1];
        Contact con2=[Select Id,Name from Contact limit 1];
                hed__Course__c course = new hed__Course__c(
            hed__Account__c = acc.Id,
            Name = 'Test Course'
        );
        insert course;

        // Create a program plan
        hed__Program_Plan__c programPlan = new hed__Program_Plan__c(
            Name = 'Test Program Plan',
            hed__Account__c = acc.Id,
            Working_Days__c='Monday;Tuesday'
        );
        insert programPlan;

        // Create a term
        hed__Term__c term = new hed__Term__c(
            hed__Account__c = acc.Id,
            Program_Plan__c = programPlan.Id,
            Name = 'Test Term',
            Term_Reference__c='Term 1'
        );
        insert term;

        // Create a course version
        Course_Version__c courseVersion = new Course_Version__c(
            Course__c = course.Id,
            Term__c = term.Id,
            Program_Plan__c = programPlan.Id
        );
        insert courseVersion;
        
           hed__Course_Offering__c couOffering1 = new hed__Course_Offering__c(
            hed__Course__c = course.Id,
            Course_Version__c = courseVersion.Id,
            hed__Term__c = term.Id,
            hed__Section_ID__c = 'B'
        );
        insert couOffering1;

         hed__Facility__c facility = new hed__Facility__c();
        facility.Name = 'FacilityTest';
        facility.Number_of_Rows__c =5;
        facility.Number_of_Rows_Per_Column__c = 5;
        insert facility;
        
        // Create an activity related to the course version
        Activity__c activity = new Activity__c(
            Subject__c = courseVersion.Id,
            Name = 'Test Activity',
            Activity_type__c = 'Teaching',
            Start_date__c = Date.today(),
            End_date__c = Date.today().addDays(7),
            Number_of_hours_session__c = 2,
            Course_Offering__c = couOffering1.Id,
            Faculty1__c = con.Id,
            Faculty2__c = con1.Id,
            Faculty3__c = con2.Id,
            Number_of_Sessions__c=3,
            Facility__c=facility.id
        );
        insert activity;
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/activitesWithCourseVersion/';
        req.httpMethod = 'GET';

        // Set parameters for the request
        req.addParameter('courseVersionId',null ); 
        req.addParameter('facilityId',facility.id ); 

        // Assign the request and response to RestContext
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        RestApi_Activites_CourseVersions.doGet();
        Test.stopTest();

        // Assert the response
        System.assertEquals(200, res.statusCode, 'Expected status code 200');
        
    }
}