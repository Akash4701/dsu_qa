public with sharing class SendEmailsFromContactsCtrl {

    // 3 MB limit (in bytes) for each attachment
    public static final Integer MAX_FILE_SIZE_BYTES = 3 * 1024 * 1024;

    public ApexPages.StandardSetController ssc { get; private set; }
    public String subject { get; set; }
    public String body { get; set; }
    public List<String> previewRecipients { get; private set; }

    // The current file chosen in the single <apex:inputFile>
    public Attachment currentFile { get; set; }

    // We only keep ContentDocumentIds + file names (no Blob bodies)
    public List<Id> savedDocIds { get; set; }
    public List<String> savedFileNames { get; set; }

    private List<Contact> contactsList;
    private Map<Id, Set<String>> affByContactMap;

    // ---------- PROPERTIES ----------

    public Boolean getHasRecipients() {
        return previewRecipients != null && !previewRecipients.isEmpty();
    }

    public Boolean getHasFiles() {
        return savedFileNames != null && !savedFileNames.isEmpty();
    }

    // ---------- CONSTRUCTOR ----------

    public SendEmailsFromContactsCtrl(ApexPages.StandardSetController controller) {
        ssc = controller;
        previewRecipients = new List<String>();

        currentFile    = new Attachment();
        savedDocIds    = new List<Id>();
        savedFileNames = new List<String>();

        ssc.setPageSize(2000);
        buildPreview();
    }

    public String getPreviewRecipientsString() {
        return (previewRecipients == null || previewRecipients.isEmpty())
            ? ''
            : String.join(previewRecipients, ', ');
    }

    // ---------- ATTACHMENT HANDLING ----------

    // User selects file and clicks "Add attachment"
    public void addCurrentFile() {
        if (currentFile == null || currentFile.Body == null || String.isBlank(currentFile.Name)) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'Please choose a file before clicking "Add attachment".'
            ));
            return;
        }

        // Size check (3 MB)
        Integer sizeBytes = currentFile.Body.size();
        if (sizeBytes > MAX_FILE_SIZE_BYTES) {
            Decimal sizeMb = (Decimal) sizeBytes / (1024 * 1024);
            sizeMb = sizeMb.setScale(1); // e.g. 3.7

            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'File "' + currentFile.Name + '" is ' + String.valueOf(sizeMb) +
                ' MB. Maximum allowed size is 3 MB. Please upload a smaller file.'
            ));

            // Reset and do not keep this file
            currentFile = new Attachment();
            return;
        }

        try {
            // 1) Immediately save as ContentVersion
            ContentVersion cv = new ContentVersion();
            cv.Title        = currentFile.Name;
            cv.PathOnClient = currentFile.Name;
            cv.VersionData  = currentFile.Body;
            cv.Origin       = 'H';
            insert cv;

            // 2) Get its ContentDocumentId
            ContentVersion cvQuery = [
                SELECT ContentDocumentId
                FROM ContentVersion
                WHERE Id = :cv.Id
                LIMIT 1
            ];

            savedDocIds.add(cvQuery.ContentDocumentId);
            savedFileNames.add(currentFile.Name);

            // 3) Reset input (removes Blob from view state)
            currentFile = new Attachment();

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

    // Clears all selected files (does NOT delete existing Files from SF)
    public void clearFiles() {
        savedDocIds.clear();
        savedFileNames.clear();
        currentFile = new Attachment();
    }

    // ---------- RECIPIENT PREVIEW ----------

    private void buildPreview() {
        List<Contact> raw = (List<Contact>) ssc.getSelected();
        if (raw == null || raw.isEmpty()) {
            previewRecipients = new List<String>();
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.INFO,
                'Select at least one Contact in the list view.'
            ));
            return;
        }

        Set<Id> contactIds = new Set<Id>();
        for (Contact c : raw) {
            if (c != null && c.Id != null) contactIds.add(c.Id);
        }
        if (contactIds.isEmpty()) return;

        List<Contact> contacts = [
            SELECT Id, Email, HasOptedOutOfEmail
            FROM Contact
            WHERE Id IN :contactIds
        ];

        Map<Id, Set<String>> affByContact = new Map<Id, Set<String>>();
        for (hed__Affiliation__c a : [
            SELECT hed__Contact__c, DSU_Email__c
            FROM hed__Affiliation__c
            WHERE hed__Contact__c IN :contactIds
                  AND DSU_Email__c != null
        ]) {
            if (!affByContact.containsKey(a.hed__Contact__c)) {
                affByContact.put(a.hed__Contact__c, new Set<String>());
            }
            affByContact.get(a.hed__Contact__c).add(a.DSU_Email__c.trim());
        }

        Set<String> emails = new Set<String>();
        for (Contact c : contacts) {
            if (c.Email != null && !c.HasOptedOutOfEmail) {
                emails.add(c.Email.trim());
            }
        }
        for (Id cid : affByContact.keySet()) {
            emails.addAll(affByContact.get(cid));
        }

        previewRecipients.clear();
        previewRecipients.addAll(emails);
        previewRecipients.sort();

        this.contactsList    = contacts;
        this.affByContactMap = affByContact;
    }

    // ---------- FILE LINKING ----------

    private void linkFilesToContacts(List<Id> docIds, Set<Id> contactIds) {
        if (docIds == null || docIds.isEmpty() || contactIds == null || contactIds.isEmpty()) return;

        List<ContentDocumentLink> links = new List<ContentDocumentLink>();
        for (Id cId : contactIds) {
            for (Id dId : docIds) {
                ContentDocumentLink cdl = new ContentDocumentLink();
                cdl.ContentDocumentId = dId;
                cdl.LinkedEntityId    = cId;
                cdl.ShareType         = 'V';
                cdl.Visibility        = 'AllUsers';
                links.add(cdl);
            }
        }
        insert links;
    }

    // ---------- SEND EMAIL ----------

    public PageReference sendNow() {
        if (String.isBlank(subject) || String.isBlank(body)) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'Subject and Body are required.'
            ));
            return null;
        }
        if (previewRecipients == null || previewRecipients.isEmpty()) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'No valid recipients found.'
            ));
            return null;
        }
        if (contactsList == null || contactsList.isEmpty()) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'Please reload the page and try again.'
            ));
            return null;
        }

        // Files were already created in addCurrentFile()
        List<Id> fileDocIds = new List<Id>();
        fileDocIds.addAll(savedDocIds);

        Set<Id> selectedContactIds = new Set<Id>();
        for (Contact c : contactsList) selectedContactIds.add(c.Id);

        if (!fileDocIds.isEmpty()) {
            linkFilesToContacts(fileDocIds, selectedContactIds);
        }

        // Prepare data for async job
        List<Id> contactIdsForJob = new List<Id>();
        for (Contact c : contactsList) contactIdsForJob.add(c.Id);

        Map<Id, List<String>> affMapForJob = new Map<Id, List<String>>();
        if (affByContactMap != null && !affByContactMap.isEmpty()) {
            for (Id cid : affByContactMap.keySet()) {
                affMapForJob.put(cid, new List<String>(affByContactMap.get(cid)));
            }
        }

        // Uses existing ContactEmailQueue (already handles attachments)
        System.enqueueJob(new ContactEmailQueue(
            contactIdsForJob,
            affMapForJob,
            fileDocIds,
            subject,
            body,
            UserInfo.getUserId()
        ));

        ApexPages.addMessage(new ApexPages.Message(
            ApexPages.Severity.CONFIRM,
            'Successfully Sent Email'
        ));
        return null;
    }

    // ---------- CANCEL NAVIGATION ----------

    public PageReference cancel() {
        String ret = ApexPages.currentPage().getParameters().get('retURL');
        PageReference pr;

        if (!String.isBlank(ret)) {
            pr = new PageReference(ret);
        } else {
            String ref = ApexPages.currentPage().getHeaders().get('Referer');
            if (!String.isBlank(ref)) {
                pr = new PageReference(ref);
            } else {
                pr = new PageReference('/lightning/o/Contact/list');
            }
        }
        pr.setRedirect(true);
        return pr;
    }
}