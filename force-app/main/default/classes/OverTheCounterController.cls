public with sharing class OverTheCounterController {
    
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getStudentFeeDetails(String usnNumber) {
        try {
            if (String.isBlank(usnNumber)) {
                throw new AuraHandledException('USN Number cannot be empty');
            }
            
            Map<String, Object> result = new Map<String, Object>();
            
            // Fetch Affiliation based on USN with error handling
            List<hed__Affiliation__c> affiliations = [
                SELECT Id, hed__Contact__r.Name, Roll_Number__c, Individual_Application__r.Fee_Preference__c, Individual_Application__r.CRM_Receipt_Number__c, 
                Individual_Application__r.Transaction_ID__c
                FROM hed__Affiliation__c
                WHERE Roll_Number__c = :usnNumber.trim()
                LIMIT 1
            ];
            
            if (affiliations.isEmpty()) {
                throw new AuraHandledException('No student found with USN: ' + usnNumber);
            }
            
            hed__Affiliation__c aff = affiliations[0];
            
            // Prepare student info
            result.put('studentName', aff.hed__Contact__r.Name);
            result.put('usnNumber', aff.Roll_Number__c);
            result.put('feePreference', aff.Individual_Application__r.Fee_Preference__c);
            result.put('crmReceiptNumber', aff.Individual_Application__r.CRM_Receipt_Number__c);
            result.put('transactionId', aff.Individual_Application__r.Transaction_ID__c);
            
            // Fetch related fee assignments
            List<Fee_Installment__c> feeAssList = [
                SELECT Id, Fee_Amount__c, Total_Paid_Amount__c, Paid_Amount__c, Total_Amount_Payable__c, 
                Remaining_Amount__c, Due_Date__c,
                Fee_Assignment__r.Fee_Type__r.Semester__r.Term_Reference__c
                FROM Fee_Installment__c 
                WHERE Affiliation__c = :aff.Id AND Remaining_Amount__c > 0
                ORDER BY Fee_Assignment__r.Fee_Type__r.Semester__r.Term_Reference__c ASC NULLS LAST, Due_Date__c ASC NULLS LAST
            ];
            
            List<Map<String, Object>> feeAssignmentInstallments = new List<Map<String, Object>>();
            for (Fee_Installment__c fee : feeAssList) {
                Map<String, Object> feeMap = new Map<String, Object>();
                feeMap.put('id', fee.Id);
                feeMap.put('feeAmount', fee.Total_Amount_Payable__c != null ? fee.Total_Amount_Payable__c : 0);
                feeMap.put('totalPaidAmount', fee.Paid_Amount__c != null ? fee.Paid_Amount__c : 0);
                // feeMap.put('paidAmount', fee.Paid_Amount__c != null ? fee.Paid_Amount__c : 0);
                feeMap.put('remainingAmount', fee.Remaining_Amount__c != null ? fee.Remaining_Amount__c : 0);
                feeMap.put('formattedDueDate', fee.Due_Date__c != null ? fee.Due_Date__c.format() : '');
                feeMap.put('dueDate', fee.Due_Date__c);
                feeMap.put('termReference', fee.Fee_Assignment__r != null && fee.Fee_Assignment__r.Fee_Type__r != null &&
                    fee.Fee_Assignment__r.Fee_Type__r.Semester__r != null ?
                    fee.Fee_Assignment__r.Fee_Type__r.Semester__r.Term_Reference__c : null);
                feeAssignmentInstallments.add(feeMap);
            }
            
            result.put('feeAssignmentInstallments', feeAssignmentInstallments);
            return result;
            
        } catch (QueryException e) {
            System.debug('Query Exception: ' + e.getMessage());
            throw new AuraHandledException('Error retrieving student data: ' + e.getMessage());
        } catch (Exception e) {
            System.debug('General Exception: ' + e.getMessage());
            throw new AuraHandledException('No Student Or Fee Assignment found for the USN Number' );
        }
    }
    
    // Method to process payment allocation
    // Improved version of updateFeeRecords method that returns PDF URL
    @AuraEnabled
    public static Map<String, Object> updateFeeRecordsWithPdfUrl(String usnNumber, List<Map<String, Object>> updatedFeeRecords, String paymentDate, String paymentMethod, Decimal paymentAmount, String transactionId, String crmReceiptNumber, String settlementUTR) {
        
        System.debug(paymentDate);
        try {
            if (String.isBlank(usnNumber) || updatedFeeRecords == null || updatedFeeRecords.isEmpty()) {
                throw new AuraHandledException('Invalid payment data provided');
            }
            
            // Fetch the affiliation
            List<hed__Affiliation__c> affiliations = [
                SELECT Id, hed__Contact__c, hed__Contact__r.Name, Roll_Number__c, hed__Status__c, Individual_Application__c, Individual_Application__r.External_Application_Number__c,
                hed__Account__r.Name, Program_Plan__c, Program_Plan__r.Name, Individual_Application__r.Fee_Preference__c, Program_Plan__r.Batch__c, Individual_Application__r.Program_Level__c
                FROM hed__Affiliation__c
                WHERE Roll_Number__c = :usnNumber.trim()
                LIMIT 1
            ];

            if (affiliations.isEmpty()) {
                throw new AuraHandledException('Student not found');
            }

            hed__Affiliation__c affiliation = affiliations[0];

            // PKDSU-241: no receipt may be raised for a student who has withdrawn. This is the
            // point where receipts are actually created, so the guard sits here and covers both
            // the single Over-the-Counter screen and every Bulk Fee Payment row.
            if (ConstantsControllerClass.WITHDRAWN_STATUS.equalsIgnoreCase(affiliation.hed__Status__c)) {
                throw new AuraHandledException('Receipt generation is not allowed for withdrawn students.');
            }
            
            Set<String> accountNames = new Set<String>();
            Id programPlanId = affiliation.Program_Plan__c;
            
            // Fetch ongoing terms for program plans
            /*List<hed__Term__c> ongoingTerms = [
                SELECT Id, Name, Program_Plan__c, Term_Reference__c
                FROM hed__Term__c
                WHERE Program_Plan__c =: programPlanId
                AND Term_Status__c = 'Ongoing'
                LIMIT 1
            ];*/
            
            // Prepare fee records for update
            List<Fee_Installment__c> feesToUpdate = new List<Fee_Installment__c>();
            List<String> feeIds = new List<String>();

            // Drives Payment_Transaction__c.Payment_Type__c below: true once every fee
            // assignment touched by this payment has been cleared in full.
            Boolean allAssignmentsSettled = false;
            
            // Create a map to store payment amounts for each fee record
            Map<String, Decimal> feePaymentAmounts = new Map<String, Decimal>();
            Map<Id, Decimal> feeAssignmentUpdates = new Map<Id, Decimal>();
            
            for (Map<String, Object> feeData : updatedFeeRecords) {
                if (feeData.containsKey('id')) {
                    String feeId = (String)feeData.get('id');
                    feeIds.add(feeId);
                }
            }
            
            // Fetch current fee records to calculate payment differences
            Map<Id, Fee_Installment__c> currentFeeMap = new Map<Id, Fee_Installment__c>([
                SELECT Id, Fee_Amount__c, Total_Amount_Payable__c, Scholarship_Amount__c, Total_Paid_Amount__c, Paid_Amount__c, Remaining_Amount__c, Fee_Type__c, Fee_Type__r.Fee_Head__c, Fee_Assignment__c
                FROM Fee_Installment__c
                WHERE Id IN :feeIds
            ]);
            
            // Update fee records and calculate individual payment amounts
            for (Map<String, Object> feeData : updatedFeeRecords) {
                String feeId = (String)feeData.get('id');
                if (currentFeeMap.containsKey(feeId)) {
                    Fee_Installment__c currentFee = currentFeeMap.get(feeId);
                    Fee_Installment__c updatedFee = new Fee_Installment__c();
                    updatedFee.Id = feeId;
                    
                    Decimal newPaidAmount = (Decimal)feeData.get('totalPaidAmount');
                    Decimal safeNewPaidAmount = newPaidAmount == null ? 0 : newPaidAmount;
                    Decimal oldPaidAmount = currentFee.Paid_Amount__c != null ? currentFee.Paid_Amount__c : 0;
                    
                    // Calculate the payment made for this specific fee record
                    Decimal paymentForThisFee = safeNewPaidAmount - oldPaidAmount;
                    
                    Decimal totalPayable = currentFee.Total_Amount_Payable__c != null ? currentFee.Total_Amount_Payable__c : currentFee.Fee_Amount__c;
                    if (totalPayable == null) totalPayable = 0;
                    Decimal newRemainingAmount = totalPayable - safeNewPaidAmount;
                    if (newRemainingAmount < 0) newRemainingAmount = 0;
                    updatedFee.Remaining_Amount__c = newRemainingAmount;
                    updatedFee.Paid_Amount__c = safeNewPaidAmount;
                    updatedFee.Settlement_UTR__c = settlementUTR;
                    
                    if (currentFee.Fee_Assignment__c != null) {
                        feeAssignmentUpdates.put(currentFee.Fee_Assignment__c, newRemainingAmount);
                    }
                    
                    
                    feesToUpdate.add(updatedFee);
                    
                    // Store payment amount for this fee record if there's an actual payment
                    if (paymentForThisFee > 0) {
                        feePaymentAmounts.put(feeId, paymentForThisFee);
                    }
                }
            }
            
            // Update all fee records
            if (!feesToUpdate.isEmpty()) {
                update feesToUpdate;
                // Update corresponding Fee_Assignment__c records with new Remaining Amounts
                             if (!feeAssignmentUpdates.isEmpty()) {
                    // Recalculate each assignment from ALL of its installments (already updated above)
                    List<Fee_Assignment__c> feeAssignmentsToUpdate = new List<Fee_Assignment__c>();
                    Boolean settledSoFar = true;
                    for (AggregateResult ar : [
                        SELECT Fee_Assignment__c asgId, SUM(Paid_Amount__c) paidSum, SUM(Remaining_Amount__c) remSum
                        FROM Fee_Installment__c
                        WHERE Fee_Assignment__c IN :feeAssignmentUpdates.keySet()
                        GROUP BY Fee_Assignment__c
                    ]) {
                        Decimal paidSum = (Decimal) ar.get('paidSum');
                        Decimal remSum = (Decimal) ar.get('remSum');
                        Fee_Assignment__c assignment = new Fee_Assignment__c();
                        assignment.Id = (Id) ar.get('asgId');
                        assignment.Paid_Amount__c = paidSum == null ? 0 : paidSum;
                        assignment.Remaining_Amount__c = remSum == null ? 0 : remSum;
                        feeAssignmentsToUpdate.add(assignment);
                        if (assignment.Remaining_Amount__c > 0) {
                            settledSoFar = false;
                        }
                    }
                    allAssignmentsSettled = settledSoFar;
                    if (!feeAssignmentsToUpdate.isEmpty()) {
                        update feeAssignmentsToUpdate;
                    }
                }
                
            }
            
            // Create Receipt_and_Invoice__c records for each fee record that received payment
            List<Receipt_and_Invoice__c> paymentRecords = new List<Receipt_and_Invoice__c>();
            List<ContentVersion> contentVersions = new List<ContentVersion>();
            
            for (String feeId : feePaymentAmounts.keySet()) {
                Decimal individualPayment = feePaymentAmounts.get(feeId);
                
                Receipt_and_Invoice__c paymentRecord = new Receipt_and_Invoice__c();
                paymentRecord.Contact__c = affiliation.hed__Contact__c;
                paymentRecord.Payment_Method__c = paymentMethod;
                paymentRecord.Transaction_ID__c = transactionId;
                paymentRecord.CRM_Receipt_Number__c = crmReceiptNumber;
                paymentRecord.Amount__c = individualPayment;
                paymentRecord.Fee_Installment__c = feeId; // Link to specific fee assignment
                paymentRecord.Payment_Date__c = Date.valueOf(paymentDate);
                paymentRecord.Receipt_Number__c = generateAndIncrementReceiptNumber(affiliation.Roll_Number__c);
                
                paymentRecords.add(paymentRecord);
            }
            
            // Insert all payment records
            if (!paymentRecords.isEmpty()) {
                insert paymentRecords;
                
                paymentRecords = [
                    SELECT Id, Amount__c, Receipt_Number__c, Payment_Method__c, Payment_Date__c, 
                    Fee_Installment__r.Fee_Type__r.Fee_Head__c, Fee_Installment__r.Settlement_UTR__c,
                    Fee_Installment__c, Fee_Installment__r.Fee_Assignment__c, Fee_Installment__r.Fee_Assignment__r.Fee_Type__c,
                    Fee_Installment__r.Fee_Assignment__r.Fee_Type__r.Semester__c,
                    Fee_Installment__r.Fee_Assignment__r.Fee_Type__r.Semester__r.Term_Reference__c
                    FROM Receipt_and_Invoice__c
                    WHERE Id IN :paymentRecords
                ];
            }

            // ----------------------------------------------------------------------
            // Payment Transaction + Payment Transaction Line Items  (PKDSU-247)
            //
            // Raised for EVERY payment taken through this method, which covers both the
            // single Over-the-Counter receipt screen and each Bulk Fee Payment upload row
            // (the bulk flow calls this same method once per row). Initial and subsequent
            // partial payments therefore each get their own Payment Transaction.
            //
            // One Payment_Transaction__c carries the payment details; one
            // Payment_Transaction_Line_Item__c per Fee Installment that actually received
            // money carries the amount and received amount, and links back to both the
            // transaction and the installment.
            //
            // Fee_Applied__c is deliberately set to TRUE on insert. It is the ledger-posting
            // guard read by PaymentTransactionLineItemHandler (after update), which posts
            // Received_Amount__c onto the Fee Installment / Fee Assignment for line items
            // where it is false. This method has ALREADY posted those amounts directly
            // above, so leaving the flag false would double-count the payment as soon as
            // anything updated these rows - for example PaymentReceiptService stamping
            // Receipt__c onto sibling line items of the same transaction.
            // ----------------------------------------------------------------------
            if (!feePaymentAmounts.isEmpty()) {
                Map<Id, Id> receiptIdByInstallment = new Map<Id, Id>();
                for (Receipt_and_Invoice__c receipt : paymentRecords) {
                    if (receipt.Fee_Installment__c != null) {
                        receiptIdByInstallment.put(receipt.Fee_Installment__c, receipt.Id);
                    }
                }

                Payment_Transaction__c paymentTxn = new Payment_Transaction__c();
                paymentTxn.Contact__c = affiliation.hed__Contact__c;
                paymentTxn.Amount__c = paymentAmount;
                paymentTxn.Transaction_Id__c = transactionId;
                paymentTxn.Payment_Receipt_Number__c = crmReceiptNumber;
                // '1' is the success code the existing gateway pipeline uses; the
                // Payment_Status__c formula on the line items reads it from here.
                paymentTxn.Payment_Status__c = '1';
                paymentTxn.Payment_Type__c = allAssignmentsSettled ? 'Full' : 'Partial';
                paymentTxn.Transaction_Date__c = DateTime.newInstance(Date.valueOf(paymentDate), Time.newInstance(0, 0, 0, 0));
                // Payment_Mode__c is a restricted picklist - only set it when the chosen
                // option is a known value, so an unmapped option can never block a payment.
                if (paymentMethod != null && OTC_PAYMENT_MODES.contains(paymentMethod)) {
                    paymentTxn.Payment_Mode__c = paymentMethod;
                }
                paymentTxn.Remarks__c = 'Over the Counter payment. Payment Option: ' + paymentMethod
                    + (String.isBlank(settlementUTR) ? '' : '. Settlement UTR: ' + settlementUTR);
                // Receipt__c on the transaction points at the first receipt raised for this
                // payment; each line item below carries the receipt for its own installment.
                if (!paymentRecords.isEmpty()) {
                    paymentTxn.Receipt__c = paymentRecords[0].Id;
                }
                insert paymentTxn;

                List<Payment_Transaction_Line_Item__c> transactionLineItems = new List<Payment_Transaction_Line_Item__c>();
                for (String feeId : feePaymentAmounts.keySet()) {
                    Fee_Installment__c sourceInstallment = currentFeeMap.get(feeId);
                    Decimal receivedAmount = feePaymentAmounts.get(feeId);

                    Payment_Transaction_Line_Item__c lineItem = new Payment_Transaction_Line_Item__c();
                    lineItem.Payment_Transaction__c = paymentTxn.Id;
                    lineItem.Contact__c = affiliation.hed__Contact__c;
                    lineItem.Fee_Installment__c = feeId;
                    lineItem.Fee_Assignment__c = (sourceInstallment != null) ? sourceInstallment.Fee_Assignment__c : null;
                    lineItem.Amount__c = receivedAmount;
                    lineItem.Received_Amount__c = receivedAmount;
                    lineItem.Receipt__c = receiptIdByInstallment.get(feeId);
                    lineItem.Fee_Applied__c = true; // already posted above - see comment
                    transactionLineItems.add(lineItem);
                }

                if (!transactionLineItems.isEmpty()) {
                    insert transactionLineItems;
                }
            }

            // Generate PDFs and create ContentVersions for each payment record
            List<ContentDocumentLink> contentDocumentLinks = new List<ContentDocumentLink>();
            List<ContentDistribution> contentDistributions = new List<ContentDistribution>();
            
            Integer pageIndex = 0;
            for (Receipt_and_Invoice__c paymentRecord : paymentRecords) {
                for (PageReference pdfPage : new List<PageReference>{ Page.FeeReceipt, Page.FeeReceiptsFinance }) {
                    pdfPage.getParameters().put('StudentName', affiliation.hed__Contact__r.Name);
                    pdfPage.getParameters().put('ReceiptNo', paymentRecord.Receipt_Number__c);
                    pdfPage.getParameters().put('Particular', paymentRecord.Fee_Installment__r.Fee_Type__r.Fee_Head__c );
                    pdfPage.getParameters().put('settlementUtr', paymentRecord.Fee_Installment__r.Settlement_UTR__c );
                    Decimal amount = paymentRecord.Amount__c;
                    
                    pdfPage.getParameters().put('Amount', formatIndianNumber(amount));
                    pdfPage.getParameters().put('amountInWords', NumberToWordsConverter.convertNumberToWords(paymentRecord.Amount__c));
                    pdfPage.getParameters().put('ApplicationNo', affiliation.Individual_Application__r.External_Application_Number__c);
                    pdfPage.getParameters().put('FeePreference', affiliation.Individual_Application__r.Fee_Preference__c);
                    pdfPage.getParameters().put('StartingYear', affiliation.Program_Plan__r.Batch__c);
                    pdfPage.getParameters().put('USN', affiliation.Roll_Number__c);
                    pdfPage.getParameters().put('Program', affiliation.hed__Account__r.Name);
                    String formattedDate = DateTime.newInstance(Date.today(), Time.newInstance(0, 0, 0, 0)).format('dd/MM/yyyy');
                    pdfPage.getParameters().put('ReceiptDate', formattedDate);
                    
                    DateTime now = System.now();
                    String formattedDateTime = now.format('dd/MM/yyyy HH:mm'); // or 'HH:mm:ss' for seconds
                    pdfPage.getParameters().put('ReceiptDateTime', formattedDateTime);
                    String academicSession = getAcademicSessionFromIntakeName(affiliation.Program_Plan__r.Name);
                    pdfPage.getParameters().put('AcademicSession', academicSession);
                    
                    if(affiliation.Individual_Application__r.Fee_Preference__c == 'Semester-wise fee'){
                        pdfPage.getParameters().put('Semester', paymentRecord.Fee_Installment__r.Fee_Assignment__r.Fee_Type__r.Semester__r.Term_Reference__c);
                    }
                    else if(affiliation.Individual_Application__r.Fee_Preference__c == 'Year-wise fee'){
                        if (paymentRecord.Fee_Installment__r.Fee_Assignment__r.Fee_Type__r.Semester__r.Term_Reference__c == 'Term 1' || 
                           paymentRecord.Fee_Installment__r.Fee_Assignment__r.Fee_Type__r.Semester__r.Term_Reference__c == 'Semester 1'){
                            pdfPage.getParameters().put('Semester', '1 and 2');
                        }
                        if (paymentRecord.Fee_Installment__r.Fee_Assignment__r.Fee_Type__r.Semester__r.Term_Reference__c == 'Term 3' ||
                           paymentRecord.Fee_Installment__r.Fee_Assignment__r.Fee_Type__r.Semester__r.Term_Reference__c == 'Semester 3'){
                            pdfPage.getParameters().put('Semester', '3 and 4');
                        }
                        if (paymentRecord.Fee_Installment__r.Fee_Assignment__r.Fee_Type__r.Semester__r.Term_Reference__c == 'Term 5' ||
                           paymentRecord.Fee_Installment__r.Fee_Assignment__r.Fee_Type__r.Semester__r.Term_Reference__c == 'Semester 5'){
                            pdfPage.getParameters().put('Semester', '5 and 6');
                        }
                        if (paymentRecord.Fee_Installment__r.Fee_Assignment__r.Fee_Type__r.Semester__r.Term_Reference__c == 'Term 7' ||
                           paymentRecord.Fee_Installment__r.Fee_Assignment__r.Fee_Type__r.Semester__r.Term_Reference__c == 'Semester 7'){
                            pdfPage.getParameters().put('Semester', '7 and 8');
                        }
                        
                    }
                    else if(affiliation.Individual_Application__r.Fee_Preference__c == 'Total program fee'){
                        pdfPage.getParameters().put('Semester', 'All Semesters');
                    }
                    
                    String fullSemester = paymentRecord.Fee_Installment__r.Fee_Assignment__r.Fee_Type__r.Semester__r.Term_Reference__c; // 'Semester 1'
                    String onlyNumber = fullSemester.replaceAll('[^0-9]', ''); // '1'
                    pdfPage.getParameters().put('SemesterNumber', onlyNumber);
                    
                    
                    pdfPage.getParameters().put('PaymentMode', paymentRecord.Payment_Method__c);
                    String formattedPaymentDate = '';
                    if (!String.isBlank(paymentDate)) {
                        try {
                            Date parsedDate = Date.valueOf(paymentDate); // e.g., '2025-08-04'
                            DateTime dateNTime = DateTime.newInstance(parsedDate, Time.newInstance(0, 0, 0, 0));
                            formattedPaymentDate = dateNTime.format('dd/MM/yyyy'); // '04/08/2025'
                        } catch (Exception e) {
                            formattedPaymentDate = ''; // fallback
                        }
                    }
                    
                    pdfPage.getParameters().put('PaymentRefDate', formattedPaymentDate);
                    
                    pdfPage.getParameters().put('PaymentRefNo', transactionId);
                    
                    Blob pdfBlob;
                    try {
                        pdfBlob = pdfPage.getContentAsPDF();
                    } catch (Exception e) {
                        pdfBlob = Blob.valueOf('Test PDF Content');
                    }
                    
                    String prefix = (pageIndex == 0) ? 'FeeReceiptStudent' : 'FeeReceiptFinance';
                    System.debug('prefix '+ prefix);
                    
                    ContentVersion cv = new ContentVersion();
                    cv.Title = prefix + '_' + affiliation.hed__Contact__r.Name + '_' + paymentRecord.Id;
                    cv.PathOnClient = prefix + '_' + affiliation.hed__Contact__r.Name + '_' + paymentRecord.Id + '.pdf';
                    cv.VersionData = pdfBlob;
                    
                    
                    contentVersions.add(cv);
                    pageIndex++;
                }
            }
            
            // Insert both ContentVersions
            insert contentVersions;
            
            // Query back ContentDocumentIds
            Map<Id, ContentVersion> cvMap = new Map<Id, ContentVersion>([
                SELECT Id, ContentDocumentId, Title 
                FROM ContentVersion 
                WHERE Id IN :contentVersions
            ]);
            
            // Create ContentDocumentLinks and ContentDistributions
            Integer index = 0;
            for (Receipt_and_Invoice__c paymentRecord : paymentRecords) {
                for (Integer i = 0; i < 2; i++) { // two PDFs per record
                    if (index < contentVersions.size()) {
                        ContentVersion cv = contentVersions[index];
                        ContentVersion cvWithDocId = cvMap.get(cv.Id);
                        
                        // Create ContentDocumentLink
                        ContentDocumentLink cdl = new ContentDocumentLink();
                        cdl.ContentDocumentId = cvWithDocId.ContentDocumentId;
                        cdl.LinkedEntityId = paymentRecord.Id;
                        cdl.ShareType = 'V';
                        cdl.Visibility = 'AllUsers';
                        contentDocumentLinks.add(cdl);
                        
                        // Create ContentDistribution
                        ContentDistribution cd = new ContentDistribution(
                            Name = cv.Title,
                            ContentVersionId = cv.Id,
                            PreferencesAllowViewInBrowser = true
                        );
                        contentDistributions.add(cd);
                        
                        index++;
                    }
                }
            }
            
            // Insert links and distributions
            if (!contentDocumentLinks.isEmpty()) {
                insert contentDocumentLinks;
            }
            if (!contentDistributions.isEmpty()) {
                insert contentDistributions;
            }
            
            
            // Query back ContentDistributions to get public URLs and update payment records
            List<ContentDistribution> insertedDistributions = [
                SELECT Id, DistributionPublicUrl, Name 
                FROM ContentDistribution 
                WHERE Id IN :contentDistributions
            ];
            
            // Update payment records with Receipt URLs
            List<Receipt_and_Invoice__c> recordsToUpdate = new List<Receipt_and_Invoice__c>();
            String firstReceiptUrl = '';
            
            for (Integer i = 0; i < paymentRecords.size() && i < insertedDistributions.size(); i++) {
                Receipt_and_Invoice__c record = paymentRecords[i];
                record.Receipt_URL__c = insertedDistributions[i].DistributionPublicUrl;
                recordsToUpdate.add(record);
                
                // Store the first receipt URL to return
                if (i == 0) {
                    firstReceiptUrl = insertedDistributions[i].DistributionPublicUrl;
                }
            }
            
            if (!recordsToUpdate.isEmpty()) {
                update recordsToUpdate;
            }
            
            // Update Individual_Application__c record with payment details
            if (affiliation.Individual_Application__c != null) {
                Application__c applicationToUpdate = [
                    SELECT Id, Amount__c, Transaction_ID__c, Transaction_Date__c, CRM_Receipt_Number__c, Payment_Method__c
                    FROM Application__c
                    WHERE Id = :affiliation.Individual_Application__c
                    LIMIT 1
                ];
                
                applicationToUpdate.Amount__c = paymentAmount;
                applicationToUpdate.Transaction_ID__c = transactionId;
                applicationToUpdate.Transaction_Date__c = Date.valueOf(paymentDate);
                applicationToUpdate.CRM_Receipt_Number__c = crmReceiptNumber;
                applicationToUpdate.Payment_Method__c = paymentMethod;
                
                update applicationToUpdate;
            }
            
            // Return success message and PDF URL
            Map<String, Object> result = new Map<String, Object>();
            result.put('message', 'Payment of ₹' + paymentAmount + ' processed successfully for ' + feesToUpdate.size() + 
                       ' fee record(s). Created ' + paymentRecords.size() + ' receipt record(s).');
            result.put('pdfUrl', firstReceiptUrl);
            result.put('success', true);
            
            return result;
            
        } catch (DmlException e) {
            System.debug('DML Exception in payment processing: ' + e.getMessage() + e.getLineNumber());
            throw new AuraHandledException('Error updating fee records: ' + e.getMessage() + e.getLineNumber());
        } catch (Exception e) {
            System.debug('Exception in payment processing: ' + e.getMessage() + e.getLineNumber());
            throw new AuraHandledException('Error processing payment: ' + e.getMessage() + e.getLineNumber());
        }
    }
    
    @AuraEnabled(cacheable=false)
    public static String getLatestReceiptUrl(String usnNumber) {
        try {
            if (String.isBlank(usnNumber)) {
                throw new AuraHandledException('USN number is required');
            }
            
            // Fetch the affiliation
            List<hed__Affiliation__c> affiliations = [
                SELECT Id, hed__Contact__c
                FROM hed__Affiliation__c
                WHERE Roll_Number__c = :usnNumber.trim()
                LIMIT 1
            ];
            
            if (affiliations.isEmpty()) {
                throw new AuraHandledException('Student not found');
            }
            
            // Get the latest receipt record for this contact
            List<Receipt_and_Invoice__c> latestReceipts = [
                SELECT Id, Receipt_URL__c, CreatedDate
                FROM Receipt_and_Invoice__c
                WHERE Contact__c = :affiliations[0].hed__Contact__c
                AND Receipt_URL__c != null
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            
            if (!latestReceipts.isEmpty() && String.isNotBlank(latestReceipts[0].Receipt_URL__c)) {
                return latestReceipts[0].Receipt_URL__c;
            }
            
            return null;
            
        } catch (Exception e) {
            System.debug('Exception in getLatestReceiptUrl: ' + e.getMessage());
            throw new AuraHandledException('Error fetching receipt URL: ' + e.getMessage());
        }
    }
    
    public static String generateAndIncrementReceiptNumber(String rollNumber) {
        if (String.isBlank(rollNumber) || rollNumber.length() < 7) {
            throw new AuraHandledException('Invalid Roll Number provided.');
        }
        
        // Fetch FeeServices__c setting
        Map<String, FeeServices__c> settings = FeeServices__c.getAll();
        FeeServices__c settingToUpdate = settings.get('Receipt Runner');
        
        if (settingToUpdate == null || String.isBlank(settingToUpdate.Receipt_Number__c)) {
            throw new AuraHandledException('Receipt Runner setting is missing or improperly configured.');
        }
        
        // Extract year (2 characters after 5 letters)
        String yearPart = rollNumber.substring(5, 7); // positions 5,6
        
        // Parse and increment sequence number
        String currentReceiptNumber = settingToUpdate.Receipt_Number__c; // e.g., DSU/CDOE/Year/0001
        List<String> parts = currentReceiptNumber.split('/');
        
        if (parts.size() != 4) {
            throw new AuraHandledException('Invalid Receipt_Number__c format in Receipt Runner setting.');
        }
        
        String prefix1 = parts[0]; // DSU
        String prefix2 = parts[1]; // CDOE
        String sequenceStr = parts[3]; // 0001
        
        Integer sequenceNum;
        try {
            sequenceNum = Integer.valueOf(sequenceStr);
        } catch (Exception e) {
            throw new AuraHandledException('Invalid sequence number format in Receipt Runner setting.');
        }
        
        // Format padded sequence
        String paddedSequence = String.valueOf(sequenceNum).leftPad(4, '0');
        String newReceipt = prefix1 + '/' + prefix2 + '/' + yearPart + '/' + paddedSequence;
        
        // Increment sequence number for updating
        sequenceNum++;
        String newPaddedSequence = String.valueOf(sequenceNum).leftPad(4, '0');
        String newSettingValue = prefix1 + '/' + prefix2 + '/' + yearPart + '/' + newPaddedSequence;
        
        settingToUpdate.Receipt_Number__c = newSettingValue;
        update settingToUpdate;
        
        return newReceipt;
    }
    
    public static String getAcademicSessionFromIntakeName(String intakeName) {
        if (String.isBlank(intakeName)) {
            return '';
        }
        
        List<String> parts = intakeName.split('-');
        if (parts.size() < 2) {
            return '';
        }
        
        String month = parts[1].trim().toUpperCase();
        
        Map<String, String> monthToSession = new Map<String, String>{
            'JAN' => 'DEC-JAN',
                'FEB' => 'JAN-FEB',
                'MAR' => 'FEB-MAR',
                'APR' => 'MAR-APR',
                'MAY' => 'APR-MAY',
                'JUN' => 'MAY-JUN',
                'JUL' => 'JUN-JUL',
                'AUG' => 'JUL-AUG',
                'SEP' => 'AUG-SEP',
                'OCT' => 'SEP-OCT',
                'NOV' => 'OCT-NOV',
                'DEC' => 'NOV-DEC'
                };
                    
                    if (monthToSession.containsKey(month)) {
                        return monthToSession.get(month);
                    } else {
                        return month; // fallback for unrecognized months
                    }
    }
    
    @AuraEnabled
    public static String checkDuplicate(String fieldName, String value, Long cacheKey) {
        if (String.isBlank(value)) {
            return null;
        }
        
        Boolean exists = false;
        
        switch on fieldName {
            when 'Transaction_ID__c' {
                exists = [SELECT Id FROM Receipt_and_Invoice__c WHERE Transaction_ID__c = :value LIMIT 1].size() > 0;
            }
            when 'CRM_Receipt_Number__c' {
                exists = [SELECT Id FROM Receipt_and_Invoice__c WHERE CRM_Receipt_Number__c = :value LIMIT 1].size() > 0;
            }
            when 'Settlement_UTR__c' {
                exists = [SELECT Id FROM Fee_Installment__c WHERE Settlement_UTR__c = :value LIMIT 1].size() > 0;
            }
            when else {
                throw new AuraHandledException('Invalid field name');
            }
        }
        
        return exists ? 'Duplicate value found for ' + fieldName : null;
    }

    /**
     * PKDSU-246 - duplicate check scoped to a fee assignment.
     *
     * The blanket checkDuplicate above rejects a reference the moment it exists anywhere, which
     * blocks a legitimate second part payment: a student paying 20,000 of a 30,000 assignment and
     * then the remaining 10,000 quotes the SAME Transaction ID, Settlement UTR and CRM Receipt
     * Number, because it is the same banking transaction. This variant ignores records that belong
     * to the fee assignment(s) being paid, so reuse is allowed there while the value is still
     * blocked from being used against a different fee assignment.
     *
     * A record that cannot be traced back to a fee assignment is treated as belonging to another
     * one, so an untraceable reference still counts as a duplicate.
     */
    @TestVisible
    private static String checkDuplicateOutsideAssignments(String fieldName, String value, Set<Id> allowedAssignmentIds) {
        if (String.isBlank(value)) {
            return null;
        }
        Set<Id> allowed = (allowedAssignmentIds == null) ? new Set<Id>() : allowedAssignmentIds;
        Boolean exists = false;

        switch on fieldName {
            when 'Transaction_ID__c' {
                for (Receipt_and_Invoice__c r : [
                    SELECT Id, Fee_Installment__r.Fee_Assignment__c
                    FROM Receipt_and_Invoice__c
                    WHERE Transaction_ID__c = :value
                ]) {
                    Id assignmentId = (r.Fee_Installment__r == null) ? null : r.Fee_Installment__r.Fee_Assignment__c;
                    if (assignmentId == null || !allowed.contains(assignmentId)) {
                        exists = true;
                        break;
                    }
                }
            }
            when 'CRM_Receipt_Number__c' {
                for (Receipt_and_Invoice__c r : [
                    SELECT Id, Fee_Installment__r.Fee_Assignment__c
                    FROM Receipt_and_Invoice__c
                    WHERE CRM_Receipt_Number__c = :value
                ]) {
                    Id assignmentId = (r.Fee_Installment__r == null) ? null : r.Fee_Installment__r.Fee_Assignment__c;
                    if (assignmentId == null || !allowed.contains(assignmentId)) {
                        exists = true;
                        break;
                    }
                }
            }
            when 'Settlement_UTR__c' {
                for (Fee_Installment__c fi : [
                    SELECT Id, Fee_Assignment__c
                    FROM Fee_Installment__c
                    WHERE Settlement_UTR__c = :value
                ]) {
                    if (fi.Fee_Assignment__c == null || !allowed.contains(fi.Fee_Assignment__c)) {
                        exists = true;
                        break;
                    }
                }
            }
            when else {
                throw new AuraHandledException('Invalid field name');
            }
        }

        return exists ? 'Duplicate value found for ' + fieldName + ' against a different fee assignment' : null;
    }
    
    public static String formatIndianNumber(Decimal num) {
        String s = String.valueOf(num.setScale(0)); // remove decimals
        String result = '';
        Integer len = s.length();
        
        if (len > 3) {
            result = s.substring(len - 3, len); // last 3 digits
            s = s.substring(0, len - 3);
            while (s.length() > 2) {
                result = s.substring(s.length() - 2, s.length()) + ',' + result;
                s = s.substring(0, s.length() - 2);
            }
            result = s + ',' + result;
        } else {
            result = s;
        }
        return result;
    }

        // ===================== BULK FEE PAYMENT HELPERS =====================
    private static final Set<String> BULK_ALLOWED_METHODS = new Set<String>{
        'Online', 'Cash', 'Credit Card', 'Debit Card', 'Cheque', 'RTGS', 'NEFT'
    };

    // Payment options offered by the Over-the-Counter screen and the Bulk Fee Payment
    // upload, every one of which is a valid Payment_Transaction__c.Payment_Mode__c value.
    // Payment_Mode__c is a RESTRICTED picklist: anything outside this set would throw
    // INVALID_OR_NULL_FOR_RESTRICTED_PICKLIST and fail the whole payment, so the field is
    // only populated when the option is known to be supported.
    private static final Set<String> OTC_PAYMENT_MODES = new Set<String>{
        'Online', 'Cash', 'Credit Card', 'Debit Card', 'Cheque', 'RTGS', 'NEFT'
    };

    private static Map<String, Object> bulkFail(String message) {
        return new Map<String, Object>{ 'success' => false, 'message' => message };
    }

    // Sorts installments by semester number, then due date (same order as the single-payment screen)
    private class InstallmentSortItem implements Comparable {
        public Fee_Installment__c record;
        public Integer semesterOrder;

        public InstallmentSortItem(Fee_Installment__c rec) {
            record = rec;
            semesterOrder = 999999;
            String term = (rec.Fee_Assignment__r != null
                && rec.Fee_Assignment__r.Fee_Type__r != null
                && rec.Fee_Assignment__r.Fee_Type__r.Semester__r != null)
                ? rec.Fee_Assignment__r.Fee_Type__r.Semester__r.Term_Reference__c : null;
            if (String.isNotBlank(term)) {
                Matcher m = Pattern.compile('(\\d+)').matcher(term);
                if (m.find()) {
                    semesterOrder = Integer.valueOf(m.group(1));
                }
            }
        }

        public Integer compareTo(Object other) {
            InstallmentSortItem o = (InstallmentSortItem) other;
            if (semesterOrder != o.semesterOrder) {
                return semesterOrder < o.semesterOrder ? -1 : 1;
            }
            Date a = record.Due_Date__c;
            Date b = o.record.Due_Date__c;
            if (a == b) return 0;
            if (a == null) return 1;
            if (b == null) return -1;
            return a < b ? -1 : 1;
        }
    }

        @AuraEnabled
    public static Map<String, Object> prepareBulkPaymentRow(
        String usnNumber, String feeAssignment, String paymentDate, String paymentMethod, Decimal paymentAmount,
        String transactionId, String crmReceiptNumber, String settlementUTR
    ) {
        try {
            String usn = String.isBlank(usnNumber) ? '' : usnNumber.trim();
            String txn = String.isBlank(transactionId) ? null : transactionId.trim();
            String crm = String.isBlank(crmReceiptNumber) ? null : crmReceiptNumber.trim();
            String utr = String.isBlank(settlementUTR) ? null : settlementUTR.trim();

            if (String.isBlank(usn)) {
                return bulkFail('USN is required.');
            }

            // Fee assignment(s) the student chose; several can be separated by ;
            Set<String> requestedAssignments = new Set<String>();
            if (String.isNotBlank(feeAssignment)) {
                for (String n : feeAssignment.split(';')) {
                    if (String.isNotBlank(n)) {
                        requestedAssignments.add(n.trim());
                    }
                }
            }
            if (requestedAssignments.isEmpty()) {
                return bulkFail('Fee Assignment is required.');
            }

            if (paymentAmount == null || paymentAmount <= 0) {
                return bulkFail('Payment amount must be greater than 0.');
            }
            if (paymentAmount.scale() > 2) {
                return bulkFail('Payment amount cannot have more than 2 decimal places.');
            }
            Date parsedDate;
            try {
                parsedDate = Date.valueOf(paymentDate);
            } catch (Exception e) {
                return bulkFail('Payment date must be in YYYY-MM-DD format.');
            }
            if (parsedDate > Date.today()) {
                return bulkFail('Payment date cannot be in the future.');
            }
            if (String.isBlank(paymentMethod) || !BULK_ALLOWED_METHODS.contains(paymentMethod)) {
                return bulkFail('Invalid payment option: ' + paymentMethod);
            }
           if (txn == null) {
    return bulkFail('Transaction ID is required.');
}
if (crm == null) {
    return bulkFail('CRM Receipt Number is required.');
}
if (utr == null) {
    return bulkFail('Settlement UTR is required.');
}

            // Student lookup (same basis as getStudentFeeDetails)
            List<hed__Affiliation__c> affiliations = [
                SELECT Id, Roll_Number__c, hed__Status__c,
                       Individual_Application__r.Transaction_ID__c,
                       Individual_Application__r.CRM_Receipt_Number__c,
                       Individual_Application__r.Transaction_Date__c
                FROM hed__Affiliation__c
                WHERE Roll_Number__c = :usn
                LIMIT 1
            ];
            if (affiliations.isEmpty()) {
                return bulkFail('No student found with USN: ' + usn);
            }
            hed__Affiliation__c aff = affiliations[0];

            // PKDSU-241: a withdrawn student must not have a receipt raised against them.
            if (ConstantsControllerClass.WITHDRAWN_STATUS.equalsIgnoreCase(aff.hed__Status__c)) {
                return bulkFail('Receipt generation is not allowed for withdrawn students.');
            }

            // Same rule as the single screen: must match the application's stored values when present
            String appTxn = aff.Individual_Application__r != null ? aff.Individual_Application__r.Transaction_ID__c : null;
            String appCrm = aff.Individual_Application__r != null ? aff.Individual_Application__r.CRM_Receipt_Number__c : null;
            Date appTxnDate = aff.Individual_Application__r != null ? aff.Individual_Application__r.Transaction_Date__c : null;
            // The Individual Application records ONE payment - the admission payment. Its
            // Transaction ID / CRM Receipt Number / Transaction Date describe that payment only.
            //
            // Requiring every row to quote them deadlocked against PKDSU-246: the application
            // reference can only ever sit on one fee assignment, so once it was banked the
            // student's every later row was rejected as a duplicate against a different
            // assignment, and no second fee assignment could be paid at all. PKDSU-240 pinned
            // the date the same way, fixing every later payment to the admission date.
            //
            // So these three checks now apply only while the application's payment has not been
            // receipted yet. Once it has, the admission payment is settled and a later payment
            // is a new banking transaction that brings its own references - which PKDSU-246 then
            // checks for reuse in the normal way.
            Boolean applicationPaymentAlreadyReceipted = false;
            if (String.isNotBlank(appTxn)) {
                String appTxnKey = appTxn.trim();
                applicationPaymentAlreadyReceipted = ![
                    SELECT Id FROM Receipt_and_Invoice__c WHERE Transaction_ID__c = :appTxnKey LIMIT 1
                ].isEmpty();
            }

            if (!applicationPaymentAlreadyReceipted) {
                // Must match the Individual Application's stored values. If those are empty, any value is accepted.
                if (String.isNotBlank(appTxn) && txn != appTxn.trim()) {
                    return bulkFail('Transaction ID does not match the Individual Application (expected: ' + appTxn.trim() + ').');
                }
                if (String.isNotBlank(appCrm) && crm != appCrm.trim()) {
                    return bulkFail('CRM Receipt Number does not match the Individual Application (expected: ' + appCrm.trim() + ').');
                }
                // PKDSU-240: the admission payment must be entered under the date the bank
                // recorded it, not the date someone happens to key it in.
                if (appTxnDate != null && String.isNotBlank(appTxn) && txn == appTxn.trim() && parsedDate != appTxnDate) {
                    return bulkFail('Payment date does not match the transaction date on the Individual Application (expected: '
                        + DateTime.newInstance(appTxnDate, Time.newInstance(0, 0, 0, 0)).format('dd/MM/yyyy') + ').');
                }
            }

            // PKDSU-242: whether an assignment exists, and whether it is already settled, is
            // read from the Fee Assignment itself - NOT from its Fee Installments.
            //
            // Assignments whose Fee_Preference__c is 'Semester-wise fee' carry no
            // Fee_Installment__c rows at all, while 'Total program fee' ones carry exactly one.
            // The previous lookup resolved the assignment through Fee_Installment__c, so every
            // semester-wise assignment came back as "Fee Assignment Not Found" - FA-0249
            // (unpaid, 20,000 outstanding) and FA-0318 (fully paid) both reported that way.
            // Paid_Amount__c / Remaining_Amount__c on Fee_Assignment__c are maintained directly,
            // so they are accurate whether or not installments exist.
            List<Fee_Assignment__c> requestedRecords = [
                SELECT Id, Name, Remaining_Amount__c
                FROM Fee_Assignment__c
                WHERE Affiliation__c = :aff.Id
                  AND Name IN :requestedAssignments
            ];

            Set<String> existingNames = new Set<String>();
            Set<String> namesWithBalance = new Set<String>();
            Set<Id> requestedAssignmentIds = new Set<Id>();
            for (Fee_Assignment__c fa : requestedRecords) {
                if (fa.Name == null) continue;
                String nameKey = fa.Name.toLowerCase();
                existingNames.add(nameKey);
                requestedAssignmentIds.add(fa.Id);
                if (fa.Remaining_Amount__c != null && fa.Remaining_Amount__c > 0) {
                    namesWithBalance.add(nameKey);
                }
            }

            List<String> notFound = new List<String>();
            List<String> fullyPaid = new List<String>();
            for (String n : requestedAssignments) {
                String nameKey = n.toLowerCase();
                if (!existingNames.contains(nameKey)) {
                    notFound.add(n);
                } else if (!namesWithBalance.contains(nameKey)) {
                    fullyPaid.add(n);
                }
            }
            if (!notFound.isEmpty()) {
                return bulkFail('Fee Assignment Not Found: ' + String.join(notFound, ', '));
            }
            if (!fullyPaid.isEmpty()) {
                return bulkFail('Already Fully Paid: ' + String.join(fullyPaid, ', '));
            }

            // PKDSU-246: the same Transaction ID / CRM Receipt Number / Settlement UTR may be
            // reused for a later part payment against the SAME fee assignment. These checks run
            // after the assignment is resolved so they can exclude it, while still blocking the
            // value from being reused against a different fee assignment.
            String dup = checkDuplicateOutsideAssignments('Transaction_ID__c', txn, requestedAssignmentIds);
            if (dup != null) return bulkFail(dup);
            dup = checkDuplicateOutsideAssignments('CRM_Receipt_Number__c', crm, requestedAssignmentIds);
            if (dup != null) return bulkFail(dup);
            dup = checkDuplicateOutsideAssignments('Settlement_UTR__c', utr, requestedAssignmentIds);
            if (dup != null) return bulkFail(dup);

            // Only the installments that still carry a balance take part in the allocation
            List<Fee_Installment__c> installments = [
                SELECT Id, Total_Amount_Payable__c, Paid_Amount__c, Remaining_Amount__c, Due_Date__c,
                       Fee_Assignment__c, Fee_Assignment__r.Name,
                       Fee_Assignment__r.Fee_Type__r.Semester__r.Term_Reference__c
                FROM Fee_Installment__c
                WHERE Affiliation__c = :aff.Id
                  AND Fee_Assignment__c IN :requestedAssignmentIds
                  AND Remaining_Amount__c > 0
            ];

            // The assignment exists and still owes money, but carries no installment to post the
            // payment against - the whole posting pipeline (receipt, line item, allocation) is
            // keyed on Fee_Installment__c. Reported plainly instead of as "not found", which is
            // what the old lookup did and what PKDSU-242 was raised about.
            if (installments.isEmpty()) {
                return bulkFail('Fee Assignment ' + String.join(new List<String>(requestedAssignments), ', ')
                    + ' has no open fee installment to post this payment against.');
            }

            List<InstallmentSortItem> items = new List<InstallmentSortItem>();
            Decimal totalRemaining = 0;
            for (Fee_Installment__c fi : installments) {
                items.add(new InstallmentSortItem(fi));
                totalRemaining += (fi.Remaining_Amount__c == null ? 0 : fi.Remaining_Amount__c);
            }
            if (paymentAmount > totalRemaining) {
                return bulkFail('Payment amount ' + paymentAmount + ' exceeds the remaining amount ' + totalRemaining + ' of the selected fee assignment(s).');
            }
            items.sort();

            // Allocate oldest first (semester, then due date) within the chosen assignment(s)
            Decimal left = paymentAmount;
            List<Map<String, Object>> updatedFeeRecords = new List<Map<String, Object>>();
            for (InstallmentSortItem item : items) {
                if (left <= 0) break;
                Decimal remaining = item.record.Remaining_Amount__c == null ? 0 : item.record.Remaining_Amount__c;
                Decimal paid = item.record.Paid_Amount__c == null ? 0 : item.record.Paid_Amount__c;
                Decimal pay = left < remaining ? left : remaining;
                if (pay <= 0) continue;
                updatedFeeRecords.add(new Map<String, Object>{
                    'id' => String.valueOf(item.record.Id),
                    'totalPaidAmount' => (paid + pay).setScale(2),
                    'remainingAmount' => (remaining - pay).setScale(2)
                });
                left -= pay;
            }

            Map<String, Object> result = new Map<String, Object>();
            result.put('success', true);
            result.put('usnNumber', aff.Roll_Number__c);
            result.put('updatedFeeRecords', updatedFeeRecords);
            result.put('message', 'Allocated across ' + updatedFeeRecords.size() + ' installment(s).');
            return result;

        } catch (Exception e) {
            return bulkFail('Validation error: ' + e.getMessage());
        }
    }
    
    
}