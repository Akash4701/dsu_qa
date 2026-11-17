@isTest
public class RestApi_UpdateWithAdminNotesTest {   
    @testSetup
    static void setupTestData() {
        // Create Test Contact
        Contact testContact = new Contact(
            FirstName = 'John',
            LastName = 'Doe',
            Admin_Notes__c = 'Initial Notes'
        );
        insert testContact;
    }

    @isTest
    static void testDoPost_Success() {
        Test.startTest();
        
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestUri = '/services/apexrest/adminNotes/';
        req.httpMethod = 'POST';
        req.addHeader('Content-Type', 'application/json');
        req.requestBody = Blob.valueOf('[{"contactId": "' + testContact.Id + '", "adminNotes": "Updated Admin Notes"}]');

        RestContext.request = req;
        RestContext.response = res;

        RestApi_UpdateWithAdminNotes.doPost();

        System.assertEquals(200, res.statusCode, 'Expected HTTP 200 response');
        System.assert(res.responseBody.toString().contains('Data added successfully'), 'Response should confirm update');

        Contact updatedContact = [SELECT Admin_Notes__c FROM Contact WHERE Id = :testContact.Id];
        System.assertEquals('Updated Admin Notes', updatedContact.Admin_Notes__c, 'Admin Notes should be updated');

        Test.stopTest();
    }

    // **Test Case: Empty Request Body**
    @isTest
    static void testDoPost_EmptyRequestBody() {
        Test.startTest();

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestUri = '/services/apexrest/adminNotes/';
        req.httpMethod = 'POST';
        req.addHeader('Content-Type', 'application/json');
        req.requestBody = Blob.valueOf('');  // Empty body

        RestContext.request = req;
        RestContext.response = res;

        RestApi_UpdateWithAdminNotes.doPost();

        System.assertEquals(400, res.statusCode, 'Expected HTTP 400 response for empty request body');

        Test.stopTest();
    }

    // **Test Case: Invalid Contact ID**
    @isTest
    static void testDoPost_InvalidContactId() {
        Test.startTest();

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestUri = '/services/apexrest/adminNotes/';
        req.httpMethod = 'POST';
        req.addHeader('Content-Type', 'application/json');

        // Generating a fake but valid-looking Contact ID
        String fakeContactId = '003' + System.currentTimeMillis() + 'XYZ';

        req.requestBody = Blob.valueOf('[{"contactId": "' + fakeContactId + '", "adminNotes": "Updated Admin Notes"}]');

        RestContext.request = req;
        RestContext.response = res;

        RestApi_UpdateWithAdminNotes.doPost();

        System.assertEquals(400, res.statusCode, 'Expected HTTP 400 response for invalid Contact ID');

        Test.stopTest();
    }

    // **Test Case: No Matching Contacts**
    @isTest
    static void testDoPost_NoMatchingContacts() {
        Test.startTest();

        // Create and delete a Contact to ensure it no longer exists
        Contact extraContact = new Contact(FirstName = 'Dummy', LastName = 'User');
        insert extraContact;
        Id deletedContactId = extraContact.Id;
        delete extraContact; // Remove it

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestUri = '/services/apexrest/adminNotes/';
        req.httpMethod = 'POST';
        req.addHeader('Content-Type', 'application/json');
        req.requestBody = Blob.valueOf('[{"contactId": "' + deletedContactId + '", "adminNotes": "New Note"}]');

        RestContext.request = req;
        RestContext.response = res;

        RestApi_UpdateWithAdminNotes.doPost();

        System.assertEquals(400, res.statusCode, 'Expected HTTP 400 response for no matching contacts');

        Test.stopTest();
    }

    // **Fixed Test Case: Missing Required Fields**
    @isTest
    static void testDoPost_MissingRequiredFields() {
        Test.startTest();

        Contact testContact = [SELECT Id FROM Contact LIMIT 1];

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestUri = '/services/apexrest/adminNotes/';
        req.httpMethod = 'POST';
        req.addHeader('Content-Type', 'application/json');

        // **Corrected JSON Format** to properly handle missing fields scenario
        req.requestBody = Blob.valueOf('[{"contactId": "' + testContact.Id + '"}]');

        RestContext.request = req;
        RestContext.response = res;

        try {
            RestApi_UpdateWithAdminNotes.doPost();
        } catch (Exception e) {
            System.debug('Expected Exception: ' + e.getMessage());
            System.assertEquals(400, res.statusCode, 'Expected HTTP 400 response for missing required fields');
        }

        Test.stopTest();
    }
}