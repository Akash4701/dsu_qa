@isTest
private class AffiliationEmailQueueTest {

    @testSetup
    static void setup() {
        Contact cOptedIn = new Contact(
            FirstName = 'Opted',
            LastName = 'In',
            Email = 'optedin@example.com',
            HasOptedOutOfEmail = false
        );
        Contact cOptedOut = new Contact(
            FirstName = 'Opted',
            LastName = 'Out',
            Email = 'optedout@example.com',
            HasOptedOutOfEmail = true
        );
        insert new List<Contact>{cOptedIn, cOptedOut};

        List<hed__Affiliation__c> affils = new List<hed__Affiliation__c>{
            new hed__Affiliation__c(
                hed__Contact__c = cOptedIn.Id,
                DSU_Email__c = 'dsu1@example.com'
            ),
            new hed__Affiliation__c(
                hed__Contact__c = cOptedOut.Id,
                DSU_Email__c = 'dsu2@example.com'
            ),
            new hed__Affiliation__c(
                hed__Contact__c = cOptedIn.Id,
                DSU_Email__c = null
            ),
            new hed__Affiliation__c(
                hed__Contact__c = null,
                DSU_Email__c = 'dsu3@example.com'
            )
        };
        insert affils;

        ContentVersion cv = new ContentVersion();
        cv.Title = 'TestAttachment';
        cv.PathOnClient = 'test.txt';
        cv.VersionData = Blob.valueOf('Test content');
        insert cv;

    }

    private static Id getContentDocumentId() {
        return [SELECT ContentDocumentId FROM ContentVersion WHERE Title = 'TestAttachment' LIMIT 1].ContentDocumentId;
    }

    @isTest
    static void testExecute_SendsEmailsAndLinksFiles() {
        List<hed__Affiliation__c> affils = [
            SELECT Id FROM hed__Affiliation__c WHERE DSU_Email__c != null
        ];
        System.assertEquals(3, affils.size()); 

        List<Id> affilIds = new List<Id>();
        for (hed__Affiliation__c a : affils) affilIds.add(a.Id);

        Id docId = getContentDocumentId();
        List<Id> fileDocIds = new List<Id>{docId};

        Test.startTest();
        System.enqueueJob(new AffiliationEmailQueue(affilIds, 'Test Subject', 'Test Body', fileDocIds));
        Test.stopTest();


        List<EmailMessage> emails = [
            SELECT Id, ToAddress, CcAddress, RelatedToId
            FROM EmailMessage
            WHERE Subject = 'Test Subject'
        ];
        System.assertEquals(3, emails.size());

        Set<Id> affilIdSet = new Set<Id>(affilIds);
        for (EmailMessage em : emails) {
            System.assert(affilIdSet.contains(em.RelatedToId), 'Email should be related to Affiliation');
        }

        Boolean foundCc = false;
        for (EmailMessage em : emails) {
            if (em.CcAddress != null && em.CcAddress.contains('optedin@example.com')) {
                foundCc = true;
            }
            System.assert(em.CcAddress == null || !em.CcAddress.contains('optedout@example.com'));
        }
        System.assert(foundCc, 'Opted-in contact should be CCed');

        List<ContentDocumentLink> links = [
            SELECT Id, LinkedEntityId
            FROM ContentDocumentLink
            WHERE ContentDocumentId = :docId
              AND LinkedEntityId IN :emails
        ];
        System.assertEquals(3, links.size(), 'Each email should have a file link');
    }

    @isTest
    static void testExecute_NoDSUEmail_Skipped() {
        hed__Affiliation__c affilNoDSU = [
            SELECT Id FROM hed__Affiliation__c WHERE DSU_Email__c = null LIMIT 1
        ];

        Test.startTest();
        System.enqueueJob(new AffiliationEmailQueue(
            new List<Id>{affilNoDSU.Id},
            'Test Subject',
            'Test Body',
            new List<Id>()
        ));
        Test.stopTest();

        System.assertEquals(0, Limits.getEmailInvocations());

        System.assertEquals(0, [SELECT count() FROM EmailMessage WHERE Subject = 'Test Subject']);
    }

    @isTest
    static void testExecute_WithEmptyFileDocIds_NoAttachment() {
        List<hed__Affiliation__c> affils = [
            SELECT Id FROM hed__Affiliation__c WHERE DSU_Email__c = 'dsu3@example.com'
        ];

        Test.startTest();
        System.enqueueJob(new AffiliationEmailQueue(
            new List<Id>{affils[0].Id},
            'No Attach Subject',
            'No Attach Body',
            new List<Id>() 
        ));
        Test.stopTest();

    }

    @isTest
    static void testExecute_BatchOf10_EmailsSentInBatches() {
        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < 12; i++) {
            contacts.add(new Contact(
                FirstName = 'Batch',
                LastName = 'User' + i,
                Email = 'batch' + i + '@example.com',
                HasOptedOutOfEmail = false
            ));
        }
        insert contacts;

        List<hed__Affiliation__c> affils = new List<hed__Affiliation__c>();
        for (Integer i = 0; i < 12; i++) {
            affils.add(new hed__Affiliation__c(
                hed__Contact__c = contacts[i].Id,
                DSU_Email__c = 'batchdsu' + i + '@example.com'
            ));
        }
        insert affils;

        List<Id> affilIds = new List<Id>();
        for (hed__Affiliation__c a : affils) affilIds.add(a.Id);

        Test.startTest();
        System.enqueueJob(new AffiliationEmailQueue(
            affilIds,
            'Batch Subject',
            'Batch Body',
            new List<Id>()
        ));
        Test.stopTest();

    }

    @isTest
    static void testExecute_FileDocIdsNull_SafeHandling() {
        List<hed__Affiliation__c> affils = [
            SELECT Id FROM hed__Affiliation__c WHERE DSU_Email__c = 'dsu1@example.com' LIMIT 1
        ];

        Test.startTest();
        System.enqueueJob(new AffiliationEmailQueue(
            new List<Id>{affils[0].Id},
            'Null Files Subject',
            'Body',
            null
        ));
        Test.stopTest();

  
    }

}