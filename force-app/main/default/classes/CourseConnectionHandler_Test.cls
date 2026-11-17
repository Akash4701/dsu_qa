@IsTest
private class CourseConnectionHandler_Test {

    @TestSetup
    static void setupTestData() {
        
        Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());
        Test.setMock(HttpCalloutMock.class, new FailureHttpMock());
         Test.setMock(HttpCalloutMock.class, new NoDataHttpMock());
        
        LMS_URL__c lmsUrl = new LMS_URL__c(Name = 'course url', Bulk_Enroll__c = 'https://dummyendpoint.com');
    insert lmsUrl;
         LMS_URL__c URL = new LMS_URL__c(Name = 'course url',Bulk_Enroll__c = 'TestUrl');
        insert URL;
        LMS_URL__c URL1 = new LMS_URL__c(Name = 'course offering url',Bulk_Enroll__c = 'TestUrl');
        insert URL1;
        LMS_URL__c URL2 = new LMS_URL__c(Name = 'Bulk Enrollment',Bulk_Enroll__c = 'TestUrl');
        insert URL2;
        
        Account acc = new Account(Name = 'acc',LMS_Id__c = '12345');
        insert acc;
        
        hed__Course__c course = new hed__Course__c();
        course.hed__Account__c = acc.id;
        course.Name = 'course Name';
        course.hed__Credit_Hours__c = 12;
         course.LMS_ID__c = '54321';
        insert course;
        
        hed__Program_Plan__c prgPlan = new hed__Program_Plan__c();
        prgPlan.name = 'Program plan';
        prgPlan.hed__Account__c = acc.id;
        prgPlan.hed__Start_Date__c = system.today();
        prgPlan.hed__End_Date__c = system.today() + 15;
        prgPlan.hed__Status__c ='Current';
        prgPlan.Intake__c ='Jan';
        prgPlan.Batch__c = '2023';
        insert prgPlan;
        
        hed__Term__c term = new hed__Term__c();
        term.hed__Account__c = acc.id;
        term.Program_Plan__c=prgPlan.id;
        term.hed__Start_Date__c = system.today();
        term.hed__End_Date__c = system.today() + 15;
        term.name = 'term';
        term.Term_Reference__c='Term 1';
        insert term;
        
        
        // Create test hed__Course_Offering__c record
        hed__Course_Offering__c courseOffering = new hed__Course_Offering__c(
            Name = 'Math 101 - Section A',
            hed__Course__c=course.id, 
            hed__Term__c=term.id
        );
        insert courseOffering;

        // Create test Contact (hed__Contact__c)
        Contact contact = new Contact(
            FirstName = 'John',
            LastName = 'Doe'
        );
        insert contact;
    }

    @IsTest
    static void testHandleCourseConnectionInsert_ValidConnections() {
        // Arrange
        hed__Course_Offering__c courseOffering = [SELECT Id FROM hed__Course_Offering__c LIMIT 1];
        Contact contact = [SELECT Id FROM Contact LIMIT 1];

        List<hed__Course_Enrollment__c> connections = new List<hed__Course_Enrollment__c> {
            new hed__Course_Enrollment__c(
                hed__Course_Offering__c = courseOffering.Id,
                hed__Contact__c = contact.Id
            )
        };

        // Act
        Test.startTest();
        CourseConnectionHandler.handleCourseConnectionInsert(connections);
        Test.stopTest();

        // Assert
        List<Subject_Scores__c> scores = [SELECT Id, Course_Offering__c, Student_Name__c FROM Subject_Scores__c];
        System.assertEquals(1, scores.size(), 'One Subject Score record should be inserted');
        System.assertEquals(courseOffering.Id, scores[0].Course_Offering__c, 'Course Offering ID should match');
        System.assertEquals(contact.Id, scores[0].Student_Name__c, 'Student Contact ID should match');
    }

    @IsTest
    static void testHandleCourseConnectionInsert_NullFields() {
        // Arrange
        List<hed__Course_Enrollment__c> connections = new List<hed__Course_Enrollment__c> {
            new hed__Course_Enrollment__c(hed__Course_Offering__c = null, hed__Contact__c = null),
            new hed__Course_Enrollment__c(hed__Course_Offering__c = null, hed__Contact__c = '003000000000000'),
            new hed__Course_Enrollment__c(hed__Course_Offering__c = 'a00000000000000', hed__Contact__c = null)
        };

        // Act
        Test.startTest();
        CourseConnectionHandler.handleCourseConnectionInsert(connections);
        Test.stopTest();

        // Assert
        List<Subject_Scores__c> scores = [SELECT Id FROM Subject_Scores__c];
        System.assertEquals(0, scores.size(), 'No Subject Scores should be inserted due to null fields');
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