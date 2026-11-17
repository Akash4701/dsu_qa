/**
 * Request body for MerritoDocumentSyncService: the documents a student captured on the
 * Meritto application form, sent on their own after the application already exists.
 */
public class MerritoDocumentSyncWrapper {
    public List<DocumentInfo> Documents;

    /** One captured document → one Document_Checklist__c row. */
    public class DocumentInfo {
        public String DocumentType;
        public String DocumentName;
        /** Required. Matched against Application__c.External_Application_Number__c. */
        public String ApplicationNumber;
        public String DocumentUploadUrl;
    }
}