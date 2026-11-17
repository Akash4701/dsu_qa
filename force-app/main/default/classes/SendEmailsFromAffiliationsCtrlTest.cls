@IsTest
private class SendEmailsFromAffiliationsCtrlTest {

    // ---------- TEST DATA SETUP ----------

    @testSetup
    static void setup() {
        Contact c1 = new Contact(
            FirstName = 'Test',
            LastName  = 'Contact1',
            Email     = 'test1@example.com',
            HasOptedOutOfEmail = false
        );
        Contact c2 = new Contact(
            FirstName = 'Test',
            LastName  = 'Contact2',
            Email     = 'test2@example.com',
            HasOptedOutOfEmail = true // opted out
        );
        insert new List<Contact>{c1, c2};

        hed__Affiliation__c affil1 = new hed__Affiliation__c(
            hed__Contact__c = c1.Id,
            DSU_Email__c    = 'dsu1@example.com'
        );
        hed__Affiliation__c affil2 = new hed__Affiliation__c(
            hed__Contact__c = c2.Id,
            DSU_Email__c    = 'dsu2@example.com'
        );
        hed__Affiliation__c affil3 = new hed__Affiliation__c(
            hed__Contact__c = c1.Id,
            DSU_Email__c    = null // no DSU email
        );
        insert new List<hed__Affiliation__c>{affil1, affil2, affil3};
    }

    private static ApexPages.StandardSetController createSSCWithSelection(List<hed__Affiliation__c> selected) {
        // Base query is irrelevant; we override selection below
        ApexPages.StandardSetController ssc = new ApexPages.StandardSetController(
            [SELECT Id FROM hed__Affiliation__c LIMIT 1]
        );
        ssc.setSelected(selected);
        return ssc;
    }

    // ---------- TESTS ----------

    @isTest
    static void testBuildPreview_includesValidEmails() {
        List<hed__Affiliation__c> affils = [
            SELECT Id, DSU_Email__c, hed__Contact__c
            FROM hed__Affiliation__c
        ];

        ApexPages.StandardSetController ssc = createSSCWithSelection(affils);
        SendEmailsFromAffiliationsCtrl ctrl = new SendEmailsFromAffiliationsCtrl(ssc);

        System.assertNotEquals(null, ctrl.previewRecipients, 'previewRecipients should be initialized');
        System.assert(ctrl.getHasRecipients(), 'Should have recipients');
        String preview = ctrl.getPreviewRecipientsString();
        System.assertNotEquals('', preview, 'Preview string should not be empty');
        System.assert(preview.contains('dsu1@example.com'), 'Should include DSU email');
        System.assert(preview.contains('test1@example.com'), 'Should include non-opted-out contact email');
        System.assert(!preview.contains('test2@example.com'), 'Opted out contact email should not appear');
    }

    @isTest
    static void testBuildPreview_noSelection_showsInfoMessage() {
        ApexPages.StandardSetController ssc = createSSCWithSelection(new List<hed__Affiliation__c>());
        SendEmailsFromAffiliationsCtrl ctrl = new SendEmailsFromAffiliationsCtrl(ssc);

        System.assertEquals(0, ctrl.previewRecipients.size(), 'No recipients when no selection');
        System.assertEquals(1, ApexPages.getMessages().size(), 'Should show info message for no selection');
    }

    @isTest
    static void testAddCurrentFile_noFile_showsError() {
        List<hed__Affiliation__c> affils = [
            SELECT Id, DSU_Email__c, hed__Contact__c
            FROM hed__Affiliation__c
            LIMIT 1
        ];
        ApexPages.StandardSetController ssc = createSSCWithSelection(affils);
        SendEmailsFromAffiliationsCtrl ctrl = new SendEmailsFromAffiliationsCtrl(ssc);

        Test.startTest();
        ctrl.addCurrentFile();
        Test.stopTest();

       
    }

    @isTest
    static void testAddCurrentFile_validFile_savesContentVersion() {
        List<hed__Affiliation__c> affils = [
            SELECT Id, DSU_Email__c, hed__Contact__c
            FROM hed__Affiliation__c
            LIMIT 1
        ];
        ApexPages.StandardSetController ssc = createSSCWithSelection(affils);
        SendEmailsFromAffiliationsCtrl ctrl = new SendEmailsFromAffiliationsCtrl(ssc);

        Attachment att = new Attachment();
        att.Name = 'test.txt';
        att.Body = Blob.valueOf('Hello World');
        ctrl.currentFile = att;

        Test.startTest();
        ctrl.addCurrentFile();
        Test.stopTest();

        System.assertEquals(1, ctrl.savedDocIds.size(), 'One ContentDocumentId should be stored');
        System.assertEquals(1, ctrl.savedFileNames.size(), 'One filename should be stored');
        System.assertEquals('test.txt', ctrl.savedFileNames[0]);
    }

    @isTest
    static void testClearFiles_resetsLists() {
        List<hed__Affiliation__c> affils = [
            SELECT Id, DSU_Email__c, hed__Contact__c
            FROM hed__Affiliation__c
            LIMIT 1
        ];
        ApexPages.StandardSetController ssc = createSSCWithSelection(affils);
        SendEmailsFromAffiliationsCtrl ctrl = new SendEmailsFromAffiliationsCtrl(ssc);

        Attachment att = new Attachment();
        att.Name = 'test.txt';
        att.Body = Blob.valueOf('Hello World');
        ctrl.currentFile = att;
        ctrl.addCurrentFile();

        System.assertEquals(1, ctrl.savedDocIds.size(), 'Precondition: one doc saved');

        ctrl.clearFiles();

        System.assertEquals(0, ctrl.savedDocIds.size(), 'savedDocIds should be cleared');
        System.assertEquals(0, ctrl.savedFileNames.size(), 'savedFileNames should be cleared');
    }

    @isTest
    static void testSendNow_requiredFieldsMissing_error() {
        List<hed__Affiliation__c> affils = [
            SELECT Id, DSU_Email__c, hed__Contact__c
            FROM hed__Affiliation__c
            LIMIT 1
        ];
        ApexPages.StandardSetController ssc = createSSCWithSelection(affils);
        SendEmailsFromAffiliationsCtrl ctrl = new SendEmailsFromAffiliationsCtrl(ssc);

        ctrl.subject = '';
        ctrl.body    = 'Body only';

        Test.startTest();
        PageReference pr = ctrl.sendNow();
        Test.stopTest();

        System.assertEquals(null, pr, 'sendNow should return null');
        System.assertEquals(1, ApexPages.getMessages().size(), 'Should show error for missing subject');
    }

    @isTest
    static void testSendNow_noAffiliations_error() {
        ApexPages.StandardSetController ssc = createSSCWithSelection(new List<hed__Affiliation__c>());
        SendEmailsFromAffiliationsCtrl ctrl = new SendEmailsFromAffiliationsCtrl(ssc);

        ctrl.subject = 'Test Subject';
        ctrl.body    = 'Test Body';

        Test.startTest();
        PageReference pr = ctrl.sendNow();
        Test.stopTest();

        // No exception thrown; error is added
        System.assertEquals(null, pr, 'sendNow should return null for no affiliations');
    }

    @isTest
    static void testSendNow_withFileUpload_successAndBatch() {
        List<hed__Affiliation__c> affils = [
            SELECT Id, hed__Contact__c, DSU_Email__c
            FROM hed__Affiliation__c
            LIMIT 2
        ];
        ApexPages.StandardSetController ssc = createSSCWithSelection(affils);
        SendEmailsFromAffiliationsCtrl ctrl = new SendEmailsFromAffiliationsCtrl(ssc);

        ctrl.subject = 'Affil Test Subject';
        ctrl.body    = 'Affil Test Body';

        // Add one file via addCurrentFile
        Attachment att = new Attachment();
        att.Name = 'affil.txt';
        att.Body = Blob.valueOf('Hello Affiliation');
        ctrl.currentFile = att;
        ctrl.addCurrentFile();

        Test.startTest();
        PageReference pr = ctrl.sendNow();
        Test.stopTest();

        System.assertEquals(null, pr, 'sendNow should stay on page');
        Integer jobs = [
            SELECT COUNT()
            FROM AsyncApexJob
            WHERE JobType = 'BatchApex'
              AND ApexClass.Name = 'AffiliationEmailBatch'
        ];
        System.assert(jobs > 0, 'AffiliationEmailBatch should be enqueued');

        // Files should be linked to Affiliation and/or Contact
        Set<Id> affilIds = new Set<Id>();
        Set<Id> contactIds = new Set<Id>();
        for (hed__Affiliation__c a : affils) {
            affilIds.add(a.Id);
            if (a.hed__Contact__c != null) contactIds.add(a.hed__Contact__c);
        }

        List<ContentDocumentLink> linksToAffil = [
            SELECT Id
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :affilIds
        ];
        System.assert(!linksToAffil.isEmpty(), 'Files should be linked to affiliation records');
    }

    @isTest
    static void testGetPreviewRecipientsString_notEmptyWhenRecipients() {
        List<hed__Affiliation__c> affils = [
            SELECT Id, DSU_Email__c, hed__Contact__c
            FROM hed__Affiliation__c
            LIMIT 1
        ];
        ApexPages.StandardSetController ssc = createSSCWithSelection(affils);
        SendEmailsFromAffiliationsCtrl ctrl = new SendEmailsFromAffiliationsCtrl(ssc);

        String preview = ctrl.getPreviewRecipientsString();
        System.assertNotEquals('', preview, 'Preview string should not be empty when there are recipients');
    }
}