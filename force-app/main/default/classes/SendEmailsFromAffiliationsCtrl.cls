public with sharing class SendEmailsFromAffiliationsCtrl {

    // 3 MB per file
    public static final Integer MAX_FILE_SIZE_BYTES = 3 * 1024 * 1024;

    public ApexPages.StandardSetController ssc { get; private set; }
    public String subject { get; set; }
    public String body { get; set; }

    public List<String> previewRecipients { get; private set; }

    // Single current file bound to <apex:inputFile>
    public Attachment currentFile { get; set; }

    // Files already saved as ContentDocument
    public List<Id> savedDocIds { get; set; }
    public List<String> savedFileNames { get; set; }

    private List<hed__Affiliation__c> selectedAffils;
    private Map<Id, Contact> contactsById;

    // --------- PROPERTIES ---------

    public Boolean getHasRecipients() {
        return previewRecipients != null && !previewRecipients.isEmpty();
    }

    public Boolean getHasFiles() {
        return savedFileNames != null && !savedFileNames.isEmpty();
    }

    public String getPreviewRecipientsString() {
        return (previewRecipients == null || previewRecipients.isEmpty())
            ? ''
            : String.join(previewRecipients, ', ');
    }

    // --------- CONSTRUCTOR ---------

    public SendEmailsFromAffiliationsCtrl(ApexPages.StandardSetController controller) {
        ssc = controller;
        ssc.setPageSize(2000);

        previewRecipients = new List<String>();
        currentFile       = new Attachment();
        savedDocIds       = new List<Id>();
        savedFileNames    = new List<String>();

        buildPreview();
    }

    // --------- ATTACHMENTS ---------

    public void addCurrentFile() {
        if (currentFile == null || currentFile.Body == null || String.isBlank(currentFile.Name)) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'Please choose a file before clicking "Add Attachment".'
            ));
            return;
        }

        // Size validation
        Integer sizeBytes = currentFile.Body.size();
        if (sizeBytes > MAX_FILE_SIZE_BYTES) {
            Decimal sizeMb = (Decimal) sizeBytes / (1024 * 1024);
            sizeMb = sizeMb.setScale(1);
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'File "' + currentFile.Name + '" is ' + String.valueOf(sizeMb) +
                ' MB. Maximum allowed size is 3 MB.'
            ));
            currentFile = new Attachment(); // reset
            return;
        }

        try {
            // Save as ContentVersion immediately
            ContentVersion cv = new ContentVersion();
            cv.Title        = currentFile.Name;
            cv.PathOnClient = currentFile.Name;
            cv.VersionData  = currentFile.Body;
            cv.Origin       = 'H';
            insert cv;

            // Get ContentDocumentId
            ContentVersion cvQuery = [
                SELECT ContentDocumentId
                FROM ContentVersion
                WHERE Id = :cv.Id
                LIMIT 1
            ];

            savedDocIds.add(cvQuery.ContentDocumentId);
            savedFileNames.add(currentFile.Name);

            currentFile = new Attachment(); // clear Blob from view state

            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.CONFIRM,
                'Attachment added.'
            ));
        } catch (Exception e) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'Error adding attachment: ' + e.getMessage()
            ));
            currentFile = new Attachment();
        }
    }

    public void clearFiles() {
        savedDocIds.clear();
        savedFileNames.clear();
        currentFile = new Attachment();
    }

    // --------- PREVIEW BUILDING ---------

    private void buildPreview() {
        List<hed__Affiliation__c> raw = (List<hed__Affiliation__c>) ssc.getSelected();
        if (raw == null || raw.isEmpty()) {
            previewRecipients = new List<String>();
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.INFO,
                'Select at least one Affiliation in the list view.'
            ));
            return;
        }

        Set<Id> affilIds = new Set<Id>();
        for (hed__Affiliation__c a : raw) {
            if (a != null && a.Id != null) affilIds.add(a.Id);
        }
        if (affilIds.isEmpty()) return;

        selectedAffils = [
            SELECT Id, DSU_Email__c, hed__Contact__c
            FROM hed__Affiliation__c
            WHERE Id IN :affilIds
        ];

        Set<Id> contactIds = new Set<Id>();
        for (hed__Affiliation__c a : selectedAffils) {
            if (a.hed__Contact__c != null) contactIds.add(a.hed__Contact__c);
        }

        contactsById = new Map<Id, Contact>();
        if (!contactIds.isEmpty()) {
            contactsById = new Map<Id, Contact>([
                SELECT Id, Email, HasOptedOutOfEmail
                FROM Contact
                WHERE Id IN :contactIds
            ]);
        }

        Set<String> emails = new Set<String>();
        for (hed__Affiliation__c a : selectedAffils) {
            if (a.DSU_Email__c != null) {
                emails.add(a.DSU_Email__c.trim());
            }
            Contact c = contactsById.get(a.hed__Contact__c);
            if (c != null && c.Email != null && !c.HasOptedOutOfEmail) {
                emails.add(c.Email.trim());
            }
        }

        previewRecipients.clear();
        previewRecipients.addAll(emails);
        previewRecipients.sort();
    }

    // --------- FILE LINK HELPERS ---------

    private void linkFilesToContacts(List<Id> docIds, Set<Id> contactIds) {
        if (docIds == null || docIds.isEmpty() || contactIds == null || contactIds.isEmpty()) return;

        List<ContentDocumentLink> links = new List<ContentDocumentLink>();
        for (Id cId : contactIds) {
            for (Id dId : docIds) {
                links.add(new ContentDocumentLink(
                    ContentDocumentId = dId,
                    LinkedEntityId    = cId,
                    ShareType         = 'V',
                    Visibility        = 'AllUsers'
                ));
            }
        }
        if (!links.isEmpty()) insert links;
    }

    private void linkFilesToAffiliations(List<Id> docIds, Set<Id> affiliationIds) {
        if (docIds == null || docIds.isEmpty() || affiliationIds == null || affiliationIds.isEmpty()) return;

        List<ContentDocumentLink> links = new List<ContentDocumentLink>();
        for (Id aId : affiliationIds) {
            for (Id dId : docIds) {
                links.add(new ContentDocumentLink(
                    ContentDocumentId = dId,
                    LinkedEntityId    = aId,
                    ShareType         = 'V',
                    Visibility        = 'AllUsers'
                ));
            }
        }
        if (!links.isEmpty()) insert links;
    }

    // --------- CHUNKING FOR QUEUEABLE ---------

    private static List<List<Id>> chunkIds(Set<Id> ids, Integer chunkSize) {
        List<List<Id>> chunks = new List<List<Id>>();
        if (ids == null || ids.isEmpty() || chunkSize == null || chunkSize <= 0) return chunks;

        List<Id> allIds = new List<Id>(ids);
        Integer i = 0;
        while (i < allIds.size()) {
            Integer stopIdx = Math.min(i + chunkSize, allIds.size());
            List<Id> slice = new List<Id>();
            for (Integer j = i; j < stopIdx; j++) {
                slice.add(allIds[j]);
            }
            chunks.add(slice);
            i = stopIdx;
        }
        return chunks;
    }

    // --------- SEND EMAIL ---------

    public PageReference sendNow() {
        if (String.isBlank(subject) || String.isBlank(body)) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR, 'Subject and Body are required.'
            ));
            return null;
        }
        if (selectedAffils == null || selectedAffils.isEmpty()) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR, 'No affiliations selected.'
            ));
            return null;
        }

        List<Id> fileDocIds = new List<Id>();
        fileDocIds.addAll(savedDocIds);   // already created in addCurrentFile()

        Set<Id> selectedAffilIds   = new Set<Id>();
        Set<Id> selectedContactIds = new Set<Id>();
        for (hed__Affiliation__c a : selectedAffils) {
            selectedAffilIds.add(a.Id);
            if (a.hed__Contact__c != null) {
                selectedContactIds.add(a.hed__Contact__c);
            }
        }

        if (!fileDocIds.isEmpty() && !selectedContactIds.isEmpty()) {
            linkFilesToContacts(fileDocIds, selectedContactIds);
        }
        if (!fileDocIds.isEmpty() && !selectedAffilIds.isEmpty()) {
            linkFilesToAffiliations(fileDocIds, selectedAffilIds);
        }

        // Run batch for the selected affiliations (scope size 100)
        Database.executeBatch(
            new AffiliationEmailBatch(new List<Id>(selectedAffilIds), subject, body, fileDocIds),
            100
        );

        ApexPages.addMessage(new ApexPages.Message(
            ApexPages.Severity.CONFIRM,
            'Email sent successfully'
        ));
        return null;
    }
}