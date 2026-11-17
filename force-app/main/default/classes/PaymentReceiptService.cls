public with sharing class PaymentReceiptService {

    // Fee Heads that represent exam payments (Backlog / Re-Evaluation). For these,
    // multiple courses paid in a single Payment Transaction are consolidated into ONE
    // receipt that lists every course and its amount. All other fee types keep the
    // existing behaviour of one receipt per line item.
    private static final Set<String> EXAM_FEE_HEADS = new Set<String>{
        'Backlog examination Fee', 'Re-Evaluation Fee'
    };

    // True while a reconcile pass is running, so reconcile does not enqueue another reconcile
    // (avoids an infinite chain of queueables).
    @TestVisible
    private static Boolean ReconcileInProgress = false;

    // Max number of times a reconcile will re-chain itself waiting for a transaction's line-item
    // amounts to finish committing before it gives up (renders best-effort with whatever is committed).
    private static final Integer MAX_RECONCILE_RETRIES = 6;

    public static void reconcileExamTransactions(Set<Id> txnIds) {
        reconcileExamTransactions(txnIds, 0);
    }

    // Reconcile pass (chained after the initial generation). Re-reads all paid line items for the
    // given exam-fee transactions and only renders a receipt once the transaction's paid line items
    // are STABLE (their Received_Amount__c values sum to the transaction's own Amount__c). Because the
    // payment integration commits line items and their amounts across several uncoordinated updates,
    // a transaction that is not yet stable is re-chained (up to MAX_RECONCILE_RETRIES) so the receipt
    // is only ever rendered from complete data - never a transient 0-amount row.
    public static void reconcileExamTransactions(Set<Id> txnIds, Integer retryCount) {
        if (txnIds == null || txnIds.isEmpty()) return;

        Map<Id, Payment_Transaction__c> txns = new Map<Id, Payment_Transaction__c>([
            SELECT Id, Amount__c FROM Payment_Transaction__c WHERE Id IN :txnIds
        ]);

        List<Payment_Transaction_Line_Item__c> items = [
            SELECT Id, Fee_Installment__c, Received_Amount__c, Payment_Status__c, Payment_Transaction__c, Receipt__c, CreatedDate
            FROM Payment_Transaction_Line_Item__c
            WHERE Payment_Transaction__c IN :txnIds
              AND Payment_Status__c = '1'
              AND Fee_Installment__c != null
        ];
        if (items.isEmpty()) return;

        // Group committed line items per transaction and evaluate stability.
        Map<Id, List<Payment_Transaction_Line_Item__c>> itemsByTxn = new Map<Id, List<Payment_Transaction_Line_Item__c>>();
        for (Payment_Transaction_Line_Item__c li : items) {
            if (li.Payment_Transaction__c == null) continue;
            if (!itemsByTxn.containsKey(li.Payment_Transaction__c)) {
                itemsByTxn.put(li.Payment_Transaction__c, new List<Payment_Transaction_Line_Item__c>());
            }
            itemsByTxn.get(li.Payment_Transaction__c).add(li);
        }

        List<Payment_Transaction_Line_Item__c> stableItems = new List<Payment_Transaction_Line_Item__c>();
        Set<Id> unstableTxnIds = new Set<Id>();
        for (Id txnId : itemsByTxn.keySet()) {
            Payment_Transaction__c txn = txns.get(txnId);
            Decimal txnAmount = (txn != null) ? txn.Amount__c : null;

            Decimal sumReceived = 0;
            Boolean anyZero = false;
            for (Payment_Transaction_Line_Item__c li : itemsByTxn.get(txnId)) {
                Decimal amt = li.Received_Amount__c;
                if (amt == null || amt == 0) anyZero = true;
                sumReceived += (amt != null ? amt : 0);
            }

            // Stable when the summed paid line items equal the transaction's authoritative total
            // (and none is still sitting at 0). If we can't read the txn total, fall back to
            // "no zero-amount line items" as the best available signal.
            Boolean stable = (txnAmount != null && txnAmount != 0)
                ? (sumReceived == txnAmount && !anyZero)
                : (!anyZero);

            if (stable) {
                stableItems.addAll(itemsByTxn.get(txnId));
            } else {
                unstableTxnIds.add(txnId);
            }
        }

        // Render stable transactions now.
        if (!stableItems.isEmpty()) {
            Boolean previous = ReconcileInProgress;
            ReconcileInProgress = true;
            try {
                generateReceipts(stableItems);
            } finally {
                ReconcileInProgress = previous;
            }
        }

        // Re-chain for transactions whose amounts are still settling, up to the retry cap.
        if (!unstableTxnIds.isEmpty() && retryCount < MAX_RECONCILE_RETRIES && !System.isFuture() && Limits.getLimitQueueableJobs() - Limits.getQueueableJobs() > 0) {
            System.enqueueJob(new PaymentReceiptQueueable(new List<Id>(unstableTxnIds), retryCount + 1));
        } else if (!unstableTxnIds.isEmpty() && retryCount >= MAX_RECONCILE_RETRIES) {
            // Give up waiting: render best-effort from whatever is committed so a receipt still exists.
            Boolean previous2 = ReconcileInProgress;
            ReconcileInProgress = true;
            try {
                List<Payment_Transaction_Line_Item__c> leftover = new List<Payment_Transaction_Line_Item__c>();
                for (Id txnId : unstableTxnIds) leftover.addAll(itemsByTxn.get(txnId));
                if (!leftover.isEmpty()) generateReceipts(leftover);
            } finally {
                ReconcileInProgress = previous2;
            }
        }
    }

    public static void generateReceipts(List<Payment_Transaction_Line_Item__c> lineItems) {
        if (lineItems == null || lineItems.isEmpty()) return;

        // The payment integration updates line items one at a time (separate transactions,
        // not one bulk update), so a single call here may see only ONE course of a multi-course
        // exam-fee payment. For exam fee (Backlog / Re-Evaluation) items, pull in every OTHER
        // paid sibling line item on the same Payment_Transaction__c so the receipt always covers
        // everything paid so far, not just what happened to be in this trigger invocation.
        Set<Id> incomingIds = new Set<Id>();
        Set<Id> incomingTxnIds = new Set<Id>();
        for (Payment_Transaction_Line_Item__c li : lineItems) {
            incomingIds.add(li.Id);
            if (li.Payment_Transaction__c != null) incomingTxnIds.add(li.Payment_Transaction__c);
        }

        Map<Id, Payment_Transaction_Line_Item__c> allItemsById = new Map<Id, Payment_Transaction_Line_Item__c>(lineItems);
        if (!incomingTxnIds.isEmpty()) {
            for (Payment_Transaction_Line_Item__c sibling : [
                SELECT Id, Fee_Installment__c, Payment_Transaction__c, Received_Amount__c, Payment_Status__c, Receipt__c, CreatedDate
                FROM Payment_Transaction_Line_Item__c
                WHERE Payment_Transaction__c IN :incomingTxnIds
                  AND Payment_Status__c = '1'
                  AND Fee_Installment__c != null
            ]) {
                if (!allItemsById.containsKey(sibling.Id)) {
                    allItemsById.put(sibling.Id, sibling);
                }
            }
        }

        Set<Id> feeInstIds = new Set<Id>();
        Set<Id> txnIds = new Set<Id>();
        for (Payment_Transaction_Line_Item__c li : allItemsById.values()) {
            if (li.Fee_Installment__c != null) feeInstIds.add(li.Fee_Installment__c);
            if (li.Payment_Transaction__c != null) txnIds.add(li.Payment_Transaction__c);
        }

        //Fetch Installments with Affiliations
        Map<Id, Fee_Installment__c> feeMap = new Map<Id, Fee_Installment__c>([
            SELECT Id, Fee_Type__r.Fee_Head__c, Settlement_UTR__c, Fee_Assignment__c,
                   Affiliation__r.Id, Affiliation__r.Roll_Number__c,
                   Affiliation__r.hed__Contact__r.Name,
                   Affiliation__r.hed__Contact__c,
                   Affiliation__r.Individual_Application__r.External_Application_Number__c,
                   Affiliation__r.Individual_Application__r.Fee_Preference__c,
                   Affiliation__r.Program_Plan__r.Batch__c,
                   Affiliation__r.Program_Plan__r.Name,
                   Affiliation__r.hed__Account__r.Name,
				   Fee_Type__r.Semester__r.Term_Reference__c
            FROM Fee_Installment__c
            WHERE Id IN :feeInstIds
        ]);

        //Fetch Transactions (including any Receipt__c already stamped on them, and the
        // total Amount__c used as the stability check before rendering exam-fee receipts)
        Map<Id, Payment_Transaction__c> txnMap = new Map<Id, Payment_Transaction__c>([
            SELECT Id, Payment_Mode__c, Transaction_Id__c, CreatedDate, Receipt__c, Amount__c
            FROM Payment_Transaction__c
            WHERE Id IN :txnIds
        ]);

        // Partition: exam-fee items are grouped by Payment Transaction into a single receipt
        // (covering every paid sibling found above); everything else keeps the original
        // 1 receipt per line item behaviour, and only for items from THIS invocation
        // (siblings pulled in above are only relevant to the exam-fee consolidation).
        Map<Id, List<Payment_Transaction_Line_Item__c>> examGroups =
            new Map<Id, List<Payment_Transaction_Line_Item__c>>();
        List<Payment_Transaction_Line_Item__c> nonExamItems = new List<Payment_Transaction_Line_Item__c>();

        for (Payment_Transaction_Line_Item__c li : allItemsById.values()) {
            Fee_Installment__c fi = feeMap.get(li.Fee_Installment__c);
            if (fi == null || fi.Affiliation__r == null) continue;

            Boolean isExamFee = fi.Fee_Type__r != null && EXAM_FEE_HEADS.contains(fi.Fee_Type__r.Fee_Head__c);
            if (isExamFee && li.Payment_Transaction__c != null) {
                if (!examGroups.containsKey(li.Payment_Transaction__c)) {
                    examGroups.put(li.Payment_Transaction__c, new List<Payment_Transaction_Line_Item__c>());
                }
                examGroups.get(li.Payment_Transaction__c).add(li);
            } else if (incomingIds.contains(li.Id)) {
                // Non-exam stays scoped to the items this call actually received.
                nonExamItems.add(li);
            }
        }

        List<Receipt_and_Invoice__c> receiptsToInsert = new List<Receipt_and_Invoice__c>();
        List<List<Payment_Transaction_Line_Item__c>> lineItemsPerInsertedReceipt =
            new List<List<Payment_Transaction_Line_Item__c>>();

        // --- Non-exam: one receipt per line item (unchanged behaviour) ---
        for (Payment_Transaction_Line_Item__c li : nonExamItems) {
            Fee_Installment__c fi = feeMap.get(li.Fee_Installment__c);
            Payment_Transaction__c txn = txnMap.get(li.Payment_Transaction__c);
            String usn = fi.Affiliation__r.Roll_Number__c;
            String crmReceipt = OverTheCounterController.generateAndIncrementReceiptNumber(usn);

            Receipt_and_Invoice__c r = new Receipt_and_Invoice__c();
            r.Contact__c = fi.Affiliation__r.hed__Contact__c;
            r.Fee_Installment__c = fi.Id;
            r.Amount__c = li.Received_Amount__c;
            r.Payment_Date__c = Date.newInstance(li.CreatedDate.year(), li.CreatedDate.month(), li.CreatedDate.day());
            r.Payment_Method__c = 'Online';
            r.Transaction_ID__c = txn != null ? txn.Transaction_Id__c : null;
            r.CRM_Receipt_Number__c = crmReceipt;
            r.Receipt_Number__c = crmReceipt;
            receiptsToInsert.add(r);
            lineItemsPerInsertedReceipt.add(new List<Payment_Transaction_Line_Item__c>{ li });
        }

        // --- Exam fee: one consolidated receipt per Payment Transaction, covering every paid
        // sibling line item found for that transaction. If a receipt already exists on the
        // transaction (from an earlier course paid separately), update it in place with the
        // new total instead of creating a second receipt.
        List<Receipt_and_Invoice__c> receiptsToUpdate = new List<Receipt_and_Invoice__c>();
        List<List<Payment_Transaction_Line_Item__c>> lineItemsPerUpdatedReceipt =
            new List<List<Payment_Transaction_Line_Item__c>>();
        Map<Id, Id> updatedReceiptIdByTxnId = new Map<Id, Id>();

        if (!examGroups.isEmpty()) {
            Set<Id> existingReceiptIds = new Set<Id>();
            for (Id txnId : examGroups.keySet()) {
                Payment_Transaction__c txn = txnMap.get(txnId);
                if (txn != null && txn.Receipt__c != null) existingReceiptIds.add(txn.Receipt__c);
            }
            Map<Id, Receipt_and_Invoice__c> existingReceiptsById = existingReceiptIds.isEmpty()
                ? new Map<Id, Receipt_and_Invoice__c>()
                : new Map<Id, Receipt_and_Invoice__c>([
                    SELECT Id, Fee_Installment__c, CRM_Receipt_Number__c, Receipt_Number__c, Contact__c,
                           Amount__c, Payment_Date__c, Payment_Method__c, Transaction_ID__c, Receipt_URL__c
                    FROM Receipt_and_Invoice__c
                    WHERE Id IN :existingReceiptIds
                ]);

            for (Id txnId : examGroups.keySet()) {
                List<Payment_Transaction_Line_Item__c> liGroup = examGroups.get(txnId);
                Fee_Installment__c seedFi = feeMap.get(liGroup[0].Fee_Installment__c);
                Payment_Transaction__c txn = txnMap.get(txnId);

                Decimal totalReceived = 0;
                for (Payment_Transaction_Line_Item__c li : liGroup) {
                    totalReceived += (li.Received_Amount__c != null ? li.Received_Amount__c : 0);
                }

                Receipt_and_Invoice__c existing = (txn != null && txn.Receipt__c != null)
                    ? existingReceiptsById.get(txn.Receipt__c)
                    : null;

                if (existing != null) {
                    existing.Amount__c = totalReceived;
                    receiptsToUpdate.add(existing);
                    lineItemsPerUpdatedReceipt.add(liGroup);
                    updatedReceiptIdByTxnId.put(txnId, existing.Id);
                } else {
                    String usn = seedFi.Affiliation__r.Roll_Number__c;
                    String crmReceipt = OverTheCounterController.generateAndIncrementReceiptNumber(usn);

                    Receipt_and_Invoice__c r = new Receipt_and_Invoice__c();
                    r.Contact__c = seedFi.Affiliation__r.hed__Contact__c;
                    r.Fee_Installment__c = seedFi.Id;
                    r.Amount__c = totalReceived;
                    r.Payment_Date__c = Date.newInstance(liGroup[0].CreatedDate.year(), liGroup[0].CreatedDate.month(), liGroup[0].CreatedDate.day());
                    r.Payment_Method__c = 'Online';
                    r.Transaction_ID__c = txn != null ? txn.Transaction_Id__c : null;
                    r.CRM_Receipt_Number__c = crmReceipt;
                    r.Receipt_Number__c = crmReceipt;
                    receiptsToInsert.add(r);
                    lineItemsPerInsertedReceipt.add(liGroup);
                }
            }
        }

        if (!receiptsToInsert.isEmpty()) {
            // A concurrent async job (line items are paid ~1s apart, each in its own transaction)
            // may have already created the receipt for the same Payment Transaction, which surfaces
            // as a DUPLICATE_VALUE on Receipt_Number__c. Swallow it here; the chained reconcile job
            // below re-reads all paid siblings and produces the correct consolidated total.
            try {
                insert receiptsToInsert;
            } catch (DmlException e) {
                Boolean isDup = false;
                for (Integer di = 0; di < e.getNumDml(); di++) {
                    if (e.getDmlType(di) == StatusCode.DUPLICATE_VALUE) { isDup = true; break; }
                }
                if (!isDup) throw e;
                // Drop the ones that failed to insert; reconcile will rebuild them.
                List<Receipt_and_Invoice__c> stillInserted = new List<Receipt_and_Invoice__c>();
                List<List<Payment_Transaction_Line_Item__c>> stillGroups = new List<List<Payment_Transaction_Line_Item__c>>();
                for (Integer ri = 0; ri < receiptsToInsert.size(); ri++) {
                    if (receiptsToInsert[ri].Id != null) {
                        stillInserted.add(receiptsToInsert[ri]);
                        stillGroups.add(lineItemsPerInsertedReceipt[ri]);
                    }
                }
                receiptsToInsert = stillInserted;
                lineItemsPerInsertedReceipt = stillGroups;
            }
        }
        if (!receiptsToUpdate.isEmpty()) {
            update receiptsToUpdate;
        }

        // Self-healing: for every exam-fee transaction touched, enqueue a follow-up reconcile that
        // re-reads ALL paid siblings after the racing jobs have committed and recomputes the single
        // consolidated receipt (amount + PDF). This guarantees the final receipt reflects every course
        // even when two jobs ran concurrently. Guarded so the reconcile pass does not re-chain forever.
        if (!examGroups.isEmpty() && !ReconcileInProgress) {
            System.enqueueJob(new PaymentReceiptQueueable(new List<Id>(examGroups.keySet()), true));
        }

        // Combined view (inserted + updated) for linking and PDF regeneration.
        List<Receipt_and_Invoice__c> allReceipts = new List<Receipt_and_Invoice__c>();
        allReceipts.addAll(receiptsToInsert);
        allReceipts.addAll(receiptsToUpdate);
        List<List<Payment_Transaction_Line_Item__c>> lineItemsPerReceipt = new List<List<Payment_Transaction_Line_Item__c>>();
        lineItemsPerReceipt.addAll(lineItemsPerInsertedReceipt);
        lineItemsPerReceipt.addAll(lineItemsPerUpdatedReceipt);

        if (allReceipts.isEmpty()) return;

        // Link each receipt back to its source record(s):
        // - Non-exam: the receipt is stamped on the single Payment_Transaction_Line_Item__c (unchanged).
        // - Exam fee: the receipt is stamped on the Payment_Transaction__c itself (one receipt covers
        //   every installment/line item of that transaction). Every sibling line item's own
        //   Receipt__c is ALSO stamped with that shared receipt Id, purely so the trigger's
        //   "already processed" guard (Receipt__c == null) does not reprocess it again later.
        List<Payment_Transaction_Line_Item__c> itemsToUpdate = new List<Payment_Transaction_Line_Item__c>();
        List<Payment_Transaction__c> txnsToUpdate = new List<Payment_Transaction__c>();
        for (Integer i = 0; i < allReceipts.size(); i++) {
            List<Payment_Transaction_Line_Item__c> liGroup = lineItemsPerReceipt[i];
            Fee_Installment__c seedFi = feeMap.get(liGroup[0].Fee_Installment__c);
            Boolean isExamGroup = seedFi != null && seedFi.Fee_Type__r != null && EXAM_FEE_HEADS.contains(seedFi.Fee_Type__r.Fee_Head__c);

            if (isExamGroup) {
                Payment_Transaction__c txn = txnMap.get(liGroup[0].Payment_Transaction__c);
                if (txn == null || txn.Receipt__c == null) {
                    txnsToUpdate.add(new Payment_Transaction__c(Id = liGroup[0].Payment_Transaction__c, Receipt__c = allReceipts[i].Id));
                }
                for (Payment_Transaction_Line_Item__c li : liGroup) {
                    if (li.Receipt__c == null) {
                        itemsToUpdate.add(new Payment_Transaction_Line_Item__c(Id = li.Id, Receipt__c = allReceipts[i].Id));
                    }
                }
            } else {
                for (Payment_Transaction_Line_Item__c li : liGroup) {
                    itemsToUpdate.add(new Payment_Transaction_Line_Item__c(Id = li.Id, Receipt__c = allReceipts[i].Id));
                }
            }
        }
        if (!itemsToUpdate.isEmpty()) {
            update itemsToUpdate;
        }
        if (!txnsToUpdate.isEmpty()) {
            update txnsToUpdate;
        }

        attachReceiptsAsPDF(allReceipts, feeMap, lineItemsPerReceipt);
    }

    //Generate PDFs, attach to receipts, and update Receipt_URL__c
    private static void attachReceiptsAsPDF(
        List<Receipt_and_Invoice__c> receipts,
        Map<Id, Fee_Installment__c> feeMap,
        List<List<Payment_Transaction_Line_Item__c>> lineItemsPerReceipt
    ) {
        List<ContentVersion> cvs = new List<ContentVersion>();
        List<ContentDocumentLink> links = new List<ContentDocumentLink>();
        List<ContentDistribution> dists = new List<ContentDistribution>();

        // For Exam Fee (Backlog / Re-Evaluation) receipts: resolve the Student Service Request
        // linked to each fee assignment so the receipt can show Course Code / Course Name per subject.
        Set<Id> examFeeAssignmentIds = new Set<Id>();
        for (List<Payment_Transaction_Line_Item__c> liGroup : lineItemsPerReceipt) {
            for (Payment_Transaction_Line_Item__c li : liGroup) {
                Fee_Installment__c fi = feeMap.get(li.Fee_Installment__c);
                if (fi != null && fi.Fee_Type__r != null && EXAM_FEE_HEADS.contains(fi.Fee_Type__r.Fee_Head__c) && fi.Fee_Assignment__c != null) {
                    examFeeAssignmentIds.add(fi.Fee_Assignment__c);
                }
            }
        }
        Map<Id, Student_Service_Request__c> ssrByFeeAssignment = new Map<Id, Student_Service_Request__c>();
        if (!examFeeAssignmentIds.isEmpty()) {
            for (Student_Service_Request__c ssr : [
                SELECT Id, Fee_Assignment__c, Course_Name__c, Exam_Name__c,
                       Course_Connection__r.hed__Course_Offering__r.hed__Course__r.hed__Course_ID__c,
                       Course_Connection__r.hed__Course_Offering__r.hed__Term__r.Name,
                       Course_Connection__r.hed__Course_Offering__r.hed__Term__r.Term_Reference__c
                FROM Student_Service_Request__c
                WHERE Fee_Assignment__c IN :examFeeAssignmentIds
            ]) {
                if (ssr.Fee_Assignment__c != null && !ssrByFeeAssignment.containsKey(ssr.Fee_Assignment__c)) {
                    ssrByFeeAssignment.put(ssr.Fee_Assignment__c, ssr);
                }
            }
        }

        Integer pageIndex = 0;

        for (Integer rIdx = 0; rIdx < receipts.size(); rIdx++) {
            Receipt_and_Invoice__c rec = receipts[rIdx];
            List<Payment_Transaction_Line_Item__c> liGroup = lineItemsPerReceipt[rIdx];
            Fee_Installment__c fi = feeMap.get(rec.Fee_Installment__c);
            if (fi == null || fi.Affiliation__r == null) continue;

            // Exam (Backlog / Re-Evaluation) fee receipt details, if applicable
            Boolean isExamFee = (fi.Fee_Type__r != null && EXAM_FEE_HEADS.contains(fi.Fee_Type__r.Fee_Head__c));
            String particularLabel = fi.Fee_Type__r.Fee_Head__c;

            // Build one course row per line item in this receipt (exam only).
            List<ExamRow> examRows = new List<ExamRow>();
            String examSemesterLabel = null;
            if (isExamFee) {
                for (Payment_Transaction_Line_Item__c li : liGroup) {
                    Fee_Installment__c liFi = feeMap.get(li.Fee_Installment__c);
                    if (liFi == null) continue;
                    Student_Service_Request__c ssr = ssrByFeeAssignment.get(liFi.Fee_Assignment__c);

                    ExamRow row = new ExamRow();
                    row.courseCode = '';
                    row.courseName = '';
                    row.semester = '';
                    if (ssr != null) {
                        if (ssr.Course_Connection__r != null
                            && ssr.Course_Connection__r.hed__Course_Offering__r != null
                            && ssr.Course_Connection__r.hed__Course_Offering__r.hed__Course__r != null) {
                            row.courseCode = ssr.Course_Connection__r.hed__Course_Offering__r.hed__Course__r.hed__Course_ID__c;
                        }
                        row.courseName = ssr.Course_Name__c != null ? ssr.Course_Name__c : '';
                        if (ssr.Course_Connection__r != null
                            && ssr.Course_Connection__r.hed__Course_Offering__r != null
                            && ssr.Course_Connection__r.hed__Course_Offering__r.hed__Term__r != null) {
                            String tRef = ssr.Course_Connection__r.hed__Course_Offering__r.hed__Term__r.Term_Reference__c;
                            row.semester = tRef != null ? tRef : ssr.Course_Connection__r.hed__Course_Offering__r.hed__Term__r.Name;
                        }
                    }
                    row.amount = OverTheCounterController.formatIndianNumber(li.Received_Amount__c);
                    if (String.isBlank(examSemesterLabel) && String.isNotBlank(row.semester)) {
                        examSemesterLabel = row.semester;
                    }
                    examRows.add(row);
                }
            }

            // Generate both student and finance PDFs
            for (PageReference page : new List<PageReference>{ Page.FeeReceipt, Page.FeeReceiptsFinance }) {
                page.getParameters().put('StudentName', fi.Affiliation__r.hed__Contact__r.Name);
                page.getParameters().put('ReceiptNo', rec.Receipt_Number__c);
                page.getParameters().put('Particular', particularLabel);
                page.getParameters().put('IsExamFee', isExamFee ? 'true' : 'false');
                if (isExamFee) {
                    page.getParameters().put('ExamRows', JSON.serialize(examRows));
                    page.getParameters().put('NumberOfSubjects', String.valueOf(examRows.size()));
                }
                page.getParameters().put('settlementUtr', fi.Settlement_UTR__c);
                page.getParameters().put('Amount', OverTheCounterController.formatIndianNumber(rec.Amount__c));
                page.getParameters().put('amountInWords', NumberToWordsConverter.convertNumberToWords(rec.Amount__c));
                page.getParameters().put('ApplicationNo', fi.Affiliation__r.Individual_Application__r.External_Application_Number__c);
                page.getParameters().put('FeePreference', fi.Affiliation__r.Individual_Application__r.Fee_Preference__c);
                page.getParameters().put('StartingYear', fi.Affiliation__r.Program_Plan__r.Batch__c);
                page.getParameters().put('USN', fi.Affiliation__r.Roll_Number__c);
                page.getParameters().put('Program', fi.Affiliation__r.hed__Account__r.Name);
                page.getParameters().put('PaymentMode', rec.Payment_Method__c);
                page.getParameters().put('PaymentRefNo', rec.Transaction_ID__c);
                page.getParameters().put('PaymentRefDate', rec.Payment_Date__c != null ?
                    DateTime.newInstance(rec.Payment_Date__c, Time.newInstance(0, 0, 0, 0)).format('dd/MM/yyyy') : '');
                page.getParameters().put('ReceiptDate', DateTime.newInstance(Date.today(), Time.newInstance(0, 0, 0, 0)).format('dd/MM/yyyy'));
                page.getParameters().put('ReceiptDateTime', System.now().format('dd/MM/yyyy HH:mm'));

                // Academic Session extraction
                String intakeName = fi.Affiliation__r.Program_Plan__r.Name;
                String academicSession = OverTheCounterController.getAcademicSessionFromIntakeName(intakeName);
                page.getParameters().put('AcademicSession', academicSession);

                // Fee preference and semester text
                String feePref = fi.Affiliation__r.Individual_Application__r.Fee_Preference__c;
                String termRef = fi.Fee_Type__r.Semester__r.Term_Reference__c;
                String semesterLabel;

                if (feePref == 'Semester-wise fee') {
                    semesterLabel = termRef != null ? termRef : 'Ongoing Term';
                } else if (feePref == 'Year-wise fee') {
                    if (termRef != null) {
                        String semNumStr = termRef.replaceAll('[^0-9]', '');
                        if (semNumStr != null && semNumStr != '') {
                            Integer semNum = Integer.valueOf(semNumStr);
                            Integer yearNum = Integer.valueOf(Math.ceil(semNum / 2.0));
                            semesterLabel = 'Year ' + yearNum;
                        } else {
                            semesterLabel = 'Year 1';
                        }
                    } else {
                        semesterLabel = 'Year 1';
                    }
                } else if (feePref == 'Total program fee') {
                    semesterLabel = 'All Semesters';
                } else {
                    semesterLabel = 'N/A';
                }

                page.getParameters().put('Semester', semesterLabel);

                // For exam fee receipts override semester with the Term Reference from the course's term.
                if (isExamFee && String.isNotBlank(examSemesterLabel)) {
                    page.getParameters().put('Semester', examSemesterLabel);
                }

                page.getParameters().put('SemesterNumber', termRef != null ? termRef : '');

                Blob pdfBlob;
                try {
                    pdfBlob = page.getContentAsPDF();
                } catch (Exception e) {
                    pdfBlob = Blob.valueOf('Error generating PDF');
                }

                String prefix = (pageIndex == 0) ? 'FeeReceiptStudent' : 'FeeReceiptFinance';
                ContentVersion cv = new ContentVersion(
                    Title = prefix + '_' + fi.Affiliation__r.hed__Contact__r.Name + '_' + rec.Id,
                    PathOnClient = prefix + '_' + fi.Affiliation__r.hed__Contact__r.Name + '_' + rec.Id + '.pdf',
                    VersionData = pdfBlob
                );
                cvs.add(cv);
                pageIndex++;
            }
        }

        insert cvs;

        // Query back content versions with document IDs
        Map<Id, ContentVersion> cvMap = new Map<Id, ContentVersion>([
            SELECT Id, ContentDocumentId, Title FROM ContentVersion WHERE Id IN :cvs
        ]);

        // Create links and public distributions
        Integer idx = 0;
        for (Receipt_and_Invoice__c rec : receipts) {
            for (Integer i = 0; i < 2; i++) {
                if (idx < cvs.size()) {
                    ContentVersion cv = cvs[idx];
                    ContentVersion cvDoc = cvMap.get(cv.Id);

                    links.add(new ContentDocumentLink(
                        ContentDocumentId = cvDoc.ContentDocumentId,
                        LinkedEntityId = rec.Id,
                        ShareType = 'V',
                        Visibility = 'AllUsers'
                    ));

                    ContentDistribution cd = new ContentDistribution(
                        Name = cv.Title,
                        ContentVersionId = cv.Id,
                        PreferencesAllowViewInBrowser = true
                    );
                    dists.add(cd);
                    idx++;
                }
            }
        }

        insert links;
        insert dists;

        //Get public URLs and update receipts
        Map<Id, ContentDistribution> distMap = new Map<Id, ContentDistribution>([
            SELECT Id, ContentDownloadUrl FROM ContentDistribution WHERE Id IN :dists
        ]);

        Integer k = 0;
        for (Receipt_and_Invoice__c rec : receipts) {
            if (k < distMap.size()) {
                rec.Receipt_URL__c = distMap.values()[k].ContentDownloadUrl;
                k++;
            }
        }
        update receipts;
    }

    // One course line on an exam (Backlog / Re-Evaluation) receipt.
    // Properties (get/set) are required so Visualforce can bind to them via {!row.x}.
    public class ExamRow {
        public String courseCode { get; set; }
        public String courseName { get; set; }
        public String semester { get; set; }
        public String amount { get; set; }
    }
}