/**
 * Bulk-friendly entry point for FeedbackItemEmailActivityAction.sendEmails, for Flows that only
 * have a plain collection of Feedback_Item__c Ids to work with.
 *
 * FeedbackItemEmailActivityAction.sendEmails already sends every email in a single
 * Messaging.sendEmail(messages, false) call when given the full List<Request> up front -- it was
 * never the bottleneck. The bug this class fixes lived in the calling Flow instead:
 * Feedback_Item_Pending_Backlog_Catchup invoked that action once per loop iteration (once per
 * Feedback_Item__c record) rather than once for the whole batch, so a day with 11+ pending items
 * exceeded the platform's "Total number of Messaging.sendEmail methods allowed" limit (10 per
 * transaction) and the entire flow interview faulted -- rolling back every record in that run,
 * not just the ones past the 10th.
 *
 * A Flow could pass its own List<Request> directly to sendEmails, but Request is an inner class,
 * and Flow's Apex-Defined Variable support does not accept nested/inner Apex classes as a
 * standalone variable type. A plain List<Id> is a type every Flow already knows how to collect
 * (e.g. via an Add-to-collection assignment inside the loop), so this wrapper takes that instead
 * and builds the Request list internally.
 *
 * The bare-List<Id> parameter this class originally used doesn't work for that, though:
 * @InvocableMethod always treats a single top-level parameter's outer List as the bulk-invocation
 * wrapper (one element per separate Flow interview), so Flow only ever lets you assign a single,
 * non-collection Id to it -- exactly the per-record wiring this class exists to avoid. Wrapping
 * the input in its own BulkRequest class with a List<Id> *field* sidesteps this: the outer
 * List<BulkRequest> is still the bulk-invocation wrapper, but feedbackItemIds is now a normal
 * collection-typed field on it, which Flow can assign a whole collection variable to directly.
 */
public with sharing class FeedbackItemBacklogEmailBulkAction {

    public class BulkRequest {
        @InvocableVariable(required=true label='Feedback Item Ids')
        public List<Id> feedbackItemIds;
    }

    @InvocableMethod(
        label='Send Backlog Feedback Emails (Bulk)'
        description='Sends Feedback Item backlog emails for a whole batch of Ids in one call, avoiding the per-transaction Messaging.sendEmail limit that per-record invocation hits.'
    )
    public static List<FeedbackItemEmailActivityAction.Response> sendBacklogEmails(
        List<BulkRequest> bulkRequests
    ) {
        List<FeedbackItemEmailActivityAction.Request> requests = new List<FeedbackItemEmailActivityAction.Request>();
        if (bulkRequests != null) {
            for (BulkRequest bulkRequest : bulkRequests) {
                if (bulkRequest.feedbackItemIds == null) continue;
                for (Id feedbackItemId : bulkRequest.feedbackItemIds) {
                    FeedbackItemEmailActivityAction.Request req = new FeedbackItemEmailActivityAction.Request();
                    req.feedbackItemId = feedbackItemId;
                    req.isReminder = false;
                    requests.add(req);
                }
            }
        }
        return FeedbackItemEmailActivityAction.sendEmails(requests);
    }
}