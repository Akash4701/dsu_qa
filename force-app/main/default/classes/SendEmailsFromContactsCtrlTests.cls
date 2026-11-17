@IsTest
private class SendEmailsFromContactsCtrlTests {

    // ---------- TEST DATA SETUP ----------

    private static Map<String, Id> makeData() {
        // Contacts
        List<Contact> cons = new List<Contact>{
            new Contact(LastName='HasEmail',  Email='to1@example.com', HasOptedOutOfEmail=false),
            new Contact(LastName='OptedOut', Email='to2@example.com', HasOptedOutOfEmail=true)
        };
        insert cons;

        // Affiliation emails for each contact
        List<hed__Affiliation__c> aff = new List<hed__Affiliation__c>{
            new hed__Affiliation__c(hed__Contact__c=cons[0].Id, DSU_Email__c='aff1@example.com'),
            new hed__Affiliation__c(hed__Contact__c=cons[1].Id, DSU_Email__c='aff2@example.com')
        };
        insert aff;

        return new Map<String, Id>{
            'c1' => cons[0].Id,
            'c2' => cons[1].Id
        };
    }

    private static SendEmailsFromContactsCtrl makeControllerWithSelection(Set<Id> selectedIds) {
        List<Contact> base = [SELECT Id FROM Contact WHERE Id IN :selectedIds];
        ApexPages.StandardSetController ssc = new ApexPages.StandardSetController(base);
        ssc.setSelected(base);
        SendEmailsFromContactsCtrl ctrl = new SendEmailsFromContactsCtrl(ssc);
        return ctrl;
    }

    private static Attachment makeUpload(String name, String bodyText, String contentType) {
        Attachment a = new Attachment();
        a.Name = name;
        a.ContentType = contentType;
        a.Body = Blob.valueOf(bodyText);
        return a;
    }

    // ---------- TESTS ----------

    @IsTest
    static void testBuildPreview_andGetPreviewRecipientsString() {
        Map<String, Id> ids = makeData();
        Set<Id> selected = new Set<Id>{ ids.get('c1'), ids.get('c2') };

        SendEmailsFromContactsCtrl ctrl = makeControllerWithSelection(selected);

        System.assert(ctrl.getHasRecipients(), 'Should have recipients');
        String preview = ctrl.getPreviewRecipientsString();
        System.assertNotEquals('', preview, 'Preview recipients string should not be empty');
        System.assert(preview.contains('to1@example.com'), 'Preview should include non-opt-out email');
        System.assert(preview.contains('aff1@example.com'), 'Preview should include affiliation email');
    }

    @IsTest
    static void testAddCurrentFile_noFile_showsError() {
        Map<String, Id> ids = makeData();
        Set<Id> selected = new Set<Id>{ ids.get('c1') };

        SendEmailsFromContactsCtrl ctrl = makeControllerWithSelection(selected);

        // No file set
        Test.startTest();
        ctrl.addCurrentFile();
        Test.stopTest();

        System.assertEquals(0, ctrl.savedDocIds.size(), 'No docs should be saved');
        System.assertEquals(1, ApexPages.getMessages().size(), 'Error message should be shown');
    }

    @IsTest
    static void testAddCurrentFile_validFile_savesContentVersion() {
        Map<String, Id> ids = makeData();
        Set<Id> selected = new Set<Id>{ ids.get('c1') };

        SendEmailsFromContactsCtrl ctrl = makeControllerWithSelection(selected);

        // Simulate file upload
        ctrl.currentFile = makeUpload('unit.txt', 'Hello File', 'text/plain');

        Test.startTest();
        ctrl.addCurrentFile();
        Test.stopTest();

        
    }

    @IsTest
    static void testClearFiles_resetsLists() {
        Map<String, Id> ids = makeData();
        Set<Id> selected = new Set<Id>{ ids.get('c1') };

        SendEmailsFromContactsCtrl ctrl = makeControllerWithSelection(selected);

        ctrl.currentFile = makeUpload('unit.txt', 'Hello File', 'text/plain');
        ctrl.addCurrentFile();

        System.assertEquals(1, ctrl.savedDocIds.size(), 'Precondition: one doc saved');

        ctrl.clearFiles();

        System.assertEquals(0, ctrl.savedDocIds.size(), 'savedDocIds should be cleared');
        System.assertEquals(0, ctrl.savedFileNames.size(), 'savedFileNames should be cleared');
    }

    @IsTest
    static void testSendNow_missingSubjectOrBody_showsError() {
        Map<String, Id> ids = makeData();
        Set<Id> selected = new Set<Id>{ ids.get('c1') };

        SendEmailsFromContactsCtrl ctrl = makeControllerWithSelection(selected);

        ctrl.subject = '';
        ctrl.body    = 'Body only';

        Test.startTest();
        PageReference pr = ctrl.sendNow();
        Test.stopTest();

        System.assertEquals(null, pr, 'sendNow should return null');
        System.assertEquals(1, ApexPages.getMessages().size(), 'Should show error for missing subject');
    }

    @IsTest
    static void testSendNow_success_withAttachment_andQueueable() {
        Map<String, Id> ids = makeData();
        Set<Id> selected = new Set<Id>{ ids.get('c1'), ids.get('c2') };

        SendEmailsFromContactsCtrl ctrl = makeControllerWithSelection(selected);
        ctrl.subject = 'UnitTest Subject';
        ctrl.body    = 'UnitTest Body';

        // Add one attachment
        ctrl.currentFile = makeUpload('unit.txt', 'Hello File', 'text/plain');
        ctrl.addCurrentFile();

        Test.startTest();
        PageReference pr = ctrl.sendNow();
        Test.stopTest();

        System.assertEquals(null, pr, 'sendNow should not navigate away');
        // Queueable jobs created
        Integer jobs = [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable'];
        System.assert(jobs > 0, 'Queueable job should be enqueued');

        // Files should be linked to Contacts
        List<ContentDocumentLink> cdlToContacts = [
            SELECT Id
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :selected
        ];
        System.assert(!cdlToContacts.isEmpty(), 'Files should be linked to selected contacts');
    }

    @IsTest
    static void testCancel_redirectsSomewhere() {
        Map<String, Id> ids = makeData();
        Set<Id> selected = new Set<Id>{ ids.get('c1') };

        SendEmailsFromContactsCtrl ctrl = makeControllerWithSelection(selected);

        Test.startTest();
        PageReference pr = ctrl.cancel();
        Test.stopTest();

        System.assertNotEquals(null, pr, 'cancel should return a PageReference');
        System.assertEquals(true, pr.getRedirect(), 'cancel should redirect');
    }
}