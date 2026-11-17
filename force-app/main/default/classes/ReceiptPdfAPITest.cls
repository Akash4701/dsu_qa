@isTest
public class ReceiptPdfAPITest {

    @TestSetup
    static void setupTestData() {
        // Create Contact
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Student'
        );
        insert testContact;

        // Create Application
        Application__c testApp = new Application__c(
            ContactId__c = testContact.Id,
            Payment_Method__c = 'Online',
            Fee_Preference__c = 'Semester-wise fee',
            External_Application_Number__c = 'HBJSCF5612H',
            Program_Level__c = 'UG'
        );
        insert testApp;

        // Create Affiliation
        hed__Affiliation__c affiliation = new hed__Affiliation__c(
            hed__Contact__c = testContact.Id,
            Individual_Application__c = testApp.Id,
            hed__Status__c = 'Current'
        );
        insert affiliation;

        // Create Account and Academic Term
        Account testAccount = new Account(Name = 'Test University');
        insert testAccount;

        hed__Term__c testTerm = new hed__Term__c(
            Name = 'Fall 2024',
            hed__Account__c = testAccount.Id,
            Term_Reference__c = 'FALL2024'
        );
        insert testTerm;

        // Create Fee Type
        Fee_Type__c feeType = new Fee_Type__c(
            Semester__c = testTerm.Id,
            Amount__c = 5000,
            Program__c = testAccount.Id
        );
        insert feeType;

        // Create Fee Assignment
        Fee_Assignment__c feeAssignment = new Fee_Assignment__c(
            Contact__c = testContact.Id,
            Fee_Type__c = feeType.Id,
            Paid_Amount__c = 2000,
            Scholarship_Amount__c = 500,
            Remaining_Amount__c = 2500,
            Total_Amount_Payable__c = 4500,
            CurrencyIsoCode = 'INR',
            Is_Active__c = true
        );
        insert feeAssignment;


        // Create Fee Installment
        Fee_Installment__c feeInstallment = new Fee_Installment__c(
            Fee_Assignment__c = feeAssignment.Id,
            Fee_Type__c = feeType.Id,
            Contact__c = testContact.Id,
            Remaining_Amount__c = 2000,
            Is_Partial_Payment_Allowed__c = true
        );
        insert feeInstallment;


        // Create Payment Transaction
        Payment_Transaction__c trans = new Payment_Transaction__c(
            Payment_Mode__c = 'Online - ICICI',
            Transaction_Id__c = 'TXN123456',
            Payment_Gateway_Status__c = 'SUCCESS',
            Payment_Type__c = 'Full',
			Payment_Status__c = '1'
        );
        insert trans;

        // Create Receipt
        Receipt_and_Invoice__c receipt = new Receipt_and_Invoice__c(
            Contact__c = testContact.Id,
            Fee_Installment__c = feeInstallment.Id,
            Amount__c = 2000,
            Payment_Method__c = 'Credit Card',
            Transaction_ID__c = 'TXN123456',
            Payment_Date__c = Date.today(),
            Receipt_URL__c = 'https://test.salesforce.com/receipt123'
        );
        insert receipt;

        // Create Payment Transaction Line Item
        Payment_Transaction_Line_Item__c lineItem = new Payment_Transaction_Line_Item__c(
            Fee_Installment__c = feeInstallment.Id,
            Payment_Transaction__c = trans.Id,
            Received_Amount__c = 2000,
            Receipt__c = receipt.Id
        );
        insert lineItem;
    }
    
    @isTest
static void testSuccessfulResponse_withFeeDetailsAndTransactions() {

    Contact testContact = [SELECT Id FROM Contact LIMIT 1];

    RestRequest req = new RestRequest();
    req.requestURI = '/getReceiptsByContact/' + testContact.Id;
    req.httpMethod = 'GET';

    RestContext.request = req;

    Test.startTest();
    ReceiptPdfAPI.ResponseWrapper response =
        ReceiptPdfAPI.getDetailsByContact();
    Test.stopTest();
}


    @isTest
    static void testSuccessfulResponse() {
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];
        RestRequest req = new RestRequest();
        req.requestURI = '/getReceiptsByContact/' + testContact.Id;
        RestContext.request = req;

        Test.startTest();
        ReceiptPdfAPI.ResponseWrapper response = ReceiptPdfAPI.getDetailsByContact();
        Test.stopTest();
    }

    // Fees tied to a Withdrawn affiliation must not reach the student portal;
    // fees of the current program (and fees with no affiliation) must.
    @isTest
    static void testFeeDetailsExcludeWithdrawnAffiliation() {
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];
        Fee_Type__c feeType = [SELECT Id FROM Fee_Type__c LIMIT 1];
        Fee_Installment__c existingInstallment = [SELECT Id FROM Fee_Installment__c LIMIT 1];

        hed__Affiliation__c withdrawnAffiliation = new hed__Affiliation__c(
            hed__Contact__c = testContact.Id,
            hed__Status__c = 'Withdrawn'
        );
        insert withdrawnAffiliation;

        Fee_Assignment__c withdrawnAssignment = new Fee_Assignment__c(
            Contact__c = testContact.Id,
            Fee_Type__c = feeType.Id,
            Affiliation__c = withdrawnAffiliation.Id,
            Paid_Amount__c = 0,
            Remaining_Amount__c = 1000,
            Total_Amount_Payable__c = 1000,
            CurrencyIsoCode = 'INR',
            Is_Active__c = true
        );
        insert withdrawnAssignment;

        Fee_Installment__c withdrawnInstallment = new Fee_Installment__c(
            Fee_Assignment__c = withdrawnAssignment.Id,
            Fee_Type__c = feeType.Id,
            Contact__c = testContact.Id,
            Affiliation__c = withdrawnAffiliation.Id,
            Remaining_Amount__c = 1000
        );
        insert withdrawnInstallment;

        RestRequest req = new RestRequest();
        req.requestURI = '/getReceiptsByContact/' + testContact.Id;
        RestContext.request = req;

        Test.startTest();
        ReceiptPdfAPI.ResponseWrapper response = ReceiptPdfAPI.getDetailsByContact();
        Test.stopTest();

        Set<Id> returnedInstallmentIds = new Set<Id>();
        for (ReceiptPdfAPI.FeeDetail detail : response.feeDetails) {
            returnedInstallmentIds.add(detail.FeeInstallmentId);
        }
        System.assert(!returnedInstallmentIds.contains(withdrawnInstallment.Id),
            'Fee installment of a withdrawn affiliation must not be returned');
        System.assert(returnedInstallmentIds.contains(existingInstallment.Id),
            'Fee installment with no affiliation must still be returned');
    }
}