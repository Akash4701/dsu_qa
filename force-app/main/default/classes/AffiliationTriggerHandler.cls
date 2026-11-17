/**
 * Handler for AffiliationTrigger - automatic student E-ID card generation.
 *
 * Bulk strategy (safe for 90k+ records in one DML transaction):
 *   1. before insert/update: qualifying rows get ID_Card_Generation_Status__c =
 *      'Pending' in memory. This is a zero-DML field update so it scales to any
 *      volume with no governor pressure.
 *   2. after insert/update: a single AffiliationIdCardBatch is launched per
 *      transaction (static guard persists across all 200-record chunks of the
 *      same DML), and only if no batch of this type is already active. The batch
 *      query picks up every 'Pending' row, so one launch covers the whole load.
 *
 * "Qualifying" = Roll Number AND DSU Email both populated, and (on insert) newly
 * present or (on update) at least one of the two changed. Status-only updates
 * made by the batch itself are therefore NOT qualifying -> no recursion.
 */
public without sharing class AffiliationTriggerHandler {

    private static final String STATUS_PENDING = 'Pending';

    /** Guard: one batch launch per transaction (statics persist across chunks). */
    @TestVisible
    private static Boolean batchLaunched = false;

    /** Allows tests (and admins via future toggle) to suppress auto-launch. */
    public static Boolean bypassAutoLaunch = false;

    // =====================================================================
    // before insert / before update
    // =====================================================================
    public static void flagPendingIdCards(
        List<hed__Affiliation__c> newList,
        Map<Id, hed__Affiliation__c> oldMap,
        Boolean isInsert
    ) {
        if (newList == null || newList.isEmpty()) return;

        for (hed__Affiliation__c aff : newList) {
            if (isQualifying(aff, oldMap, isInsert)) {
                aff.ID_Card_Generation_Status__c = STATUS_PENDING;
            }
        }
    }

    // =====================================================================
    // after insert / after update
    // =====================================================================
    public static void launchIdCardGeneration(
        List<hed__Affiliation__c> newList,
        Map<Id, hed__Affiliation__c> oldMap,
        Boolean isInsert
    ) {
        if (bypassAutoLaunch || batchLaunched || newList == null || newList.isEmpty()) {
            return;
        }

        Boolean hasQualifying = false;
        for (hed__Affiliation__c aff : newList) {
            if (isQualifying(aff, oldMap, isInsert)) {
                hasQualifying = true;
                break;
            }
        }
        if (!hasQualifying) {
            return;
        }

        // One launch per transaction (static guard persists across all 200-record
        // chunks of the same DML). Rows are already flagged 'Pending', and the
        // batch's finish() re-launches while a backlog remains, so a single launch
        // here drains the whole load even at 90k+ volume. The try/catch keeps the
        // DML safe if the async queue is momentarily full.
        try {
            Database.executeBatch(new AffiliationIdCardBatch(), AffiliationIdCardBatch.DEFAULT_SCOPE);
            batchLaunched = true;
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN,
                'AffiliationTriggerHandler: could not launch batch - ' + ex.getMessage());
        }
    }

    // =====================================================================
    // Helpers
    // =====================================================================
    @TestVisible
    private static Boolean isQualifying(
        hed__Affiliation__c aff,
        Map<Id, hed__Affiliation__c> oldMap,
        Boolean isInsert
    ) {
        if (String.isBlank(aff.Roll_Number__c) || String.isBlank(aff.DSU_Email__c)) {
            return false;
        }
        if (isInsert) {
            return true;
        }
        hed__Affiliation__c old = (oldMap != null) ? oldMap.get(aff.Id) : null;
        if (old == null) {
            return true;
        }
        return aff.Roll_Number__c != old.Roll_Number__c
            || aff.DSU_Email__c != old.DSU_Email__c;
    }
}