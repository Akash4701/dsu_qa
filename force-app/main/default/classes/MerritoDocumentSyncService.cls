/**
 * Records the documents captured on the Meritto application form on each Application's
 * document checklist, separately from ApplicantServiceV4 so documents can be sent (or
 * re-sent) after the application was created.
 *
 * Request:
 *   { "Documents": [ { "DocumentType": "PDF", "DocumentName": "Class 10 marksheet",
 *                      "ApplicationNumber": "LEGACY-9999",
 *                      "DocumentUploadUrl": "https://example.com/doc/class10.pdf" } ] }
 *
 * Each document is matched to the Application whose External_Application_Number__c
 * equals its ApplicationNumber. A document already on that Application with the same
 * DocumentUploadUrl is updated rather than added again, so re-sending is safe.
 *
 * A document named "Passport Size Photo" also sets the applicant Contact's
 * Passport_Size_Photo__c to its DocumentUploadUrl.
 *
 * Every Application that has a document saved gets Documents_Synced__c ticked and
 * Documents_Synced_On__c set to the time of the sync. One in Status__c "CRM Enrolled" also
 * moves to "Enrolled with Documents"; any other status is left as it is.
 *
 * Response: one result per document, in request order.
 *   200 - every document was recorded, or was rejected for a reason a retry cannot fix.
 *   404 - at least one document's application is not in Salesforce; the others are saved.
 *   400 - the body is not a valid request.
 *   500 - the save failed; nothing in the request was saved.
 */
@RestResource(urlMapping='/MerritoDocumentSync')
global with sharing class MerritoDocumentSyncService {

    @TestVisible static final String STATUS_CREATED = 'CREATED';
    @TestVisible static final String STATUS_UPDATED = 'UPDATED';
    @TestVisible static final String STATUS_APPLICATION_NOT_FOUND = 'APPLICATION_NOT_FOUND';
    @TestVisible static final String STATUS_INVALID = 'INVALID';

    // Length of Document_Checklist__c's text and URL fields.
    private static final Integer MAX_FIELD_LENGTH = 255;

    // Document_Name__c of the checklist row whose URL becomes the Contact's photo.
    @TestVisible static final String PASSPORT_PHOTO_DOCUMENT_NAME = 'Passport Size Photo';

    // An Application in CRM Enrolled moves to Enrolled with Documents once it has documents saved.
    @TestVisible static final String APPLICATION_STATUS_CRM_ENROLLED = 'CRM Enrolled';
    @TestVisible static final String APPLICATION_STATUS_ENROLLED_WITH_DOCUMENTS = 'Enrolled with Documents';

    @HttpPost
    global static void syncDocuments() {
        List<MerritoDocumentSyncWrapper.DocumentInfo> documents;
        try {
            MerritoDocumentSyncWrapper body = (MerritoDocumentSyncWrapper) JSON.deserialize(
                RestContext.request.requestBody.toString(), MerritoDocumentSyncWrapper.class);
            documents = body == null ? null : body.Documents;
        } catch (Exception e) {
            respond(400, new Map<String, Object>{ 'error' => 'Request body is not valid JSON: ' + e.getMessage() });
            return;
        }
        if (documents == null || documents.isEmpty()) {
            respond(400, new Map<String, Object>{ 'error' => 'Documents is required' });
            return;
        }

        List<Result> results;
        try {
            results = sync(documents);
        } catch (Exception e) {
            // A lock wait that timed out or a failed save; nothing was saved.
            respond(500, new Map<String, Object>{ 'error' => e.getMessage() });
            return;
        }

        Integer status = 200;
        for (Result r : results) {
            if (r.status == STATUS_APPLICATION_NOT_FOUND) {
                status = 404;
            }
        }
        respond(status, new Map<String, Object>{ 'results' => results });
    }

    @TestVisible
    private static List<Result> sync(List<MerritoDocumentSyncWrapper.DocumentInfo> documents) {
        List<Result> results = new List<Result>();
        Set<String> numbers = new Set<String>();

        for (Integer i = 0; i < documents.size(); i++) {
            MerritoDocumentSyncWrapper.DocumentInfo doc = documents[i];
            Result result = new Result();
            result.index = i;
            results.add(result);
            result.applicationNumber = doc.ApplicationNumber;
            result.documentName = doc.DocumentName;
            result.message = invalidReason(doc);
            if (result.message != null) {
                result.status = STATUS_INVALID;
            } else {
                numbers.add(doc.ApplicationNumber.trim());
            }
        }

        Map<String, Application__c> appsByNumber = new Map<String, Application__c>();
        if (!numbers.isEmpty()) {
            for (Application__c app : [
                SELECT Id, External_Application_Number__c, ContactId__c
                FROM Application__c
                WHERE External_Application_Number__c IN :numbers
            ]) {
                appsByNumber.put(app.External_Application_Number__c, app);
            }
        }

        Set<Id> appIds = new Set<Id>();
        Set<String> urls = new Set<String>();
        for (Integer i = 0; i < documents.size(); i++) {
            if (results[i].status != null) {
                continue;
            }
            MerritoDocumentSyncWrapper.DocumentInfo doc = documents[i];
            Application__c app = appsByNumber.get(doc.ApplicationNumber.trim());
            if (app == null) {
                results[i].status = STATUS_APPLICATION_NOT_FOUND;
                results[i].message = 'No Application with CRM Application Number ' + doc.ApplicationNumber.trim();
                continue;
            }
            appIds.add(app.Id);
            if (String.isNotBlank(doc.DocumentUploadUrl)) {
                urls.add(doc.DocumentUploadUrl.trim());
            }
        }
        if (appIds.isEmpty()) {
            return results;
        }

        // The same request sent twice at once would otherwise insert every document twice:
        // locking the applications makes the second wait and then find the first's rows.
        List<Application__c> locked = [SELECT Id, Status__c FROM Application__c WHERE Id IN :appIds FOR UPDATE];

        Map<String, Document_Checklist__c> rowsByAppAndUrl = new Map<String, Document_Checklist__c>();
        if (!urls.isEmpty()) {
            for (Document_Checklist__c row : [
                SELECT Id, Application__c, Document_Name__c, Document_Upload_URL__c
                FROM Document_Checklist__c
                WHERE Application__c IN :appIds AND Document_Upload_URL__c IN :urls
                ORDER BY CreatedDate, Id
            ]) {
                String appAndUrl = row.Application__c + '|' + row.Document_Upload_URL__c;
                if (!rowsByAppAndUrl.containsKey(appAndUrl)) {
                    rowsByAppAndUrl.put(appAndUrl, row);
                }
            }
        }

        // Rows to save, one per document; a document repeated within the request shares a row.
        List<Document_Checklist__c> rowsToSave = new List<Document_Checklist__c>();
        Set<Id> existingIdsToSave = new Set<Id>();
        Map<Integer, Document_Checklist__c> rowsByIndex = new Map<Integer, Document_Checklist__c>();
        for (Integer i = 0; i < documents.size(); i++) {
            if (results[i].status != null) {
                continue;
            }
            MerritoDocumentSyncWrapper.DocumentInfo doc = documents[i];
            Application__c app = appsByNumber.get(doc.ApplicationNumber.trim());
            String url = String.isBlank(doc.DocumentUploadUrl) ? null : doc.DocumentUploadUrl.trim();

            Document_Checklist__c row = url == null ? null : rowsByAppAndUrl.get(app.Id + '|' + url);
            if (row == null) {
                row = new Document_Checklist__c(Application__c = app.Id, Document_Upload_URL__c = url);
                rowsToSave.add(row);
                if (url != null) {
                    rowsByAppAndUrl.put(app.Id + '|' + url, row);
                }
                results[i].status = STATUS_CREATED;
            } else {
                // A new row is already in the list; an existing one is added the first time.
                if (row.Id != null && existingIdsToSave.add(row.Id)) {
                    rowsToSave.add(row);
                }
                results[i].status = row.Id == null ? STATUS_CREATED : STATUS_UPDATED;
            }

            row.Application_Number__c = app.External_Application_Number__c;
            // Blank values never wipe what an earlier send already recorded.
            if (String.isNotBlank(doc.DocumentType)) {
                row.Document_Type__c = doc.DocumentType.trim();
            }
            if (String.isNotBlank(doc.DocumentName)) {
                row.Document_Name__c = doc.DocumentName.trim();
            }
            rowsByIndex.put(i, row);
        }

        upsert rowsToSave;

        // Request order, so the last photo sent for a Contact is the one it keeps.
        Map<Id, String> photoUrlByContact = new Map<Id, String>();
        for (Integer i = 0; i < documents.size(); i++) {
            Document_Checklist__c row = rowsByIndex.get(i);
            if (row == null) {
                continue;
            }
            results[i].documentChecklistId = row.Id;

            Id contactId = appsByNumber.get(documents[i].ApplicationNumber.trim()).ContactId__c;
            if (contactId != null && isPassportPhoto(row)) {
                photoUrlByContact.put(contactId, row.Document_Upload_URL__c);
            }
        }
        updateContactPhotos(photoUrlByContact);
        markDocumentsSynced(locked);
        return results;
    }

    /**
     * Ticks Documents_Synced__c and stamps Documents_Synced_On__c on each Application that had
     * a document saved, whatever its status. Only CRM Enrolled also moves to Enrolled with
     * Documents; any other status (on hold, admitted, ...) is left as it is.
     */
    private static void markDocumentsSynced(List<Application__c> apps) {
        List<Application__c> appsToUpdate = new List<Application__c>();
        Datetime syncedOn = Datetime.now();
        for (Application__c app : apps) {
            Application__c appToUpdate = new Application__c(
                Id = app.Id, Documents_Synced__c = true, Documents_Synced_On__c = syncedOn);
            if (app.Status__c == APPLICATION_STATUS_CRM_ENROLLED) {
                appToUpdate.Status__c = APPLICATION_STATUS_ENROLLED_WITH_DOCUMENTS;
            }
            appsToUpdate.add(appToUpdate);
        }
        update appsToUpdate;
    }

    /** Whether the row is the applicant's passport photo, with a URL to show it from. */
    private static Boolean isPassportPhoto(Document_Checklist__c row) {
        return String.isNotBlank(row.Document_Upload_URL__c)
            && row.Document_Name__c != null
            && row.Document_Name__c.trim().equalsIgnoreCase(PASSPORT_PHOTO_DOCUMENT_NAME);
    }

    /** Sets Passport_Size_Photo__c on each Contact, skipping those that already have that URL. */
    private static void updateContactPhotos(Map<Id, String> photoUrlByContact) {
        if (photoUrlByContact.isEmpty()) {
            return;
        }
        List<Contact> contactsToUpdate = new List<Contact>();
        for (Contact c : [
            SELECT Id, Passport_Size_Photo__c FROM Contact WHERE Id IN :photoUrlByContact.keySet()
        ]) {
            String url = photoUrlByContact.get(c.Id);
            // equals, not !=, because Apex's != ignores case and URLs do not.
            if (!url.equals(c.Passport_Size_Photo__c)) {
                c.Passport_Size_Photo__c = url;
                contactsToUpdate.add(c);
            }
        }
        update contactsToUpdate;
    }

    /** Why a document cannot be recorded, or null when it can. */
    private static String invalidReason(MerritoDocumentSyncWrapper.DocumentInfo doc) {
        if (String.isBlank(doc.ApplicationNumber)) {
            return 'ApplicationNumber is required';
        }
        if (String.isBlank(doc.DocumentType) && String.isBlank(doc.DocumentName)
            && String.isBlank(doc.DocumentUploadUrl)) {
            return 'At least one of DocumentType, DocumentName or DocumentUploadUrl is required';
        }
        for (String value : new List<String>{ doc.DocumentType, doc.DocumentName, doc.DocumentUploadUrl }) {
            if (value != null && value.trim().length() > MAX_FIELD_LENGTH) {
                return 'DocumentType, DocumentName and DocumentUploadUrl must be at most '
                    + MAX_FIELD_LENGTH + ' characters';
            }
        }
        return null;
    }

    private static void respond(Integer statusCode, Object body) {
        RestContext.response.statusCode = statusCode;
        RestContext.response.addHeader('Content-Type', 'application/json');
        RestContext.response.responseBody = Blob.valueOf(JSON.serialize(body));
    }

    public class Result {
        public Integer index;
        public String applicationNumber;
        public String documentName;
        public String status;
        public Id documentChecklistId;
        public String message;
    }
}