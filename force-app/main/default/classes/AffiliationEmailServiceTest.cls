@isTest
private class AffiliationEmailServiceTest {

    @testSetup
    static void setup() {
        Contact contactOptedIn = new Contact(
            FirstName = 'Opted',
            LastName = 'In',
            Email = 'optedin@example.com',
            HasOptedOutOfEmail = false
        );
        Contact contactOptedOut = new Contact(
            FirstName = 'Opted',
            LastName = 'Out',
            Email = 'optedout@example.com',
            HasOptedOutOfEmail = true
        );
        insert new List<Contact>{ contactOptedIn, contactOptedOut };

        List<hed__Affiliation__c> affiliations = new List<hed__Affiliation__c>{
            new hed__Affiliation__c(
                hed__Contact__c = contactOptedIn.Id,
                DSU_Email__c = 'dsu1@example.com'
            ),
            new hed__Affiliation__c(
                hed__Contact__c = contactOptedOut.Id,
                DSU_Email__c = 'dsu2@example.com'
            ),
            new hed__Affiliation__c(
                hed__Contact__c = contactOptedIn.Id,
                DSU_Email__c = null
            ),
            new hed__Affiliation__c(
                hed__Contact__c = null,
                DSU_Email__c = 'dsu3@example.com'
            )
        };
        insert affiliations;

        List<hed__Affiliation__c> batchAffiliations = new List<hed__Affiliation__c>();
        for (Integer i = 0; i < 7; i++) {
            batchAffiliations.add(new hed__Affiliation__c(
                hed__Contact__c = contactOptedIn.Id,
                DSU_Email__c = 'batch' + i + '@example.com'
            ));
        }
        insert batchAffiliations;

        ContentVersion contentVersion = new ContentVersion();
        contentVersion.Title = 'AffilEmailAttachment';
        contentVersion.PathOnClient = 'affil.txt';
        contentVersion.VersionData = Blob.valueOf('Attachment content');
        insert contentVersion;
    }

    private static Id getContentDocumentId() {
        return [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Title = 'AffilEmailAttachment'
            LIMIT 1
        ].ContentDocumentId;
    }

    @isTest
    static void testSendWithFiles() {
        List<Id> affiliationIds = new List<Id>();
        for (hed__Affiliation__c affiliation : [
            SELECT Id
            FROM hed__Affiliation__c
            WHERE DSU_Email__c IN ('dsu1@example.com', 'dsu2@example.com')
        ]) {
            affiliationIds.add(affiliation.Id);
        }
        System.assertEquals(2, affiliationIds.size());

        List<Id> fileDocumentIds = new List<Id>{ getContentDocumentId() };

        Test.startTest();
        AffiliationEmailService.send(affiliationIds, 'Files Subject', 'Files Body', fileDocumentIds);
        Test.stopTest();

        List<EmailMessage> emails = [
            SELECT Id, CcAddress
            FROM EmailMessage
            WHERE Subject = 'Files Subject'
        ];
        System.assertEquals(2, emails.size());

        Boolean foundOptedInCc = false;
        for (EmailMessage emailMessage : emails) {
            if (emailMessage.CcAddress != null && emailMessage.CcAddress.contains('optedin@example.com')) {
                foundOptedInCc = true;
            }
            System.assert(emailMessage.CcAddress == null || !emailMessage.CcAddress.contains('optedout@example.com'));
        }
        System.assert(foundOptedInCc, 'Opted-in contact should be CCed');

        List<ContentDocumentLink> documentLinks = [
            SELECT Id
            FROM ContentDocumentLink
            WHERE ContentDocumentId = :fileDocumentIds[0]
              AND LinkedEntityId IN :emails
        ];
        System.assertEquals(2, documentLinks.size());
    }

    @isTest
    static void testSendWithFiles_OverTenRecipients_NoDuplicateLinkError() {
        Contact contactOptedIn = [SELECT Id FROM Contact WHERE Email = 'optedin@example.com' LIMIT 1];
        List<hed__Affiliation__c> extraAffiliations = new List<hed__Affiliation__c>();
        for (Integer i = 0; i < 11; i++) {
            extraAffiliations.add(new hed__Affiliation__c(
                hed__Contact__c = contactOptedIn.Id,
                DSU_Email__c = 'bulk' + i + '@example.com'
            ));
        }
        insert extraAffiliations;

        List<Id> affiliationIds = new List<Id>();
        for (hed__Affiliation__c affiliation : extraAffiliations) {
            affiliationIds.add(affiliation.Id);
        }
        List<Id> fileDocumentIds = new List<Id>{ getContentDocumentId() };

        Test.startTest();
        AffiliationEmailService.send(affiliationIds, 'OverTen Files Subject', 'Body', fileDocumentIds);
        Test.stopTest();

        System.assertEquals(11, [SELECT count() FROM EmailMessage WHERE Subject = 'OverTen Files Subject']);
        List<EmailMessage> emails = [SELECT Id FROM EmailMessage WHERE Subject = 'OverTen Files Subject'];
        System.assertEquals(
            11,
            [
                SELECT count()
                FROM ContentDocumentLink
                WHERE ContentDocumentId = :fileDocumentIds[0] AND LinkedEntityId IN :emails
            ]
        );
    }

    @isTest
    static void testBatchOf10_SendInLoop() {
        List<Id> affiliationIds = new List<Id>();
        for (hed__Affiliation__c affiliation : [
            SELECT Id
            FROM hed__Affiliation__c
            WHERE DSU_Email__c != null
            LIMIT 10
        ]) {
            affiliationIds.add(affiliation.Id);
        }
        System.assertEquals(10, affiliationIds.size());

        Test.startTest();
        AffiliationEmailService.send(affiliationIds, 'Batch10 Subject', 'Batch10 Body', new List<Id>());
        Test.stopTest();

        System.assertEquals(10, [SELECT count() FROM EmailMessage WHERE Subject = 'Batch10 Subject']);
    }

    @isTest
    static void testSkipBlankAndInvalidContentVersion_NullFiles() {
        Id blankAffiliationId = [
            SELECT Id
            FROM hed__Affiliation__c
            WHERE DSU_Email__c = null
            LIMIT 1
        ].Id;
        Id invalidDocumentId = [SELECT Id FROM Contact LIMIT 1].Id;

        Test.startTest();
        AffiliationEmailService.send(
            new List<Id>{ blankAffiliationId },
            'NoSend Subject',
            'NoSend Body',
            new List<Id>{ invalidDocumentId }
        );
        AffiliationEmailService.send(
            new List<Id>{ blankAffiliationId },
            'NullFiles Subject',
            'NullFiles Body',
            null
        );
        Test.stopTest();

        System.assertEquals(0, [SELECT count() FROM EmailMessage WHERE Subject = 'NoSend Subject']);
        System.assertEquals(0, [SELECT count() FROM EmailMessage WHERE Subject = 'NullFiles Subject']);
    }
}