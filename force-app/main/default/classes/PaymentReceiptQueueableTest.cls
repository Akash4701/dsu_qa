@isTest
public class PaymentReceiptQueueableTest {

    @testSetup
    static void setupData() {
        // Create Fee Assignment
        Fee_Assignment__c fa = new Fee_Assignment__c(
            Remaining_Amount__c = 1000
        );
        insert fa;

        // Create Fee Installment
        Fee_Installment__c fi = new Fee_Installment__c(
            Fee_Assignment__c = fa.Id,
            Remaining_Amount__c = 500
        );
        insert fi;

		Payment_Transaction__c pt = new Payment_Transaction__c(
			Payment_Status__c = '1', 
			Amount__c = 1000, 
			Payment_Gateway_Status__c = 'Success'
		);
		insert pt;

        // Create Payment Transaction Line Item
        Payment_Transaction_Line_Item__c pli = new Payment_Transaction_Line_Item__c(
            Fee_Installment__c = fi.Id,
            Received_Amount__c = 250,
            Payment_Transaction__c = pt.Id
        );
        insert pli;
    }

    @isTest
    static void testQueueableExecution() {
        // Fetch sample line items
        List<Payment_Transaction_Line_Item__c> lineItems = [
            SELECT Id FROM Payment_Transaction_Line_Item__c LIMIT 1
        ];

        Test.startTest();
            System.enqueueJob(new PaymentReceiptQueueable(
                new List<Id>{ lineItems[0].Id }
            ));
        Test.stopTest();
    }
}