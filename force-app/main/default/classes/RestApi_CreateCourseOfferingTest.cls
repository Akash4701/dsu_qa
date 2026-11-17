@isTest
public class RestApi_CreateCourseOfferingTest {
  @TestSetup
    static void setup() {
        LMS_URL__c URL = new LMS_URL__c(Name = 'course url',Bulk_Enroll__c = 'TestUrl');
        insert URL;
        LMS_URL__c URL1 = new LMS_URL__c(Name = 'course offering url',Bulk_Enroll__c = 'TestUrl');
        insert URL1;
        LMS_URL__c URL2 = new LMS_URL__c(Name = 'Bulk Enrollment',Bulk_Enroll__c = 'TestUrl');
        insert URL2;
        Account testAccount = new Account(Name = 'Test Account', LMS_Id__c = '12345');
        insert testAccount;
        Account acc = new Account(
            Name = 'test'
        );
        insert acc;
        
        Contact con = new Contact(
            LastName = 'test',
            AccountId = acc.Id
        );
        insert con;
        
    }
    
    @isTest
    static void testDoCourseOffering_AddOperation() {
         Test.setMock(HttpCalloutMock.class, new MockEnrollmentRespBBClass());
        Account acc = [SELECT Id, Name FROM Account LIMIT 1];
        Contact con = [SELECT Id, LastName FROM Contact LIMIT 1];
         hed__Term__c term = new hed__Term__c(
            Name = 'Test Term',
            hed__Account__c = acc.Id,
            Term_Reference__c = 'Test Term Reference'
        );
        insert term;
        
        hed__Course__c course = new hed__Course__c(
            Name = 'Test Course',
            hed__Account__c = acc.Id
        );
        insert course;
        
        Course_Version__c courseVersion = new Course_Version__c(
            Term__c = term.Id,
            Course__c = course.Id,
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addMonths(1)
        );
        insert courseVersion;
        
        hed__Course_Offering__c courseOffering = new hed__Course_Offering__c(
            Course_Version__c = courseVersion.Id,
            hed__Section_ID__c = 'Test Section ID',
            hed__Capacity__c = 30,
            hed__Course__c = course.Id,
            hed__Term__c = term.Id,
            hed__Faculty__c=con.id
        );
        insert courseOffering;
        
        Exam_Connections__c examConnection = new Exam_Connections__c(
            Course_Name__c = courseOffering.Id,
            Student_Name__c = con.Id
        );
        insert examConnection;
        
       
        RestApi_CreateCourseOffering.requestCourseOfferingDataWrapper reqCouOffWrap = new RestApi_CreateCourseOffering.requestCourseOfferingDataWrapper();
        reqCouOffWrap.courseOfferingId=courseOffering.id;
        reqCouOffWrap.courseOfferingCapacity = '30';
        reqCouOffWrap.courseOfferingSectionId = 'Test Section ID';
        reqCouOffWrap.courseVersionId = courseVersion.Id;
        reqCouOffWrap.coursePrimaryFaculty =con.id;
        RestApi_CreateCourseOffering.requestCourseOfferingWrapper request = new RestApi_CreateCourseOffering.requestCourseOfferingWrapper();
        request.Operation = 'Delete';
        request.CourseOffering=reqCouOffWrap;
        RestApi_CreateCourseOffering.responseCourseOfferingyWrapper response=new RestApi_CreateCourseOffering.responseCourseOfferingyWrapper();
        response.courseOfferingId=courseOffering.id;
        
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/createCourseOffering/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(request));
        RestContext.request = req;
        
        RestResponse res = new RestResponse();
        RestContext.response = res;
        
        Test.startTest();
        RestApi_CreateCourseOffering.doCourseOffering();
        Test.stopTest();
        
    }
    
    @isTest
    static void testDoCourseOffering_DeleteOperation() { 
        Test.setMock(HttpCalloutMock.class, new MockEnrollmentRespBBClass());
        Account acc = [SELECT Id, Name FROM Account LIMIT 1];
        Contact con = [SELECT Id, LastName FROM Contact LIMIT 1];
          hed__Term__c term = new hed__Term__c(
            Name = 'Test Term',
            hed__Account__c = acc.Id,
            Term_Reference__c = 'Test Term Reference'
        );
        insert term;
        
        hed__Course__c course = new hed__Course__c(
            Name = 'Test Course',
            hed__Account__c = acc.Id
        );
        insert course;
        
        Course_Version__c courseVersion = new Course_Version__c(
            Term__c = term.Id,
            Course__c = course.Id,
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addMonths(1)
        );
        insert courseVersion;
        
        hed__Course_Offering__c courseOffering = new hed__Course_Offering__c(
            Course_Version__c = courseVersion.Id,
            hed__Section_ID__c = 'Test Section ID',
            hed__Capacity__c = 30,
            hed__Course__c = course.Id,
            hed__Term__c = term.Id,
            hed__Faculty__c=con.id
        );
        insert courseOffering;
        
        Exam_Connections__c examConnection = new Exam_Connections__c(
            Course_Name__c = courseOffering.Id,
            Student_Name__c = con.Id
        );
        insert examConnection;
        
       RestApi_CreateCourseOffering.requestCourseOfferingDataWrapper reqCouOffWrap = new RestApi_CreateCourseOffering.requestCourseOfferingDataWrapper();
        //reqCouOffWrap.courseOfferingId=courseOffering.id;
        reqCouOffWrap.courseOfferingCapacity = '30';
        reqCouOffWrap.courseOfferingSectionId = 'Test Section ID';
        reqCouOffWrap.courseVersionId = courseVersion.Id;
        reqCouOffWrap.coursePrimaryFaculty =con.id;
        RestApi_CreateCourseOffering.requestCourseOfferingWrapper request = new RestApi_CreateCourseOffering.requestCourseOfferingWrapper();
        request.Operation = 'Insert';
        request.CourseOffering=reqCouOffWrap;
        RestApi_CreateCourseOffering.responseCourseOfferingyWrapper response=new RestApi_CreateCourseOffering.responseCourseOfferingyWrapper();
        response.courseOfferingId=courseOffering.id;
        
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/createCourseOffering/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(request));
        RestContext.request = req;
        
        RestResponse res = new RestResponse();
        RestContext.response = res;
        
        Test.startTest();
        RestApi_CreateCourseOffering.doCourseOffering();
        Test.stopTest();
        
        System.assertEquals(200, res.statusCode);
          }
     @isTest
    static void testDoCourseOffering_DeleteOperation2() { 
        Test.setMock(HttpCalloutMock.class, new MockEnrollmentRespBBClass());
        Account acc = [SELECT Id, Name FROM Account LIMIT 1];
        Contact con = [SELECT Id, LastName FROM Contact LIMIT 1];
          hed__Term__c term = new hed__Term__c(
            Name = 'Test Term',
            hed__Account__c = acc.Id,
            Term_Reference__c = 'Test Term Reference'
        );
        insert term;
        
        hed__Course__c course = new hed__Course__c(
            Name = 'Test Course',
            hed__Account__c = acc.Id
        );
        insert course;
        
        Course_Version__c courseVersion = new Course_Version__c(
            Term__c = term.Id,
            Course__c = course.Id,
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addMonths(1)
        );
        insert courseVersion;
        
        hed__Course_Offering__c courseOffering = new hed__Course_Offering__c(
            Course_Version__c = courseVersion.Id,
            hed__Section_ID__c = 'Test Section ID',
            hed__Capacity__c = 30,
            hed__Course__c = course.Id,
            hed__Term__c = term.Id,
            hed__Faculty__c=con.id
        );
        insert courseOffering;
        
        Exam_Connections__c examConnection = new Exam_Connections__c(
            Course_Name__c = courseOffering.Id,
            Student_Name__c = con.Id
        );
        insert examConnection;
        
       RestApi_CreateCourseOffering.requestCourseOfferingDataWrapper reqCouOffWrap = new RestApi_CreateCourseOffering.requestCourseOfferingDataWrapper();
        //reqCouOffWrap.courseOfferingId=courseOffering.id;
        //reqCouOffWrap.courseOfferingCapacity = '30';
        //reqCouOffWrap.courseOfferingSectionId = 'Test Section ID';
        //reqCouOffWrap.courseVersionId = courseVersion.Id;
        //reqCouOffWrap.coursePrimaryFaculty =con.id;
        reqCouOffWrap.courseOfferingIds = new List<String>{courseOffering.Id};
        RestApi_CreateCourseOffering.requestCourseOfferingWrapper request = new RestApi_CreateCourseOffering.requestCourseOfferingWrapper();
        request.Operation = 'Delete';
        request.CourseOffering=reqCouOffWrap;
        RestApi_CreateCourseOffering.responseCourseOfferingyWrapper response=new RestApi_CreateCourseOffering.responseCourseOfferingyWrapper();
        response.courseOfferingId=courseOffering.id;
        
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/createCourseOffering/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(request));
        RestContext.request = req;
        
        RestResponse res = new RestResponse();
        RestContext.response = res;
        
        Test.startTest();
        RestApi_CreateCourseOffering.doCourseOffering();
        Test.stopTest();
        
          }
}