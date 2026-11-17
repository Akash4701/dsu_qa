@IsTest
public class FeeReceiptAPITest {

    @testSetup
    static void setupData() {

        // -------- Account hierarchy --------
        Account institute = new Account(Name = 'Test Institute');
        insert institute;

        Account programAccount = new Account(
            Name = 'Bachelor of Technology',
            ParentId = institute.Id
        );
        insert programAccount;

        // -------- Program Plan --------
        hed__Program_Plan__c plan = new hed__Program_Plan__c(
            Name = '2025-BTECH',
            hed__Account__c = programAccount.Id,
            Batch__c = '2025',
            Intake_Number__c = 1,
            Sequence_Number__c = 1
        );
        insert plan;

        // -------- Term --------
        hed__Term__c term = new hed__Term__c(
            Program_Plan__c = plan.Id,
            Term_Reference__c = 'Semester 1',
            hed__Account__c = programAccount.Id
        );
        insert term;

        // -------- Contact --------
        Contact student = new Contact(
            FirstName = 'John',
            LastName = 'Doe'
        );
        insert student;

        // -------- Affiliation --------
        hed__Affiliation__c aff = new hed__Affiliation__c(
            hed__Contact__c = student.Id,
            Program_Plan__c = plan.Id
        );
        insert aff;

        // -------- Fee Type --------
        Fee_Type__c feeType = new Fee_Type__c(
            Program__c = programAccount.Id,
            Semester__c = term.Id,
            Fee_Head__c = 'Semester Fee',
            Fee_Preference__c = 'Semester-wise fee',
            Amount__c = 50000
        );
        insert feeType;

        // -------- Fee Assignment --------
        Fee_Assignment__c fa = new Fee_Assignment__c(
            Affiliation__c = aff.Id,
            Contact__c = student.Id,
            Fee_Type__c = feeType.Id,
            Remaining_Amount__c = 50000,
            Total_Amount_Payable__c = 50000,
            Is_Active__c = true
        );
        insert fa;

        // -------- Fee Installment --------
        Fee_Installment__c inst = new Fee_Installment__c(
            Fee_Assignment__c = fa.Id,
            Fee_Type__c = feeType.Id,
            Affiliation__c = aff.Id,
            Contact__c = student.Id,
            Remaining_Amount__c = 50000
        );
        insert inst;

        // -------- Receipt --------
        Receipt_and_Invoice__c receipt = new Receipt_and_Invoice__c(
            Contact__c = student.Id,
            Fee_Installment__c = inst.Id,
            Amount__c = 50000,
            Transaction_ID__c = 'TXN-001',
            Payment_Date__c = Date.today(),
            Payment_Method__c = 'Online',
            Receipt_URL__c = 'https://example.com/receipt.pdf'
        );
        insert receipt;
    }

    // ---------------- HAPPY PATH ----------------
    @IsTest
    static void testGetReceiptsSuccess() {

        Contact c = [SELECT Id FROM Contact LIMIT 1];

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/fees/receipt';
        req.httpMethod = 'GET';
        req.addParameter('contactId', c.Id);

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        List<FeeReceiptAPI.ReceiptResponseDTO> result =
            FeeReceiptAPI.getReceipts();
        Test.stopTest();

        
    }

    // ---------------- MISSING PARAM ----------------
    @IsTest
    static void testGetReceiptsMissingContactId() {

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/fees/receipt';
        req.httpMethod = 'GET';

        RestContext.request = req;
        RestContext.response = res;

        try {
            Test.startTest();
            FeeReceiptAPI.getReceipts();
            Test.stopTest();
        } catch (AuraHandledException ex) {
            
        }
    }

    // ---------------- NO RECEIPTS ----------------
    @IsTest
    static void testGetReceiptsNoData() {

        Contact c = new Contact(FirstName = 'Empty', LastName = 'User');
        insert c;

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/fees/receipt';
        req.httpMethod = 'GET';
        req.addParameter('contactId', c.Id);

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        List<FeeReceiptAPI.ReceiptResponseDTO> result =
            FeeReceiptAPI.getReceipts();
        Test.stopTest();

  }
}