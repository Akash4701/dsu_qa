public class PaymentReceiptQueueable implements Queueable, Database.AllowsCallouts {
    private List<Id> ids;
    private Boolean reconcile;
    private Integer retryCount;

    public PaymentReceiptQueueable(List<Id> lineItemIds) {
        this.ids = lineItemIds;
        this.reconcile = false;
        this.retryCount = 0;
    }

    // reconcile = true: ids are Payment_Transaction__c Ids; re-read all paid siblings and
    // recompute the consolidated exam-fee receipt only when the data is stable (self-healing
    // + stability guard after concurrent jobs). Starts at retry 0.
    public PaymentReceiptQueueable(List<Id> recordIds, Boolean reconcile) {
        this.ids = recordIds;
        this.reconcile = reconcile;
        this.retryCount = 0;
    }

    // Reconcile with an explicit retry count (used when the reconcile re-chains itself while
    // waiting for a transaction's line-item amounts to finish committing).
    public PaymentReceiptQueueable(List<Id> txnIds, Integer retryCount) {
        this.ids = txnIds;
        this.reconcile = true;
        this.retryCount = retryCount;
    }

    public void execute(QueueableContext qc) {
        if (reconcile == true) {
            PaymentReceiptService.reconcileExamTransactions(new Set<Id>(ids), retryCount);
            return;
        }

        List<Payment_Transaction_Line_Item__c> items = [SELECT Id, Fee_Installment__c, Received_Amount__c, Payment_Status__c, Payment_Transaction__c, Receipt__c, CreatedDate
														FROM Payment_Transaction_Line_Item__c WHERE Id IN :ids];

        PaymentReceiptService.generateReceipts(items);
    }
}