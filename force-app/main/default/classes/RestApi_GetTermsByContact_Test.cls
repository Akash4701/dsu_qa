@isTest
private class RestApi_GetTermsByContact_Test {

    @testSetup
    static void setupTestData() {
        Account acc = new Account(Name = 'Test Institution');
        insert acc;
        // Create Contact
        Contact testContact = new Contact(FirstName = 'Test', LastName = 'Student');
        insert testContact;

        // Create Term
        hed__Term__c term = new hed__Term__c(
            Name = 'Fall 2024',
            hed__Start_Date__c = Date.today().addMonths(-6), 
            hed__End_Date__c = Date.today().addMonths(-3),
            Term_Reference__c='Semester 1',
			hed__Account__c=acc.Id
           );
        insert term;

        // Create Affiliation
        hed__Affiliation__c affiliation = new hed__Affiliation__c(
            hed__Contact__c = testContact.Id,
            hed__Account__c = acc.Id, // Dummy value
            hed__Status__c = 'Current'
            
        );
        insert affiliation;

        // Create Program Enrollment
        hed__Program_Enrollment__c enrollment = new hed__Program_Enrollment__c(
            hed__Contact__c = testContact.Id,
            hed__Affiliation__c = affiliation.Id,
            Term__c = term.Id,
            RecordTypeId = Schema.SObjectType.hed__Program_Enrollment__c.getRecordTypeInfosByName().get('Student').getRecordTypeId()
        );
        insert enrollment;
    }

    @isTest
    static void testDoGet_withValidContactAndData() {
        Contact contact = [SELECT Id FROM Contact LIMIT 1];

        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/TermsHistory/';
        req.httpMethod = 'GET';
        req.params.put('contactId', contact.Id);

        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        RestApi_GetTermsByContact.doGet();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        System.assert(RestContext.response.responseBody.toString().contains('"success": "true"'), 'Response should indicate success');
        System.assert(RestContext.response.responseBody.toString().contains(contact.Id), 'Response should contain contact ID');
    }

    @isTest
    static void testDoGet_withValidContactNoEnrollments() {
        Contact newContact = new Contact(FirstName = 'No', LastName = 'Enrollments');
        insert newContact;

        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/TermsHistory/';
        req.httpMethod = 'GET';
        req.params.put('contactId', newContact.Id);

        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        RestApi_GetTermsByContact.doGet();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        System.assert(RestContext.response.responseBody.toString().contains('"data": []'), 'Response should contain empty data array');
    }

    @isTest
    static void testDoGet_withInvalidContactId() {
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/TermsHistory/';
        req.httpMethod = 'GET';
        req.params.put('contactId', 'invalid-id');

        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        RestApi_GetTermsByContact.doGet();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        System.assert(RestContext.response.responseBody.toString().contains('Invalid Parameters'), 'Should detect invalid contactId');
    }

    @isTest
    static void testDoGet_withoutContactId() {
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/TermsHistory/';
        req.httpMethod = 'GET';

        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        RestApi_GetTermsByContact.doGet();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        System.assert(RestContext.response.responseBody.toString().contains('Invalid Parameters'), 'Missing contactId should be handled');
    }
}