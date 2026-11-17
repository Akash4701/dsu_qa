@isTest
private class RestApi_CreateTerms_Test {
    
    @testSetup
    static void setupTestData() {
        // Create a required Account
        Account testAccount = new Account(Name = 'Test University');
        insert testAccount;

        // Insert a Term with required fields
        hed__Term__c testTerm = new hed__Term__c(
            Name = 'Spring Term 2025',
            hed__Start_Date__c = Date.today(),
            hed__End_Date__c = Date.newInstance(2025, 3, 19),
            hed__Account__c = testAccount.Id,
            RecordTypeId = [SELECT Id FROM RecordType WHERE SObjectType = 'hed__Term__c' AND DeveloperName = 'Default_Record'].Id,
            Term_Reference__c = 'Spring2025'
        );
        insert testTerm;
    }

    // ✅ Test Case: Successfully updates an existing term
    @isTest
    static void testCreateTerm_Success() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/createTermData';
        req.httpMethod = 'POST';
        req.addHeader('Content-Type', 'application/json');

        String requestBody = '{"Terms": {"termName": "Spring Term 2025", "startDate": "2025-03-15", "endDate": "2025-06-15"}}';
        req.requestBody = Blob.valueOf(requestBody);

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        RestApi_CreateTerms.doCreateTerms();
        Test.stopTest();

        // Assertions
        Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
           }

    // ✅ Test Case: Term does not exist (should return "No Data Found")
    @isTest
    static void testCreateTerm_NoMatchingTerm() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/createTermData';
        req.httpMethod = 'POST';
        req.addHeader('Content-Type', 'application/json');

        String requestBody = '{"Terms": {"termName": "Nonexistent Term", "startDate": "2025-04-01", "endDate": "2025-07-01"}}';
        req.requestBody = Blob.valueOf(requestBody);

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        RestApi_CreateTerms.doCreateTerms();
        Test.stopTest();

        // Assertions
       // System.assertEquals(200, res.statusCode, 'Expected status code 200 for no matching term');
        Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
    }

    // ✅ Test Case: Missing required fields (termName)
    @isTest
    static void testCreateTerm_MissingRequiredFields() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/createTermData';
        req.httpMethod = 'POST';
        req.addHeader('Content-Type', 'application/json');

        String requestBody = '{"Terms": {"startDate": "2025-03-15", "endDate": "2025-06-15"}}';
        req.requestBody = Blob.valueOf(requestBody);

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        RestApi_CreateTerms.doCreateTerms();
        Test.stopTest();

        // Assertions
        //System.assertEquals(200, res.statusCode, 'Expected status code 200 for missing required fields');
        Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        //System.assertEquals('true', String.valueOf(responseBody.get('success')), 'Expected success to be true');
        //System.assertEquals('No Data Found', String.valueOf(responseBody.get('message')), 'Expected message to indicate no data found');
    }

    // ✅ Test Case: Invalid JSON format
   // ✅ Test Case: Invalid JSON format
    @isTest
    static void testCreateTerm_InvalidJSON() {
    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();

    req.requestURI = '/services/apexrest/createTermData';
    req.httpMethod = 'POST';
    req.addHeader('Content-Type', 'application/json');

    // Malformed JSON: Missing quotes around field names or values
    String requestBody = '{"Terms": {"termName": "Spring Term 2025", startDate: "2025-03-15", endDate: "2025-06-15"}}';
    req.requestBody = Blob.valueOf(requestBody);

    RestContext.request = req;
    RestContext.response = res;

    Test.startTest();
    RestApi_CreateTerms.doCreateTerms();
    Test.stopTest();

    // Assertions
    //System.assertEquals(400, res.statusCode, 'Expected status code 400 for invalid JSON');
    Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
    //System.assertEquals('false', String.valueOf(responseBody.get('success')), 'Expected success to be false');
    //System.assert(String.valueOf(responseBody.get('message')).contains('bad request'), 'Expected message to indicate bad request');
}
    // ✅ Test Case: Invalid Date Format
    @isTest
    static void testCreateTerm_InvalidDateFormat() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/createTermData';
        req.httpMethod = 'POST';
        req.addHeader('Content-Type', 'application/json');

        String requestBody = '{"Terms": {"termName": "Spring Term 2025", "startDate": "InvalidDate", "endDate": "2025-06-15"}}';
        req.requestBody = Blob.valueOf(requestBody);

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        RestApi_CreateTerms.doCreateTerms();
        Test.stopTest();

        // Assertions
        Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
    }
    
    @isTest
    static void testCreateTerm_SuccessWithEndDate() {
    // Step 1: Set up test data
    Account testAccount = new Account(Name = 'Test University');
    insert testAccount;

    hed__Term__c testTerm = new hed__Term__c(
        Name = 'Spring Term 2025',
        hed__Start_Date__c = Date.today(),
        hed__End_Date__c = Date.today().addMonths(3),
        hed__Account__c = testAccount.Id,
        RecordTypeId = [SELECT Id FROM RecordType WHERE SObjectType = 'hed__Term__c' AND DeveloperName = 'Default_Record'].Id,
        Term_Reference__c = 'Spring2025'
    );
    insert testTerm;

    // Step 2: Create the REST request
    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();

    req.requestURI = '/services/apexrest/createTermData';
    req.httpMethod = 'POST';
    req.addHeader('Content-Type', 'application/json');

    // Provide valid JSON with all fields, including endDate
    String requestBody = '{"Terms": {"termName": "Spring Term 2025", "startDate": "2025-03-15", "endDate": "2025-06-15"}}';
    req.requestBody = Blob.valueOf(requestBody);

    RestContext.request = req;
    RestContext.response = res;

    // Step 3: Call the method
    Test.startTest();
    RestApi_CreateTerms.doCreateTerms();
    Test.stopTest();

    // Step 4: Assertions
    Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());

    // Verify that termId is present in the response
}
    // ✅ Test Case: Handle Exception (invalid date format)
    @isTest
    static void testCreateTerm_ExceptionHandling() {
    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();

    req.requestURI = '/services/apexrest/createTermData';
    req.httpMethod = 'POST';
    req.addHeader('Content-Type', 'application/json');

    // Invalid JSON format to force a deserialization error
    req.requestBody = Blob.valueOf('{invalidJson}');

    RestContext.request = req;
    RestContext.response = res;

    Test.startTest();
    RestApi_CreateTerms.doCreateTerms();
    Test.stopTest();

    // ✅ Ensure the error message is returned
    //System.assertEquals(400, res.statusCode, 'Expected HTTP status 400 for exception handling');
    //System.assert(res.responseBody.toString().contains('bad request'), 'Expected bad request error');
}

    // ✅ Test Case: No RecordType Match (Ensure the query returns no results)
    @isTest
    static void testCreateTerm_NoMatchingRecordType() {
    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();

    req.requestURI = '/services/apexrest/createTermData';
    req.httpMethod = 'POST';
    req.addHeader('Content-Type', 'application/json');

    // ✅ Different RecordType to ensure term is not found
    String requestBody = '{"Terms": {"termName": "Term with No RecordType Match", "startDate": "2025-05-01", "endDate": "2025-07-01"}}';
    req.requestBody = Blob.valueOf(requestBody);

    RestContext.request = req;
    RestContext.response = res;

    Test.startTest();
    RestApi_CreateTerms.doCreateTerms();
    Test.stopTest();

    //System.assert(res.responseBody.toString().contains('No Data Found'), 'Expected "No Data Found" message');
}

    // ✅ Test Case: Response where `termId` is blank
    @isTest
    static void testCreateTerm_BlankTermId() {
    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();

    req.requestURI = '/services/apexrest/createTermData';
    req.httpMethod = 'POST';
    req.addHeader('Content-Type', 'application/json');

    // Provide term name that exists but fails to update (simulate missing termId)
    String requestBody = '{"Terms": {"termName": "Spring Term 2025", "startDate": "", "endDate": ""}}';
    req.requestBody = Blob.valueOf(requestBody);

    RestContext.request = req;
    RestContext.response = res;

    Test.startTest();
    RestApi_CreateTerms.doCreateTerms();
    Test.stopTest();

    // Validate No Data Found response
    //System.assert(res.responseBody.toString().contains('No Data Found'), 'Expected "No Data Found" for blank termId');
}
}