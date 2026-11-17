/**
 * BulkDocumentControllerTest
 * --------------------------
 * Covers BulkDocumentController:
 *   getDocumentPage()  — Files on Affiliations / Program Enrollments (student, program,
 *                        batch, term), dedup, Fee Receipts (title / date fallbacks,
 *                        program + batch from Affiliation, term from Program Enrollment),
 *                        every Fee Head resolution path in priority order, categories,
 *                        program / batch / term / fee head / search filters, record
 *                        mode and the keyset cursor (no duplicates or gaps across pages).
 *                        Every "all documents" assertion walks pages of 2 so the merge of
 *                        files and receipts across page boundaries is always exercised.
 *   getDocumentCount() — equals what getDocumentPage pages through, per tab and filter.
 *   getFilterOptions() / getTermOptions() — options from Program Plans / Fee Types / PEs.
 *   getFileContent()   — base64 round trip + null guard.
 *   getFileContents()  — several files per call, keyed by version Id + empty guard.
 */
@isTest
private class BulkDocumentControllerTest {

    private static final String PROGRAM_BBA = 'Bachelor of Business Administration';
    private static final String PROGRAM_MBA = 'Master of Business Administration';
    private static final String PLAN_BBA    = '2026-JAN-BBA';
    private static final String PLAN_MBA    = '2026-FEB-MBA';
    private static final String TERM_NAME   = '2026-FEB-MBA-Sem 1-ONLINE';

    // ─── shared test data ────────────────────────────────────────────────────

    @testSetup
    static void setupData() {
        Account progBBA = new Account(Name = PROGRAM_BBA);
        Account progMBA = new Account(Name = PROGRAM_MBA);
        insert new List<Account>{ progBBA, progMBA };

        hed__Program_Plan__c planBBA = new hed__Program_Plan__c(Name = PLAN_BBA, hed__Account__c = progBBA.Id);
        hed__Program_Plan__c planMBA = new hed__Program_Plan__c(Name = PLAN_MBA, hed__Account__c = progMBA.Id);
        insert new List<hed__Program_Plan__c>{ planBBA, planMBA };

        hed__Term__c term = new hed__Term__c(
            Name               = TERM_NAME,
            Term_Reference__c  = 'Semester 1',
            hed__Account__c    = progMBA.Id,
            hed__Start_Date__c = Date.today().addDays(-10),
            hed__End_Date__c   = Date.today().addDays(10)
        );
        insert term;

        Contact alice = new Contact(FirstName = 'Alice', LastName = 'Anderson'); // BBA affiliation
        Contact bob   = new Contact(FirstName = 'Bob',   LastName = 'Brown');    // MBA affiliation, no files
        Contact carol = new Contact(FirstName = 'Carol', LastName = 'Chen');     // MBA enrollment with term
        Contact dan   = new Contact(FirstName = 'Dan',   LastName = 'Das');      // affiliation with no batch
        insert new List<Contact>{ alice, bob, carol, dan };

        hed__Affiliation__c affAlice = new hed__Affiliation__c(
            hed__Contact__c = alice.Id, hed__Account__c = progBBA.Id, Program_Plan__c = planBBA.Id);
        hed__Affiliation__c affBob = new hed__Affiliation__c(
            hed__Contact__c = bob.Id,   hed__Account__c = progMBA.Id, Program_Plan__c = planMBA.Id);
        hed__Affiliation__c affDan = new hed__Affiliation__c(
            hed__Contact__c = dan.Id,   hed__Account__c = progMBA.Id, Program_Plan__c = null);
        hed__Affiliation__c affNoContact = new hed__Affiliation__c(hed__Contact__c = null);
        insert new List<hed__Affiliation__c>{ affAlice, affBob, affDan, affNoContact };

        hed__Program_Enrollment__c peCarol = new hed__Program_Enrollment__c(
            hed__Contact__c      = carol.Id,
            hed__Account__c      = progMBA.Id,
            hed__Program_Plan__c = planMBA.Id,
            Term__c              = term.Id
        );
        insert peCarol;

        createLinkedFile('Admission Letter BBA', affAlice.Id);
        createLinkedFile('Enrollment Doc',       peCarol.Id);
        createLinkedFile('No Batch Doc',         affDan.Id);
        createLinkedFile('Orphan Doc',           affNoContact.Id);

        insert new List<Receipt_and_Invoice__c>{
            // Full receipt: number + type + date + contact with a batch
            new Receipt_and_Invoice__c(
                Contact__c        = alice.Id,
                Receipt_Number__c = 'RCPT-001',
                Document_Type__c  = 'Receipt',
                Receipt_URL__c    = 'https://example.com/rcpt-001.pdf',
                Payment_Date__c   = Date.newInstance(2026, 1, 15)
            ),
            // Minimal receipt: no number (falls back to Name), no date, no contact
            new Receipt_and_Invoice__c(
                Receipt_URL__c = 'https://example.com/rcpt-min.pdf'
            ),
            // No URL — must never be returned
            new Receipt_and_Invoice__c(
                Contact__c        = bob.Id,
                Receipt_Number__c = 'RCPT-NOURL'
            )
        };
    }

    // ─── helpers ─────────────────────────────────────────────────────────────

    private static Id createLinkedFile(String title, Id linkedEntityId) {
        ContentVersion cv = new ContentVersion(
            Title        = title,
            PathOnClient = title.replace(' ', '_') + '.pdf',
            VersionData  = Blob.valueOf('Body of ' + title)
        );
        insert cv;
        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        insert new ContentDocumentLink(
            ContentDocumentId = docId,
            LinkedEntityId    = linkedEntityId,
            ShareType         = 'V',
            Visibility        = 'AllUsers'
        );
        return docId;
    }

    private static Contact contactNamed(String firstName) {
        return [SELECT Id FROM Contact WHERE FirstName = :firstName LIMIT 1];
    }

    private static Account program(String name) {
        return [SELECT Id FROM Account WHERE Name = :name LIMIT 1];
    }

    private static Fee_Type__c insertFeeType(String head, String feeName) {
        Fee_Type__c ft = new Fee_Type__c(
            Fee_Head__c = head,
            Fee_Name__c = feeName,
            Program__c  = program(PROGRAM_BBA).Id
        );
        insert ft;
        return ft;
    }

    private static Receipt_and_Invoice__c newReceipt(String receiptNo, Id contactId) {
        return new Receipt_and_Invoice__c(
            Contact__c        = contactId,
            Receipt_Number__c = receiptNo,
            Document_Type__c  = 'Receipt',
            Receipt_URL__c    = 'https://example.com/' + receiptNo + '.pdf',
            Payment_Date__c   = Date.today()
        );
    }

    // Student with an affiliation whose application states the given fee plan.
    private static Contact studentWithFeePreference(String lastName, String feePreference) {
        Contact ct = new Contact(FirstName = 'Pref', LastName = lastName);
        insert ct;
        Application__c app = new Application__c(
            Fee_Preference__c              = feePreference,
            External_Application_Number__c = 'EXT-' + lastName,
            Program_Level__c               = 'UG'
        );
        insert app;
        insert new hed__Affiliation__c(
            hed__Contact__c           = ct.Id,
            hed__Account__c           = program(PROGRAM_BBA).Id,
            Program_Plan__c           = [SELECT Id FROM hed__Program_Plan__c WHERE Name = :PLAN_BBA].Id,
            Individual_Application__c = app.Id
        );
        return ct;
    }

    // Every document across all pages, following nextCursor the way the LWC does.
    private static List<Map<String, Object>> walk(Id recordId, String category, String programName,
            String programPlan, String term, String feeHead, String search, Integer pageSize) {
        List<Map<String, Object>> docs = new List<Map<String, Object>>();
        String cursor = null;
        for (Integer guard = 0; guard < 60; guard++) {
            BulkDocumentController.DocumentPage page = BulkDocumentController.getDocumentPage(
                recordId, category, programName, programPlan, term, feeHead, search, cursor, pageSize);
            System.assert(page.documents.size() <= pageSize, 'Never more than one page');
            docs.addAll(page.documents);
            if (!page.hasMore) return docs;
            cursor = page.nextCursor;
        }
        System.assert(false, 'Pagination did not terminate');
        return docs;
    }

    private static List<Map<String, Object>> walkFiltered(String category, String programName,
            String programPlan, String term, String feeHead, String search) {
        Test.startTest();
        List<Map<String, Object>> docs = walk(null, category, programName, programPlan, term, feeHead, search, 2);
        Test.stopTest();
        return docs;
    }

    private static List<Map<String, Object>> runGetAll() {
        return walkFiltered('All', null, null, null, null, null);
    }

    private static Set<String> titlesOf(List<Map<String, Object>> docs) {
        Set<String> titles = new Set<String>();
        for (Map<String, Object> d : docs) titles.add((String) d.get('title'));
        return titles;
    }

    private static Map<String, Object> findByTitle(List<Map<String, Object>> docs, String title) {
        for (Map<String, Object> d : docs) {
            if (title.equals(d.get('title'))) return d;
        }
        return null;
    }

    private static Integer countByTitle(List<Map<String, Object>> docs, String title) {
        Integer n = 0;
        for (Map<String, Object> d : docs) {
            if (title.equals(d.get('title'))) n++;
        }
        return n;
    }

    // ─── getDocumentPage: files ───────────────────────────────────────

    @isTest
    static void getAll_returnsEveryFileAndOnlyReceiptsWithUrl() {
        List<Map<String, Object>> docs = runGetAll();

        System.assertEquals(6, docs.size(), '4 files + 2 receipts with a URL');
        System.assertEquals(null, findByTitle(docs, 'RCPT-NOURL'), 'Receipt without a URL is excluded');
        for (Map<String, Object> d : docs) {
            System.assert(String.isNotBlank((String) d.get('downloadUrl')), 'Every row is downloadable');
        }
    }

    @isTest
    static void getAll_affiliationFileCarriesStudentProgramAndBatch() {
        Map<String, Object> d = findByTitle(runGetAll(), 'Admission Letter BBA');

        System.assertNotEquals(null, d, 'File on an affiliation is returned');
        System.assertEquals('Alice Anderson', d.get('studentName'));
        System.assertEquals(PROGRAM_BBA,      d.get('programName'), 'Program = Affiliation account');
        System.assertEquals(PLAN_BBA,         d.get('programPlan'), 'Batch = Affiliation program plan');
        System.assertEquals(null,             d.get('term'),        'Affiliations carry no term');
        System.assertEquals('PDF',            d.get('fileType'));
        System.assertNotEquals(null,          d.get('versionId'),   'Files expose their version for zipping');
        System.assertEquals(
            '/sfc/servlet.shepherd/document/download/' + d.get('id') + '?operationContext=S1',
            d.get('downloadUrl'), 'Shepherd download URL built from the ContentDocument Id');
    }

    @isTest
    static void getAll_enrollmentFileCarriesProgramBatchAndTerm() {
        Map<String, Object> d = findByTitle(runGetAll(), 'Enrollment Doc');

        System.assertNotEquals(null, d, 'File on a program enrollment is returned');
        System.assertEquals('Carol Chen', d.get('studentName'));
        System.assertEquals(PROGRAM_MBA,  d.get('programName'), 'Program = Enrollment account');
        System.assertEquals(PLAN_MBA,     d.get('programPlan'), 'Batch = Enrollment program plan');
        System.assertEquals(TERM_NAME,    d.get('term'),        'Term = Term record Name, not Term_Reference__c');
    }

    @isTest
    static void getAll_affiliationWithoutBatchHasProgramButNullBatch() {
        Map<String, Object> d = findByTitle(runGetAll(), 'No Batch Doc');

        System.assertNotEquals(null, d, 'File is still returned when the batch is missing');
        System.assertEquals(PROGRAM_MBA, d.get('programName'));
        System.assertEquals(null,        d.get('programPlan'), 'No Program Plan → null batch');
    }

    @isTest
    static void getAll_affiliationWithoutContactFallsBackToDash() {
        Map<String, Object> d = findByTitle(runGetAll(), 'Orphan Doc');

        System.assertNotEquals(null, d, 'File on a contact-less affiliation is returned');
        System.assertEquals('—',  d.get('studentName'), 'No contact → em-dash');
        System.assertEquals(null, d.get('programName'));
        System.assertEquals(null, d.get('programPlan'));
    }

    @isTest
    static void getAll_fileLinkedToTwoRecordsAppearsOnce() {
        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Title = 'Admission Letter BBA'].ContentDocumentId;
        hed__Affiliation__c affBob = [SELECT Id FROM hed__Affiliation__c WHERE hed__Contact__r.FirstName = 'Bob'];
        insert new ContentDocumentLink(
            ContentDocumentId = docId, LinkedEntityId = affBob.Id, ShareType = 'V', Visibility = 'AllUsers');

        System.assertEquals(1, countByTitle(runGetAll(), 'Admission Letter BBA'),
            'A document shared by two students is listed once');
    }

    @isTest
    static void getAll_regeneratedDocumentListsOnlyNewestCopy() {
        hed__Affiliation__c affAlice = [SELECT Id FROM hed__Affiliation__c WHERE hed__Contact__r.FirstName = 'Alice'];
        hed__Affiliation__c affBob   = [SELECT Id FROM hed__Affiliation__c WHERE hed__Contact__r.FirstName = 'Bob'];
        // Regenerated twice for Alice; same title for Bob is a different student's copy.
        // Copies created in the same second tie on date and fall back to Id order, so
        // the last one inserted is the newest.
        createLinkedFile('Admission Letter Regen', affAlice.Id);
        createLinkedFile('Admission Letter Regen', affAlice.Id);
        Id latest = createLinkedFile('Admission Letter Regen', affAlice.Id);
        Id bobs   = createLinkedFile('Admission Letter Regen', affBob.Id);

        List<Map<String, Object>> docs = runGetAll();
        Set<Id> ids = new Set<Id>();
        for (Map<String, Object> d : docs) {
            if ('Admission Letter Regen'.equals(d.get('title'))) ids.add((Id) d.get('id'));
        }
        System.assertEquals(new Set<Id>{ latest, bobs }, ids,
            'Only the newest copy per student; another student\'s copy is kept');
        System.assertEquals(docs.size(), BulkDocumentController.getDocumentCount(null, 'All', null, null, null, null, null),
            'Count leaves out the older copies too');
    }

    @isTest
    static void getAll_fileNotOnAStudentRecordIsIgnored() {
        createLinkedFile('Account Brochure', program(PROGRAM_BBA).Id);

        System.assertEquals(null, findByTitle(runGetAll(), 'Account Brochure'),
            'Only files on Affiliations / Program Enrollments are listed');
    }

    @isTest
    static void getAll_noFilesWithoutAffiliationsOrEnrollmentsButReceiptsRemain() {
        delete [SELECT Id FROM hed__Program_Enrollment__c];
        delete [SELECT Id FROM hed__Affiliation__c];

        List<Map<String, Object>> docs = runGetAll();

        System.assertEquals(2, docs.size(), 'Only the two receipts with a URL are left');
        for (Map<String, Object> d : docs) {
            System.assertEquals(null, d.get('versionId'), 'No files without a student record');
        }
    }

    // ─── getDocumentPage: receipts ────────────────────────────────────

    @isTest
    static void getAll_fullReceiptMapsAllFields() {
        Map<String, Object> d = findByTitle(runGetAll(), 'RCPT-001 (Receipt)');

        System.assertNotEquals(null, d, 'Title = Receipt Number + (Document Type)');
        System.assertEquals('Alice Anderson', d.get('studentName'));
        System.assertEquals(PROGRAM_BBA,      d.get('programName'), 'Program from the student\'s affiliation');
        System.assertEquals(PLAN_BBA,         d.get('programPlan'), 'Batch from the student\'s affiliation');
        System.assertEquals('PDF',            d.get('fileType'));
        System.assertEquals(null,             d.get('versionId'),   'Non-Salesforce URL → no version');
        System.assertEquals(null,             d.get('fileSize'));
        System.assertEquals('https://example.com/rcpt-001.pdf', d.get('downloadUrl'));
        System.assertEquals(
            Datetime.newInstance(Date.newInstance(2026, 1, 15), Time.newInstance(0, 0, 0, 0)),
            d.get('lastModified'), 'Payment date at midnight');
    }

    // Receipt_URL__c holds a Salesforce public link; both its forms resolve to the shared file.
    @isTest
    static void getAll_receiptPublicLinkResolvesToSharedFile() {
        ContentVersion cv = new ContentVersion(
            Title = 'Receipt PDF', PathOnClient = 'Receipt.pdf', VersionData = Blob.valueOf('receipt body'));
        insert cv;
        ContentDistribution dist = new ContentDistribution(
            Name = 'Receipt PDF', ContentVersionId = cv.Id, PreferencesAllowViewInBrowser = true);
        insert dist;
        dist = [SELECT DistributionPublicUrl, ContentDownloadUrl FROM ContentDistribution WHERE Id = :dist.Id];

        Receipt_and_Invoice__c preview  = newReceipt('RCPT-LINK-P', contactNamed('Alice').Id);
        preview.Receipt_URL__c  = dist.DistributionPublicUrl;
        Receipt_and_Invoice__c download = newReceipt('RCPT-LINK-D', contactNamed('Alice').Id);
        download.Receipt_URL__c = dist.ContentDownloadUrl;
        insert new List<Receipt_and_Invoice__c>{ preview, download };

        List<Map<String, Object>> docs = runGetAll();
        for (String title : new List<String>{ 'RCPT-LINK-P (Receipt)', 'RCPT-LINK-D (Receipt)' }) {
            Map<String, Object> d = findByTitle(docs, title);
            System.assertNotEquals(null, d, title);
            System.assertEquals(cv.Id, d.get('versionId'), 'Public link → the shared version, read via Apex');
            System.assertEquals(12, d.get('fileSize'), 'Size of the shared version');
        }
    }

    @isTest
    static void getAll_minimalReceiptUsesFallbacks() {
        Receipt_and_Invoice__c ri = [
            SELECT Id, Name FROM Receipt_and_Invoice__c WHERE Receipt_URL__c = 'https://example.com/rcpt-min.pdf'
        ];
        // Document_Type__c defaults to 'Receipt' on insert, so clear it to reach the bare-Name title.
        ri.Document_Type__c = null;
        update ri;
        Map<String, Object> d = findByTitle(runGetAll(), ri.Name);

        System.assertNotEquals(null, d, 'No receipt number or type → title is the record Name');
        System.assertEquals('—',  d.get('studentName'));
        System.assertEquals(null, d.get('lastModified'), 'No payment date → null');
        System.assertEquals(null, d.get('programName'));
        System.assertEquals(null, d.get('programPlan'));
        System.assertEquals(null, d.get('term'));
        System.assertEquals(null, d.get('feeHead'));
    }

    @isTest
    static void getAll_receiptTermComesFromStudentsEnrollment() {
        insert newReceipt('RCPT-TERM', contactNamed('Carol').Id);

        Map<String, Object> d = findByTitle(runGetAll(), 'RCPT-TERM (Receipt)');

        System.assertNotEquals(null, d);
        System.assertEquals(TERM_NAME, d.get('term'), 'Term from the student\'s program enrollment');
        System.assertEquals(null, d.get('programPlan'), 'Carol has no affiliation → no batch on the receipt');
    }

    @isTest
    static void getAll_receiptIgnoresAffiliationWithoutBatch() {
        insert newReceipt('RCPT-DAN', contactNamed('Dan').Id);

        Map<String, Object> d = findByTitle(runGetAll(), 'RCPT-DAN (Receipt)');

        System.assertNotEquals(null, d);
        System.assertEquals('Dan Das', d.get('studentName'));
        System.assertEquals(null, d.get('programPlan'), 'Affiliations without a plan are not used for receipts');
        System.assertEquals(null, d.get('programName'));
    }

    // ─── getDocumentPage: Fee Head resolution ─────────────────────────

    @isTest
    static void feeHead_fromReceiptFeeType() {
        Receipt_and_Invoice__c ri = newReceipt('RCPT-FT', contactNamed('Alice').Id);
        ri.Fee_Type__c = insertFeeType('Year Wise Fee', null).Id;
        insert ri;

        System.assertEquals('Year Wise Fee', findByTitle(runGetAll(), 'RCPT-FT (Receipt)').get('feeHead'));
    }

    @isTest
    static void feeHead_fromReceiptFeeInstallment() {
        Contact ct = contactNamed('Alice');
        Fee_Installment__c fi = new Fee_Installment__c(
            Contact__c = ct.Id, Fee_Type__c = insertFeeType('Semester Fee', null).Id);
        insert fi;
        Receipt_and_Invoice__c ri = newReceipt('RCPT-FI', ct.Id);
        ri.Fee_Installment__c = fi.Id;
        insert ri;

        System.assertEquals('Semester Fee', findByTitle(runGetAll(), 'RCPT-FI (Receipt)').get('feeHead'));
    }

    @isTest
    static void feeHead_fromReceiptFeeAssignment() {
        Contact ct = contactNamed('Alice');
        Fee_Assignment__c fa = new Fee_Assignment__c(
            Contact__c = ct.Id, Fee_Type__c = insertFeeType('Program Fee', null).Id);
        insert fa;
        Receipt_and_Invoice__c ri = newReceipt('RCPT-FA', ct.Id);
        ri.Fee_Assignment__c = fa.Id;
        insert ri;

        System.assertEquals('Program Fee', findByTitle(runGetAll(), 'RCPT-FA (Receipt)').get('feeHead'));
    }

    @isTest
    static void feeHead_fromLineItemFeeInstallment() {
        Contact ct = contactNamed('Alice');
        Fee_Installment__c fi = new Fee_Installment__c(
            Contact__c = ct.Id, Fee_Type__c = insertFeeType('Re-Evaluation Fee', null).Id);
        insert fi;
        Receipt_and_Invoice__c ri = newReceipt('RCPT-LI1', ct.Id);
        insert ri;
        insert new Payment_Transaction_Line_Item__c(Receipt__c = ri.Id, Fee_Installment__c = fi.Id);

        System.assertEquals('Re-Evaluation Fee', findByTitle(runGetAll(), 'RCPT-LI1 (Receipt)').get('feeHead'),
            'Receipt with no fee link falls back to its line item\'s installment');
    }

    @isTest
    static void feeHead_fromLineItemFeeAssignment() {
        Contact ct = contactNamed('Alice');
        Fee_Assignment__c fa = new Fee_Assignment__c(
            Contact__c = ct.Id, Fee_Type__c = insertFeeType('Backlog examination Fee', null).Id);
        insert fa;
        Receipt_and_Invoice__c ri = newReceipt('RCPT-LI2', ct.Id);
        insert ri;
        insert new Payment_Transaction_Line_Item__c(Receipt__c = ri.Id, Fee_Assignment__c = fa.Id);

        System.assertEquals('Backlog examination Fee', findByTitle(runGetAll(), 'RCPT-LI2 (Receipt)').get('feeHead'),
            'Receipt with no fee link falls back to its line item\'s assignment');
    }

    @isTest
    static void feeHead_fromLineItemFeeNameWhenFeeTypeHasNoHead() {
        Contact ct = contactNamed('Alice');
        Fee_Assignment__c fa = new Fee_Assignment__c(
            Contact__c = ct.Id, Fee_Type__c = insertFeeType(null, 'Course fees').Id);
        insert fa;
        Receipt_and_Invoice__c ri = newReceipt('RCPT-LI3', ct.Id);
        insert ri;
        insert new Payment_Transaction_Line_Item__c(Receipt__c = ri.Id, Fee_Assignment__c = fa.Id);

        System.assertEquals('Course fees', findByTitle(runGetAll(), 'RCPT-LI3 (Receipt)').get('feeHead'),
            'Line item Fee_Name__c is the last line-item fallback');
    }

    @isTest
    static void feeHead_derivedFromEachFeePreference() {
        Map<String, String> expected = new Map<String, String>{
            'Semester-wise fee' => 'Semester Fee',
            'Year-wise fee'     => 'Year Wise Fee',
            'Total program fee' => 'Program Fee'
        };
        List<Receipt_and_Invoice__c> receipts = new List<Receipt_and_Invoice__c>();
        Map<String, String> titleToHead = new Map<String, String>();
        Integer i = 0;
        for (String pref : expected.keySet()) {
            i++;
            Contact ct = studentWithFeePreference('Pref' + i, pref);
            receipts.add(newReceipt('RCPT-PREF' + i, ct.Id));
            titleToHead.put('RCPT-PREF' + i + ' (Receipt)', expected.get(pref));
        }
        insert receipts;

        List<Map<String, Object>> docs = runGetAll();
        for (String title : titleToHead.keySet()) {
            System.assertEquals(titleToHead.get(title), findByTitle(docs, title).get('feeHead'),
                'Fee plan maps to its tuition Fee Head for ' + title);
        }
    }

    @isTest
    static void feeHead_unmappedFeePreferenceStaysNull() {
        Contact ct = studentWithFeePreference('Unmapped', null);
        insert newReceipt('RCPT-NOPREF', ct.Id);

        System.assertEquals(null, findByTitle(runGetAll(), 'RCPT-NOPREF (Receipt)').get('feeHead'),
            'No recognised fee plan → no guessed Fee Head');
    }

    @isTest
    static void feeHead_realValueWinsOverDerivedFeePreference() {
        Contact ct = studentWithFeePreference('Both', 'Semester-wise fee');
        Receipt_and_Invoice__c ri = newReceipt('RCPT-WINS', ct.Id);
        ri.Fee_Type__c = insertFeeType('Backlog examination Fee', null).Id;
        insert ri;

        System.assertEquals('Backlog examination Fee', findByTitle(runGetAll(), 'RCPT-WINS (Receipt)').get('feeHead'),
            'A real Fee_Head__c is never overridden by the fee plan');
    }

    @isTest
    static void feeHead_nullWhenReceiptHasNoFeeLink() {
        System.assertEquals(null, findByTitle(runGetAll(), 'RCPT-001 (Receipt)').get('feeHead'),
            'No fee link and no fee plan → null');
    }

    // ─── getFileContent ──────────────────────────────────────────────────────

    @isTest
    static void getFileContent_returnsBase64OfVersionData() {
        ContentVersion cv = [SELECT Id FROM ContentVersion WHERE Title = 'Enrollment Doc'];

        Test.startTest();
        String encoded = BulkDocumentController.getFileContent(cv.Id);
        Test.stopTest();

        System.assertEquals('Body of Enrollment Doc', EncodingUtil.base64Decode(encoded).toString(),
            'Round-trips to the original file body');
    }

    @isTest
    static void getFileContent_nullVersionIdReturnsNull() {
        Test.startTest();
        String result = BulkDocumentController.getFileContent(null);
        Test.stopTest();

        System.assertEquals(null, result);
    }

    @isTest
    static void getFileContents_returnsEachFileByVersionId() {
        Map<Id, String> titleById = new Map<Id, String>();
        for (ContentVersion cv : [SELECT Id, Title FROM ContentVersion WHERE Title IN ('Enrollment Doc', 'Admission Letter BBA')]) {
            titleById.put(cv.Id, cv.Title);
        }

        Test.startTest();
        Map<Id, String> contents = BulkDocumentController.getFileContents(new List<Id>(titleById.keySet()));
        Test.stopTest();

        System.assertEquals(2, contents.size(), 'Both files come back in one call');
        for (Id versionId : titleById.keySet()) {
            System.assertEquals('Body of ' + titleById.get(versionId),
                EncodingUtil.base64Decode(contents.get(versionId)).toString(),
                'Each entry round-trips to its own file body');
        }
    }

    @isTest
    static void getFileContents_emptyInputReturnsEmptyMap() {
        Test.startTest();
        System.assert(BulkDocumentController.getFileContents(null).isEmpty());
        System.assert(BulkDocumentController.getFileContents(new List<Id>()).isEmpty());
        Test.stopTest();
    }

    // ─── getDocumentPage: pagination ─────────────────────────────────────────

    @isTest
    static void page_walksEveryDocumentOnceAcrossFilesReceiptsAndSharedLinks() {
        hed__Affiliation__c affBob = [SELECT Id FROM hed__Affiliation__c WHERE hed__Contact__r.FirstName = 'Bob'];
        hed__Program_Enrollment__c pe = [SELECT Id FROM hed__Program_Enrollment__c LIMIT 1];
        Set<String> expected = titlesOf(walk(null, 'All', null, null, null, null, null, 200));
        List<Receipt_and_Invoice__c> receipts = new List<Receipt_and_Invoice__c>();
        for (Integer i = 0; i < 4; i++) {
            createLinkedFile('Offer Letter ' + i, affBob.Id);
            createLinkedFile('Grade Card ' + i, pe.Id);
            receipts.add(newReceipt('RCPT-PG' + i, contactNamed('Bob').Id));
            expected.addAll(new Set<String>{ 'Offer Letter ' + i, 'Grade Card ' + i, 'RCPT-PG' + i + ' (Receipt)' });
        }
        insert receipts;
        // Same file on an affiliation and an enrollment: two streams, one document.
        Id shared = createLinkedFile('Shared Doc', affBob.Id);
        insert new ContentDocumentLink(ContentDocumentId = shared, LinkedEntityId = pe.Id,
                                       ShareType = 'V', Visibility = 'AllUsers');
        expected.add('Shared Doc');

        Test.startTest();
        for (Integer size : new List<Integer>{ 3, 7 }) {
            List<Map<String, Object>> docs = walk(null, 'All', null, null, null, null, null, size);
            System.assertEquals(expected.size(), docs.size(), 'No duplicates at page size ' + size);
            System.assertEquals(expected, titlesOf(docs), 'Nothing missed at page size ' + size);
        }
        Test.stopTest();
    }

    @isTest
    static void page_firstPageReportsMoreAndLastPageDoesNot() {
        Test.startTest();
        BulkDocumentController.DocumentPage first =
            BulkDocumentController.getDocumentPage(null, 'All', null, null, null, null, null, null, 2);
        BulkDocumentController.DocumentPage all =
            BulkDocumentController.getDocumentPage(null, 'All', null, null, null, null, null, null, 200);
        Test.stopTest();

        System.assertEquals(2, first.documents.size());
        System.assertEquals(true, first.hasMore);
        System.assertNotEquals(null, first.nextCursor);
        System.assertEquals(6, all.documents.size());
        System.assertEquals(false, all.hasMore);
    }

    @isTest
    static void page_invalidPageSizeFallsBackToMax() {
        Test.startTest();
        BulkDocumentController.DocumentPage page =
            BulkDocumentController.getDocumentPage(null, null, null, null, null, null, null, null, 0);
        Test.stopTest();

        System.assertEquals(6, page.documents.size(), 'Size 0 → max page size, blank category → All');
    }

    @isTest
    static void page_invalidCursorOrCategoryIsRejected() {
        Integer failures = 0;
        Test.startTest();
        try {
            BulkDocumentController.getDocumentPage(null, 'All', null, null, null, null, null, 'not-a-cursor', 10);
        } catch (AuraHandledException e) {
            failures++;
        }
        try {
            BulkDocumentController.getDocumentPage(null, 'Nope', null, null, null, null, null, null, 10);
        } catch (AuraHandledException e) {
            failures++;
        }
        Test.stopTest();

        System.assertEquals(2, failures);
    }

    // ─── getDocumentPage: categories ─────────────────────────────────────────

    @isTest
    static void category_matchesTitleKeywordsFirstMatchWins() {
        hed__Affiliation__c affBob = [SELECT Id FROM hed__Affiliation__c WHERE hed__Contact__r.FirstName = 'Bob'];
        createLinkedFile('Admission Fee Receipt', affBob.Id); // admission beats fee
        createLinkedFile('Fee Challan',           affBob.Id);
        createLinkedFile('Hall Ticket Sem 1',     affBob.Id);
        createLinkedFile('Student ID Card',       affBob.Id);

        Test.startTest();
        Set<String> admission = titlesOf(walk(null, 'Admission Letter', null, null, null, null, null, 5));
        Set<String> fee       = titlesOf(walk(null, 'Fee Receipt',      null, null, null, null, null, 5));
        Set<String> admit     = titlesOf(walk(null, 'Admit Card',       null, null, null, null, null, 5));
        Set<String> idCard    = titlesOf(walk(null, 'ID Card',          null, null, null, null, null, 5));
        Set<String> other     = titlesOf(walk(null, 'Other',            null, null, null, null, null, 5));
        Test.stopTest();

        System.assertEquals(new Set<String>{ 'Admission Letter BBA', 'Admission Fee Receipt' }, admission);
        System.assert(fee.contains('Fee Challan'),          'Fee keyword file');
        System.assert(fee.contains('RCPT-001 (Receipt)'),   'Receipt records are Fee Receipts');
        System.assert(!fee.contains('Admission Fee Receipt'), 'Admission matched first');
        System.assertEquals(new Set<String>{ 'Hall Ticket Sem 1' }, admit);
        System.assertEquals(new Set<String>{ 'Student ID Card' },  idCard);
        System.assertEquals(new Set<String>{ 'Enrollment Doc', 'No Batch Doc', 'Orphan Doc' }, other,
            'Other = no keyword match, and never receipts');
    }

    @isTest
    static void category_isReturnedOnEachDocument() {
        List<Map<String, Object>> docs = runGetAll();

        System.assertEquals('Admission Letter', findByTitle(docs, 'Admission Letter BBA').get('category'));
        System.assertEquals('Other',            findByTitle(docs, 'Enrollment Doc').get('category'));
        System.assertEquals('Fee Receipt',      findByTitle(docs, 'RCPT-001 (Receipt)').get('category'));
    }

    // ─── getDocumentPage: filters + search ───────────────────────────────────

    @isTest
    static void filter_programAndBatchApplyToFilesAndReceipts() {
        Set<String> bba = titlesOf(walkFiltered('All', PROGRAM_BBA, PLAN_BBA, null, null, null));

        System.assertEquals(new Set<String>{ 'Admission Letter BBA', 'RCPT-001 (Receipt)' }, bba,
            'Alice\'s file and her receipt; nothing from MBA students');
    }

    @isTest
    static void filter_programOnlyIncludesFilesWithoutBatch() {
        Set<String> mba = titlesOf(walkFiltered('All', PROGRAM_MBA, null, null, null, null));

        System.assertEquals(new Set<String>{ 'Enrollment Doc', 'No Batch Doc' }, mba);
    }

    @isTest
    static void filter_termKeepsEnrollmentFilesAndThatTermsReceipts() {
        insert newReceipt('RCPT-TERM', contactNamed('Carol').Id);

        Set<String> termDocs = titlesOf(walkFiltered('All', null, null, TERM_NAME, null, null));

        System.assertEquals(new Set<String>{ 'Enrollment Doc', 'RCPT-TERM (Receipt)' }, termDocs,
            'Affiliation files have no term and drop out');
    }

    @isTest
    static void filter_feeHeadKeepsOnlyReceiptsWithThatHead() {
        Receipt_and_Invoice__c yearly = newReceipt('RCPT-YEAR', contactNamed('Alice').Id);
        yearly.Fee_Type__c = insertFeeType('Year Wise Fee', null).Id;
        Receipt_and_Invoice__c sem = newReceipt('RCPT-SEM', contactNamed('Alice').Id);
        sem.Fee_Type__c = insertFeeType('Semester Fee', null).Id;
        insert new List<Receipt_and_Invoice__c>{ yearly, sem };

        List<Map<String, Object>> docs = walkFiltered('Fee Receipt', PROGRAM_BBA, PLAN_BBA, null, 'Year Wise Fee', null);

        System.assertEquals(new Set<String>{ 'RCPT-YEAR (Receipt)' }, titlesOf(docs));
        System.assertEquals('Year Wise Fee', docs[0].get('feeHead'));
    }

    @isTest
    static void search_matchesTitleOrStudentNameForFilesAndReceipts() {
        Test.startTest();
        Set<String> byTitle   = titlesOf(walk(null, 'All', null, null, null, null, 'enrollment', 2));
        Set<String> byStudent = titlesOf(walk(null, 'All', null, null, null, null, 'alice', 2));
        Set<String> wildcard  = titlesOf(walk(null, 'All', null, null, null, null, '%', 2));
        Test.stopTest();

        System.assertEquals(new Set<String>{ 'Enrollment Doc' }, byTitle);
        System.assertEquals(new Set<String>{ 'Admission Letter BBA', 'RCPT-001 (Receipt)' }, byStudent,
            'Student name matches both her file and her receipt');
        System.assertEquals(0, wildcard.size(), '% is searched literally, not as a wildcard');
    }

    // ─── getDocumentPage: record mode ────────────────────────────────────────

    @isTest
    static void record_byAffiliationIdReturnsOnlyItsFiles() {
        hed__Affiliation__c aff = [SELECT Id FROM hed__Affiliation__c WHERE hed__Contact__r.FirstName = 'Alice'];

        Test.startTest();
        List<Map<String, Object>> docs = walk(aff.Id, 'All', null, null, null, null, null, 2);
        Test.stopTest();

        System.assertEquals(1, docs.size(), 'Only the file on this affiliation, never receipts');
        Map<String, Object> d = docs[0];
        System.assertEquals('Admission Letter BBA', d.get('title'));
        System.assertEquals('PDF',                  d.get('fileType'));
        System.assertNotEquals(null,                d.get('versionId'));
        System.assertNotEquals(null,                d.get('fileSize'));
        System.assertEquals(
            '/sfc/servlet.shepherd/document/download/' + d.get('id') + '?operationContext=S1',
            d.get('downloadUrl'));
    }

    @isTest
    static void record_byEnrollmentIdAndWithoutFiles() {
        hed__Program_Enrollment__c pe = [SELECT Id FROM hed__Program_Enrollment__c LIMIT 1];
        hed__Affiliation__c bob = [SELECT Id FROM hed__Affiliation__c WHERE hed__Contact__r.FirstName = 'Bob'];

        Test.startTest();
        List<Map<String, Object>> peDocs  = walk(pe.Id,  'All', null, null, null, null, null, 2);
        List<Map<String, Object>> bobDocs = walk(bob.Id, 'All', null, null, null, null, null, 2);
        Test.stopTest();

        System.assertEquals(1, peDocs.size());
        System.assertEquals('Enrollment Doc', peDocs[0].get('title'));
        System.assertEquals(0, bobDocs.size());
    }

    // ─── getDocumentCount ────────────────────────────────────────────────────

    private static void assertCountMatchesPages(Id recordId, String category, String programName,
            String programPlan, String term, String feeHead, String search) {
        Integer counted = BulkDocumentController.getDocumentCount(
            recordId, category, programName, programPlan, term, feeHead, search);
        Integer paged = walk(recordId, category, programName, programPlan, term, feeHead, search, 200).size();
        System.assertEquals(paged, counted,
            'Count for ' + category + ' / ' + programName + ' / ' + term + ' / ' + feeHead + ' / ' + search);
    }

    @isTest
    static void count_equalsPagedTotalForEachTab() {
        hed__Affiliation__c affBob = [SELECT Id FROM hed__Affiliation__c WHERE hed__Contact__r.FirstName = 'Bob'];
        createLinkedFile('Fee Challan', affBob.Id);
        createLinkedFile('Hall Ticket', affBob.Id);

        Test.startTest();
        for (String category : new List<String>{ 'All', 'Admission Letter', 'Fee Receipt', 'Admit Card', 'Other' }) {
            assertCountMatchesPages(null, category, null, null, null, null, null);
        }
        Test.stopTest();

        System.assertEquals(8, BulkDocumentController.getDocumentCount(null, 'All', null, null, null, null, null),
            '6 from setup + 2 new files');
    }

    @isTest
    static void count_equalsPagedTotalUnderFiltersSearchAndRecord() {
        hed__Affiliation__c affAlice = [SELECT Id FROM hed__Affiliation__c WHERE hed__Contact__r.FirstName = 'Alice'];
        // Title and student both match "alice": still one document, one count.
        createLinkedFile('Alice Notes', affAlice.Id);
        Receipt_and_Invoice__c yearly = newReceipt('RCPT-YEAR', contactNamed('Alice').Id);
        yearly.Fee_Type__c = insertFeeType('Year Wise Fee', null).Id;
        insert yearly;
        insert newReceipt('RCPT-TERM', contactNamed('Carol').Id);

        Test.startTest();
        assertCountMatchesPages(null, 'All', PROGRAM_BBA, PLAN_BBA, null, null, null);
        assertCountMatchesPages(null, 'All', null, null, null, null, 'alice');
        assertCountMatchesPages(null, 'All', null, null, TERM_NAME, null, null);
        assertCountMatchesPages(null, 'Fee Receipt', PROGRAM_BBA, PLAN_BBA, null, 'Year Wise Fee', null);
        assertCountMatchesPages(affAlice.Id, 'All', null, null, null, null, null);
        Test.stopTest();

        System.assertEquals(4, BulkDocumentController.getDocumentCount(null, 'All', null, null, null, null, 'alice'),
            'Admission Letter BBA + Alice Notes (counted once) + RCPT-001 + RCPT-YEAR');
    }

    // ─── getFilterOptions / getTermOptions ───────────────────────────────────

    @isTest
    static void filterOptions_programsBatchesAndFeeHeads() {
        insertFeeType('Backlog examination Fee', null);

        Test.startTest();
        BulkDocumentController.FilterOptions opts = BulkDocumentController.getFilterOptions();
        Test.stopTest();

        System.assertEquals(new List<String>{ PROGRAM_BBA, PROGRAM_MBA }, opts.programs);
        System.assertEquals(new List<String>{ PLAN_BBA }, opts.batchesByProgram.get(PROGRAM_BBA));
        System.assertEquals(new List<String>{ PLAN_MBA }, opts.batchesByProgram.get(PROGRAM_MBA));
        System.assert(opts.feeHeads.contains('Backlog examination Fee'), 'From Fee_Type__c');
        System.assert(opts.feeHeads.contains('Semester Fee'), 'Derived fee-plan heads are always offered');
    }

    @isTest
    static void termOptions_forABatchAndBlank() {
        Test.startTest();
        List<String> terms = BulkDocumentController.getTermOptions(PLAN_MBA);
        List<String> none  = BulkDocumentController.getTermOptions(PLAN_BBA);
        List<String> blank = BulkDocumentController.getTermOptions(null);
        Test.stopTest();

        System.assertEquals(new List<String>{ TERM_NAME }, terms);
        System.assertEquals(0, none.size());
        System.assertEquals(0, blank.size());
    }
}