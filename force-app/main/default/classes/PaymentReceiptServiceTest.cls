@isTest
public class PaymentReceiptServiceTest {

    @testSetup
    static void setupTestData() {

		FeeServices__c fese = new FeeServices__c(Name = 'Receipt Runner', Receipt_Number__c = 'DSU/CDOE/28/0085');
		insert fese;

        // Contact
        Contact con = new Contact(FirstName = 'Test', LastName = 'Student');
        insert con;

        // Account (Program)
        Account acc = new Account(Name = 'Test Program');
        insert acc;

        // Individual Application
        Application__c app = new Application__c(
            External_Application_Number__c = 'APP001',
            Fee_Preference__c = 'Semester-wise fee',
			Program_Level__c = 'UG'
        );
        insert app;

        // Program Plan
        hed__Program_Plan__c plan = new hed__Program_Plan__c(
            Name = 'B.Tech 2025',
            Batch__c = '2025',
            hed__Account__c = acc.Id
        );
        insert plan;

        // Affiliation (ties everything together)
        hed__Affiliation__c aff = new hed__Affiliation__c(
            hed__Contact__c = con.Id,
            Roll_Number__c = 'USN000001',
            Program_Plan__c = plan.Id,
            Individual_Application__c = app.Id
        );
        insert aff;

		hed__Term__c term = new hed__Term__c(
			Term_Reference__c = 'Semester 1',
			hed__Account__c = acc.Id,
			Program_Plan__c = plan.Id
		);
		insert term;		

        Fee_Type__c ft = new Fee_Type__c(
            Fee_Head__c = 'Semester Fee',
			Fee_Preference__c = 'Semester-wise fee',
			Amount__c = 10000,
			Semester__c = term.Id,
            Program__c = acc.Id
        );
        insert ft;

        // Fee Assignment
        Fee_Assignment__c fa = new Fee_Assignment__c(
            Remaining_Amount__c = 1000,
			Fee_Type__c = ft.ID
            
        );
        insert fa;

        // Fee Installment (linked to Affiliation and Fee Type)
        Fee_Installment__c fi = new Fee_Installment__c(
            Fee_Assignment__c = fa.Id,
            Remaining_Amount__c = 500,
            Fee_Type__c = ft.Id,
            Affiliation__c = aff.Id,
            Settlement_UTR__c = 'UTR123'
        );
        insert fi;

        // Payment Transaction
        Payment_Transaction__c pt = new Payment_Transaction__c(
            Payment_Status__c = '1',
            Amount__c = 1000,
            Payment_Gateway_Status__c = 'Success',
            Payment_Mode__c = 'Online - ICICI',
            Transaction_Id__c = 'TXN12345'
        );
        insert pt;

        // Payment Line Item (connected to installment and transaction)
        Payment_Transaction_Line_Item__c pli = new Payment_Transaction_Line_Item__c(
            Fee_Installment__c = fi.Id,
            Received_Amount__c = 200,
            Payment_Transaction__c = pt.Id
        );
        insert pli;
    }

    @isTest
    static void testGenerateReceipts() {
        // Fetch line items
        List<Payment_Transaction_Line_Item__c> lineItems = [
            SELECT Id, Fee_Installment__c, Payment_Transaction__c, Received_Amount__c, CreatedDate
            FROM Payment_Transaction_Line_Item__c
        ];

        Test.startTest();
            PaymentReceiptService.generateReceipts(lineItems);
        Test.stopTest();
    }
}