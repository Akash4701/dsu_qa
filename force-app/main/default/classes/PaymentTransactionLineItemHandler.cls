public class PaymentTransactionLineItemHandler extends TriggerHandler {

	public override void processAfterUpdate() {
        List<Payment_Transaction_Line_Item__c> cleanLineItems = new List<Payment_Transaction_Line_Item__c>();

        // Fee_Applied__c (not Receipt__c) is the ledger-posting guard. Receipt__c is also written
        // by PaymentReceiptService onto SIBLING line items of the same Payment_Transaction__c (to
        // consolidate multi-course exam-fee receipts) before those siblings' own Payment_Status__c
        // update has run. Using Receipt__c as the guard let that sibling write permanently skip
        // updateInstallmentAndAssignmentRemainingAmount for those records. Fee_Applied__c is only
        // ever set by this class, so it can't be tripped by an unrelated process.
        for (Payment_Transaction_Line_Item__c pli : (List<Payment_Transaction_Line_Item__c>) Trigger.new) {
            if (pli.Fee_Installment__c != null && pli.Received_Amount__c > 0 && pli.Payment_Status__c == '1' && pli.Fee_Applied__c == false) {
                cleanLineItems.add(pli);
            }
        }

        if (!cleanLineItems.isEmpty()) {
            updateInstallmentAndAssignmentRemainingAmount(cleanLineItems);

            List<Payment_Transaction_Line_Item__c> markApplied = new List<Payment_Transaction_Line_Item__c>();
            for (Payment_Transaction_Line_Item__c pli : cleanLineItems) {
                markApplied.add(new Payment_Transaction_Line_Item__c(Id = pli.Id, Fee_Applied__c = true));
            }
            update markApplied;

			System.enqueueJob(new PaymentReceiptQueueable(new List<Id>(new Map<Id, Payment_Transaction_Line_Item__c>(cleanLineItems).keySet())));
        }
    }

    @TestVisible
    private static void updateInstallmentAndAssignmentRemainingAmount(List<Payment_Transaction_Line_Item__c> lineItems) {
        // Collect Fee Installment IDs
        Set<Id> installmentIds = new Set<Id>();
        for (Payment_Transaction_Line_Item__c pli : lineItems) {
            installmentIds.add(pli.Fee_Installment__c);
        }

        if (installmentIds.isEmpty()) return;

        // Aggregate received amounts for successful payments
        Map<Id, Decimal> totalReceivedByInstallment = new Map<Id, Decimal>();
        for (Payment_Transaction_Line_Item__c pli : lineItems) {
            if (pli.Fee_Installment__c != null && pli.Payment_Status__c == '1') {
                Decimal existing = totalReceivedByInstallment.containsKey(pli.Fee_Installment__c)
                    ? totalReceivedByInstallment.get(pli.Fee_Installment__c)
                    : 0;
                totalReceivedByInstallment.put(pli.Fee_Installment__c, existing + pli.Received_Amount__c);
            }
        }

        // Query Fee Installments and related Fee Assignments
        Map<Id, Decimal> assignmentPaidAgg = new Map<Id, Decimal>();
        Map<Id, Decimal> assignmentTotalMap = new Map<Id, Decimal>();
        List<Fee_Installment__c> installmentsToUpdate = new List<Fee_Installment__c>();
        List<Fee_Assignment__c> assignmentsToUpdate = new List<Fee_Assignment__c>();

        for (Fee_Installment__c fi : [
            SELECT Id, Fee_Amount__c, Scholarship_Amount__c, Total_Amount_Payable__c, Paid_Amount__c, Remaining_Amount__c, Fee_Assignment__c,
                   Fee_Assignment__r.Id, Fee_Assignment__r.Total_Amount_Payable__c, Fee_Assignment__r.Paid_Amount__c, Fee_Assignment__r.Remaining_Amount__c
            FROM Fee_Installment__c
            WHERE Id IN :installmentIds
        ]) {
            Decimal totalReceived = totalReceivedByInstallment.get(fi.Id);
            if (totalReceived == null) totalReceived = 0;

            Decimal instTotal = fi.Total_Amount_Payable__c;
            if (instTotal == null) instTotal = 0;
            Decimal instPaidExisting = fi.Paid_Amount__c == null ? 0 : fi.Paid_Amount__c;
            Decimal instPaidNew = instPaidExisting + totalReceived;

            // Update Installment Remaining
            Decimal newInstallmentRemaining = instTotal - instPaidNew;
            if (newInstallmentRemaining < 0) newInstallmentRemaining = 0;

            fi.Paid_Amount__c = instPaidNew;
            fi.Remaining_Amount__c = newInstallmentRemaining;
            installmentsToUpdate.add(fi);

            // Also update related Fee Assignment Remaining
            if (fi.Fee_Assignment__c != null) {
                Decimal currentPaid = assignmentPaidAgg.containsKey(fi.Fee_Assignment__c)
                    ? assignmentPaidAgg.get(fi.Fee_Assignment__c)
                    : (fi.Fee_Assignment__r.Paid_Amount__c == null ? 0 : fi.Fee_Assignment__r.Paid_Amount__c);
                Decimal assignmentTotal = assignmentTotalMap.containsKey(fi.Fee_Assignment__c)
                    ? assignmentTotalMap.get(fi.Fee_Assignment__c)
                    : (fi.Fee_Assignment__r.Total_Amount_Payable__c != null
                        ? fi.Fee_Assignment__r.Total_Amount_Payable__c
                        : ((fi.Fee_Assignment__r.Paid_Amount__c == null ? 0 : fi.Fee_Assignment__r.Paid_Amount__c) +
                           (fi.Fee_Assignment__r.Remaining_Amount__c == null ? 0 : fi.Fee_Assignment__r.Remaining_Amount__c)));

                assignmentPaidAgg.put(fi.Fee_Assignment__c, currentPaid + totalReceived);
                assignmentTotalMap.put(fi.Fee_Assignment__c, assignmentTotal);
            }
        }

        for (Id assignmentId : assignmentPaidAgg.keySet()) {
            Decimal total = assignmentTotalMap.get(assignmentId);
            if (total == null) total = 0;
            Decimal paid = assignmentPaidAgg.get(assignmentId);
            Decimal remaining = total - paid;
            if (remaining < 0) remaining = 0;
            assignmentsToUpdate.add(new Fee_Assignment__c(
                Id = assignmentId,
                Paid_Amount__c = paid,
                Remaining_Amount__c = remaining
            ));
        }

        // Perform DML
        if (!installmentsToUpdate.isEmpty()) update installmentsToUpdate;
        if (!assignmentsToUpdate.isEmpty()) update assignmentsToUpdate;
    }
}