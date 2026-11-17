@RestResource(urlMapping='/fees/receipt')
global without sharing class FeeReceiptAPI {

    @HttpGet
    global static List<ReceiptResponseDTO> getReceipts() {

        RestRequest req = RestContext.request;
        String contactId = req.params.get('contactId');

        if (String.isBlank(contactId)) {
            throw new AuraHandledException('contactId is required');
        }

        List<Receipt_and_Invoice__c> receipts = [
            SELECT
                Amount__c,
                Receipt_URL__c,
                Transaction_ID__c,
                Payment_Date__c,
                Payment_Method__c,
                Fee_Installment__r.Affiliation__r.Program_Plan__r.Name,
                Fee_Installment__r.Affiliation__r.Program_Plan__r.hed__Account__r.Name,
                Fee_Installment__r.Fee_Assignment__r.Fee_Type__r.Semester__r.Term_Reference__c,
                CreatedDate
            FROM Receipt_and_Invoice__c
            WHERE Contact__c = :contactId
            ORDER BY Payment_Date__c DESC
        ];

        List<ReceiptResponseDTO> response = new List<ReceiptResponseDTO>();

        for (Receipt_and_Invoice__c r : receipts) {
            response.add(new ReceiptResponseDTO(r));
        }

        return response;
    }

    // ===================== DTO =====================

    global class ReceiptResponseDTO {
        public String transactionId;
        public Date transactionDate;
        public Datetime transactionDateTime;
        public String semester;
        public String receiptUrl;
        public String programPlanName;
        public String programName;
        public String paymentType;
        public String paymentStatus;
        public String paymentGatewayStatus;
        public Decimal paidAmount;
        public String modeOfPayment;

        public ReceiptResponseDTO(Receipt_and_Invoice__c r) {

            transactionId = r.Transaction_ID__c;
            transactionDate = r.Payment_Date__c != null
                ? r.Payment_Date__c
                : null;

            transactionDateTime = r.CreatedDate;

            semester = r.Fee_Installment__r
                ?.Fee_Assignment__r
                ?.Fee_Type__r
                ?.Semester__r
                ?.Term_Reference__c;

            receiptUrl = r.Receipt_URL__c;

            programPlanName = r.Fee_Installment__r
                ?.Affiliation__r
                ?.Program_Plan__r
                ?.Name;

            programName = r.Fee_Installment__r
                ?.Affiliation__r
                ?.Program_Plan__r
                ?.hed__Account__r
                ?.Name;

            paidAmount = r.Amount__c;
            modeOfPayment = r.Payment_Method__c;

            // Constants (as per requirement)
            paymentType = 'Full';
            paymentStatus = '1';
            paymentGatewayStatus = 'Success';
        }
    }
}