@isTest
private class DocumentRestServiceTest {

    @isTest
    static void testCreateDocument() {
        // Create a dummy record to attach the document to, e.g. an Account
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        // Prepare JSON request body with:
        // - recordId: the Account Id
        // - versionData: base64 encoded string (simple example)
        // - title: document title
        String fileContent = 'Hello, this is test content!';
        String base64Encoded = EncodingUtil.base64Encode(Blob.valueOf(fileContent));

        Map<String, Object> requestMap = new Map<String, Object>{
            'recordId' => acc.Id,
            'versionData' => base64Encoded,
            'title' => 'TestDocument.txt'
        };
        String requestBody = JSON.serialize(requestMap);

        // Setup RestRequest and RestResponse context for testing
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestUri = '/services/apexrest/createDocument';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(requestBody);

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DocumentRestService.createDocument();
        Test.stopTest();

        // Assert response status code 200 (success)
        
    }
}