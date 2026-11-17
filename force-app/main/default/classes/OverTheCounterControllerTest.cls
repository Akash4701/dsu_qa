@isTest
public class OverTheCounterControllerTest {
    
        @TestSetup
    static void makeData() {
        // Create FeeServices__c custom setting
        FeeServices__c receiptSetting = new FeeServices__c();
        receiptSetting.Name = 'Receipt Runner';
        receiptSetting.Receipt_Number__c = 'DSU/CDOE/25/0001';
        insert receiptSetting;
        
        // Create Account
        Account testAccount = new Account(Name = 'Test University');
        insert testAccount;
        
        RecordType recId = [SELECT ID FROM RecordType where Name = 'Academic Program' LIMIT 1];
        
        Account AcademicAccount = new Account(Name = 'Bachelor of Business Administration', RecordType = recId);
        insert AcademicAccount;
        
        // Create Contact
        Contact testContact = new Contact(
            FirstName = 'John',
            LastName = 'Doe'
        );
        insert testContact;
        
        // Create Program Plan
        hed__Program_Plan__c programPlan = new hed__Program_Plan__c(
            Name = 'BCA-JUL-2025',
            hed__Account__c = testAccount.Id,
            Batch__c = '2025'
        );
        insert programPlan;
        
        // Create Application
        Application__c application = new Application__c(
            External_Application_Number__c = 'APP2025001',
            Program_Level__c = 'UG',
            Fee_Preference__c = 'Semester-wise fee'
        );
        insert application;
        
        // Create Affiliation
        hed__Affiliation__c affiliation = new hed__Affiliation__c(
            hed__Contact__c = testContact.Id,
            hed__Account__c = testAccount.Id,
            Roll_Number__c = '1AB25CS001',
            Individual_Application__c = application.Id,
            Program_Plan__c = programPlan.Id
        );
        insert affiliation;
        
        // Create Term
        hed__Term__c term = new hed__Term__c(
            hed__Account__c = testAccount.Id,
            Name = 'Semester 1',
            Program_Plan__c = programPlan.Id,
            hed__Start_Date__c = Date.newInstance(2025, 8, 1),
            hed__End_Date__c = Date.newInstance(2026, 1, 29),
            Term_Reference__c = 'Semester 1'
        );
        insert term;
        
        // Create Fee Type
        Fee_Type__c feeType = new Fee_Type__c(
            Fee_Head__c = 'Semester Fee',
            Due_Date__c = Date.today().addDays(10),
            Amount__c = 5000,
            Program__c = testAccount.Id,
            Semester__c = term.Id
        );
        insert feeType;
        
        // Create Fee Assignment
        Fee_Assignment__c feeAssignment = new Fee_Assignment__c(
            Affiliation__c = affiliation.Id,
            Fee_Type__c = feeType.Id, 
            Remaining_Amount__c = 5000
        );
        insert feeAssignment;
        
        // Create Fee Installment
        Fee_Installment__c feeInstallment = new Fee_Installment__c(
            Affiliation__c = affiliation.Id,
            Fee_Type__c = feeType.Id,
            Fee_Assignment__c = feeAssignment.Id,
            Paid_Amount__c = 0,
            Remaining_Amount__c = 5000
        );
        insert feeInstallment;
    }
    
    @isTest
    static void test_getStudentFeeDetails() {
        hed__Affiliation__c aff = [SELECT Roll_Number__c FROM hed__Affiliation__c LIMIT 1];
        OverTheCounterController.getStudentFeeDetails(aff.Roll_Number__c);
        
        // Negative path: blank usn
        try {
            OverTheCounterController.getStudentFeeDetails('');
        } catch (Exception e) {}
        
        // Negative path: wrong usn
        try {
            OverTheCounterController.getStudentFeeDetails('XYZ123');
        } catch (Exception e) {}
    }
    
    @isTest
    static void test_updateFeeRecordsWithPdfUrl() {
        try{
        hed__Affiliation__c aff = [SELECT Roll_Number__c FROM hed__Affiliation__c LIMIT 1];
        Fee_Installment__c fi = [SELECT Id, Remaining_Amount__c, Paid_Amount__c FROM Fee_Installment__c LIMIT 1];
        
        List<Map<String, Object>> updatedFees = new List<Map<String, Object>>();
        Map<String, Object> feeData = new Map<String, Object>();
        feeData.put('id', fi.Id);
        feeData.put('totalPaidAmount', 5000);
        feeData.put('remainingAmount', 0);
        updatedFees.add(feeData);
        
        OverTheCounterController.updateFeeRecordsWithPdfUrl(
            aff.Roll_Number__c,
            updatedFees,
            String.valueOf(Date.today()),
            'Cash',
            5000,
            'TXN123',
            'CRM123',
            'UTR123'
        );
        
        // Negative path: blank usn
        try {
            OverTheCounterController.updateFeeRecordsWithPdfUrl('', updatedFees, String.valueOf(Date.today()), 'Cash', 100, 'T1', 'C1', 'U1');
        } catch (Exception e) {}
        
        // Negative path: no affiliation
        try {
            OverTheCounterController.updateFeeRecordsWithPdfUrl('NOUSN', updatedFees, String.valueOf(Date.today()), 'Cash', 100, 'T1', 'C1', 'U1');
        } catch (Exception e) {}
        }
        catch(Exception e){

        }
    }

    // PKDSU-247: every payment taken through updateFeeRecordsWithPdfUrl - the single
    // Over-the-Counter screen as well as each Bulk Fee Payment row - must raise a
    // Payment Transaction and a Payment Transaction Line Item per paid installment.
    @isTest
    static void test_paymentTransactionCreatedForPayment() {
        hed__Affiliation__c aff = [
            SELECT Id, Roll_Number__c, hed__Contact__c FROM hed__Affiliation__c LIMIT 1
        ];
        Fee_Installment__c fi = [
            SELECT Id, Fee_Assignment__c FROM Fee_Installment__c LIMIT 1
        ];

        // Deliberately a part payment carrying paise, so the line item's 2-decimal scale is exercised
        List<Map<String, Object>> updatedFees = new List<Map<String, Object>>{
            new Map<String, Object>{
                'id' => fi.Id,
                'totalPaidAmount' => 2000.50,
                'remainingAmount' => 2999.50
            }
        };

        Test.startTest();
        OverTheCounterController.updateFeeRecordsWithPdfUrl(
            aff.Roll_Number__c, updatedFees, String.valueOf(Date.today()),
            'Cash', 2000.50, 'TXN-PT-1', 'CRM-PT-1', 'UTR-PT-1'
        );
        Test.stopTest();

        List<Payment_Transaction__c> txns = [
            SELECT Id, Amount__c, Transaction_Id__c, Payment_Mode__c, Payment_Status__c,
                   Payment_Type__c, Contact__c, Payment_Receipt_Number__c, Receipt__c
            FROM Payment_Transaction__c
        ];
        System.assertEquals(1, txns.size(), 'One Payment Transaction should be created for the payment');

        Payment_Transaction__c txn = txns[0];
        System.assertEquals(2000.50, txn.Amount__c, 'Transaction should carry the payment amount');
        System.assertEquals('TXN-PT-1', txn.Transaction_Id__c, 'Transaction Id should be stored');
        System.assertEquals('CRM-PT-1', txn.Payment_Receipt_Number__c, 'CRM receipt number should be stored');
        System.assertEquals('Cash', txn.Payment_Mode__c, 'Payment option should be stored as the payment mode');
        System.assertEquals('1', txn.Payment_Status__c, 'Transaction should be marked successful');
        System.assertEquals('Partial', txn.Payment_Type__c, 'A part payment should be typed as Partial');
        System.assertEquals(aff.hed__Contact__c, txn.Contact__c, 'Transaction should point at the student');
        System.assertNotEquals(null, txn.Receipt__c, 'Transaction should be linked to the receipt raised');

        List<Payment_Transaction_Line_Item__c> lineItems = [
            SELECT Id, Payment_Transaction__c, Fee_Installment__c, Fee_Assignment__c,
                   Amount__c, Received_Amount__c, Receipt__c, Fee_Applied__c, Contact__c
            FROM Payment_Transaction_Line_Item__c
        ];
        System.assertEquals(1, lineItems.size(), 'One line item should be created per paid installment');

        Payment_Transaction_Line_Item__c li = lineItems[0];
        System.assertEquals(txn.Id, li.Payment_Transaction__c, 'Line item should be linked to the transaction');
        System.assertEquals(fi.Id, li.Fee_Installment__c, 'Line item should be linked to the fee installment');
        System.assertEquals(fi.Fee_Assignment__c, li.Fee_Assignment__c, 'Line item should be linked to the fee assignment');
        // Paise must survive: these fields are precision 16, scale 2
        System.assertEquals(2000.50, li.Amount__c, 'Line item should carry the exact payment amount, paise included');
        System.assertEquals(2000.50, li.Received_Amount__c, 'Line item should carry the exact received amount, paise included');
        System.assertNotEquals(null, li.Receipt__c, 'Line item should be linked to its receipt');
        // Guards against PaymentTransactionLineItemHandler posting this amount a second time
        System.assertEquals(true, li.Fee_Applied__c, 'Line item must be flagged as already applied to the ledger');

        // The amount must have been posted exactly once, not twice
        Fee_Installment__c afterPayment = [
            SELECT Id, Paid_Amount__c FROM Fee_Installment__c WHERE Id = :fi.Id
        ];
        System.assertEquals(2000.50, afterPayment.Paid_Amount__c, 'Payment should be posted to the installment exactly once');
    }

    @isTest
    static void test_getLatestReceiptUrl() {
        hed__Affiliation__c aff = [SELECT Roll_Number__c FROM hed__Affiliation__c LIMIT 1];
        OverTheCounterController.getLatestReceiptUrl(aff.Roll_Number__c);
        
        // Negative path: blank usn
        try {
            OverTheCounterController.getLatestReceiptUrl('');
        } catch (Exception e) {}
        
        // Negative path: wrong usn
        try {
            OverTheCounterController.getLatestReceiptUrl('XXX111');
        } catch (Exception e) {}
    }
    
    @isTest
    static void test_generateAndIncrementReceiptNumber() {
        hed__Affiliation__c aff = [SELECT Roll_Number__c FROM hed__Affiliation__c LIMIT 1];
        OverTheCounterController.generateAndIncrementReceiptNumber(aff.Roll_Number__c);
        
        // Negative path: short roll number
        try {
            OverTheCounterController.generateAndIncrementReceiptNumber('123');
        } catch (Exception e) {}
    }
    
    @isTest
    static void test_getAcademicSessionFromIntakeName() {
        OverTheCounterController.getAcademicSessionFromIntakeName('BCA-JUL-2025');
        OverTheCounterController.getAcademicSessionFromIntakeName('');
        OverTheCounterController.getAcademicSessionFromIntakeName('InvalidName');
    }
    
    @isTest
    static void test_checkDuplicate() {
        // Insert a receipt to test duplicate
        Receipt_and_Invoice__c r = new Receipt_and_Invoice__c(
            Contact__c = [SELECT hed__Contact__c FROM hed__Affiliation__c LIMIT 1].hed__Contact__c,
            Transaction_ID__c = 'TXN12345',
            CRM_Receipt_Number__c = 'CRM12345',
            Amount__c = 100,
            Payment_Method__c = 'Cash',
            Payment_Date__c = Date.today()
        );
        insert r;
        
        OverTheCounterController.checkDuplicate('Transaction_ID__c', 'TXN12345', 1);
        OverTheCounterController.checkDuplicate('CRM_Receipt_Number__c', 'CRM12345', 1);
        
        Fee_Installment__c fi = [SELECT Id FROM Fee_Installment__c LIMIT 1];
        fi.Settlement_UTR__c = 'UTR999';
        update fi;
        OverTheCounterController.checkDuplicate('Settlement_UTR__c', 'UTR999', 1);
        
        // Non duplicate
        OverTheCounterController.checkDuplicate('Transaction_ID__c', 'XXX', 1);
        
        // Invalid field
        try {
            OverTheCounterController.checkDuplicate('InvalidField', '123', 1);
        } catch (Exception e) {}
    }
    
    @isTest
    static void test_formatIndianNumber() {
        OverTheCounterController.formatIndianNumber(Decimal.valueOf(123));
        OverTheCounterController.formatIndianNumber(Decimal.valueOf(12345));
        OverTheCounterController.formatIndianNumber(Decimal.valueOf(1234567));
    }

    // =====================================================================
    // Bulk Fee Payment - prepareBulkPaymentRow
    // This is the validation and allocation path behind the Bulk Fee Payment
    // upload. It had no coverage at all, which is what held the class under
    // the 75% gate.
    // =====================================================================

    private static String bulkUsn() {
        return [SELECT Roll_Number__c FROM hed__Affiliation__c LIMIT 1].Roll_Number__c;
    }

    private static String bulkAssignmentName() {
        return [SELECT Name FROM Fee_Assignment__c LIMIT 1].Name;
    }

    private static String today_yyyymmdd() {
        return String.valueOf(Date.today());
    }

    // Calls the method with sensible defaults so each test only states what it cares about.
    private static Map<String, Object> prepare(
        String usn, String feeAssignment, String payDate, String method,
        Decimal amount, String txn, String crm, String utr
    ) {
        return OverTheCounterController.prepareBulkPaymentRow(
            usn, feeAssignment, payDate, method, amount, txn, crm, utr
        );
    }

    private static String msgOf(Map<String, Object> res) {
        return (String) res.get('message');
    }

    @isTest
    static void test_prepareBulkPaymentRow_success() {
        String usn = bulkUsn();
        String fa = bulkAssignmentName();

        Test.startTest();
        Map<String, Object> res = prepare(usn, fa, today_yyyymmdd(), 'Cash', 2000, 'TXN-A', 'CRM-A', 'UTR-A');
        Test.stopTest();

        System.assertEquals(true, res.get('success'), 'A valid row should validate: ' + msgOf(res));
        System.assertEquals(usn, (String) res.get('usnNumber'), 'The resolved USN should come back');

        List<Map<String, Object>> allocated = (List<Map<String, Object>>) res.get('updatedFeeRecords');
        System.assertEquals(1, allocated.size(), 'The payment should be allocated to the single open installment');
        System.assertEquals(2000, (Decimal) allocated[0].get('totalPaidAmount'), 'Paid amount should be the payment');
        System.assertEquals(3000, (Decimal) allocated[0].get('remainingAmount'), 'Remaining should drop by the payment');
    }

    @isTest
    static void test_prepareBulkPaymentRow_requiredFieldValidation() {
        String usn = bulkUsn();
        String fa = bulkAssignmentName();
        String d = today_yyyymmdd();

        Test.startTest();
        System.assertEquals('USN is required.',
            msgOf(prepare('   ', fa, d, 'Cash', 100, 'T', 'C', 'U')));
        System.assertEquals('Fee Assignment is required.',
            msgOf(prepare(usn, '  ', d, 'Cash', 100, 'T', 'C', 'U')));
        System.assertEquals('Payment amount must be greater than 0.',
            msgOf(prepare(usn, fa, d, 'Cash', 0, 'T', 'C', 'U')));
        System.assertEquals('Payment amount must be greater than 0.',
            msgOf(prepare(usn, fa, d, 'Cash', null, 'T', 'C', 'U')));
        System.assertEquals('Payment amount cannot have more than 2 decimal places.',
            msgOf(prepare(usn, fa, d, 'Cash', 100.123, 'T', 'C', 'U')));
        System.assertEquals('Payment date must be in YYYY-MM-DD format.',
            msgOf(prepare(usn, fa, '28-10-2026', 'Cash', 100, 'T', 'C', 'U')));
        System.assertEquals('Payment date cannot be in the future.',
            msgOf(prepare(usn, fa, String.valueOf(Date.today().addDays(5)), 'Cash', 100, 'T', 'C', 'U')));
        System.assertEquals('Invalid payment option: UPI',
            msgOf(prepare(usn, fa, d, 'UPI', 100, 'T', 'C', 'U')));
        System.assertEquals('Transaction ID is required.',
            msgOf(prepare(usn, fa, d, 'Cash', 100, '  ', 'C', 'U')));
        System.assertEquals('CRM Receipt Number is required.',
            msgOf(prepare(usn, fa, d, 'Cash', 100, 'T', '  ', 'U')));
        System.assertEquals('Settlement UTR is required.',
            msgOf(prepare(usn, fa, d, 'Cash', 100, 'T', 'C', '  ')));
        Test.stopTest();
    }

    @isTest
    static void test_prepareBulkPaymentRow_studentAndAssignmentLookup() {
        String usn = bulkUsn();
        String d = today_yyyymmdd();

        Test.startTest();
        Map<String, Object> noStudent = prepare('NO-SUCH-USN', 'FA-9999', d, 'Cash', 100, 'T', 'C', 'U');
        System.assertEquals(false, noStudent.get('success'), 'An unknown USN should fail');
        System.assert(msgOf(noStudent).contains('No student found with USN'),
            'Unexpected message: ' + msgOf(noStudent));

        // PKDSU-242: "not found" is reported on its own, not merged with "already fully paid"
        Map<String, Object> noAssignment = prepare(usn, 'FA-DOES-NOT-EXIST', d, 'Cash', 100, 'T2', 'C2', 'U2');
        System.assertEquals(false, noAssignment.get('success'), 'An unknown fee assignment should fail');
        System.assert(msgOf(noAssignment).startsWith('Fee Assignment Not Found'),
            'Unexpected message: ' + msgOf(noAssignment));
        System.assert(!msgOf(noAssignment).contains('Already Fully Paid'),
            'The two situations must be reported separately: ' + msgOf(noAssignment));
        Test.stopTest();
    }

    // PKDSU-242: a fee assignment that exists but carries no balance reports
    // "Already Fully Paid", never "Fee Assignment Not Found".
    @isTest
    static void test_prepareBulkPaymentRow_alreadyFullyPaidReportedSeparately() {
        String usn = bulkUsn();
        Fee_Installment__c fi = [
            SELECT Id, Total_Amount_Payable__c, Fee_Assignment__c FROM Fee_Installment__c LIMIT 1
        ];
        fi.Paid_Amount__c = 5000;
        fi.Remaining_Amount__c = 0;
        update fi;

        // PKDSU-242: "already paid" is read from the Fee Assignment, which is where the running
        // balance actually lives, so the assignment has to be settled too - not just the
        // installment under it.
        Fee_Assignment__c settled = new Fee_Assignment__c(
            Id = fi.Fee_Assignment__c,
            Paid_Amount__c = 5000,
            Remaining_Amount__c = 0
        );
        update settled;

        String fa = bulkAssignmentName();

        Test.startTest();
        Map<String, Object> res = prepare(usn, fa, today_yyyymmdd(), 'Cash', 100, 'T-FP', 'C-FP', 'U-FP');
        Test.stopTest();

        System.assertEquals(false, res.get('success'), 'A settled fee assignment should not accept more money');
        System.assert(msgOf(res).startsWith('Already Fully Paid'),
            'Unexpected message: ' + msgOf(res));
        System.assert(!msgOf(res).contains('Not Found'),
            'A settled assignment must not be reported as missing: ' + msgOf(res));
    }

    // PKDSU-242, the FA-0318 case. A 'Semester-wise fee' assignment carries no Fee_Installment__c
    // rows at all. Resolving it through its installments reported a settled assignment as
    // "Fee Assignment Not Found"; it must report as already paid.
    @isTest
    static void test_settledAssignmentWithoutInstallmentsIsReportedAsPaid() {
        String usn = bulkUsn();
        Fee_Assignment__c noInstallments = assignmentWithoutInstallments(0, 1000);

        Test.startTest();
        Map<String, Object> res = prepare(usn, noInstallments.Name, today_yyyymmdd(), 'Cash', 500, 'T-NI1', 'C-NI1', 'U-NI1');
        Test.stopTest();

        System.assertEquals(false, res.get('success'), 'A settled assignment should not accept more money');
        System.assert(msgOf(res).startsWith('Already Fully Paid'),
            'A settled assignment with no installments must report as paid, not missing: ' + msgOf(res));
        System.assert(!msgOf(res).contains('Not Found'),
            'A settled assignment must never be reported as missing: ' + msgOf(res));
    }

    // PKDSU-242, the FA-0249 case. The assignment exists and still owes money, but has no
    // installment to post against. That is neither "not found" nor "already paid" and must say so.
    @isTest
    static void test_unpaidAssignmentWithoutInstallmentsIsNotReportedAsMissing() {
        String usn = bulkUsn();
        Fee_Assignment__c noInstallments = assignmentWithoutInstallments(20000, 0);

        Test.startTest();
        Map<String, Object> res = prepare(usn, noInstallments.Name, today_yyyymmdd(), 'Cash', 500, 'T-NI2', 'C-NI2', 'U-NI2');
        Test.stopTest();

        System.assertEquals(false, res.get('success'), 'There is nothing to post the payment against');
        System.assert(!msgOf(res).contains('Not Found'),
            'An assignment that exists must never be reported as missing: ' + msgOf(res));
        System.assert(!msgOf(res).contains('Already Fully Paid'),
            'An unpaid assignment must not be reported as settled: ' + msgOf(res));
        System.assert(msgOf(res).contains('no open fee installment'),
            'Unexpected message: ' + msgOf(res));
    }

    // A fee assignment on the test affiliation deliberately created with no Fee_Installment__c
    // children, mirroring how 'Semester-wise fee' assignments are stored.
    static Fee_Assignment__c assignmentWithoutInstallments(Decimal remaining, Decimal paid) {
        hed__Affiliation__c aff = [SELECT Id FROM hed__Affiliation__c LIMIT 1];
        Fee_Type__c ft = [SELECT Id FROM Fee_Type__c LIMIT 1];

        // Apex does not advance auto-number sequences inside a test transaction, so a second
        // Fee Assignment would be handed the same Name as the one from @TestSetup and both
        // would resolve by name. The setup records go first so this is the only one carrying it.
        delete [SELECT Id FROM Fee_Installment__c];
        delete [SELECT Id FROM Fee_Assignment__c];

        Fee_Assignment__c fa = new Fee_Assignment__c(
            Affiliation__c = aff.Id,
            Fee_Type__c = ft.Id,
            Paid_Amount__c = paid,
            Remaining_Amount__c = remaining
        );
        insert fa;
        return [SELECT Id, Name FROM Fee_Assignment__c WHERE Id = :fa.Id];
    }

    @isTest
    static void test_prepareBulkPaymentRow_amountExceedsRemaining() {
        String usn = bulkUsn();
        String fa = bulkAssignmentName();

        Test.startTest();
        // The single installment carries 5000 remaining
        Map<String, Object> res = prepare(usn, fa, today_yyyymmdd(), 'NEFT', 99999, 'T-X', 'C-X', 'U-X');
        Test.stopTest();

        System.assertEquals(false, res.get('success'), 'Overpayment should be rejected');
        System.assert(msgOf(res).contains('exceeds the remaining amount'),
            'Unexpected message: ' + msgOf(res));
    }

    @isTest
    static void test_prepareBulkPaymentRow_duplicateReferences() {
        String usn = bulkUsn();
        String fa = bulkAssignmentName();
        String d = today_yyyymmdd();
        Contact c = [SELECT Id FROM Contact LIMIT 1];

        // An existing receipt makes these reference values duplicates
        insert new Receipt_and_Invoice__c(
            Contact__c = c.Id,
            Transaction_ID__c = 'DUP-TXN',
            CRM_Receipt_Number__c = 'DUP-CRM'
        );
        // Settlement UTR duplicates are looked for on Fee Installment. This one is not attached
        // to any fee assignment, so it cannot be traced back to the one being paid and still
        // counts as a duplicate under the PKDSU-246 scoping.
        hed__Affiliation__c aff = [SELECT Id, hed__Account__c FROM hed__Affiliation__c LIMIT 1];
        insert new Fee_Installment__c(
            Affiliation__c = aff.Id,
            Paid_Amount__c = 0,
            Remaining_Amount__c = 0,
            Settlement_UTR__c = 'DUP-UTR'
        );

        Test.startTest();
        System.assert(msgOf(prepare(usn, fa, d, 'Cash', 100, 'DUP-TXN', 'C9', 'U9'))
            .contains('Duplicate value found for Transaction_ID__c'), 'Duplicate transaction id should be caught');
        System.assert(msgOf(prepare(usn, fa, d, 'Cash', 100, 'T9', 'DUP-CRM', 'U9'))
            .contains('Duplicate value found for CRM_Receipt_Number__c'), 'Duplicate CRM receipt should be caught');
        System.assert(msgOf(prepare(usn, fa, d, 'Cash', 100, 'T9', 'C9', 'DUP-UTR'))
            .contains('Duplicate value found for Settlement_UTR__c'), 'Duplicate settlement UTR should be caught');
        Test.stopTest();
    }

    @isTest
    static void test_prepareBulkPaymentRow_mustMatchApplicationReferences() {
        String usn = bulkUsn();
        String fa = bulkAssignmentName();
        String d = today_yyyymmdd();

        Application__c app = [SELECT Id FROM Application__c LIMIT 1];
        app.Transaction_ID__c = 'APP-TXN';
        app.CRM_Receipt_Number__c = 'APP-CRM';
        update app;

        Test.startTest();
        Map<String, Object> wrongTxn = prepare(usn, fa, d, 'Cash', 100, 'SOMETHING-ELSE', 'APP-CRM', 'U1');
        System.assertEquals(false, wrongTxn.get('success'), 'A mismatched transaction id should fail');
        System.assert(msgOf(wrongTxn).contains('does not match the Individual Application'),
            'Unexpected message: ' + msgOf(wrongTxn));

        Map<String, Object> wrongCrm = prepare(usn, fa, d, 'Cash', 100, 'APP-TXN', 'SOMETHING-ELSE', 'U2');
        System.assertEquals(false, wrongCrm.get('success'), 'A mismatched CRM receipt should fail');
        System.assert(msgOf(wrongCrm).contains('CRM Receipt Number does not match'),
            'Unexpected message: ' + msgOf(wrongCrm));

        // Matching values are accepted
        Map<String, Object> ok = prepare(usn, fa, d, 'Cash', 100, 'APP-TXN', 'APP-CRM', 'U3');
        System.assertEquals(true, ok.get('success'), 'Matching references should pass: ' + msgOf(ok));
        Test.stopTest();
    }

    // The deadlock between the application-reference rule and PKDSU-246: the application
    // reference can sit on only one fee assignment, so once it had been receipted, requiring
    // every later row to quote it left the student unable to pay any other fee assignment.
    // Once the admission payment is receipted, a later payment brings its own references.
    @isTest
    static void test_laterPaymentIsNotTiedToTheApplicationReference() {
        String usn = bulkUsn();
        String fa = bulkAssignmentName();

        Application__c app = [SELECT Id FROM Application__c LIMIT 1];
        app.Transaction_ID__c = 'APP-TXN-DL';
        app.CRM_Receipt_Number__c = 'APP-CRM-DL';
        app.Transaction_Date__c = Date.today().addDays(-30);
        update app;

        // The admission payment has been banked and receipted against a DIFFERENT assignment.
        // Apex does not advance auto-number sequences inside a test transaction, so a second
        // Fee Assignment would share this one's Name; an installment with no assignment at all
        // stands in for "banked somewhere other than the assignment being paid".
        hed__Affiliation__c aff = [SELECT Id FROM hed__Affiliation__c LIMIT 1];
        Fee_Installment__c elsewhere = new Fee_Installment__c(
            Affiliation__c = aff.Id,
            Paid_Amount__c = 0,
            Remaining_Amount__c = 1000
        );
        insert elsewhere;
        insert new Receipt_and_Invoice__c(
            Fee_Installment__c = elsewhere.Id,
            Transaction_ID__c = 'APP-TXN-DL',
            CRM_Receipt_Number__c = 'APP-CRM-DL'
        );

        Test.startTest();
        // Quoting the banked application reference again is now a plain duplicate
        Map<String, Object> reused = prepare(usn, fa, today_yyyymmdd(), 'Cash', 100,
            'APP-TXN-DL', 'NEW-CRM-1', 'NEW-UTR-1');
        System.assertEquals(false, reused.get('success'),
            'The application reference is already banked against another assignment');

        // A genuinely new payment carries its own references and its own date, and is accepted
        Map<String, Object> ok = prepare(usn, fa, today_yyyymmdd(), 'Cash', 100,
            'NEW-TXN-2', 'NEW-CRM-2', 'NEW-UTR-2');
        Test.stopTest();

        System.assertEquals(true, ok.get('success'),
            'A later payment must not be forced to quote the application reference: ' + msgOf(ok));
    }

    // Covers the semester/due-date ordering (InstallmentSortItem and its compareTo)
    // and the oldest-first allocation loop across more than one fee assignment.
    @isTest
    static void test_prepareBulkPaymentRow_allocatesOldestFirstAcrossAssignments() {
        hed__Affiliation__c aff = [
            SELECT Id, Roll_Number__c, hed__Account__c, Program_Plan__c FROM hed__Affiliation__c LIMIT 1
        ];
        Fee_Assignment__c firstAssignment = [SELECT Id, Name FROM Fee_Assignment__c LIMIT 1];

        // A second, later semester for the same student
        hed__Term__c term2 = new hed__Term__c(
            hed__Account__c = aff.hed__Account__c,
            Name = 'Semester 2',
            Program_Plan__c = aff.Program_Plan__c,
            hed__Start_Date__c = Date.newInstance(2026, 2, 1),
            hed__End_Date__c = Date.newInstance(2026, 7, 29),
            Term_Reference__c = 'Semester 2'
        );
        insert term2;

        Fee_Type__c feeType2 = new Fee_Type__c(
            Fee_Head__c = 'Semester Fee',
            Due_Date__c = Date.today().addDays(40),
            Amount__c = 3000,
            Program__c = aff.hed__Account__c,
            Semester__c = term2.Id
        );
        insert feeType2;

        Fee_Assignment__c assignment2 = new Fee_Assignment__c(
            Affiliation__c = aff.Id,
            Fee_Type__c = feeType2.Id,
            Remaining_Amount__c = 3000
        );
        insert assignment2;

        insert new Fee_Installment__c(
            Affiliation__c = aff.Id,
            Fee_Type__c = feeType2.Id,
            Fee_Assignment__c = assignment2.Id,
            Paid_Amount__c = 0,
            Remaining_Amount__c = 3000
        );

        assignment2 = [SELECT Id, Name FROM Fee_Assignment__c WHERE Id = :assignment2.Id];
        String bothAssignments = firstAssignment.Name + ';' + assignment2.Name;

        Test.startTest();
        // 6000 against 5000 (Semester 1) + 3000 (Semester 2)
        Map<String, Object> res = prepare(
            aff.Roll_Number__c, bothAssignments, today_yyyymmdd(), 'RTGS', 6000, 'T-MULTI', 'C-MULTI', 'U-MULTI'
        );
        Test.stopTest();

        System.assertEquals(true, res.get('success'), 'Paying across two assignments should validate: ' + msgOf(res));

        List<Map<String, Object>> allocated = (List<Map<String, Object>>) res.get('updatedFeeRecords');
        System.assertEquals(2, allocated.size(), 'Both installments should receive part of the payment');

        // Semester 1 is settled in full first, Semester 2 takes the remainder
        System.assertEquals(5000, (Decimal) allocated[0].get('totalPaidAmount'), 'Semester 1 should be cleared first');
        System.assertEquals(0, (Decimal) allocated[0].get('remainingAmount'), 'Semester 1 should be left with nothing due');
        System.assertEquals(1000, (Decimal) allocated[1].get('totalPaidAmount'), 'Semester 2 should take the remaining 1000');
        System.assertEquals(2000, (Decimal) allocated[1].get('remainingAmount'), 'Semester 2 should still owe 2000');
    }

    // PKDSU-246: a later part payment against the SAME fee assignment may quote the same
    // Transaction ID, CRM Receipt Number and Settlement UTR, because it is the same banking
    // transaction. The same values against a DIFFERENT fee assignment are still rejected.
    @isTest
    static void test_prepareBulkPaymentRow_referencesReusableWithinSameAssignment() {
        hed__Affiliation__c aff = [SELECT Id, hed__Contact__c, Roll_Number__c, hed__Account__c FROM hed__Affiliation__c LIMIT 1];
        Fee_Installment__c fi = [SELECT Id, Fee_Assignment__c FROM Fee_Installment__c LIMIT 1];
        Fee_Assignment__c fa = [SELECT Id, Name FROM Fee_Assignment__c LIMIT 1];

        // A first part payment of 2000 has already been receipted against this assignment
        insert new Receipt_and_Invoice__c(
            Contact__c = aff.hed__Contact__c,
            Fee_Installment__c = fi.Id,
            Transaction_ID__c = 'SHARED-TXN',
            CRM_Receipt_Number__c = 'SHARED-CRM',
            Amount__c = 2000
        );
        fi.Paid_Amount__c = 2000;
        fi.Remaining_Amount__c = 3000;
        fi.Settlement_UTR__c = 'SHARED-UTR';
        update fi;

        Test.startTest();
        // The remaining 3000, quoting the very same references - must be accepted
        Map<String, Object> second = prepare(
            aff.Roll_Number__c, fa.Name, today_yyyymmdd(), 'NEFT', 3000,
            'SHARED-TXN', 'SHARED-CRM', 'SHARED-UTR'
        );
        System.assertEquals(true, second.get('success'),
            'A part payment against the same fee assignment should be able to reuse its references: ' + msgOf(second));

        Test.stopTest();
    }

    // PKDSU-246, the other half: the same references against a DIFFERENT fee assignment are
    // still rejected.
    //
    // This drives checkDuplicateOutsideAssignments directly rather than going through
    // prepareBulkPaymentRow, because that method resolves fee assignments by Name and Apex does
    // not advance an AutoNumber sequence inside a test transaction - two Fee Assignments created
    // here both come back as the same FA-xxxxx, so a by-name test could not tell them apart.
    @isTest
    static void test_checkDuplicateOutsideAssignments_scoping() {
        hed__Affiliation__c aff = [SELECT Id, hed__Contact__c FROM hed__Affiliation__c LIMIT 1];
        Fee_Installment__c fi = [SELECT Id, Fee_Assignment__c FROM Fee_Installment__c LIMIT 1];
        Id paidAssignment = fi.Fee_Assignment__c;
        Id unrelatedAssignment = [SELECT Id FROM Fee_Assignment__c LIMIT 1].Id;

        insert new Receipt_and_Invoice__c(
            Contact__c = aff.hed__Contact__c,
            Fee_Installment__c = fi.Id,
            Transaction_ID__c = 'SCOPED-TXN',
            CRM_Receipt_Number__c = 'SCOPED-CRM',
            Amount__c = 1000
        );
        fi.Settlement_UTR__c = 'SCOPED-UTR';
        update fi;

        Test.startTest();
        // In scope: the reference belongs to the assignment being paid, so reuse is allowed
        System.assertEquals(null,
            OverTheCounterController.checkDuplicateOutsideAssignments(
                'Transaction_ID__c', 'SCOPED-TXN', new Set<Id>{ paidAssignment }),
            'A reference on the same fee assignment must be reusable');
        System.assertEquals(null,
            OverTheCounterController.checkDuplicateOutsideAssignments(
                'CRM_Receipt_Number__c', 'SCOPED-CRM', new Set<Id>{ paidAssignment }),
            'A CRM receipt on the same fee assignment must be reusable');
        System.assertEquals(null,
            OverTheCounterController.checkDuplicateOutsideAssignments(
                'Settlement_UTR__c', 'SCOPED-UTR', new Set<Id>{ paidAssignment }),
            'A settlement UTR on the same fee assignment must be reusable');

        // Out of scope: paying a different fee assignment, so the same references are duplicates
        Set<Id> somewhereElse = new Set<Id>{ aff.Id };
        System.assertNotEquals(null,
            OverTheCounterController.checkDuplicateOutsideAssignments(
                'Transaction_ID__c', 'SCOPED-TXN', somewhereElse),
            'A reference used on another fee assignment must still be a duplicate');
        System.assertNotEquals(null,
            OverTheCounterController.checkDuplicateOutsideAssignments(
                'CRM_Receipt_Number__c', 'SCOPED-CRM', somewhereElse),
            'A CRM receipt used on another fee assignment must still be a duplicate');
        System.assertNotEquals(null,
            OverTheCounterController.checkDuplicateOutsideAssignments(
                'Settlement_UTR__c', 'SCOPED-UTR', somewhereElse),
            'A settlement UTR used on another fee assignment must still be a duplicate');

        // An unknown value is never a duplicate, and a blank one is skipped entirely
        System.assertEquals(null,
            OverTheCounterController.checkDuplicateOutsideAssignments(
                'Transaction_ID__c', 'NEVER-USED', new Set<Id>{ unrelatedAssignment }),
            'An unused reference is not a duplicate');
        System.assertEquals(null,
            OverTheCounterController.checkDuplicateOutsideAssignments('Transaction_ID__c', '  ', null),
            'A blank reference is skipped');

        try {
            OverTheCounterController.checkDuplicateOutsideAssignments('Bogus__c', 'x', null);
            System.assert(false, 'An unknown field name should be rejected');
        } catch (Exception e) {
            // expected
        }
        Test.stopTest();
    }

    // PKDSU-240: the payment date must agree with the transaction date already recorded on the
    // Individual Application when the row quotes that application's Transaction ID.
    @isTest
    static void test_prepareBulkPaymentRow_transactionDateMustMatchApplication() {
        String usn = bulkUsn();
        String fa = bulkAssignmentName();

        Application__c app = [SELECT Id FROM Application__c LIMIT 1];
        app.Transaction_ID__c = 'DATED-TXN';
        app.Transaction_Date__c = Date.today().addDays(-3);
        update app;

        Test.startTest();
        Map<String, Object> mismatch = prepare(usn, fa, today_yyyymmdd(), 'NEFT', 1000, 'DATED-TXN', 'C-D1', 'U-D1');
        System.assertEquals(false, mismatch.get('success'), 'A date that disagrees with the application should fail');
        System.assert(msgOf(mismatch).contains('Payment date does not match the transaction date'),
            'Unexpected message: ' + msgOf(mismatch));

        Map<String, Object> match = prepare(
            usn, fa, String.valueOf(Date.today().addDays(-3)), 'NEFT', 1000, 'DATED-TXN', 'C-D2', 'U-D2'
        );
        Test.stopTest();

        System.assertEquals(true, match.get('success'),
            'The application transaction date should be accepted: ' + msgOf(match));
    }

    // PKDSU-241: no receipt may be raised for a withdrawn student, on either screen.
    @isTest
    static void test_withdrawnStudentCannotGenerateReceipt() {
        hed__Affiliation__c aff = [SELECT Id, Roll_Number__c FROM hed__Affiliation__c LIMIT 1];
        aff.hed__Status__c = 'Withdrawn';
        update aff;

        Fee_Installment__c fi = [SELECT Id FROM Fee_Installment__c LIMIT 1];
        String fa = bulkAssignmentName();

        Test.startTest();
        // Bulk Fee Payment row
        Map<String, Object> bulkRow = prepare(aff.Roll_Number__c, fa, today_yyyymmdd(), 'Cash', 1000, 'T-W', 'C-W', 'U-W');
        System.assertEquals(false, bulkRow.get('success'), 'A withdrawn student should be rejected in bulk');
        System.assert(msgOf(bulkRow).contains('withdrawn'),
            'Unexpected message: ' + msgOf(bulkRow));

        // Single Over-the-Counter receipt
        Boolean blocked = false;
        try {
            OverTheCounterController.updateFeeRecordsWithPdfUrl(
                aff.Roll_Number__c,
                new List<Map<String, Object>>{
                    new Map<String, Object>{ 'id' => fi.Id, 'totalPaidAmount' => 1000, 'remainingAmount' => 4000 }
                },
                today_yyyymmdd(), 'Cash', 1000, 'T-W2', 'C-W2', 'U-W2'
            );
        } catch (Exception e) {
            blocked = true;
        }
        Test.stopTest();

        System.assertEquals(true, blocked, 'A withdrawn student should be rejected on the single receipt screen too');
        System.assertEquals(0, [SELECT COUNT() FROM Receipt_and_Invoice__c],
            'No receipt should have been raised for a withdrawn student');
    }
}