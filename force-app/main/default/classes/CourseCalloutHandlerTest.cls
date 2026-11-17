@isTest
public class CourseCalloutHandlerTest {
    
    @testSetup
    static void setupData() {
        Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());
        Test.setMock(HttpCalloutMock.class, new FailureHttpMock());
        Account testAccount = new Account(Name = 'Test Account', LMS_Id__c = '12345');
        insert testAccount;
        LMS_URL__c lmsUrl = new LMS_URL__c(Name = 'course url', Bulk_Enroll__c = 'https://dummyendpoint.com');
    insert lmsUrl;
        
        hed__Course__c testCourse = new hed__Course__c(
            Name = 'Test Course',
            hed__Course_ID__c = 'TC001',
            hed__Account__c = testAccount.Id
        );
        insert testCourse;
    }
    
    @isTest
    static void testSendCoursesSuccess() {
        Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());
        
        List<hed__Course__c> courses = [SELECT Id FROM hed__Course__c LIMIT 1];
        List<Id> courseIds = new List<Id>();
        for (hed__Course__c course : courses) {
            courseIds.add(course.Id);
        }
        
        Test.startTest();
        CourseCalloutHandler.sendCourses(courseIds);
        Test.stopTest();
        
        hed__Course__c updatedCourse = [SELECT Id, LMS_Id__c FROM hed__Course__c WHERE Id = :courses[0].Id];
    }
    
    @isTest
    static void testSendCoursesFailure() {
        Test.setMock(HttpCalloutMock.class, new FailureHttpMock());
        
        List<hed__Course__c> courses = [SELECT Id FROM hed__Course__c LIMIT 1];
        List<Id> courseIds = new List<Id>();
        for (hed__Course__c course : courses) {
            courseIds.add(course.Id);
        }
        
        Test.startTest();
        System.enqueueJob(new CourseCalloutQueueable(courseIds));
        Test.stopTest();
        
        hed__Course__c updatedCourse = [SELECT Id, LMS_Id__c FROM hed__Course__c WHERE Id = :courses[0].Id];
        System.assertEquals(null, updatedCourse.LMS_Id__c);
    }
    
    @isTest
    static void testSendCoursesNoDataInResponse() {
        Test.setMock(HttpCalloutMock.class, new NoDataHttpMock());
        
        List<hed__Course__c> courses = [SELECT Id FROM hed__Course__c LIMIT 1];
        List<Id> courseIds = new List<Id>();
        for (hed__Course__c course : courses) {
            courseIds.add(course.Id);
        }
        
        Test.startTest();
        System.enqueueJob(new CourseCalloutQueueable(courseIds));
        Test.stopTest();
        
        hed__Course__c updatedCourse = [SELECT Id, LMS_Id__c FROM hed__Course__c WHERE Id = :courses[0].Id];
        System.assertEquals(null, updatedCourse.LMS_Id__c);
    }
    
    public class CourseCalloutQueueable implements Queueable, Database.AllowsCallouts {
        private List<Id> courseIds;
        
        public CourseCalloutQueueable(List<Id> courseIds) {
            this.courseIds = courseIds;
        }
        
        public void execute(QueueableContext context) {
            CourseCalloutHandler.sendCourses(courseIds);
        }
    }
    
    public class SuccessHttpMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(' {"success": "true","data": {"Identifier": "98765","Code": "Ken BBA-01","Name": "Ken - BBA Template","Path": "/content/enforced/6887-KenBBA-01"}}');
            res.setStatusCode(200);
            return res;
        }
    }
    
    public class FailureHttpMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"error": "Internal Server Error"}');
            res.setStatusCode(500);
            return res;
        }
    }
    
    public class NoDataHttpMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"message": "Success"}');
            res.setStatusCode(200);
            return res;
        }
    }
}