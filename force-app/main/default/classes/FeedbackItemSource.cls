/**
 * Strategy: where the Feedback Items of one kind of Feedback Scheduler come from. Each feedback type
 * family implements this once and FeedbackItemSources picks the right one, so supporting a new type
 * means adding a class here, not editing the trigger handler (open/closed).
 *
 * The query is exposed as text plus binds (not executed here) so the same definition can run
 * synchronously with a row cap for small schedules, or as a Database.QueryLocator in a batch job for
 * schedules too large for one transaction.
 */
public interface FeedbackItemSource {
    /** SOQL selecting the source rows (enrolments) a scheduler's items are built from. */
    String query();

    /** Bind variables referenced by the query for this scheduler. */
    Map<String, Object> binds(Feedback_Scheduler__c scheduler);

    AccessLevel accessLevel();

    /** Builds one Feedback Item per source row. Must not run SOQL or DML. */
    List<Feedback_Item__c> toItems(Feedback_Scheduler__c scheduler, List<SObject> rows);
}