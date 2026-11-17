/**
 * Sends the "feedback dates changed" email to a Feedback Item's Assignee, and keeps doing so correctly
 * when thousands of items change at once.
 *
 * Salesforce caps single emails per day for the whole org, and a mass date change would otherwise burn
 * the allowance (and silently drop the rest, since sending is best-effort). So every call is
 * capacity-aware:
 *   - emails go out now, up to the remaining daily allowance (minus a reserve for the org's other mail)
 *     and a per-transaction ceiling;
 *   - the rest are flagged Extension_Email_Pending__c and FeedbackExtensionEmailBatch, scheduled
 *     daily, sends them as capacity returns. Nothing is lost and nothing exceeds the cap.
 */
public with sharing class FeedbackExtensionEmailService {

    public static final String TEMPLATE_NAME = 'Feedback Extension template';

    /** Emails left unused so Flows, approvals and other senders in the org are never starved. */
    @TestVisible private static Integer dailyReserve = 200;
    /** Most emails sent in one transaction (one Messaging.sendEmail call). */
    @TestVisible private static Integer perTransactionLimit = 200;
    /** Tests set this to simulate "daily allowance used up" (or a specific remainder). */
    @TestVisible private static Integer capacityOverride;

    /** Emails that may still be sent right now. */
    public static Integer availableCapacity() {
        Integer daily = capacityOverride;
        if (daily == null) {
            System.OrgLimit singleEmail = System.OrgLimits.getMap().get('SingleEmail');
            daily = singleEmail == null ? perTransactionLimit : singleEmail.getLimit() - singleEmail.getValue();
        }
        Integer invocationsLeft = Limits.getLimitEmailInvocations() - Limits.getEmailInvocations();
        Integer perTransaction = invocationsLeft > 0 ? perTransactionLimit : 0;
        return Math.max(0, Math.min(daily - dailyReserve, perTransaction));
    }

    /**
     * Sends for as many items as capacity allows, flags the rest as pending, and makes sure the daily
     * job exists to finish them. Safe to call from a trigger.
     */
    public static void notify(List<Id> itemIds) {
        if (itemIds == null || itemIds.isEmpty()) {
            return;
        }
        Integer capacity = availableCapacity();
        List<Id> sendNow = new List<Id>();
        List<Id> deferred = new List<Id>();
        for (Id itemId : itemIds) {
            if (sendNow.size() < capacity) {
                sendNow.add(itemId);
            } else {
                deferred.add(itemId);
            }
        }
        sendAndClear(sendNow, false);
        if (!deferred.isEmpty()) {
            setPending(deferred, true);
            FeedbackExtensionEmailBatch.ensureScheduled();
        }
    }

    /**
     * Sends for the given items and returns how many emails were sent. When `clearPending` is true the
     * pending flag is cleared on every processed item (also those that cannot be emailed, such as no
     * Assignee email, so they never loop forever).
     */
    public static Integer sendAndClear(List<Id> itemIds, Boolean clearPending) {
        if (itemIds.isEmpty()) {
            return 0;
        }
        List<Messaging.SingleEmailMessage> emails = buildEmails(itemIds);
        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails, false);
        }
        if (clearPending) {
            setPending(itemIds, false);
        }
        return emails.size();
    }

    @TestVisible
    private static List<Messaging.SingleEmailMessage> buildEmails(List<Id> itemIds) {
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        List<Feedback_Item__c> items = [
            SELECT Id, Assignee__c, Assignee__r.Email, Course_Offering__r.Name,
                   Feedback_Scheduler__r.Feedback_Master__r.Feedback_Type__c
            FROM Feedback_Item__c
            WHERE Id IN :itemIds AND Assignee__c != NULL
            WITH SYSTEM_MODE
        ];
        if (items.isEmpty()) {
            return emails;
        }
        List<EmailTemplate> templates = [SELECT Id FROM EmailTemplate WHERE Name = :TEMPLATE_NAME LIMIT 1];
        if (templates.isEmpty()) {
            return emails;
        }
        Id templateId = templates[0].Id;

        for (Feedback_Item__c item : items) {
            if (String.isBlank(item.Assignee__r.Email)) {
                continue;
            }
            // The template engine cannot resolve relationship merge fields, so the template uses plain
            // %%TOKEN%% placeholders that are substituted here.
            String feedbackType = item.Feedback_Scheduler__r?.Feedback_Master__r?.Feedback_Type__c;
            String courseOfferingName = item.Course_Offering__r?.Name;

            Messaging.SingleEmailMessage rendered = Messaging.renderStoredEmailTemplate(templateId, item.Assignee__c, item.Id);
            String htmlBody = String.isNotBlank(rendered.getHtmlBody())
                ? rendered.getHtmlBody()
                    .replace('%%FEEDBACK_TYPE%%', String.isBlank(feedbackType) ? '' : feedbackType)
                    .replace('%%COURSE_OFFERING_NAME%%', String.isBlank(courseOfferingName) ? '' : courseOfferingName)
                : null;
            htmlBody = EmailBrandingHelper.applyBranding(htmlBody);

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setSubject(rendered.getSubject());
            if (htmlBody != null) {
                mail.setHtmlBody(htmlBody);
            } else {
                mail.setPlainTextBody(rendered.getPlainTextBody());
            }
            mail.setTargetObjectId(item.Assignee__c);
            mail.setWhatId(item.Id);
            mail.setTreatTargetObjectAsRecipient(true);
            // Enhanced Email logs the EmailMessage and its relation to the Assignee automatically.
            mail.setSaveAsActivity(true);
            emails.add(mail);
        }
        return emails;
    }

    /** Flips the pending flag using minimal records, so no other field is touched. */
    private static void setPending(List<Id> itemIds, Boolean pending) {
        List<Feedback_Item__c> flags = new List<Feedback_Item__c>();
        for (Id itemId : itemIds) {
            flags.add(new Feedback_Item__c(Id = itemId, Extension_Email_Pending__c = pending));
        }
        Database.update(flags, false);
    }
}