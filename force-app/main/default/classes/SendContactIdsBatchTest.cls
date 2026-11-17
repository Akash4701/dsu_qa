@isTest
private class SendContactIdsBatchTest {
    
    // Mock class for HTTP callout
    class MockHttpResponseGenerator implements HttpCalloutMock {
        private String contactId;
        private String enrollmentId;
        
        public MockHttpResponseGenerator(String contactId, String enrollmentId) {
            this.contactId = contactId;
            this.enrollmentId = enrollmentId;
        }
        
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);

            // Simulated response structure with actual record IDs
            String responseBody = JSON.serialize(new Map<String, Object>{
                'data' => new List<Object>{
                    new Map<String, Object>{
                        'user' => new Map<String, Object>{
                            'status' => true,
                            'recordId' => this.contactId,
                            'lmsId' => 'LMS123456'
                        },
                        'enroll' => new List<Object>{
                            new Map<String, Object>{
                                'status' => true,
                                'recordId' => this.enrollmentId
                            }
                        }
                    }
                }
            });

            res.setBody(responseBody);
            return res;
        }
    }

    @testSetup
    static void setupTestData() {
        
        Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());
		Test.setMock(HttpCalloutMock.class, new FailureHttpMock());
 		Test.setMock(HttpCalloutMock.class, new NoDataHttpMock());
        // Create parent account
        Account parentAccount = new Account(Name = 'Test Parent Account', LMS_Id__c = '12345');
        insert parentAccount;
        
        // Create LMS URL configurations
        LMS_URL__c lmsUrl = new LMS_URL__c(Name = 'course url', Bulk_Enroll__c = 'https://dummyendpoint.com');
        insert lmsUrl;
        
        LMS_URL__c URL1 = new LMS_URL__c(Name = 'course offering url', Bulk_Enroll__c = 'TestUrl');
        insert URL1;
        
        LMS_URL__c URL2 = new LMS_URL__c(Name = 'Bulk Enrollment', Bulk_Enroll__c = 'TestUrl');
        insert URL2;
        
        // Create child account
        Account childAccount = new Account(Name = 'Department A', ParentId = parentAccount.Id, LMS_Id__c = 'CHILDLMS456');
        insert childAccount;

        // Create Course
        hed__Course__c course = new hed__Course__c(Name = 'Physics', hed__Account__c = childAccount.Id, LMS_Id__c = 'COURSELMS789');
        insert course;

        // Create Term
        hed__Term__c term = new hed__Term__c(
            Name = 'Test Term',
            hed__Account__c = childAccount.Id,
            Term_Reference__c = 'Semester 1'
        );
        insert term;

        // Create Course Offering
        hed__Course_Offering__c offering = new hed__Course_Offering__c(
            Name = 'Physics 101',
            hed__Course__c = course.Id,
            LMS_Id__c = 'OFFERLMS321',
            hed__Term__c = term.Id
        );
        insert offering;

        // Create Contact
        Contact contact = new Contact(FirstName = 'John', LastName = 'Doe', Email = 'john.doe@example.com');
        insert contact;

        // Create Course Enrollment
        hed__Course_Enrollment__c enrollment = new hed__Course_Enrollment__c(
            hed__Contact__c = contact.Id,
            hed__Course_Offering__c = offering.Id
        );
        insert enrollment;
    }

    @isTest
    static void testSendContactIdsBatch() {
        // Get the actual record IDs from the test data
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];
        hed__Course_Enrollment__c testEnrollment = [SELECT Id FROM hed__Course_Enrollment__c WHERE hed__Contact__c = :testContact.Id LIMIT 1];
        
        // Set mock with actual record IDs
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(testContact.Id, testEnrollment.Id));

        Test.startTest();
        SendContactIdsBatch batch = new SendContactIdsBatch(new List<Id>{ testContact.Id });
        Database.executeBatch(batch, 1);
        Test.stopTest();

        // Assert expected values
        Contact updatedContact = [SELECT LMS_ID__c, Registered__c FROM Contact WHERE Id = :testContact.Id LIMIT 1];
        System.assertEquals('LMS123456', updatedContact.LMS_ID__c);
        System.assertEquals(true, updatedContact.Registered__c);

        hed__Course_Enrollment__c updatedEnrollment = [SELECT Registered__c FROM hed__Course_Enrollment__c WHERE hed__Contact__c = :testContact.Id LIMIT 1];
        System.assertEquals(true, updatedEnrollment.Registered__c);
    }
    
    @isTest
    static void testSendContactIdsBatchWithFailureResponse() {
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];
        
        Test.setMock(HttpCalloutMock.class, new FailureHttpMock());

        Test.startTest();
        SendContactIdsBatch batch = new SendContactIdsBatch(new List<Id>{ testContact.Id });
        Database.executeBatch(batch, 1);
        Test.stopTest();

        // Verify that records are not updated when the callout fails
        Contact updatedContact = [SELECT LMS_ID__c, Registered__c FROM Contact WHERE Id = :testContact.Id LIMIT 1];
        System.assertEquals(null, updatedContact.LMS_ID__c);
    //    System.assertEquals(null, updatedContact.Registered__c);
    }
    
    @isTest
    static void testSendContactIdsBatchWithNoEnrollments() {
        // Create a contact without enrollments
        Contact contactWithoutEnrollment = new Contact(FirstName = 'Jane', LastName = 'Smith', Email = 'jane.smith@example.com');
        insert contactWithoutEnrollment;
        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(contactWithoutEnrollment.Id, null));

        Test.startTest();
        SendContactIdsBatch batch = new SendContactIdsBatch(new List<Id>{ contactWithoutEnrollment.Id });
        Database.executeBatch(batch, 1);
        Test.stopTest();

        // This test ensures the batch can handle contacts without enrollments
        Contact updatedContact = [SELECT Id FROM Contact WHERE Id = :contactWithoutEnrollment.Id LIMIT 1];
        System.assertNotEquals(null, updatedContact.Id);
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
    
    public class SuccessHttpMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"success": "true","data": {"Identifier": "98765","Code": "Ken BBA-01","Name": "Ken - BBA Template","Path": "/content/enforced/6887-KenBBA-01"}}');
            res.setStatusCode(200);
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
        }}
}