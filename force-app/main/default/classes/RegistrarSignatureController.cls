/**
 * Registrar signature for the Student E-ID Card.
 *
 * Responsibilities:
 *  - Backs the registrarSignatureManager LWC (Registrar Signature tab) where an
 *    admin uploads, replaces or removes the signature.
 *  - Gives StudentIdCard.page the URL to print the signature under "Registrar".
 *
 * Storage: a Document (DeveloperName Registrar_Signature) in the "ID Card Assets"
 * folder, which is Public / Read Only so every internal user - and so whoever or
 * whatever generates the card - can read it. Other options were tried in QA and
 * do not render in the Visualforce PDF:
 *  - Files: access is enforced even in system-mode Apex, so a File uploaded by one
 *    admin is unreadable when another user or the batch generates the card.
 *  - base64 data URIs: the PDF renderer shows a broken image.
 *  - Relative /servlet URLs: not fetched with a session; the absolute org-domain URL is.
 *
 * Only users with the Manage_ID_Card_Settings custom permission (granted by the
 * ID_Card_Settings_Admin permission set) can change the signature.
 */
public with sharing class RegistrarSignatureController {

    public static final String MANAGE_PERMISSION = 'Manage_ID_Card_Settings';
    @TestVisible
    private static final String FOLDER_NAME = 'ID_Card_Assets';
    @TestVisible
    private static final String DOCUMENT_NAME = 'Registrar_Signature';
    @TestVisible
    private static final Integer MAX_BYTES = 1024 * 1024;

    public class SignatureInfo {
        @AuraEnabled public Boolean canManage;
        @AuraEnabled public Boolean hasSignature;
        @AuraEnabled public String fileName;
        @AuraEnabled public String dataUrl;
        @AuraEnabled public String lastModifiedBy;
        @AuraEnabled public Datetime lastModifiedDate;
        @AuraEnabled public Integer maxBytes;
    }

    // =====================================================================
    // LWC entry points
    // =====================================================================

    @AuraEnabled
    public static SignatureInfo getRegistrarSignature() {
        return toInfo(new Store().load(true));
    }

    @AuraEnabled
    public static SignatureInfo saveRegistrarSignature(String fileName, String base64Data) {
        requireManagePermission();
        if (String.isBlank(base64Data)) {
            throw new AuraHandledException('Choose a signature image to upload.');
        }
        String contentType = detectContentType(base64Data);
        if (contentType == null) {
            throw new AuraHandledException('The signature must be a PNG or JPG image.');
        }
        Blob body;
        try {
            body = EncodingUtil.base64Decode(base64Data);
        } catch (Exception e) {
            throw new AuraHandledException('The uploaded file could not be read.');
        }
        if (body.size() > MAX_BYTES) {
            throw new AuraHandledException('The signature image must be ' + (MAX_BYTES / 1024)
                + ' KB or smaller. This file is ' + Math.ceil(body.size() / 1024.0).intValue() + ' KB.');
        }

        Store store = new Store();
        Document doc = store.load(false);
        if (doc == null) {
            doc = new Document(DeveloperName = DOCUMENT_NAME, FolderId = store.folderId(), IsPublic = false);
        }
        // Name is what admins see in the Documents tab; keep the uploaded file name there.
        doc.Name = String.isBlank(fileName) ? 'Registrar Signature' : fileName.left(255);
        doc.ContentType = contentType;
        doc.Type = contentType == 'image/png' ? 'png' : 'jpg';
        doc.Body = body;
        store.save(doc);

        return toInfo(store.load(true));
    }

    @AuraEnabled
    public static SignatureInfo removeRegistrarSignature() {
        requireManagePermission();
        Store store = new Store();
        Document doc = store.load(false);
        if (doc != null) {
            store.remove(doc);
        }
        return toInfo(null);
    }

    // =====================================================================
    // ID card entry point
    // =====================================================================

    /** Absolute download URL for StudentIdCard.page, or null when none is uploaded. */
    public static String getSignatureUrl() {
        Document doc = new Store().load(false);
        if (doc == null) return null;
        return URL.getOrgDomainUrl().toExternalForm() + '/servlet/servlet.FileDownload?file=' + doc.Id;
    }

    // =====================================================================
    // Helpers
    // =====================================================================

    private static void requireManagePermission() {
        if (!FeatureManagement.checkPermission(MANAGE_PERMISSION)) {
            throw new AuraHandledException(
                'You do not have permission to manage the Registrar signature. '
                + 'Ask an admin for the ID Card Settings Admin permission set.');
        }
    }

    /** Sniffs the image type from the base64 header instead of trusting the browser. */
    @TestVisible
    private static String detectContentType(String base64Data) {
        if (base64Data.startsWith('iVBORw0KGgo')) return 'image/png';
        if (base64Data.startsWith('/9j/')) return 'image/jpeg';
        return null;
    }

    private static SignatureInfo toInfo(Document doc) {
        SignatureInfo info = new SignatureInfo();
        info.canManage = FeatureManagement.checkPermission(MANAGE_PERMISSION);
        info.maxBytes = MAX_BYTES;
        info.hasSignature = doc != null;
        if (info.hasSignature) {
            info.fileName = doc.Name;
            // Preview for the LWC only; the PDF uses getSignatureUrl().
            info.dataUrl = 'data:' + doc.ContentType + ';base64,' + EncodingUtil.base64Encode(doc.Body);
            info.lastModifiedBy = doc.LastModifiedBy != null ? doc.LastModifiedBy.Name : null;
            info.lastModifiedDate = doc.LastModifiedDate;
        }
        return info;
    }

    /**
     * Reads and writes the Document in system context so the card shows the same
     * signature for every user, and one admin can replace another admin's upload.
     * Callers enforce the custom permission before any write.
     */
    private without sharing class Store {
        Document load(Boolean withBody) {
            List<Document> docs = withBody
                ? [SELECT Id, Name, ContentType, Body, LastModifiedDate, LastModifiedBy.Name
                   FROM Document WHERE DeveloperName = :DOCUMENT_NAME LIMIT 1]
                : [SELECT Id, Name, ContentType, LastModifiedDate, LastModifiedBy.Name
                   FROM Document WHERE DeveloperName = :DOCUMENT_NAME LIMIT 1];
            return docs.isEmpty() ? null : docs[0];
        }
        Id folderId() {
            List<Folder> folders = [SELECT Id FROM Folder WHERE DeveloperName = :FOLDER_NAME LIMIT 1];
            if (folders.isEmpty()) {
                throw new AuraHandledException('The "ID Card Assets" document folder is missing. Deploy it first.');
            }
            return folders[0].Id;
        }
        void save(Document doc) {
            upsert doc;
        }
        void remove(Document doc) {
            delete doc;
        }
    }
}