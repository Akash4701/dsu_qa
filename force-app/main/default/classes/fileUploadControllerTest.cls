@isTest
private class fileUploadControllerTest {
    
    @isTest
    static void testUploadAndGetPublicUrl() {
        String fileName = 'testFile.txt';
        String base64Content = EncodingUtil.base64Encode(Blob.valueOf('Test content'));
        
        Test.startTest();
        String result = fileUploadController.uploadAndGetPublicUrl(fileName, base64Content);
        Test.stopTest();
    }
    
    @isTest
    static void testSaveFileRecord() {
        Announcement__c announcement = new Announcement__c(Description__c = 'Test');
        insert announcement;
        
        String fileUrl = 'https://example.com/testfile';
        String fileName = 'testFile.txt';
        
        Test.startTest();
        fileUploadController.saveFileRecord(announcement.Id, fileUrl, fileName);
        Test.stopTest();
    }
    
    @isTest
    static void testSaveFileRecordWithBlankFolderId() {
        Test.startTest();
        try {
            fileUploadController.saveFileRecord('', 'testUrl', 'testFile');
        } catch (AuraHandledException e) {
        }
        Test.stopTest();
    }
}