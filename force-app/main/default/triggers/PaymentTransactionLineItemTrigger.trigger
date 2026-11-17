trigger PaymentTransactionLineItemTrigger on Payment_Transaction_Line_Item__c (after update) {   
    new PaymentTransactionLineItemHandler().process();
}