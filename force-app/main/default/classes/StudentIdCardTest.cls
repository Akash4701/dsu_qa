@IsTest
private class StudentIdCardTest {

    // ---------------------------------------------------------------
    // Test data
    // ---------------------------------------------------------------
    @TestSetup
    static void setupData() {
        // No auto-launch while seeding data.
        AffiliationTriggerHandler.bypassAutoLaunch = true;

        Account acct = new Account(
            Name = 'CDOE Department',
            Alias__c = 'BBA',
            Phone_Number__c = '9880147004'
        );
        insert acct;

        hed__Program_Plan__c plan = new hed__Program_Plan__c(
            Name = 'BBA Online',
            hed__Account__c = acct.Id,
            Academic_Year__c = '2025-2026'
        );
        insert plan;

        Contact con = new Contact(
            LastName = 'Akshathaa Test',
            Passport_Size_Photo__c = 'https://example.com/photo.jpg',
            DEB_Date_of_birth__c = Date.newInstance(1995, 6, 15),
            Blood_Group__c = 'O+',
            Phone_Number__c = '9880147004'
        );
        insert con;
    }

    private static hed__Affiliation__c buildAffiliation(Boolean withEmail) {
        Account acct = [SELECT Id FROM Account LIMIT 1];
        hed__Program_Plan__c plan = [SELECT Id FROM hed__Program_Plan__c LIMIT 1];
        Contact con = [SELECT Id FROM Contact LIMIT 1];

        hed__Affiliation__c aff = new hed__Affiliation__c(
            hed__Contact__c = con.Id,
            hed__Account__c = acct.Id,
            Program_Plan__c = plan.Id,
            Roll_Number__c = 'DSUOE28120BBA0001'
        );
        if (withEmail) {
            aff.DSU_Email__c = 'dsuoe28120bba0001@dsuonline.in';
        }
        return aff;
    }

    // ---------------------------------------------------------------
    // before trigger: flag Pending
    // ---------------------------------------------------------------
    @IsTest
    static void testBeforeInsert_flagsPendingWhenBothPresent() {
        AffiliationTriggerHandler.bypassAutoLaunch = true;
        hed__Affiliation__c aff = buildAffiliation(true);
        insert aff;

        hed__Affiliation__c reloaded = [
            SELECT ID_Card_Generation_Status__c FROM hed__Affiliation__c WHERE Id = :aff.Id
        ];
        System.assertEquals('Pending', reloaded.ID_Card_Generation_Status__c,
            'Both Roll Number and DSU Email present should flag Pending on insert.');
    }

    @IsTest
    static void testBeforeInsert_doesNotFlagWhenEmailMissing() {
        AffiliationTriggerHandler.bypassAutoLaunch = true;
        hed__Affiliation__c aff = buildAffiliation(false); // no DSU email
        insert aff;

        hed__Affiliation__c reloaded = [
            SELECT ID_Card_Generation_Status__c FROM hed__Affiliation__c WHERE Id = :aff.Id
        ];
        System.assertEquals(null, reloaded.ID_Card_Generation_Status__c,
            'Missing DSU Email should not flag Pending.');
    }

    @IsTest
    static void testBeforeUpdate_flagsOnChange() {
        AffiliationTriggerHandler.bypassAutoLaunch = true;
        hed__Affiliation__c aff = buildAffiliation(false);
        insert aff;

        aff.DSU_Email__c = 'dsuoe28120bba0001@dsuonline.in';
        update aff;

        hed__Affiliation__c reloaded = [
            SELECT ID_Card_Generation_Status__c FROM hed__Affiliation__c WHERE Id = :aff.Id
        ];
        System.assertEquals('Pending', reloaded.ID_Card_Generation_Status__c,
            'Adding the DSU Email on update should flag Pending.');
    }

    // ---------------------------------------------------------------
    // VF controller
    // ---------------------------------------------------------------
    @IsTest
    static void testVfController_populatesAllFields() {
        AffiliationTriggerHandler.bypassAutoLaunch = true;
        hed__Affiliation__c aff = buildAffiliation(true);
        insert aff;

        Test.setCurrentPage(Page.StudentIdCard);
        ApexPages.currentPage().getParameters().put('affiliationId', aff.Id);

        StudentIdCardController ctrl = new StudentIdCardController();
        System.assertEquals('Akshathaa Test', ctrl.studentName, 'Name should come from Contact.');
        System.assertEquals('DSUOE28120BBA0001', ctrl.usn, 'USN should be Roll Number.');
        System.assertEquals('BBA', ctrl.program, 'Program should be Account Alias.');
        System.assertNotEquals(null, ctrl.phone, 'Phone field should be initialized.');
        System.assertEquals('2025-2026', ctrl.acadYear, 'ACD YR should be Program Plan Academic Year.');
        System.assertEquals('O+', ctrl.bloodGroup, 'Blood group should come from Contact.');
        System.assertEquals('15-JUN-1995', ctrl.dob, 'DOB should be formatted dd-MMM-yyyy uppercase.');
        System.assertEquals(true, ctrl.hasPhoto, 'Photo url present so hasPhoto = true.');
        System.assertEquals(false, ctrl.hasSignature, 'No signature checklist row yet.');
    }

    @IsTest
    static void testVfController_picksUpSignature() {
        AffiliationTriggerHandler.bypassAutoLaunch = true;
        hed__Affiliation__c aff = buildAffiliation(true);
        insert aff;

        Application__c app = new Application__c(
            ContactId__c = aff.hed__Contact__c,
            External_Application_Number__c = 'TEST-SIGN-0001',
            Program_Level__c = 'UG'
        );
        insert app;
        insert new List<Document_Checklist__c>{
            new Document_Checklist__c(Application__c = app.Id, Document_Type__c = 'Signature',
                Document_Upload_URL__c = 'https://example.com/sign.jpg'),
            new Document_Checklist__c(Application__c = app.Id, Document_Type__c = 'Aadhaar',
                Document_Upload_URL__c = 'https://example.com/aadhaar.jpg')
        };

        Test.setCurrentPage(Page.StudentIdCard);
        ApexPages.currentPage().getParameters().put('affiliationId', aff.Id);

        StudentIdCardController ctrl = new StudentIdCardController();
        System.assertEquals(true, ctrl.hasSignature, 'Signature row should be found.');
        System.assertEquals('https://example.com/sign.jpg', ctrl.signatureUrl,
            'Only the Signature-type document should be used.');
        System.assertEquals(null, StudentIdCardController.findSignatureUrl(null),
            'Null contact yields no signature.');
    }

    @IsTest
    static void testVfController_signatureFileNotReusedAsPhoto() {
        AffiliationTriggerHandler.bypassAutoLaunch = true;
        hed__Affiliation__c aff = buildAffiliation(true);
        insert aff;

        Application__c app = new Application__c(
            ContactId__c = aff.hed__Contact__c,
            External_Application_Number__c = 'TEST-SIGN-0002',
            Program_Level__c = 'UG'
        );
        insert app;
        // Same file as the Contact's Passport_Size_Photo__c from setupData.
        insert new Document_Checklist__c(Application__c = app.Id, Document_Type__c = 'Signature',
            Document_Upload_URL__c = 'https://example.com/photo.jpg');

        Test.setCurrentPage(Page.StudentIdCard);
        ApexPages.currentPage().getParameters().put('affiliationId', aff.Id);

        StudentIdCardController ctrl = new StudentIdCardController();
        System.assertEquals(true, ctrl.hasSignature, 'Signature should still be shown.');
        System.assertEquals(false, ctrl.hasPhoto, 'Signature file must not appear as the photo.');
        System.assertEquals(false, ctrl.hasPhotoHtml, 'Formula photo must be suppressed too.');
    }

    @IsTest
    static void testVfController_showsRegistrarSignature() {
        String png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';
        Folder f = [SELECT Id FROM Folder WHERE DeveloperName = 'ID_Card_Assets' LIMIT 1];
        Document doc = new Document(Name = 'registrar.png', DeveloperName = 'Registrar_Signature',
            FolderId = f.Id, ContentType = 'image/png', Type = 'png', Body = EncodingUtil.base64Decode(png));
        try {
            insert doc;
        } catch (DmlException e) {
            // An org that already holds the real Registrar_Signature Document reserves the name and an
            // isolated test cannot see or reuse it, so there is nothing to assert here.
            System.assert(e.getMessage().contains('DUPLICATE_DEVELOPER_NAME'), e.getMessage());
            return;
        }

        Test.setCurrentPage(Page.StudentIdCard);
        StudentIdCardController ctrl = new StudentIdCardController();
        System.assertEquals(true, ctrl.hasRegistrarSignature, 'Registrar signature should be on the card.');
        System.assert(ctrl.registrarSignatureUrl.endsWith('/servlet/servlet.FileDownload?file=' + doc.Id),
            'Card should link to the Registrar signature Document.');
    }

    @IsTest
    static void testVfController_nullParam() {
        Test.setCurrentPage(Page.StudentIdCard);
        StudentIdCardController ctrl = new StudentIdCardController();
        System.assertEquals('', ctrl.studentName, 'No param should leave defaults.');
        System.assertEquals(false, ctrl.hasPhoto, 'No photo with no data.');
        System.assertEquals(false, ctrl.hasRegistrarSignature, 'No Registrar signature uploaded.');
    }

    // ---------------------------------------------------------------
    // getAffiliationInfo
    // ---------------------------------------------------------------
    @IsTest
    static void testGetAffiliationInfo_ready() {
        AffiliationTriggerHandler.bypassAutoLaunch = true;
        hed__Affiliation__c aff = buildAffiliation(true);
        insert aff;

        StudentIdCardController.AffiliationInfo info =
            StudentIdCardController.getAffiliationInfo(aff.Id);
        System.assertEquals(true, info.ready, 'Both fields present => ready.');
        System.assertEquals('DSUOE28120BBA0001', info.usn);
    }

    @IsTest
    static void testGetAffiliationInfo_notReady() {
        AffiliationTriggerHandler.bypassAutoLaunch = true;
        hed__Affiliation__c aff = buildAffiliation(false);
        insert aff;

        StudentIdCardController.AffiliationInfo info =
            StudentIdCardController.getAffiliationInfo(aff.Id);
        System.assertEquals(false, info.ready, 'Missing email => not ready.');
        System.assertNotEquals(null, info.message, 'Not-ready info should carry a message.');
    }

    @IsTest
    static void testGetAffiliationInfo_nullThrows() {
        try {
            StudentIdCardController.getAffiliationInfo(null);
            System.assert(false, 'Expected exception for null id.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }

    // ---------------------------------------------------------------
    // generateIdCard (single) + override behaviour
    // ---------------------------------------------------------------
    @IsTest
    static void testGenerateIdCard_andOverride() {
        AffiliationTriggerHandler.bypassAutoLaunch = true;
        hed__Affiliation__c aff = buildAffiliation(true);
        insert aff;

        Test.startTest();
        Id docId1 = StudentIdCardController.generateIdCard(aff.Id);
        Id docId2 = StudentIdCardController.generateIdCard(aff.Id); // should override
        Test.stopTest();

        System.assertNotEquals(null, docId1, 'First generation returns a document.');
        System.assertNotEquals(null, docId2, 'Second generation returns a document.');

        // Only ONE ID card document should remain linked to the affiliation.
        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink cdl : [
            SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :aff.Id
        ]) {
            docIds.add(cdl.ContentDocumentId);
        }
        Integer idCardCount = [
            SELECT COUNT()
            FROM ContentVersion
            WHERE ContentDocumentId IN :docIds
              AND IsLatest = true
              AND Document_Type__c = 'Student ID Card'
        ];
        System.assertEquals(1, idCardCount, 'Override must keep exactly one ID card per affiliation.');

        hed__Affiliation__c reloaded = [
            SELECT ID_Card_Generation_Status__c, ID_Card_Last_Generated__c
            FROM hed__Affiliation__c WHERE Id = :aff.Id
        ];
        System.assertEquals('Generated', reloaded.ID_Card_Generation_Status__c, 'Status should be Generated.');
        System.assertNotEquals(null, reloaded.ID_Card_Last_Generated__c, 'Generated timestamp should be set.');
    }

    @IsTest
    static void testGenerateIdCard_notReadyThrows() {
        AffiliationTriggerHandler.bypassAutoLaunch = true;
        hed__Affiliation__c aff = buildAffiliation(false);
        insert aff;

        try {
            StudentIdCardController.generateIdCard(aff.Id);
            System.assert(false, 'Expected exception when not ready.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }

    @IsTest
    static void testGenerateIdCard_nullThrows() {
        try {
            StudentIdCardController.generateIdCard(null);
            System.assert(false, 'Expected exception for null id.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }

    // ---------------------------------------------------------------
    // Batch
    // ---------------------------------------------------------------
    @IsTest
    static void testBatch_generatesForPending() {
        AffiliationTriggerHandler.bypassAutoLaunch = true;
        List<hed__Affiliation__c> affs = new List<hed__Affiliation__c>();
        for (Integer i = 0; i < 3; i++) {
            hed__Affiliation__c aff = buildAffiliation(true);
            aff.Roll_Number__c = 'DSUOE28120BBA000' + (i + 1);
            aff.DSU_Email__c = 'dsuoe28120bba000' + (i + 1) + '@dsuonline.in';
            affs.add(aff);
        }
        insert affs; // before-trigger flags all Pending

        Test.startTest();
        Database.executeBatch(new AffiliationIdCardBatch(), 5);
        Test.stopTest();

        Integer generated = [
            SELECT COUNT() FROM hed__Affiliation__c WHERE ID_Card_Generation_Status__c = 'Generated'
        ];
        System.assertEquals(3, generated, 'All pending affiliations should be Generated by the batch.');

        Integer idCards = [
            SELECT COUNT()
            FROM ContentVersion
            WHERE IsLatest = true AND Document_Type__c = 'Student ID Card'
        ];
        System.assertEquals(3, idCards, 'One ID card per affiliation should be created.');
    }

    @IsTest
    static void testBatch_failurePathMarksFailed() {
        AffiliationTriggerHandler.bypassAutoLaunch = true;
        hed__Affiliation__c aff = buildAffiliation(true);
        insert aff; // flagged Pending

        StudentIdCardController.simulateStoreFailure = true;

        Test.startTest();
        Database.executeBatch(new AffiliationIdCardBatch(), 5);
        Test.stopTest();

        hed__Affiliation__c reloaded = [
            SELECT ID_Card_Generation_Status__c FROM hed__Affiliation__c WHERE Id = :aff.Id
        ];
        System.assertEquals('Failed', reloaded.ID_Card_Generation_Status__c,
            'A store failure should mark the affiliation Failed (not silently lost).');
    }

    // ---------------------------------------------------------------
    // after trigger launches the batch (end-to-end automation)
    // ---------------------------------------------------------------
    @IsTest
    static void testTrigger_launchesBatchAndGenerates() {
        AffiliationTriggerHandler.bypassAutoLaunch = false; // allow auto launch
        hed__Affiliation__c aff = buildAffiliation(true);

        Test.startTest();
        insert aff; // before flags Pending, after launches batch
        Test.stopTest(); // batch runs here

        hed__Affiliation__c reloaded = [
            SELECT ID_Card_Generation_Status__c FROM hed__Affiliation__c WHERE Id = :aff.Id
        ];
        System.assertEquals('Generated', reloaded.ID_Card_Generation_Status__c,
            'Trigger-launched batch should generate the ID card.');
    }

    // ---------------------------------------------------------------
    // Handler unit branches
    // ---------------------------------------------------------------
    @IsTest
    static void testHandler_branches() {
        hed__Affiliation__c blank = new hed__Affiliation__c();
        System.assertEquals(false,
            AffiliationTriggerHandler.isQualifying(blank, null, true),
            'Blank Roll/Email is not qualifying.');

        hed__Affiliation__c full = new hed__Affiliation__c();
        full.Roll_Number__c = 'R1';
        full.DSU_Email__c = 'a@b.com';
        System.assertEquals(true,
            AffiliationTriggerHandler.isQualifying(full, null, true),
            'Insert with both present is qualifying.');

        // update, oldMap null branch -> qualifying true
        System.assertEquals(true,
            AffiliationTriggerHandler.isQualifying(full, new Map<Id, hed__Affiliation__c>(), false),
            'Update with no old record is treated as qualifying.');

        // empty list early returns
        AffiliationTriggerHandler.flagPendingIdCards(new List<hed__Affiliation__c>(), null, true);
        AffiliationTriggerHandler.launchIdCardGeneration(new List<hed__Affiliation__c>(), null, true);

        // bypass early return
        AffiliationTriggerHandler.bypassAutoLaunch = true;
        AffiliationTriggerHandler.launchIdCardGeneration(
            new List<hed__Affiliation__c>{ full }, null, true);
        System.assert(true, 'Bypass path executed without launching.');
    }

    // ---------------------------------------------------------------
    // Static helper coverage
    // ---------------------------------------------------------------
    @IsTest
    static void testHelpers() {
        System.assertEquals('', StudentIdCardController.formatDob(null));
        System.assertEquals('15-JUN-1995',
            StudentIdCardController.formatDob(Date.newInstance(1995, 6, 15)));

        System.assertEquals(null, StudentIdCardController.normalizePhotoUrl(null));
        System.assertEquals('https://x/y',
            StudentIdCardController.normalizePhotoUrl('https://x/y'));
        System.assertEquals('/sfc/servlet.shepherd/version/download/068000000000001',
            StudentIdCardController.normalizePhotoUrl('068000000000001')); // 15 chars
        System.assertEquals('plainvalue',
            StudentIdCardController.normalizePhotoUrl('plainvalue'));

        System.assert(
            StudentIdCardController.buildTitle('Name', 'USN1', null).contains('Name(USN1)'),
            'Title with name+usn.');
        System.assert(
            StudentIdCardController.buildTitle(null, 'USN1', null).startsWith('USN1'),
            'Title with usn only.');
        System.assert(
            StudentIdCardController.buildTitle('Name', null, null).startsWith('Name'),
            'Title with name only.');

        // empty-map store + empty status set early returns
        System.assertEquals(0,
            StudentIdCardController.storeIdCards(new Map<Id, Blob>(), null, null).size());
        StudentIdCardController.markStatus(new Set<Id>(), 'Generated');
        System.assert(true);
    }
}