@RestResource(urlMapping='/getReceiptsByContact/*')
global with sharing class ReceiptPdfAPI {

    @HttpGet
    global static ResponseWrapper getDetailsByContact() {
        RestRequest req = RestContext.request;
        String contactId = req.requestURI.substringAfter('/getReceiptsByContact/');
        ResponseWrapper response = new ResponseWrapper(true, 'Success');

        if (String.isBlank(contactId)) {
            return new ResponseWrapper(false, 'Missing Contact Id in request URL.');
        }

        try {
            // -------------------------
            // 1. Fetch Application Info
            // -------------------------
            String paymentMethod = null;
            String paymentPreference = null;

            List<Application__c> applications = [
                SELECT Id, Payment_Method__c, Fee_Preference__c
                FROM Application__c
                WHERE ContactId__c = :contactId
                AND Id IN (
                    SELECT Individual_Application__c
                    FROM hed__Affiliation__c
                    WHERE hed__Contact__c = :contactId
                    AND hed__Status__c = 'Current'
                )
                LIMIT 1
            ];

            if (!applications.isEmpty()) {
                paymentMethod = applications[0].Payment_Method__c;
                paymentPreference = applications[0].Fee_Preference__c;
            }

            // ------------------------
            // 2. Fee Details Section (Using FeeInstallment__c)
            // Fees of a program the student withdrew from are not returned
            // (installments with no affiliation are kept).
            // ------------------------
            List<Fee_Installment__c> installments = [
                SELECT Id, Name, Is_Partial_Payment_Allowed__c, Fee_Assignment__c, Fee_Assignment__r.Fee_Type__r.Semester__r.Term_Reference__c,
                       Fee_Assignment__r.CurrencyIsoCode,
                       Fee_Assignment__r.Fee_Amount__c,
                  	   Fee_Assignment__r.Total_Amount_Payable__c,
                       Fee_Assignment__r.Total_Paid_Amount__c,
                	   Fee_Assignment__r.Paid_Amount__c,
                       Fee_Assignment__r.Remaining_Amount__c,
                	   Fee_Assignment__r.Scholarship_Amount__c,
                	   Fee_Assignment__r.Is_Active__c
                FROM Fee_Installment__c
                WHERE Contact__c = :contactId AND Fee_Assignment__r.Is_Active__c = true AND Fee_Assignment__r.Fee_Head__c NOT IN ('Exam Fee', 'Backlog examination Fee', 'Re-Evaluation Fee')
                AND (Affiliation__c = NULL OR Affiliation__r.hed__Status__c != 'Withdrawn')
            ];

            for (Fee_Installment__c fi : installments) {
                FeeDetail detail = new FeeDetail();
                detail.FeeAssignmentId = fi.Fee_Assignment__c;
                detail.FeeInstallmentId = fi.Id;
                detail.semester = fi.Fee_Assignment__r.Fee_Type__r.Semester__r.Term_Reference__c;
                detail.currencyType = fi.Fee_Assignment__r.CurrencyIsoCode;
                detail.totalAmount = fi.Fee_Assignment__r.Fee_Amount__c;
                detail.paidAmount = fi.Fee_Assignment__r.Paid_Amount__c;
                detail.scholarshipAmount = fi.Fee_Assignment__r.Scholarship_Amount__c;
                detail.remainingAmount = fi.Fee_Assignment__r.Remaining_Amount__c;
                detail.modeOfPayment = paymentMethod;
                detail.paymentPreference = paymentPreference;
				detail.isPartialPaymentAllowed = fi.Is_Partial_Payment_Allowed__c;

                response.feeDetails.add(detail);
            }

            // ------------------------
            // 3. Transaction Section (using Payment_Transaction__c and Receipt_URL__c)
            // ------------------------
            List<Payment_Transaction_Line_Item__c> lineItems = [
                SELECT Id,
                       Received_Amount__c,
                       Payment_Status__c,
                       Payment_Transaction__r.Transaction_Date__c,
                       Payment_Transaction__r.Payment_Mode__c,
                       Payment_Transaction__r.Transaction_Id__c,
					   Payment_Transaction__r.Payment_Gateway_Status__c,
					   Payment_Transaction__r.Payment_Type__c,
                       Fee_Installment__r.Fee_Type__r.Semester__r.Term_Reference__c,
					   Fee_Installment__r.Affiliation__r.Program_Plan__r.Name,
					   Fee_Installment__r.Affiliation__r.Program_Plan__r.hed__Account__r.Name,
                       Receipt__r.Receipt_URL__c,
                       Payment_Transaction__r.Receipt__r.Receipt_URL__c
                FROM Payment_Transaction_Line_Item__c
                WHERE Fee_Installment__r.Contact__c = :contactId
            ];

            for (Payment_Transaction_Line_Item__c li : lineItems) {
                Transactions txn = new Transactions();
                txn.semester = li.Fee_Installment__r.Fee_Type__r.Semester__r.Term_Reference__c;
                txn.paidAmount = li.Received_Amount__c;
                txn.modeOfPayment = li.Payment_Transaction__r.Payment_Mode__c;
                txn.transactionId = li.Payment_Transaction__r.Transaction_Id__c;
                txn.transactionDate = li.Payment_Transaction__r.Transaction_Date__c != null
                    ? li.Payment_Transaction__r.Transaction_Date__c.format('yyyy-MM-dd HH:mm:ss')
                    : null;
                // Non-exam receipts are stamped on the line item; exam-fee (Backlog / Re-Evaluation)
                // receipts are consolidated on the parent Payment_Transaction__c instead.
                txn.receiptUrl = li.Receipt__r != null
                    ? li.Receipt__r.Receipt_URL__c
                    : (li.Payment_Transaction__r != null && li.Payment_Transaction__r.Receipt__r != null
                        ? li.Payment_Transaction__r.Receipt__r.Receipt_URL__c
                        : null);
				txn.paymentStatus = li.Payment_Status__c;
				txn.paymentGatewayStatus = li.Payment_Transaction__r.Payment_Gateway_Status__c;
				txn.paymentType = li.Payment_Transaction__r.Payment_Type__c;  
				txn.programPlanName = li.Fee_Installment__r.Affiliation__r.Program_Plan__r.Name;
				txn.programName = li.Fee_Installment__r.Affiliation__r.Program_Plan__r.hed__Account__r.Name;     

                response.transactions.add(txn);
            }

            // ------------------------
            // 4. Final Message Logic
            // ------------------------
            if (response.feeDetails.isEmpty() && response.transactions.isEmpty()) {
                response.success = false;
                response.message = 'No Fee Details or Receipts found for the contact.';
            } else if (response.feeDetails.isEmpty()) {
                response.message = 'Only receipt transactions found. No fee details available.';
            } else if (response.transactions.isEmpty()) {
                response.message = 'Only fee details found. No receipt transactions available.';
            } else {
                response.message = 'Success';
            }

            return response;

        } catch (Exception e) {
            return new ResponseWrapper(false, 'Unexpected error: ' + e.getMessage() + ' at line ' + e.getLineNumber());
        }
    }

    // -------------------- Wrapper Classes --------------------
    global class Transactions {
        public String semester;
        public Decimal paidAmount;
        public String modeOfPayment;
        public String transactionId;
        public String transactionDate;
        public String receiptUrl;
		public String paymentStatus;
		public String paymentGatewayStatus;
		public String paymentType;
		public String programPlanName;
		public String programName;
    }

    global class FeeDetail {
        public String semester;
        public Id FeeAssignmentId;
        public Id FeeInstallmentId;
        public String currencyType;
        public Decimal totalAmount;
        public Decimal scholarshipAmount;
        public Decimal paidAmount;
        public Decimal remainingAmount;
        public String modeOfPayment;
        public String paymentPreference;
		public Boolean isPartialPaymentAllowed;
    }

    global class ResponseWrapper {
        public Boolean success;
        public String message;
        public List<FeeDetail> feeDetails;
        public List<Transactions> transactions;

        public ResponseWrapper(Boolean success, String message) {
            this.success = success;
            this.message = message;
            this.feeDetails = new List<FeeDetail>();
            this.transactions = new List<Transactions>();
        }
    }
}