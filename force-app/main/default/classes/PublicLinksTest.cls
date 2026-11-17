@IsTest
public class PublicLinksTest {
    
    @TestSetup
    static void setupTestData() {
        
        // Create a test ContentVersion linked to the above ContentDocument
        ContentVersion contentVersion = new ContentVersion();
        contentVersion.Title = 'Test Content Version';
        contentVersion.PathOnClient = 'testdoc.pdf';
        contentVersion.VersionData = Blob.valueOf('Test data');
        insert contentVersion;
    }
    
    @IsTest
    static void testGeneratePublicLinks() {
        // Retrieve test ContentVersion for input to the method
        ContentVersion contentVersion = [SELECT Id, Title FROM ContentVersion LIMIT 1];

        // Call the method to be tested
        List<ContentVersion> newRecords = new List<ContentVersion>{contentVersion};
        Test.startTest();
        PublicLinks.generatePublicLinks(newRecords);
        Test.stopTest();
        
        // Verify ContentDistribution record is created
        List<ContentDistribution> distributions = [SELECT Id, Name, ContentVersionId, PreferencesAllowViewInBrowser 
                                                   FROM ContentDistribution WHERE ContentVersionId =: contentVersion.Id];
        
        System.assertEquals(1, distributions.size(), 'There should be one ContentDistribution record');
        System.assertEquals(contentVersion.Title, distributions[0].Name, 'The Name should match the ContentVersion Title');
        System.assertEquals(contentVersion.Id, distributions[0].ContentVersionId, 'The ContentVersionId should match');
   //     System.assertTrue(distributions[0].PreferencesAllowViewInBrowser, 'PreferencesAllowViewInBrowser should be true');
    }
    
    @IsTest
    static void testGeneratePublicLinksWithEmptyRecords() {
        // Call the method with an empty list
        Test.startTest();
        PublicLinks.generatePublicLinks(new List<ContentVersion>());
        Test.stopTest();

        // Verify that no ContentDistribution records are created
        List<ContentDistribution> distributions = [SELECT Id FROM ContentDistribution];
        System.assertEquals(0, distributions.size(), 'There should be no ContentDistribution records');
    }
    
    @IsTest
    static void testGeneratePublicLinksWithMultipleRecords() {
       
        ContentVersion contentVersion2 = new ContentVersion();
        contentVersion2.Title = 'Test Content Version 2';
        contentVersion2.PathOnClient = 'testdoc2.pdf';
        contentVersion2.VersionData = Blob.valueOf('Test data 2');
        insert contentVersion2;
        
        // Retrieve test ContentVersion records
        List<ContentVersion> newRecords = [SELECT Id, Title FROM ContentVersion];
        
        // Call the method with multiple records
        Test.startTest();
        PublicLinks.generatePublicLinks(newRecords);
        Test.stopTest();
        
        // Verify multiple ContentDistribution records are created
        List<ContentDistribution> distributions = [SELECT Id, Name, ContentVersionId 
                                                   FROM ContentDistribution WHERE ContentVersionId IN :newRecords];
        System.assertEquals(2, distributions.size(), 'There should be two ContentDistribution records');
    }
}