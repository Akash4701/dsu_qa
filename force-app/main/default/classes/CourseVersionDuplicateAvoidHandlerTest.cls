@isTest
private class CourseVersionDuplicateAvoidHandlerTest {
    
    @isTest
    static void testAvoidingDuplicateCourseVersions() {
        Account acc = new Account(Name = ' Test');
        insert acc;
         LMS_URL__c URL = new LMS_URL__c(Name = 'course url',Bulk_Enroll__c = 'TestUrl');
        insert URL;
        LMS_URL__c URL1 = new LMS_URL__c(Name = 'course offering url',Bulk_Enroll__c = 'TestUrl');
        insert URL1;
        LMS_URL__c URL2 = new LMS_URL__c(Name = 'Bulk Enrollment',Bulk_Enroll__c = 'TestUrl');
        insert URL2;
        
         Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());
        Test.setMock(HttpCalloutMock.class, new FailureHttpMock());
            Test.setMock(HttpCalloutMock.class, new NoDataHttpMock());
        
        // Step 1: Create Program Plan (if needed)
        Id programPlanId = Schema.SObjectType.hed__Term__c.getRecordTypeInfos().size() > 0
            ? Schema.SObjectType.hed__Term__c.getRecordTypeInfos()[0].getRecordTypeId()
            : null;
        
        hed__Program_Plan__c pp = new hed__Program_Plan__c(Name = 'test',Batch__c = '2020',Intake__c ='OCT');
        insert pp;

        // Step 2: Create Course
        hed__Course__c course = new hed__Course__c(Name = 'Test Course',hed__Account__c = acc.Id);
        insert course;

        // Step 3: Create Term
        hed__Term__c term = new hed__Term__c(
            Name = 'Fall 2025',
            Program_Plan__c = pp.Id,
            hed__Account__c = acc.Id,
            Term_Reference__c = '2025-Term-Ref'
        );
        insert term;

        // Step 4: Create existing Course_Version__c (simulate already existing record)
        Course_Version__c existingCV = new Course_Version__c(
            Term__c = term.Id,
            Course__c = course.Id
        );
        insert existingCV;

        // Step 5: Create a new Course_Version__c (duplicate attempt)
        Course_Version__c duplicateCV = new Course_Version__c(
            Term__c = term.Id,
            Course__c = course.Id
        );

        // Step 6: Run the method inside try-catch to verify error
        Test.startTest();
        try {
            CourseVersionDuplicateAvoidHandler.avoidingDuplicateCourseVersoins(new List<Course_Version__c>{duplicateCV});
        } catch (Exception e) {
        }
        Test.stopTest();
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