/**
 * Drives automatic student E-ID card generation and Application Sub_Status sync.
 *
 * before insert/update : flags qualifying records (Roll Number + DSU Email both
 *                        present and newly set/changed) as ID card 'Pending'
 *                        - pure in-memory field update, fully bulk-safe for 90k+.
 * after  insert/update : launches AffiliationIdCardBatch once per transaction to
 *                        render PDFs asynchronously.
 * after  update        : syncs the related Application__c.Sub_Status__c off
 *                        Approval_Status__c / Is_DSU_Email_Active__c changes
 *                        (AffiliationHandler.UpdateApplicationSubstatus).
 */
trigger AffiliationTrigger on hed__Affiliation__c (before insert, before update, after insert, after update) {

    if (Trigger.isBefore)      {
        AffiliationTriggerHandler.flagPendingIdCards(Trigger.new, Trigger.oldMap, Trigger.isInsert);
    }

    if (Trigger.isAfter) {
        AffiliationTriggerHandler.launchIdCardGeneration(Trigger.new, Trigger.oldMap, Trigger.isInsert);

        if (Trigger.isUpdate) {
            AffiliationHandler.UpdateApplicationSubstatus(Trigger.new, Trigger.oldMap);
        }
    }
}