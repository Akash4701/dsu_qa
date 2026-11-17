public with sharing class ContactEmailQueue implements Queueable {
    private List<Id> contactIds;
    private Map<Id, List<String>> affByContact;
    private List<Id> fileDocIds;
    private String subj;
    private String bodyText;
    private Id createdById;

    private Integer depth = 0;

    public ContactEmailQueue(
        List<Id> contactIds,
        Map<Id, List<String>> affByContact,
        List<Id> fileDocIds,
        String subj,
        String bodyText,
        Id createdById
    ) {
        this(contactIds, affByContact, fileDocIds, subj, bodyText, createdById, 0);
    }

    public ContactEmailQueue(
        List<Id> contactIds,
        Map<Id, List<String>> affByContact,
        List<Id> fileDocIds,
        String subj,
        String bodyText,
        Id createdById,
        Integer depth
    ) {
        this.contactIds = (contactIds == null) ? new List<Id>() : new List<Id>(contactIds);

        this.affByContact = new Map<Id, List<String>>();
        if (affByContact != null) {
            for (Id k : affByContact.keySet()) {
                List<String> v = affByContact.get(k);
                this.affByContact.put(k, (v == null) ? new List<String>() : new List<String>(v));
            }
        }

        this.fileDocIds  = (fileDocIds == null) ? new List<Id>() : new List<Id>(fileDocIds);
        this.subj        = subj;
        this.bodyText    = bodyText;
        this.createdById = createdById;
        this.depth       = (depth == null) ? 0 : depth;
    }


    public void execute(QueueableContext qc) {
          if (contactIds.isEmpty()) return;

    Integer take = Math.min(10, contactIds.size());
    List<Id> batchIds = new List<Id>();
    for (Integer i = 0; i < take; i++) batchIds.add(contactIds.remove(0));

    Map<Id, Contact> contactMap = new Map<Id, Contact>([
        SELECT Id, Email, HasOptedOutOfEmail
        FROM Contact
        WHERE Id IN :batchIds
    ]);

    List<Messaging.EmailFileAttachment> outAtts = new List<Messaging.EmailFileAttachment>();
    if (!fileDocIds.isEmpty()) {
        for (ContentVersion cv : [
            SELECT ContentDocumentId, VersionData, Title, FileExtension
            FROM ContentVersion
            WHERE IsLatest = true AND ContentDocumentId IN :fileDocIds
        ]) {
            Messaging.EmailFileAttachment efa = new Messaging.EmailFileAttachment();
            String fn = cv.Title;
            if (cv.FileExtension != null) fn += '.' + cv.FileExtension;
            efa.setFileName(fn);
            efa.setBody(cv.VersionData);
            outAtts.add(efa);
        }
    }

    List<Messaging.SingleEmailMessage> msgs = new List<Messaging.SingleEmailMessage>();
    List<Task> tasksToInsert = new List<Task>();
    List<ContentDocumentLink> taskFileLinks = new List<ContentDocumentLink>();

    for (Id cid : batchIds) {
        Contact c = contactMap.get(cid);
        if (c == null) continue;

        List<String> affEmails = affByContact.containsKey(cid)
            ? affByContact.get(cid)
            : new List<String>();

        Boolean sendToContact = (c.Email != null && !c.HasOptedOutOfEmail);

        if (!sendToContact && affEmails.isEmpty()) continue;

        if (sendToContact) {
            Messaging.SingleEmailMessage m = new Messaging.SingleEmailMessage();
            m.setTargetObjectId(cid);
            m.setSaveAsActivity(true);
            m.setTreatTargetObjectAsRecipient(true);
            if (!affEmails.isEmpty()) m.setCcAddresses(affEmails);
            m.setSubject(subj);
            m.setPlainTextBody(bodyText);
            if (!outAtts.isEmpty()) m.setFileAttachments(outAtts);
            msgs.add(m);
        } else {
            Messaging.SingleEmailMessage m = new Messaging.SingleEmailMessage();
            m.setTreatTargetObjectAsRecipient(false);
            m.setToAddresses(affEmails);
            m.setSubject(subj);
            m.setPlainTextBody(bodyText);
            if (!outAtts.isEmpty()) m.setFileAttachments(outAtts);
            msgs.add(m);

            Task t = new Task();
            t.Subject      = 'Email sent to affiliation addresses';
            t.Status       = 'Completed';
            t.Priority     = 'Normal';
            t.ActivityDate = Date.today();
            t.WhoId        = cid;
            t.Description  = 'Subject: ' + subj + '\n\n'
                           + 'Body:\n' + bodyText + '\n\n'
                           + 'Recipients (Affiliations): ' + String.join(affEmails, ', ');
            tasksToInsert.add(t);
        }
    }

    if (!msgs.isEmpty()) {
        Messaging.sendEmail(msgs, false);
        linkFilesToEmailMessages(subj, batchIds, fileDocIds, createdById);
    }

    if (!tasksToInsert.isEmpty()) {
        insert tasksToInsert;

        if (!fileDocIds.isEmpty()) {
            for (Task t : tasksToInsert) {
                for (Id d : fileDocIds) {
                    ContentDocumentLink cdl = new ContentDocumentLink();
                    cdl.ContentDocumentId = d;
                    cdl.LinkedEntityId    = t.Id;
                    cdl.ShareType         = 'V';
                    cdl.Visibility        = 'AllUsers';
                    taskFileLinks.add(cdl);
                }
            }
            if (!taskFileLinks.isEmpty()) insert taskFileLinks;
        }
    }

    if (!contactIds.isEmpty() && depth < 40) {
        System.enqueueJob(new ContactEmailQueue(
            contactIds,
            affByContact,
            fileDocIds,
            subj,
            bodyText,
            createdById,
            depth + 1
        ));
    }
}
    private static void linkFilesToEmailMessages(
        String subj,
        List<Id> batchContactIds,
        List<Id> docIds,
        Id createdById
    ) {
        if (docIds.isEmpty() || batchContactIds.isEmpty()) return;

        Datetime cutoff = System.now().addMinutes(-30);

        List<EmailMessage> emails = [
            SELECT Id
            FROM EmailMessage
            WHERE CreatedById = :createdById
              AND MessageDate >= :cutoff
              AND Subject = :subj
              AND Id IN (
                    SELECT EmailMessageId
                    FROM EmailMessageRelation
                    WHERE RelationId IN :batchContactIds
              )
        ];
        if (emails.isEmpty()) return;

        List<ContentDocumentLink> links = new List<ContentDocumentLink>();
        for (EmailMessage em : emails) {
            for (Id d : docIds) {
                ContentDocumentLink cdl = new ContentDocumentLink();
                cdl.ContentDocumentId = d;
                cdl.LinkedEntityId    = em.Id;
                cdl.ShareType         = 'V';
                cdl.Visibility        = 'AllUsers';
                links.add(cdl);
            }
        }
        if (!links.isEmpty()) insert links;
    }
@TestVisible
static void test_linkFilesToEmailMessages(String subjectForQuery,
                                          List<Id> batchContactIds,
                                          List<Id> docIds,
                                          Id createdBy) {
    linkFilesToEmailMessages(subjectForQuery, batchContactIds, docIds, createdBy);
}


@TestVisible
static void test_chainOnce(ContactEmailQueue selfRef) {
    if (selfRef == null) return;
    if (!selfRef.contactIds.isEmpty() && selfRef.depth < 40) {
        System.enqueueJob(new ContactEmailQueue(
            selfRef.contactIds,
            selfRef.affByContact,
            selfRef.fileDocIds,
            selfRef.subj,
            selfRef.bodyText,
            selfRef.createdById,
            selfRef.depth + 1
        ));
    }
}

}