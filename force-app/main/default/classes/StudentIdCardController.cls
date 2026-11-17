/**
 * Controller for the Student E-ID Card.
 *
 * Responsibilities:
 *  - Acts as the Visualforce controller for StudentIdCard.page (renderAs="pdf").
 *  - Exposes @AuraEnabled methods consumed by the idCardGenerator LWC (manual,
 *    single-record generation from the quick action confirmation screen).
 *  - Provides a bulk-safe store helper used by both the manual path and the
 *    AffiliationIdCardBatch (no SOQL/DML inside loops).
 *
 * Field mapping (per requirement):
 *   NAME      = hed__Contact__r.Name
 *   photo     = hed__Contact__r.Passport_photo__c
 *   USN       = Roll_Number__c
 *   PROGRAM   = Program_Plan__r.hed__Account__r.Alias__c
    *   PHONE     = hed__Account__r.Contact_Phone__c
 *   ACD YR    = Program_Plan__r.Academic_Year__c
 *   DOB       = hed__Contact__r.DEB_Date_of_birth__c
 *   BLOOD GP  = hed__Contact__r.Blood_Group__c
 *   SIGNATURE = latest Document_Checklist__c (Document_Type__c = 'Signature')
 *               on an Application__c whose ContactId__c is the student
 *   REGISTRAR = RegistrarSignatureController (Document in ID Card Assets, Registrar Signature tab)
 */
public with sharing class StudentIdCardController {

    public static final String DOCUMENT_TYPE = 'Student ID Card';
    public static final String STATUS_GENERATED = 'Generated';
    public static final String STATUS_FAILED = 'Failed';
    public static final String SIGNATURE_DOCUMENT_TYPE = 'Signature';

    public class IdCardException extends Exception {}

    /** Test-only switch used to exercise the failure-handling path in the batch. */
    @TestVisible
    private static Boolean simulateStoreFailure = false;

    // ===== VF-bound properties =====
    public String studentName { get; private set; }
    public String usn { get; private set; }
    public String program { get; private set; }
    public String phone { get; private set; }
    public String acadYear { get; private set; }
    public String dob { get; private set; }
    public String bloodGroup { get; private set; }
    public String studentPhotoUrl { get; private set; }
    public Boolean hasPhoto { get { return String.isNotBlank(studentPhotoUrl); } }
    // Passport_photo__c is a formula field that already returns a full <img> tag.
    // Rendered as raw HTML (escape="false") - more reliable than the bare URL.
    public String photoHtml { get; private set; }
    public Boolean hasPhotoHtml { get { return String.isNotBlank(photoHtml); } }
    // Latest 'Signature' Document_Checklist__c upload across the student's applications.
    public String signatureUrl { get; private set; }
    public Boolean hasSignature { get { return String.isNotBlank(signatureUrl); } }
    // Uploaded by admins on the Registrar Signature tab; same Document URL on every card.
    public String registrarSignatureUrl { get; private set; }
    public Boolean hasRegistrarSignature { get { return String.isNotBlank(registrarSignatureUrl); } }

    // ===== VF constructor (reads ?affiliationId=) =====
    public StudentIdCardController() {
        studentName = '';
        usn = '';
        program = '';
        phone = '';
        acadYear = '';
        dob = '';
        bloodGroup = '';
        studentPhotoUrl = null;
        registrarSignatureUrl = RegistrarSignatureController.getSignatureUrl();

        Id affiliationId = (Id) ApexPages.currentPage().getParameters().get('affiliationId');
        if (affiliationId == null) {
            return;
        }

        List<hed__Affiliation__c> affs = queryAffiliations(new Set<Id>{ affiliationId });
        if (!affs.isEmpty()) {
            populateFrom(affs[0]);
        }
    }

    // ===== Shared, bulk-safe query =====
    public static List<hed__Affiliation__c> queryAffiliations(Set<Id> affiliationIds) {
        return [
            SELECT Id,
                   Roll_Number__c,
                   hed__Contact__c,
                   hed__Contact__r.Name,
                   hed__Contact__r.Passport_photo__c,
                   hed__Contact__r.Passport_Size_Photo__c,
                   hed__Contact__r.DEB_Date_of_birth__c,
                   hed__Contact__r.Blood_Group__c,
                   Program_Plan__r.hed__Account__r.Alias__c,
                   Program_Plan__r.Academic_Year__c,
                   hed__Contact__r.Contact_Phone__c
            FROM hed__Affiliation__c
            WHERE Id IN :affiliationIds
        ];
    }

    private void populateFrom(hed__Affiliation__c aff) {
        studentName = (aff.hed__Contact__r != null && aff.hed__Contact__r.Name != null)
            ? aff.hed__Contact__r.Name : '';
        usn = (aff.Roll_Number__c != null) ? aff.Roll_Number__c : '';
        program = (aff.Program_Plan__r != null && aff.Program_Plan__r.hed__Account__r != null
                   && aff.Program_Plan__r.hed__Account__r.Alias__c != null)
            ? aff.Program_Plan__r.hed__Account__r.Alias__c : '';
        phone = (aff.hed__Contact__r != null && aff.hed__Contact__r.Contact_Phone__c != null)
            ? aff.hed__Contact__r.Contact_Phone__c : '';
        acadYear = (aff.Program_Plan__r != null && aff.Program_Plan__r.Academic_Year__c != null)
            ? String.valueOf(aff.Program_Plan__r.Academic_Year__c) : '';
        bloodGroup = (aff.hed__Contact__r != null && aff.hed__Contact__r.Blood_Group__c != null)
            ? aff.hed__Contact__r.Blood_Group__c : '';

        if (aff.hed__Contact__r != null && aff.hed__Contact__r.DEB_Date_of_birth__c != null) {
            dob = formatDob(aff.hed__Contact__r.DEB_Date_of_birth__c);
        }
        if (aff.hed__Contact__r != null) {
            // Primary: the formula HTML <img> tag (upscaled to fit the ID card photo box).
            photoHtml = upscalePhotoHtml(aff.hed__Contact__r.Passport_photo__c);
            // Fallback: the bare URL field, rendered into a plain <img src>.
            studentPhotoUrl = normalizePhotoUrl(aff.hed__Contact__r.Passport_Size_Photo__c);
        }
        signatureUrl = findSignatureUrl(aff.hed__Contact__c);
        // A file uploaded as the signature is not the student's photo - show it only as the signature.
        if (hasSignature && signatureUrl == studentPhotoUrl) {
            photoHtml = null;
            studentPhotoUrl = null;
        }
    }

    @TestVisible
    private static String findSignatureUrl(Id contactId) {
        if (contactId == null) return null;
        List<Document_Checklist__c> docs = [
            SELECT Document_Upload_URL__c
            FROM Document_Checklist__c
            WHERE Application__r.ContactId__c = :contactId
              AND Document_Type__c = :SIGNATURE_DOCUMENT_TYPE
              AND Document_Upload_URL__c != null
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        return docs.isEmpty() ? null : normalizePhotoUrl(docs[0].Document_Upload_URL__c);
    }

    /** Enlarges the passport photo from the formula's default 78x97 to fill the ID card box. */
    @TestVisible
    private static String upscalePhotoHtml(String raw) {
        if (String.isBlank(raw)) return null;
        return raw.replace('height:97px; width:78px;', 'height:118px; width:96px;');
    }

    @TestVisible
    private static String formatDob(Date d) {
        if (d == null) return '';
        DateTime dt = DateTime.newInstance(d.year(), d.month(), d.day());
        return dt.format('dd-MMM-yyyy').toUpperCase();
    }

    @TestVisible
    private static String normalizePhotoUrl(String raw) {
        if (String.isBlank(raw)) return null;
        String v = raw.trim();
        if (v.startsWith('http://') || v.startsWith('https://') || v.startsWith('/')) {
            return v;
        }
        if (v.length() == 15 || v.length() == 18) {
            return '/sfc/servlet.shepherd/version/download/' + v;
        }
        return v;
    }

    // =====================================================================
    // LWC entry points (manual, single record from the quick action)
    // =====================================================================

    public class AffiliationInfo {
        @AuraEnabled public String name;
        @AuraEnabled public String usn;
        @AuraEnabled public String status;
        @AuraEnabled public Boolean ready;   // true when both Roll Number & DSU Email present
        @AuraEnabled public String message;
    }

    @AuraEnabled(cacheable=true)
    public static AffiliationInfo getAffiliationInfo(Id affiliationId) {
        if (affiliationId == null) {
            throw new AuraHandledException('Affiliation Id is required.');
        }
        List<hed__Affiliation__c> affs = [
            SELECT Id, Roll_Number__c, DSU_Email__c, ID_Card_Generation_Status__c,
                   hed__Contact__r.Name
            FROM hed__Affiliation__c
            WHERE Id = :affiliationId
            LIMIT 1
        ];
        if (affs.isEmpty()) {
            throw new AuraHandledException('Affiliation not found.');
        }
        hed__Affiliation__c aff = affs[0];

        AffiliationInfo info = new AffiliationInfo();
        info.name = (aff.hed__Contact__r != null) ? aff.hed__Contact__r.Name : null;
        info.usn = aff.Roll_Number__c;
        info.status = aff.ID_Card_Generation_Status__c;
        info.ready = String.isNotBlank(aff.Roll_Number__c) && String.isNotBlank(aff.DSU_Email__c);
        info.message = info.ready
            ? null
            : 'Roll Number and DSU Email must both be populated before an ID card can be generated.';
        return info;
    }

    /**
     * Generates a single ID card synchronously and saves it on the affiliation.
     * Safe for the manual/quick-action path (one PDF per transaction).
     */
    @AuraEnabled
    public static Id generateIdCard(Id affiliationId) {
        if (affiliationId == null) {
            throw new AuraHandledException('Affiliation Id is required.');
        }

        List<hed__Affiliation__c> affs = [
            SELECT Id, Roll_Number__c, DSU_Email__c, hed__Contact__r.Name
            FROM hed__Affiliation__c
            WHERE Id = :affiliationId
            LIMIT 1
        ];
        if (affs.isEmpty()) {
            throw new AuraHandledException('Affiliation not found.');
        }
        hed__Affiliation__c aff = affs[0];
        if (String.isBlank(aff.Roll_Number__c) || String.isBlank(aff.DSU_Email__c)) {
            throw new AuraHandledException(
                'Roll Number and DSU Email must both be populated before an ID card can be generated.');
        }

        Blob pdf = renderPdf(affiliationId);

        Map<Id, Blob> pdfByAff = new Map<Id, Blob>{ affiliationId => pdf };
        Map<Id, String> nameByAff = new Map<Id, String>{
            affiliationId => (aff.hed__Contact__r != null ? aff.hed__Contact__r.Name : null)
        };
        Map<Id, String> usnByAff = new Map<Id, String>{ affiliationId => aff.Roll_Number__c };

        Map<Id, Id> docByAff = storeIdCards(pdfByAff, nameByAff, usnByAff);

        markStatus(new Set<Id>{ affiliationId }, STATUS_GENERATED);

        return docByAff.get(affiliationId);
    }

    // =====================================================================
    // Shared generation + storage helpers (used by LWC + Batch)
    // =====================================================================

    /** Renders the VF PDF for one affiliation (returns dummy blob in tests). */
    public static Blob renderPdf(Id affiliationId) {
        PageReference pr = Page.StudentIdCard;
        pr.getParameters().put('affiliationId', String.valueOf(affiliationId));
        if (Test.isRunningTest()) {
            return Blob.valueOf('TEST_PDF');
        }
        return pr.getContentAsPDF();
    }

    /**
     * Bulk-safe store. For each affiliation:
     *   - deletes any existing "Student ID Card" document linked to it (override rule:
     *     never more than one ID card per affiliation),
     *   - inserts the new ContentVersion (Document_Type__c = 'Student ID Card'),
     *   - links it to the affiliation via ContentDocumentLink.
     * No SOQL or DML inside loops.
     */
    public static Map<Id, Id> storeIdCards(
        Map<Id, Blob> pdfByAff,
        Map<Id, String> nameByAff,
        Map<Id, String> usnByAff
    ) {
        Map<Id, Id> docIdByAff = new Map<Id, Id>();
        if (pdfByAff == null || pdfByAff.isEmpty()) {
            return docIdByAff;
        }
        if (Test.isRunningTest() && simulateStoreFailure) {
            throw new IdCardException('Simulated store failure');
        }

        Set<Id> affIds = pdfByAff.keySet();

        // 1) Existing links for these affiliations
        Map<Id, Set<Id>> docIdsByAff = new Map<Id, Set<Id>>();
        Set<Id> allDocIds = new Set<Id>();
        for (ContentDocumentLink cdl : [
            SELECT ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :affIds
        ]) {
            if (!docIdsByAff.containsKey(cdl.LinkedEntityId)) {
                docIdsByAff.put(cdl.LinkedEntityId, new Set<Id>());
            }
            docIdsByAff.get(cdl.LinkedEntityId).add(cdl.ContentDocumentId);
            allDocIds.add(cdl.ContentDocumentId);
        }

        // 2) Of those, which are existing ID cards (latest version, correct type)
        Set<Id> existingIdCardDocIds = new Set<Id>();
        if (!allDocIds.isEmpty()) {
            for (ContentVersion cv : [
                SELECT ContentDocumentId
                FROM ContentVersion
                WHERE ContentDocumentId IN :allDocIds
                  AND IsLatest = true
                  AND Document_Type__c = :DOCUMENT_TYPE
            ]) {
                existingIdCardDocIds.add(cv.ContentDocumentId);
            }
        }

        // 3) Delete prior ID cards (override) - only those of the correct type
        if (!existingIdCardDocIds.isEmpty()) {
            List<ContentDocument> toDelete = new List<ContentDocument>();
            for (Id docId : existingIdCardDocIds) {
                toDelete.add(new ContentDocument(Id = docId));
            }
            delete toDelete;
        }

        // 4) Insert new ContentVersions
        List<ContentVersion> versions = new List<ContentVersion>();
        List<Id> affOrder = new List<Id>();
        for (Id affId : affIds) {
            String title = buildTitle(
                (nameByAff != null ? nameByAff.get(affId) : null),
                (usnByAff != null ? usnByAff.get(affId) : null),
                affId
            );
            ContentVersion cv = new ContentVersion();
            cv.Title = title;
            cv.PathOnClient = title + '.pdf';
            cv.VersionData = pdfByAff.get(affId);
            cv.Document_Type__c = DOCUMENT_TYPE;
            versions.add(cv);
            affOrder.add(affId);
        }
        insert versions;

        // 5) Map inserted ContentVersion -> ContentDocumentId
        Set<Id> versionIds = new Set<Id>();
        for (ContentVersion cv : versions) {
            versionIds.add(cv.Id);
        }
        Map<Id, Id> docIdByVersionId = new Map<Id, Id>();
        for (ContentVersion cv : [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id IN :versionIds
        ]) {
            docIdByVersionId.put(cv.Id, cv.ContentDocumentId);
        }

        // 6) Build links
        List<ContentDocumentLink> links = new List<ContentDocumentLink>();
        for (Integer i = 0; i < versions.size(); i++) {
            Id affId = affOrder[i];
            Id docId = docIdByVersionId.get(versions[i].Id);
            if (docId == null) continue;
            docIdByAff.put(affId, docId);

            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.LinkedEntityId = affId;
            cdl.ContentDocumentId = docId;
            cdl.ShareType = 'V';
            cdl.Visibility = 'AllUsers';
            links.add(cdl);
        }
        if (!links.isEmpty()) {
            insert links;
        }

        return docIdByAff;
    }

    /** Bulk-safe status stamp on affiliations. */
    public static void markStatus(Set<Id> affiliationIds, String status) {
        if (affiliationIds == null || affiliationIds.isEmpty()) return;
        List<hed__Affiliation__c> toUpdate = new List<hed__Affiliation__c>();
        for (Id affId : affiliationIds) {
            hed__Affiliation__c aff = new hed__Affiliation__c(Id = affId);
            aff.ID_Card_Generation_Status__c = status;
            if (status == STATUS_GENERATED) {
                aff.ID_Card_Last_Generated__c = System.now();
            }
            toUpdate.add(aff);
        }
        update toUpdate;
    }

    @TestVisible
    private static String buildTitle(String studentName, String usn, Id affId) {
        String cleanName = String.isBlank(studentName) ? null : studentName.trim();
        String cleanUsn = String.isBlank(usn) ? null : usn.trim();
        if (cleanName != null && cleanUsn != null) {
            return cleanName + '(' + cleanUsn + ')_Student E-ID Card';
        }
        if (cleanUsn != null) {
            return cleanUsn + '_Student E-ID Card';
        }
        if (cleanName != null) {
            return cleanName + '_Student E-ID Card';
        }
        return String.valueOf(affId) + '_Student E-ID Card';
    }
}