@isTest
public class PaymentTransactionLineItemHandlerTest {

    @testSetup
    static void setupTestData() {

        Fee_Assignment__c assignment = new Fee_Assignment__c(
            Total_Amount_Payable__c = 1000,
            Remaining_Amount__c = 1000
        );
        insert assignment;

        Fee_Installment__c installment = new Fee_Installment__c(
            Total_Amount_Payable__c = 1000,
            Remaining_Amount__c = 1000,
            Fee_Assignment__c = assignment.Id
        );
        insert installment;

        // Payment_Transaction_Line_Item__c.Payment_Status__c is a roll-down formula
        // (TEXT(Payment_Transaction__r.Payment_Status__c)) - it can only be driven by
        // updating the PARENT Payment_Transaction__c, never assigned directly on the line item.
        Payment_Transaction__c pt = new Payment_Transaction__c(
            Payment_Status__c = '1',
            Amount__c = 1000,
            Payment_Gateway_Status__c = 'Success'
        );
        insert pt;

        // Received_Amount__c starts at 0, matching the real flow: the line item is created
        // first, then the gateway-confirmed amount lands via a later individual update.
        Payment_Transaction_Line_Item__c pli = new Payment_Transaction_Line_Item__c(
            Fee_Installment__c = installment.Id,
            Received_Amount__c = 0,
            Payment_Transaction__c = pt.Id
        );
        insert pli;
    }

    // Successful payment posts to the Fee Installment / Fee Assignment ledger and marks the
    // line item as applied so it is not reprocessed.
    @isTest
    static void testAfterUpdateTrigger_postsLedgerAndMarksApplied() {
        Payment_Transaction_Line_Item__c pli = [
            SELECT Id, Fee_Installment__c FROM Payment_Transaction_Line_Item__c LIMIT 1
        ];
        pli.Received_Amount__c = 1000;

        Test.startTest();
            update pli;
        Test.stopTest();

        Fee_Installment__c installment = [
            SELECT Paid_Amount__c, Remaining_Amount__c, Fee_Assignment__c
            FROM Fee_Installment__c WHERE Id = :pli.Fee_Installment__c
        ];
        System.assertEquals(1000, installment.Paid_Amount__c, 'Installment should be fully paid');
        System.assertEquals(0, installment.Remaining_Amount__c, 'Installment should have no remaining amount');

        Fee_Assignment__c assignment = [
            SELECT Paid_Amount__c, Remaining_Amount__c FROM Fee_Assignment__c WHERE Id = :installment.Fee_Assignment__c
        ];
        System.assertEquals(1000, assignment.Paid_Amount__c, 'Assignment should be fully paid');
        System.assertEquals(0, assignment.Remaining_Amount__c, 'Assignment should have no remaining amount');

        Payment_Transaction_Line_Item__c updatedPli = [
            SELECT Fee_Applied__c FROM Payment_Transaction_Line_Item__c WHERE Id = :pli.Id
        ];
        System.assertEquals(true, updatedPli.Fee_Applied__c, 'Line item should be marked as applied');
    }

    // Regression test for the DSU UAT multi-subject exam-fee bug: PaymentReceiptService stamps
    // Receipt__c onto sibling line items of the same Payment_Transaction__c to consolidate a
    // multi-course receipt, BEFORE that sibling's own Received_Amount__c update has landed. When
    // that later update does land, the ledger must still post - Receipt__c being already non-null
    // must not block updateInstallmentAndAssignmentRemainingAmount (Fee_Applied__c is the guard,
    // not Receipt__c).
    @isTest
    static void testReceiptAlreadyStamped_doesNotBlockLedgerPosting() {
        Receipt_and_Invoice__c receipt = new Receipt_and_Invoice__c();
        insert receipt;

        Payment_Transaction_Line_Item__c pli = [
            SELECT Id, Fee_Installment__c FROM Payment_Transaction_Line_Item__c LIMIT 1
        ];
        // Simulate PaymentReceiptService having already stamped the consolidated receipt on this
        // sibling while Received_Amount__c is still 0 (its own payment hasn't landed yet).
        pli.Receipt__c = receipt.Id;
        update pli;

        // The payment amount now lands via its own individual update.
        pli.Received_Amount__c = 1000;
        Test.startTest();
            update pli;
        Test.stopTest();

        Fee_Installment__c installment = [
            SELECT Paid_Amount__c, Remaining_Amount__c FROM Fee_Installment__c WHERE Id = :pli.Fee_Installment__c
        ];
        System.assertEquals(1000, installment.Paid_Amount__c, 'Ledger must post even though Receipt__c was already set');
        System.assertEquals(0, installment.Remaining_Amount__c, 'Installment should have no remaining amount');
    }

    // Idempotency: once Fee_Applied__c is true, further updates must not double-count the amount.
    @isTest
    static void testAlreadyAppliedLineItem_isNotReprocessed() {
        Payment_Transaction_Line_Item__c pli = [
            SELECT Id, Fee_Installment__c FROM Payment_Transaction_Line_Item__c LIMIT 1
        ];
        pli.Received_Amount__c = 1000;
        update pli; // first pass: applies 1000 and sets Fee_Applied__c = true

        pli.Received_Amount__c = 1000; // no-op change, still 1000
        Test.startTest();
            update pli;
        Test.stopTest();

        Fee_Installment__c installment = [
            SELECT Paid_Amount__c FROM Fee_Installment__c WHERE Id = :pli.Fee_Installment__c
        ];
        System.assertEquals(1000, installment.Paid_Amount__c, 'Amount must not be double-counted on reprocessing');
    }
}