@isTest
public class RestAPI_ContactAttachmentService_Test {
    
    @testSetup
    static void setupTestData() {
        // Create test Contact for attachments
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            Email = 'test@example.com'
        );
        insert testContact;
        
        // Create test Attachment
        Attachment testAttachment = new Attachment(
            Name = 'TestFile.txt',
            Body = Blob.valueOf('Test file content'),
            ParentId = testContact.Id,
            ContentType = 'text/plain'
        );
        insert testAttachment;
    }
    
    @isTest
    static void testPostService_Success() {
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];
        
        // Setup REST context
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/ContactAttachment/' + testContact.Id;
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('Test attachment content');
        req.headers.put('Content-Type', 'application/pdf');
        req.params.put('filename', 'TestDocument.pdf');
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        RestAPI_ContactAttachmentService.initPostService();
        Test.stopTest();
     
    }
    
    @isTest
    static void testPostService_NoRequestBody() {
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/ContactAttachment/' + testContact.Id;
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('');
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        RestAPI_ContactAttachmentService.initPostService();
        Test.stopTest();
    
    }
    
    @isTest
    static void testPostService_ValidationErrors() {
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/ContactAttachment/' + testContact.Id;
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('Test content');
        // Missing Content-Type header
        // Missing filename parameter
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        RestAPI_ContactAttachmentService.initPostService();
        Test.stopTest();

    }
    
    @isTest
    static void testPostService_FileNameTooLong() {
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/ContactAttachment/' + testContact.Id;
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('Test content');
        req.headers.put('Content-Type', 'text/plain');
        req.params.put('filename', 'ThisIsAVeryLongFileNameThatExceedsTheEightyCharacterLimitAndShouldCauseValidationError.txt');
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        RestAPI_ContactAttachmentService.initPostService();
        Test.stopTest();
     
    }
    
    @isTest
    static void testPostService_Exception() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/ContactAttachment/invalidId';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('Test content');
        req.headers.put('Content-Type', 'text/plain');
        req.params.put('filename', 'test.txt');
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        RestAPI_ContactAttachmentService.initPostService();
        Test.stopTest();
        
     
    }
    
    @isTest
    static void testGetAttachments_Success() {
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/ContactAttachment/';
        req.httpMethod = 'GET';
        req.params.put('recordId', testContact.Id);
        req.params.put('fileName', 'TestFile');
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        RestAPI_ContactAttachmentService.getAttachments();
        Test.stopTest();
        
    }
    
    @isTest
    static void testGetAttachments_MissingParameters() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/ContactAttachment/';
        req.httpMethod = 'GET';
        // Missing recordId and fileName parameters
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        RestAPI_ContactAttachmentService.getAttachments();
        Test.stopTest();
        

    }
    
    @isTest
    static void testGetAttachments_NoMatchingFiles() {
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/ContactAttachment/';
        req.httpMethod = 'GET';
        req.params.put('recordId', testContact.Id);
        req.params.put('fileName', 'NonExistentFile');
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        RestAPI_ContactAttachmentService.getAttachments();
        Test.stopTest();
       
    }
    
    @isTest
    static void testGetAttachments_Exception() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/ContactAttachment/';
        req.httpMethod = 'GET';
        req.params.put('recordId', 'invalidId');
        req.params.put('fileName', 'test');
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        RestAPI_ContactAttachmentService.getAttachments();
        Test.stopTest();
        
    }
    
    @isTest
    static void testDeleteAttachment_Success() {
        Attachment testAttachment = [SELECT Id FROM Attachment LIMIT 1];
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/ContactAttachment/';
        req.httpMethod = 'DELETE';
        req.params.put('Id', testAttachment.Id);
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        RestAPI_ContactAttachmentService.deleteAttachment();
        Test.stopTest();
    
    }
    
    @isTest
    static void testDeleteAttachment_NotFound() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/ContactAttachment/';
        req.httpMethod = 'DELETE';
        req.params.put('Id', 'nonExistentId');
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        RestAPI_ContactAttachmentService.deleteAttachment();
        Test.stopTest();
        
    }
    
    @isTest
    static void testFileModel_Constructor() {
        String testFileId = 'test123';
        String testFileName = 'test.txt';
        String testFileType = 'text/plain';
        Blob testBody = Blob.valueOf('test content');
        
        Test.startTest();
        RestAPI_ContactAttachmentService.FileModel fileModel = 
            new RestAPI_ContactAttachmentService.FileModel(testFileId, testFileName, testFileType, testBody);
        Test.stopTest();
        
    }
    
    @isTest
    static void testPostService_UpsertWithRecordId() {
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];
        Attachment existingAttachment = [SELECT Id FROM Attachment LIMIT 1];
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/ContactAttachment/' + testContact.Id;
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('Updated content');
        req.headers.put('Content-Type', 'application/pdf');
        req.params.put('filename', 'UpdatedFile.pdf');
        req.params.put('recordId', existingAttachment.Id);
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        RestAPI_ContactAttachmentService.initPostService();
        Test.stopTest();
        
      }
}