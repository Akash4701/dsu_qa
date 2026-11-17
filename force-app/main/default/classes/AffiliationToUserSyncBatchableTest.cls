@isTest
public class AffiliationToUserSyncBatchableTest {
    
    @testSetup
    static void setupData() {
        Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());
        Test.setMock(HttpCalloutMock.class, new FailureHttpMock());
        
        LMS_URL__c URL = new LMS_URL__c(Name = 'course url',Bulk_Enroll__c = 'TestUrl');
        insert URL;
        LMS_URL__c URL1 = new LMS_URL__c(Name = 'course offering url',Bulk_Enroll__c = 'TestUrl');
        insert URL1;
        LMS_URL__c URL2 = new LMS_URL__c(Name = 'Bulk Enrollment',Bulk_Enroll__c = 'TestUrl');
        insert URL2;
        Account testAccount = new Account(Name = 'Test Account', LMS_Id__c = '12345');
        insert testAccount;
        
        Contact testContact = new Contact(
            FirstName = 'John',
            MiddleName = 'M',
            LastName = 'Doe',
            Email = 'john.doe@test.com'
        );
        insert testContact;
        
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
        
        hed__Course_Offering__c testOffering = new hed__Course_Offering__c(
            Name = 'Test Course Offering',
            hed__Course__c = testCourse.Id,
            LMS_Id__c = '98765',
            hed__Term__c = testTerm.id
        );
        insert testOffering;
        
        hed__Affiliation__c testAffiliation = new hed__Affiliation__c(
            hed__Contact__c = testContact.Id,
            hed__Account__c = testAccount.Id
        );
        insert testAffiliation;
        
        hed__Program_Enrollment__c testProgramEnrollment = new hed__Program_Enrollment__c(
            hed__Contact__c = testContact.Id,
            hed__Affiliation__c = testAffiliation.Id
        );
        insert testProgramEnrollment;
        
        hed__Course_Enrollment__c testCourseEnrollment = new hed__Course_Enrollment__c(
            hed__Contact__c = testContact.Id,
            hed__Course_Offering__c = testOffering.Id
        );
        insert testCourseEnrollment;
    }
    
    @isTest
    static void testBatchableSuccess() {
        Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());
        
        List<hed__Affiliation__c> affiliations = [SELECT Id FROM hed__Affiliation__c LIMIT 1];
        List<Id> affiliationIds = new List<Id>();
        for (hed__Affiliation__c aff : affiliations) {
            affiliationIds.add(aff.Id);
        }
        
        Test.startTest();
        AffiliationToUserSyncBatchable batch = new AffiliationToUserSyncBatchable(affiliationIds);
        Database.executeBatch(batch);
        Test.stopTest();
        
        Contact updatedContact = [SELECT Id, LMS_ID__c, Registered__c FROM Contact LIMIT 1];
        System.assertEquals('555666', updatedContact.LMS_ID__c);
        System.assertEquals(true, updatedContact.Registered__c);
        
        
    }
    
    @isTest
    static void testBatchableFailure() {
        Test.setMock(HttpCalloutMock.class, new FailureHttpMock());
        
        List<hed__Affiliation__c> affiliations = [SELECT Id FROM hed__Affiliation__c LIMIT 1];
        List<Id> affiliationIds = new List<Id>();
        for (hed__Affiliation__c aff : affiliations) {
            affiliationIds.add(aff.Id);
        }
        
        Test.startTest();
        AffiliationToUserSyncBatchable batch = new AffiliationToUserSyncBatchable(affiliationIds);
        Database.executeBatch(batch);
        Test.stopTest();
        
        Contact updatedContact = [SELECT Id, LMS_ID__c, Registered__c FROM Contact LIMIT 1];
       
    }
    
    @isTest
    static void testBatchableNoContactIds() {
        Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());
        
        hed__Affiliation__c testAff = new hed__Affiliation__c(
            hed__Account__c = [SELECT Id FROM Account LIMIT 1].Id
        );
        insert testAff;
        
        hed__Program_Enrollment__c testPE = new hed__Program_Enrollment__c(
            hed__Affiliation__c = testAff.Id
        );
        insert testPE;
        
        List<Id> affiliationIds = new List<Id>{ testAff.Id };
        
        Test.startTest();
        AffiliationToUserSyncBatchable batch = new AffiliationToUserSyncBatchable(affiliationIds);
        Database.executeBatch(batch);
        Test.stopTest();
        
        List<Contact> contacts = [SELECT Id, LMS_ID__c FROM Contact];
        for (Contact c : contacts) {
            System.assertNotEquals('555666', c.LMS_ID__c);
        }
    }
    
    @isTest
    static void testBatchableUserStatusFalse() {
        Test.setMock(HttpCalloutMock.class, new UserStatusFalseHttpMock());
        
        List<hed__Affiliation__c> affiliations = [SELECT Id FROM hed__Affiliation__c LIMIT 1];
        List<Id> affiliationIds = new List<Id>();
        for (hed__Affiliation__c aff : affiliations) {
            affiliationIds.add(aff.Id);
        }
        
        Test.startTest();
        AffiliationToUserSyncBatchable batch = new AffiliationToUserSyncBatchable(affiliationIds);
        Database.executeBatch(batch);
        Test.stopTest();
        
        Contact updatedContact = [SELECT Id, LMS_ID__c, Registered__c FROM Contact LIMIT 1];
        
    }
    
    @isTest
    static void testBatchableEnrollStatusFalse() {
        Test.setMock(HttpCalloutMock.class, new EnrollStatusFalseHttpMock());
        
        List<hed__Affiliation__c> affiliations = [SELECT Id FROM hed__Affiliation__c LIMIT 1];
        List<Id> affiliationIds = new List<Id>();
        for (hed__Affiliation__c aff : affiliations) {
            affiliationIds.add(aff.Id);
        }
        
        Test.startTest();
        AffiliationToUserSyncBatchable batch = new AffiliationToUserSyncBatchable(affiliationIds);
        Database.executeBatch(batch);
        Test.stopTest();
        
        Contact updatedContact = [SELECT Id, LMS_ID__c, Registered__c FROM Contact LIMIT 1];
        System.assertEquals('555666', updatedContact.LMS_ID__c);
        System.assertEquals(true, updatedContact.Registered__c);
        
        
    }
    
    public class SuccessHttpMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            String responseBody = '{"data": [{"user": {"status": true, "recordId": "' + [SELECT Id FROM Contact LIMIT 1].Id + '", "lmsId": 555666}, "enroll": [{"status": true, "recordId": "' + [SELECT Id FROM hed__Course_Enrollment__c LIMIT 1].Id + '"}]}]}';
            res.setBody(responseBody);
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
    
    public class UserStatusFalseHttpMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            String responseBody = '{"data": [{"user": {"status": false, "recordId": "' + [SELECT Id FROM Contact LIMIT 1].Id + '", "lmsId": 555666}, "enroll": [{"status": true, "recordId": "' + [SELECT Id FROM hed__Course_Enrollment__c LIMIT 1].Id + '"}]}]}';
            res.setBody(responseBody);
            res.setStatusCode(200);
            return res;
        }
    }
    
    public class EnrollStatusFalseHttpMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            String responseBody = '{"data": [{"user": {"status": true, "recordId": "' + [SELECT Id FROM Contact LIMIT 1].Id + '", "lmsId": 555666}, "enroll": [{"status": false, "recordId": "' + [SELECT Id FROM hed__Course_Enrollment__c LIMIT 1].Id + '"}]}]}';
            res.setBody(responseBody);
            res.setStatusCode(200);
            return res;
        }
    }
}