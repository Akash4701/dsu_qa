public with sharing class AffiliationEmailService {

    // Salesforce allows a max of 10 Messaging.sendEmail() invocations per transaction,
    // and up to 100 SingleEmailMessage records per invocation. Chunk by 100, not 10.
    private static final Integer MAX_EMAILS_PER_SEND = 100;

    public static void send(
        List<Id> affiliationIds,
        String subject,
        String body,
        List<Id> attachmentDocumentIds
    ) {
        List<Id> safeAttachmentDocIds =
            (attachmentDocumentIds == null) ? new List<Id>() : attachmentDocumentIds;

        List<hed__Affiliation__c> affiliations = [
            SELECT Id, DSU_Email__c, hed__Contact__c,
                   hed__Contact__r.Email, hed__Contact__r.HasOptedOutOfEmail
            FROM hed__Affiliation__c
            WHERE Id IN :affiliationIds
            WITH SECURITY_ENFORCED
        ];

        // Nothing to send: skip the attachment query and blob loading entirely.
        if (affiliations.isEmpty()) {
            return;
        }

        List<Messaging.EmailFileAttachment> fileAttachments =
            buildAttachments(safeAttachmentDocIds);

        List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();

        for (hed__Affiliation__c affiliation : affiliations) {
            if (String.isBlank(affiliation.DSU_Email__c)) {
                continue;
            }

            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setWhatId(affiliation.Id);

            if (affiliation.hed__Contact__c != null) {
                email.setTargetObjectId(affiliation.hed__Contact__c);
                email.setTreatTargetObjectAsRecipient(false);
            }

            // NOTE: setSaveAsActivity(true) combined with setTargetObjectId AND file
            // attachments can throw on some configs. Verify with attachments present.
            email.setSaveAsActivity(true);
            email.setToAddresses(new List<String>{ affiliation.DSU_Email__c.trim() });

            Contact contact = affiliation.hed__Contact__r;
            if (contact != null
                && String.isNotBlank(contact.Email)
                && !contact.HasOptedOutOfEmail) {
                email.setCcAddresses(new List<String>{ contact.Email.trim() });
            }

            email.setSubject(subject);
            email.setPlainTextBody(body);
            if (!fileAttachments.isEmpty()) {
                email.setFileAttachments(fileAttachments);
            }

            emailsToSend.add(email);

            if (emailsToSend.size() == MAX_EMAILS_PER_SEND) {
                Messaging.sendEmail(emailsToSend, false);
                emailsToSend.clear();
            }
        }
        if (!emailsToSend.isEmpty()) {
            Messaging.sendEmail(emailsToSend, false);
        }

        // Link files once after all sends in this scope. Linking per-chunk previously
        // re-queried prior EmailMessages and caused DUPLICATE_VALUE on ContentDocumentLink.
        if (!safeAttachmentDocIds.isEmpty()) {
            linkFilesToEmails(safeAttachmentDocIds, subject);
        }
    }

    private static List<Messaging.EmailFileAttachment> buildAttachments(List<Id> attachmentDocIds) {
        List<Messaging.EmailFileAttachment> fileAttachments =
            new List<Messaging.EmailFileAttachment>();
        if (attachmentDocIds.isEmpty()) {
            return fileAttachments;
        }

        Map<Id, ContentVersion> latestVersionByDocId = new Map<Id, ContentVersion>();
        for (ContentVersion version : [
            SELECT Id, ContentDocumentId, Title, VersionData, FileExtension
            FROM ContentVersion
            WHERE ContentDocumentId IN :attachmentDocIds AND IsLatest = true
            WITH SECURITY_ENFORCED
        ]) {
            latestVersionByDocId.put(version.ContentDocumentId, version);
        }

        // WARNING: all VersionData blobs are held in heap and attached to every email.
        // Large files x many recipients can exceed the heap limit — guard if needed.
        for (Id docId : attachmentDocIds) {
            ContentVersion version = latestVersionByDocId.get(docId);
            if (version == null) {
                continue;
            }
            Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
            attachment.setFileName(
                version.Title + (version.FileExtension != null ? '.' + version.FileExtension : '')
            );
            attachment.setBody(version.VersionData);
            fileAttachments.add(attachment);
        }
        return fileAttachments;
    }

    private static void linkFilesToEmails(List<Id> attachmentDocIds, String subject) {
        if (attachmentDocIds == null || attachmentDocIds.isEmpty()) {
            return;
        }

        // FRAGILE: matching sent emails by user + recent time + subject is a heuristic.
        // Same subject reused within the window (or a concurrent process) can mis-link.
        // Prefer capturing SendEmailResult IDs where the platform allows it.
        Datetime cutoff = System.now().addMinutes(-10);
        List<EmailMessage> recentEmails = [
            SELECT Id
            FROM EmailMessage
            WHERE CreatedById = :UserInfo.getUserId()
              AND MessageDate >= :cutoff
              AND Subject = :subject
        ];
        if (recentEmails.isEmpty()) {
            return;
        }

        Set<Id> recentEmailIds = new Set<Id>();
        for (EmailMessage email : recentEmails) {
            recentEmailIds.add(email.Id);
        }

        Set<String> existingPairs = new Set<String>();
        for (ContentDocumentLink cdl : [
            SELECT ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE ContentDocumentId IN :attachmentDocIds
              AND LinkedEntityId IN :recentEmailIds
        ]) {
            existingPairs.add(buildLinkKey(cdl.ContentDocumentId, cdl.LinkedEntityId));
        }

        List<ContentDocumentLink> linksToInsert = new List<ContentDocumentLink>();
        for (Id emailId : recentEmailIds) {
            for (Id docId : attachmentDocIds) {
                if (existingPairs.contains(buildLinkKey(docId, emailId))) {
                    continue;
                }
                linksToInsert.add(new ContentDocumentLink(
                    ContentDocumentId = docId,
                    LinkedEntityId    = emailId,
                    ShareType         = 'V',
                    Visibility        = 'AllUsers'
                ));
            }
        }

        if (!linksToInsert.isEmpty()) {
            // Partial success: one bad link should not fail the whole batch.
            Database.insert(linksToInsert, false);
        }
    }

    private static String buildLinkKey(Id contentDocumentId, Id linkedEntityId) {
        return String.valueOf(contentDocumentId) + ':' + String.valueOf(linkedEntityId);
    }
}