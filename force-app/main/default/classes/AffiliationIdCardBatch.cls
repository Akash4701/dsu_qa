/**
 * Bulk-safe generation of student E-ID cards.
 *
 * Designed to scale to very large volumes (90k+ affiliations updated in a single
 * transaction). The affiliation trigger only flags qualifying records as
 * 'Pending' (an in-memory before-trigger field update - zero DML, infinitely
 * bulkable) and launches this batch ONCE per transaction. The batch then renders
 * the PDFs in small chunks so VF PDF generation and heap limits are respected.
 *
 * Chunking: a small scope size (DEFAULT_SCOPE) is used because each
 * PageReference.getContentAsPDF() is heavy. finish() re-checks for any remaining
 * 'Pending' rows and chains another batch, so the backlog always drains even when
 * new records are flagged while a batch is already running.
 */
global without sharing class AffiliationIdCardBatch
        implements Database.Batchable<SObject>, Database.Stateful, Database.AllowsCallouts {

    /** Small scope - one PDF render is expensive; keep heap/limits safe. */
    public static final Integer DEFAULT_SCOPE = 5;
    private static final String STATUS_PENDING = 'Pending';

    global Integer successCount = 0;
    global Integer failCount = 0;
    global List<String> errors = new List<String>();

    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Roll_Number__c,
                   hed__Contact__r.Name
            FROM hed__Affiliation__c
            WHERE ID_Card_Generation_Status__c = :STATUS_PENDING
              AND Roll_Number__c != null
              AND DSU_Email__c != null
            ORDER BY CreatedDate ASC
        ]);
    }

    global void execute(Database.BatchableContext bc, List<hed__Affiliation__c> scope) {
        Map<Id, Blob> pdfByAff = new Map<Id, Blob>();
        Map<Id, String> nameByAff = new Map<Id, String>();
        Map<Id, String> usnByAff = new Map<Id, String>();

        // Render the chunk (small scope keeps PDF heap/limits safe).
        for (hed__Affiliation__c aff : scope) {
            pdfByAff.put(aff.Id, StudentIdCardController.renderPdf(aff.Id));
            nameByAff.put(aff.Id, aff.hed__Contact__r != null ? aff.hed__Contact__r.Name : null);
            usnByAff.put(aff.Id, aff.Roll_Number__c);
        }

        Set<Id> ids = pdfByAff.keySet();
        if (ids.isEmpty()) {
            return;
        }

        // Bulk store + stamp status. If the chunk fails, mark it Failed so it is
        // not silently lost and can be retried.
        try {
            StudentIdCardController.storeIdCards(pdfByAff, nameByAff, usnByAff);
            StudentIdCardController.markStatus(ids, StudentIdCardController.STATUS_GENERATED);
            successCount += ids.size();
        } catch (Exception ex) {
            StudentIdCardController.markStatus(ids, StudentIdCardController.STATUS_FAILED);
            failCount += ids.size();
            errors.add('Chunk failed: ' + ex.getMessage());
        }
    }

    global void finish(Database.BatchableContext bc) {
        System.debug('AffiliationIdCardBatch finished. Success=' + successCount + ', Fail=' + failCount);
        if (!errors.isEmpty()) {
            System.debug('AffiliationIdCardBatch errors: ' + String.join(errors, ' | '));
        }

        // Drain any rows flagged while this batch was running.
        Integer remaining = [
            SELECT COUNT()
            FROM hed__Affiliation__c
            WHERE ID_Card_Generation_Status__c = :STATUS_PENDING
              AND Roll_Number__c != null
              AND DSU_Email__c != null
        ];
        // Re-launch only outside of test context to respect test async limits.
        if (remaining > 0 && !Test.isRunningTest()) {
            Database.executeBatch(new AffiliationIdCardBatch(), DEFAULT_SCOPE);
        }
    }
}