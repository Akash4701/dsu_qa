@isTest
private class StatementOfPurposeApiTest {

    @isTest
    static void testGetStatementOfPurposeApi_withSOP() {
        // Create a dummy application record
        Account appRecord = new Account(Name = 'Test Application');
        insert appRecord;

        // Create ContentVersion (automatically creates ContentDocument)
        ContentVersion cv = new ContentVersion(
            Title = 'Statement of Purpose - Test',
            PathOnClient = 'Statement_of_Purpose.pdf',
            VersionData = Blob.valueOf('Sample PDF Content'),
            IsMajorVersion = true
        );
        insert cv;

        // Query ContentDocumentId after insert
        Id contentDocumentId = [
            SELECT ContentDocumentId 
            FROM ContentVersion 
            WHERE Id = :cv.Id
        ].ContentDocumentId;

        // Link ContentDocument to Application
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = contentDocumentId,
            LinkedEntityId = appRecord.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert cdl;

        // Simulate REST request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/StatementOfPurpose/' + appRecord.Id;
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = res;

        // Call the method
        StatementOfPurposeApi.StatementOfPurposeResponse response = StatementOfPurposeApi.getStatementOfPurposeApi();

        // Validate response
        System.assertEquals(true, response.hasStatementOfPurpose, 'SOP should be found.');
        System.assertNotEquals(null, response.contentDocumentId, 'ContentDocumentId should not be null.');
        System.assertNotEquals(null, response.contentVersionId, 'ContentVersionId should not be null.');
    }

    @isTest
    static void testGetStatementOfPurposeApi_withoutSOP() {
        // Create a dummy application record
        Account appRecord = new Account(Name = 'Test Application No SOP');
        insert appRecord;

        // Simulate REST request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/StatementOfPurpose/' + appRecord.Id;
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = res;

        // Call the method
        StatementOfPurposeApi.StatementOfPurposeResponse response = StatementOfPurposeApi.getStatementOfPurposeApi();

        // Validate no SOP found
        System.assertEquals(false, response.hasStatementOfPurpose, 'No SOP should be found.');
        System.assertEquals(null, response.contentDocumentId, 'ContentDocumentId should be null.');
        System.assertEquals(null, response.contentVersionId, 'ContentVersionId should be null.');
    }
}