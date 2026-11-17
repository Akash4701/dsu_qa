@isTest
public class UpdateCourOffEnrollCountTest {

    @testSetup
    static void setupTestData() {
        Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());
        Test.setMock(HttpCalloutMock.class, new FailureHttpMock());
        // Create a RecordType for Course Enrollment if not already in test context
        RecordType recType = [SELECT Id FROM RecordType WHERE SObjectType = 'hed__Course_Enrollment__c' AND DeveloperName = 'Student' LIMIT 1];
		
        Account testAccount = new Account(Name = 'Test Account', LMS_Id__c = '12345');
        LMS_URL__c lmsUrl = new LMS_URL__c(Name = 'course url', Bulk_Enroll__c = 'https://dummyendpoint.com');
   		insert lmsUrl;
        LMS_URL__c URL1 = new LMS_URL__c(Name = 'course offering url',Bulk_Enroll__c = 'TestUrl');
        insert URL1;
        LMS_URL__c URL2 = new LMS_URL__c(Name = 'Bulk Enrollment',Bulk_Enroll__c = 'TestUrl');
        insert URL2;
        
        insert testAccount;
         hed__Term__c testTerm = new hed__Term__c(
             Name = 'testTerm',
             hed__Account__c = testAccount.id,
             Term_Reference__c = 'Term 1'             
             );
        insert testTerm;
        hed__Course__c testCourse = new hed__Course__c(
            Name = 'Test Course',
            hed__Course_ID__c = 'TC001',
            hed__Account__c = testAccount.Id,
            LMS_ID__c = '54321'
        );
        insert testCourse;
        
        // Create a Course Offering
        hed__Course_Offering__c offering = new hed__Course_Offering__c(
            Name = 'Test Offering',
            hed__Term__c=testTerm.Id,
            hed__Course__c=testCourse.Id,
            Total_Enrolled__c = 0
        );
        insert offering;

        // Insert sample Course Enrollments
        List<hed__Course_Enrollment__c> enrollments = new List<hed__Course_Enrollment__c>();
        for (Integer i = 0; i < 3; i++) {
            enrollments.add(new hed__Course_Enrollment__c(
                hed__Course_Offering__c = offering.Id,
                RecordTypeId = recType.Id
            ));
        }
        insert enrollments;
    }

    @isTest
    static void testInsertTrigger() {
        // Get the offering
        hed__Course_Offering__c offering = [SELECT Id, Total_Enrolled__c FROM hed__Course_Offering__c LIMIT 1];

        // Verify count after insert
        System.assertEquals(3, offering.Total_Enrolled__c, 'Enrollment count should be 3 after insert');
    }

    @isTest
    static void testDeleteTrigger() {
        // Get enrollments and delete 1
        List<hed__Course_Enrollment__c> enrollments = [
            SELECT Id FROM hed__Course_Enrollment__c LIMIT 1
        ];
        delete enrollments;

        // Re-fetch offering and check count
        hed__Course_Offering__c offering = [SELECT Id, Total_Enrolled__c FROM hed__Course_Offering__c LIMIT 1];
        System.assertEquals(2, offering.Total_Enrolled__c, 'Enrollment count should be 2 after deleting 1');
    }

    @isTest
    static void testUpdateTrigger() {
        // Update one record to ensure update is covered
        hed__Course_Enrollment__c ce = [SELECT Id FROM hed__Course_Enrollment__c LIMIT 1];
        update ce;

        // Re-fetch offering and check count (should still be 3 since update doesn't change association)
        hed__Course_Offering__c offering = [SELECT Id, Total_Enrolled__c FROM hed__Course_Offering__c LIMIT 1];
        System.assertEquals(3, offering.Total_Enrolled__c, 'Enrollment count should remain 3 after update');
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
}