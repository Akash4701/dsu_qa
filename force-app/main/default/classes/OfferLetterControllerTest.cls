@isTest
private class OfferLetterControllerTest {

    @testSetup
    static void setupTestData() {
        // Create test Account and Contact
        Account testInstitution = new Account(Name = 'Test University');
        insert testInstitution;

        Contact testStudent = new Contact(
            FirstName = 'Test',
            LastName = 'Student'
        );
        insert testStudent;

        // Create a related Affiliation record
        hed__Affiliation__c testAffiliation = new hed__Affiliation__c(
            hed__Account__c = testInstitution.Id,
            hed__Contact__c = testStudent.Id,
            Roll_Number__c = 'TEST001'
        );
        insert testAffiliation;
    }

    @isTest
    static void testConstructor() {
        hed__Affiliation__c testAffiliation = [
            SELECT Id, Roll_Number__c
            FROM hed__Affiliation__c
            LIMIT 1
        ];

        ApexPages.StandardController stdController = new ApexPages.StandardController(testAffiliation);
        OfferLetterController controller = new OfferLetterController(stdController);

        System.assertNotEquals(null, controller.affiliationRecord, 'Affiliation record should not be null');
        System.assertEquals(testAffiliation.Id, controller.affiliationRecord.Id, 'Affiliation ID should match');
        System.assertEquals('TEST001', controller.affiliationRecord.Roll_Number__c, 'Roll number should match');
    }

    @isTest
    static void testGenerateAndAttachPDF_Success() {
        hed__Affiliation__c testAffiliation = [
            SELECT Id
            FROM hed__Affiliation__c
            LIMIT 1
        ];

        // Simulate running within a Visualforce page context
        Test.setCurrentPage(Page.OfferLetterPage);

        Test.startTest();
        OfferLetterController.generateAndAttachPDF(testAffiliation.Id);
        Test.stopTest();

        // Verify that the ContentDocumentLink was created
        List<ContentDocumentLink> links = [
            SELECT Id, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :testAffiliation.Id
        ];
        System.assert(!links.isEmpty(), 'A ContentDocumentLink should have been created and linked to the Affiliation');
    }

    @isTest
    static void testGenerateAndAttachPDF_BlankId() {
        Boolean caught = false;

        Test.startTest();
        try {
            OfferLetterController.generateAndAttachPDF(null);
        } catch (AuraHandledException e) {
            caught = true;
        //    System.assertEquals('Affiliation Id is required', e.getMessage(), 'Correct error message should be returned');
        }
        Test.stopTest();

        System.assert(caught, 'Should catch AuraHandledException for null Id');
    }
}