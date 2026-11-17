import { LightningElement, track } from 'lwc';
import getStudentFeeDetails from '@salesforce/apex/OverTheCounterController.getStudentFeeDetails';
import updateFeeRecords from '@salesforce/apex/OverTheCounterController.updateFeeRecordsWithPdfUrl';
import getLatestReceiptUrl from '@salesforce/apex/OverTheCounterController.getLatestReceiptUrl';
import checkDuplicate from '@salesforce/apex/OverTheCounterController.checkDuplicate';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import FEE_TEMPLATE from '@salesforce/resourceUrl/Fee_Payment_Bulk_Template';
import prepareBulkPaymentRow from '@salesforce/apex/OverTheCounterController.prepareBulkPaymentRow';

const BULK_MAX_ROWS = 200;

export default class OverTheFeeCounter extends LightningElement {
    @track usnNumber = '';
       // Bulk Import properties
@track selectedCsvFile = null;
@track showBulkImport = false;
@track bulkProgress = '';
@track csvFileName = '';
@track bulkImportError = '';
@track isBulkImporting = false;

@track bulkRows = [];
@track bulkStage = 'select'; 
@track editingRowKey = '';
@track editDraft = {};
@track editError = '';// select | listed | validated | imported

    @track isLoading = false;
    @track errorMessage = '';
    @track studentData;
    @track hasFeeRecords = false;
    @track feeTableData = [];
    @track selectedRows = [];
    @track paymentDate = '';
    @track selectedPaymentOption = '';
    @track paymentAmount = '';
    @track originalFeeData = []; // Store original fee data
    @track hasPaymentChanges = false; // Track if there are payment changes
    @track isProcessingPayment = false; // Track payment processing state
    @track isPaymentAmountValid = true;

    // PDF Display properties
    @track showPdfViewer = false;
    @track pdfUrl = '';
    @track isPdfLoading = false;
    @track pdfError = false;

    // Add these properties to your class
    transactionId = '';
    crmReceiptNumber = '';
    settlementUTR = '';

    @track hasTransactionIdError = false;
    @track hasCrmReceiptError = false;
    @track hasSettlementUTRError = false;

    @track transactionIdError = '';
    @track crmReceiptNumberError = '';
    @track hasStudentDataValidationErrors = false;

    handleTransactionIdChange(event) {
        this.transactionId = event.target.value;
        this.checkForDuplicate(event, 'Transaction_ID__c', this.transactionId, 'transactionId');
        this.validateTransactionIdAgainstStudentData();
    }

    handleCrmReceiptNumberChange(event) {
        this.crmReceiptNumber = event.target.value;
        this.checkForDuplicate(event, 'CRM_Receipt_Number__c', this.crmReceiptNumber, 'crmReceiptNumber');
        this.validateCrmReceiptNumberAgainstStudentData();
    }

    handlesettlementUTRChange(event) {
        this.settlementUTR = event.target.value;
        this.checkForDuplicate(event, 'Settlement_UTR__c', this.settlementUTR, 'settlementUTR');
    }

    checkForDuplicate(event, fieldName, value, fieldType) {
        let inputCmp = event.target;

        if (!value || value.trim() === '') {
            // Clear error state when field is empty
            this.setValidationState(fieldType, false);
            inputCmp.setCustomValidity('');
            inputCmp.reportValidity();
            return;
        }

        const cacheKey = Date.now();
        console.log(cacheKey);

        checkDuplicate({ fieldName, value, cacheKey })
            .then(result => {
                if (result) {
                    inputCmp.setCustomValidity(result); // Show inline error
                    this.setValidationState(fieldType, true); // Set error state
                } else {
                    inputCmp.setCustomValidity(''); // Clear error
                    this.setValidationState(fieldType, false); // Clear error state
                }
                inputCmp.reportValidity();
            })
            .catch(error => {
                console.error('Error checking duplicate:', error);
                this.setValidationState(fieldType, false); // Clear error state on API error
            });
    }

    // Helper method to set validation states
    setValidationState(fieldType, hasError) {
        switch (fieldType) {
            case 'transactionId':
                this.hasTransactionIdError = hasError;
                break;
            case 'crmReceiptNumber':
                this.hasCrmReceiptError = hasError;
                break;
            case 'settlementUTR':
                this.hasSettlementUTRError = hasError;
                break;
        }
    }

    // Validate Transaction ID against student data
    validateTransactionIdAgainstStudentData() {
        if (this.transactionId && this.studentData && this.studentData.transactionId) {
            if (this.transactionId !== this.studentData.transactionId) {
                this.transactionIdError = 'Transaction ID does not match the expected value.';
            } else {
                this.transactionIdError = '';
            }
        } else {
            this.transactionIdError = '';
        }
        this.updateStudentDataValidationState();
    }

    // Validate CRM Receipt Number against student data
    validateCrmReceiptNumberAgainstStudentData() {
        if (this.crmReceiptNumber && this.studentData && this.studentData.crmReceiptNumber) {
            if (this.crmReceiptNumber !== this.studentData.crmReceiptNumber) {
                this.crmReceiptNumberError = 'CRM Receipt Number does not match the expected value.';
            } else {
                this.crmReceiptNumberError = '';
            }
        } else {
            this.crmReceiptNumberError = '';
        }
        this.updateStudentDataValidationState();
    }

    // Update overall validation state
    updateStudentDataValidationState() {
        this.hasStudentDataValidationErrors = !!(this.transactionIdError || this.crmReceiptNumberError);
    }


    // Getter to check if there are any duplicate validation errors
    get hasDuplicateErrors() {
        return this.hasTransactionIdError || this.hasCrmReceiptError || this.hasSettlementUTRError || this.hasStudentDataValidationErrors;
    }


    // Payment options for the combobox
    paymentOptions = [
        { label: 'Online', value: 'Online' },
        { label: 'Cash', value: 'Cash' },
        { label: 'Credit Card', value: 'Credit Card' },
        { label: 'Debit Card', value: 'Debit Card' },
        { label: 'Cheque', value: 'Cheque' },
        { label: 'RTGS', value: 'RTGS' },
        { label: 'NEFT', value: 'NEFT' }
    ];
    @track sortedBy;
    @track sortedDirection;

    @track isPaymentFieldsDisabled = false;
    @track showPaymentCompleteMessage = false;
    @track dynamicFeeTableColumns = [];
    termLabelPattern = /(semester|term)\s*(\d+)/i;

    // Define columns for the datatable - REMOVED Paid Amount column
    feeTableColumns = [
        {
            label: 'Fee Amount',
            fieldName: 'feeAmount',
            type: 'currency',
            sortable: true,
            cellAttributes: { alignment: 'left' },
            typeAttributes: {
                currencyCode: 'INR',
                currencyDisplayAs: 'symbol'
            }
        },
        {
            label: 'Total Paid Amount',
            fieldName: 'totalPaidAmount',
            type: 'currency',
            sortable: true,
            cellAttributes: { alignment: 'left' },
            typeAttributes: {
                currencyCode: 'INR',
                currencyDisplayAs: 'symbol'
            }
        },
        {
            label: 'Remaining Amount',
            fieldName: 'remainingAmount',
            type: 'currency',
            sortable: true,
            cellAttributes: { alignment: 'left' },
            typeAttributes: {
                currencyCode: 'INR',
                currencyDisplayAs: 'symbol'
            }
        },
        {
            label: 'Due Date',
            fieldName: 'formattedDueDate',
            type: 'text',
            sortable: true,
            cellAttributes: { alignment: 'left' }
        }
    ];

    // Getter for enhanced PDF URL with parameters to prevent caching
    get enhancedPdfUrl() {
        if (!this.pdfUrl) return '';

        // Add timestamp and other parameters to prevent caching issues
        const separator = this.pdfUrl.includes('?') ? '&' : '?';
        return `${this.pdfUrl}${separator}timestamp=${new Date().getTime()}&viewer=iframe`;
    }

    // Getter for selected rows count
    get selectedRowsCount() {
        return this.selectedRows ? this.selectedRows.length : 0;
    }

    // Getter to check if there are selected rows
    get hasSelectedRows() {
        return this.selectedRowsCount > 0;
    }

    handleChange(event) {
        this.usnNumber = event.target.value;
    }
handleBulkImport() {
    this.showBulkImport = true;
}

handleDownloadSample() {
    const link = document.createElement('a');
    link.href = FEE_TEMPLATE;
    link.download = 'Fee_Payment_Bulk_Template.csv';
    link.target = '_blank';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
}

resetBulkRows() {
    this.bulkRows = [];
    this.bulkStage = 'select';
    this.bulkImportError = '';
    this.bulkProgress = '';
    this.editingRowKey = '';
    this.editDraft = {};
    this.editError = '';
}

handleCloseBulkImport() {
    if (this.isBulkImporting) {
        return;
    }
    this.showBulkImport = false;
    this.selectedCsvFile = null;
    this.csvFileName = '';
    this.resetBulkRows();
}

// Change File: clears the current file and shows the file picker again
handleChangeFile() {
    if (this.isBulkImporting) {
        return;
    }
    this.selectedCsvFile = null;
    this.csvFileName = '';
    this.resetBulkRows();
}

get showFileInput() {
    return !this.csvFileName;
}

get hasBulkRows() {
    return this.bulkRows.length > 0;
}

countStatus(status) {
    return this.bulkRows.filter(r => r.status === status).length;
}

get bulkPendingCount() { return this.countStatus('Pending'); }
get bulkPassedCount() { return this.countStatus('Passed'); }
get bulkSuccessCount() { return this.countStatus('Success'); }
get bulkFailedCount() { return this.countStatus('Failed'); }

get bulkSummary() {
    return `${this.bulkRows.length} record(s): ${this.bulkPendingCount} pending, ` +
        `${this.bulkPassedCount} passed validation, ${this.bulkSuccessCount} imported, ${this.bulkFailedCount} failed`;
}

get isValidateDisabled() {
    return this.isBulkImporting || !!this.editingRowKey || this.bulkStage !== 'listed' || this.bulkPendingCount === 0;
}

get isImportDisabled() {
    return this.isBulkImporting || !!this.editingRowKey || this.bulkStage !== 'validated' || this.bulkPassedCount === 0;
}

get isImportDisabled() {
    return this.isBulkImporting || this.bulkStage !== 'validated' || this.bulkPassedCount === 0;
}

readFileAsText(file) {
    return new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = () => resolve(String(reader.result || ''));
        reader.onerror = () => reject(new Error('Unable to read the file.'));
        reader.readAsText(file);
    });
}

getBulkErrorMessage(error, fallback) {
    return (error && error.body && error.body.message) || (error && error.message) || fallback;
}

withStatus(row, status, message, extra = {}) {
    const cls = {
        Pending: 'slds-text-color_weak',
        Passed: 'slds-text-color_success',
        Success: 'slds-text-color_success',
        Failed: 'slds-text-color_error'
    };
    return { ...row, status, message, statusClass: cls[status], ...extra };
}

// ---------- Edit a failed row ----------
get displayRows() {
    return this.bulkRows.map(r => ({
        ...r,
        canEdit: r.status === 'Failed' && !this.isBulkImporting
    }));
}

get isEditingRow() {
    return !!this.editingRowKey;
}

get editingRow() {
    return this.bulkRows.find(r => r.key === this.editingRowKey);
}

get editTitle() {
    const row = this.editingRow;
    return row ? `Edit row ${row.rowNumber} (USN ${row.usn})` : '';
}

handleEditRow(event) {
    const key = event.currentTarget.dataset.key;
    const row = this.bulkRows.find(r => r.key === key);
    if (!row || row.status !== 'Failed' || this.isBulkImporting) {
        return;
    }
    this.editingRowKey = key;
    this.editError = '';
    this.editDraft = {
        feeAssignment: row.feeAssignment || '',
        paymentDate: row.paymentDate || '',
        paymentOption: row.paymentOption || '',
        paymentAmount: row.paymentAmount == null ? '' : String(row.paymentAmount),
        transactionId: row.transactionId || '',
        crmReceiptNumber: row.crmReceiptNumber || '',
        settlementUTR: row.settlementUTR || ''
    };
}

handleEditFieldChange(event) {
    const field = event.target.dataset.field;
    if (!field) {
        return;
    }
    this.editDraft = { ...this.editDraft, [field]: event.detail.value };
}

handleCancelEdit() {
    this.editingRowKey = '';
    this.editDraft = {};
    this.editError = '';
}

// Same CSV-level rules as parseBulkCsv, applied to one edited row
validateEditDraft(rec) {
    const errs = [];
    const required = [
        ['feeAssignment', 'Fee_Assignment'], ['paymentDate', 'Payment_Date'],
        ['paymentOption', 'Payment_Option'], ['paymentAmount', 'Payment_Amount'],
        ['transactionId', 'Transaction_ID'], ['crmReceiptNumber', 'CRM_Receipt_Number'],
        ['settlementUTR', 'Settlement_UTR']
    ];
    // PKDSU-242: one message naming every missing field, not one message per field.
    const missingFields = required.filter(([prop]) => !rec[prop]).map(([, label]) => label);
    if (missingFields.length > 0) {
        errs.push(`Required field(s) missing: ${missingFields.join(', ')}.`);
    }

    const now = new Date();
    const today = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;
    const date = rec.paymentDate ? this.normalizeDate(rec.paymentDate) : null;
    if (rec.paymentDate && !date) {
        errs.push('Payment_Date must be a real date as DD/MM/YYYY, DD-MM-YYYY or YYYY-MM-DD.');
    } else if (date && date > today) {
        errs.push('Payment_Date cannot be in the future.');
    }

    const validOptions = this.paymentOptions.map(o => o.value);
    if (rec.paymentOption && !validOptions.includes(rec.paymentOption)) {
        errs.push(`Payment_Option must be one of ${validOptions.join(', ')}.`);
    }

    const amount = Number(String(rec.paymentAmount).replace(/,/g, ''));
    if (rec.paymentAmount && (!Number.isFinite(amount) || amount <= 0)) {
        errs.push('Payment_Amount must be a number greater than 0.');
    } else if (rec.paymentAmount && Math.abs(amount * 100 - Math.round(amount * 100)) > 1e-6) {
        errs.push('Payment_Amount cannot have more than 2 decimal places.');
    }

    // Duplicates inside this file (other rows only)
    const others = this.bulkRows.filter(r => r.key !== this.editingRowKey);
    [['transactionId', 'Transaction_ID'], ['crmReceiptNumber', 'CRM_Receipt_Number'],
        ['settlementUTR', 'Settlement_UTR']].forEach(([prop, label]) => {
        if (rec[prop] && others.some(o => o[prop] === rec[prop])) {
            errs.push(`${label} is repeated in this file.`);
        }
    });

    return { errs, date, amount };
}

handleSaveEdit() {
    const rec = {};
    Object.keys(this.editDraft).forEach(k => {
        rec[k] = String(this.editDraft[k] == null ? '' : this.editDraft[k]).trim();
    });
    const { errs, date, amount } = this.validateEditDraft(rec);
    if (errs.length > 0) {
        // PKDSU-242: show one problem at a time in the edit modal too.
        this.editError = errs[0];
        return;
    }
    this.bulkRows = this.bulkRows.map(r => (r.key === this.editingRowKey
        ? this.withStatus({
            ...r,
            feeAssignment: rec.feeAssignment,
            paymentDate: date,
            paymentOption: rec.paymentOption,
            paymentAmount: amount,
            transactionId: rec.transactionId,
            crmReceiptNumber: rec.crmReceiptNumber,
            settlementUTR: rec.settlementUTR,
            receiptUrl: ''
        }, 'Pending', 'Edited. Not validated yet.')
        : r));
    this.editingRowKey = '';
    this.editDraft = {};
    this.editError = '';
    this.bulkStage = 'listed'; // re-enables Validate
    this.showToast('Row updated', 'Click Validate to re-check the edited row.', 'success');
}

// Step 1: select a file and list ALL records (valid and invalid)
async handleFileChange(event) {
    const files = event.target.files;
    this.resetBulkRows();
    if (!files || files.length === 0) {
        return;
    }
    const file = files[0];
    if (!file.name.toLowerCase().endsWith('.csv')) {
        this.showToast('Error', 'Please upload a CSV file.', 'error');
        event.target.value = null;
        return;
    }
    this.selectedCsvFile = file;
    this.csvFileName = file.name;
    try {
        const text = await this.readFileAsText(file);
        const { rows, fileErrors } = this.parseBulkCsv(text);
        if (fileErrors.length > 0) {
            this.bulkImportError = fileErrors.join('\n');
            return;
        }
        this.bulkRows = rows;
        this.bulkStage = 'listed';
    } catch (error) {
        this.bulkImportError = this.getBulkErrorMessage(error, 'Unable to read the file.');
    }
}

callPrepare(row) {
    return prepareBulkPaymentRow({
        usnNumber: row.usn,
        feeAssignment: row.feeAssignment,
        paymentDate: row.paymentDate,
        paymentMethod: row.paymentOption,
        paymentAmount: row.paymentAmount,
        transactionId: row.transactionId,
        crmReceiptNumber: row.crmReceiptNumber,
        settlementUTR: row.settlementUTR
    });
}

// Step 2: Validate. Server-side checks only, nothing is saved.
async handleBulkValidate() {
    if (this.isValidateDisabled) {
        return;
    }
    this.isBulkImporting = true;
    this.bulkImportError = '';
    const rows = [...this.bulkRows];
    try {
        for (let i = 0; i < rows.length; i++) {
            if (rows[i].status !== 'Pending') {
                continue;
            }
            this.bulkProgress = `Validating row ${rows[i].rowNumber} of ${rows.length}...`;
            try {
                // eslint-disable-next-line no-await-in-loop
                const prep = await this.callPrepare(rows[i]);
                rows[i] = prep.success
                    ? this.withStatus(rows[i], 'Passed', 'Validation passed. Ready to import.')
                    : this.withStatus(rows[i], 'Failed', prep.message);
            } catch (error) {
                rows[i] = this.withStatus(rows[i], 'Failed', this.getBulkErrorMessage(error, 'Validation failed.'));
            }
            this.bulkRows = [...rows];
        }
        this.bulkStage = 'validated';
        const passed = rows.filter(r => r.status === 'Passed').length;
        const failed = rows.filter(r => r.status === 'Failed').length;
        this.showToast('Validation complete', `${passed} passed, ${failed} failed.`,
            failed === 0 ? 'success' : 'warning');
    } finally {
        this.isBulkImporting = false;
        this.bulkProgress = '';
    }
}

// Step 3: Import only the rows that passed validation
async handleBulkProcess() {
    if (this.isImportDisabled) {
        return;
    }
    this.isBulkImporting = true;
    this.bulkImportError = '';
    const rows = [...this.bulkRows];
    try {
        for (let i = 0; i < rows.length; i++) {
            if (rows[i].status !== 'Passed') {
                continue;
            }
            this.bulkProgress = `Importing row ${rows[i].rowNumber} of ${rows.length}...`;
            // Rows run one at a time: each is its own transaction and duplicate checks stay accurate.
            // eslint-disable-next-line no-await-in-loop
            rows[i] = await this.processBulkRow(rows[i]);
            this.bulkRows = [...rows];
        }
        this.bulkStage = 'imported';
        const ok = rows.filter(r => r.status === 'Success').length;
        const failed = rows.filter(r => r.status === 'Failed').length;
        this.showToast(
            failed === 0 ? 'Success' : 'Import completed with errors',
            `${ok} imported, ${failed} failed or skipped.`,
            failed === 0 ? 'success' : (ok === 0 ? 'error' : 'warning')
        );
    } finally {
        this.isBulkImporting = false;
        this.bulkProgress = '';
    }
}

async processBulkRow(row) {
    try {
        // Re-check just before saving, because earlier rows may have changed balances
        const prep = await this.callPrepare(row);
        if (!prep.success) {
            return this.withStatus(row, 'Failed', prep.message);
        }
        const res = await updateFeeRecords({
            usnNumber: prep.usnNumber,
            updatedFeeRecords: prep.updatedFeeRecords,
            paymentDate: row.paymentDate,
            paymentMethod: row.paymentOption,
            paymentAmount: row.paymentAmount,
            transactionId: row.transactionId,
            crmReceiptNumber: row.crmReceiptNumber,
            settlementUTR: row.settlementUTR
        });
        if (res && res.success) {
            return this.withStatus(row, 'Success', res.message, { receiptUrl: res.pdfUrl || '' });
        }
        return this.withStatus(row, 'Failed', (res && res.message) || 'Payment was not processed.');
    } catch (error) {
        return this.withStatus(row, 'Failed', this.getBulkErrorMessage(error, 'Unexpected error while processing this row.'));
    }
}

handleDownloadResults() {
    if (!this.bulkRows || this.bulkRows.length === 0) {
        this.showToast('Warning', 'There are no results to download.', 'warning');
        return;
    }
    try {
        const esc = (v) => `"${String(v == null ? '' : v).replace(/"/g, '""')}"`;
        const header = ['Row', 'USN', 'Fee_Assignment', 'Payment_Date', 'Payment_Option', 'Payment_Amount',
            'Transaction_ID', 'CRM_Receipt_Number', 'Settlement_UTR', 'Status', 'Details', 'Receipt_URL'];
        const lines = [header.join(',')];
        this.bulkRows.forEach(r => {
            lines.push([
                r.rowNumber, r.usn, r.feeAssignment, r.paymentDate, r.paymentOption, r.paymentAmount,
                r.transactionId, r.crmReceiptNumber, r.settlementUTR, r.status, r.message, r.receiptUrl
            ].map(esc).join(','));
        });
        // BOM makes Excel read the file as UTF-8 (messages contain the rupee symbol)
        const csv = '\uFEFF' + lines.join('\r\n');
        const stamp = new Date().toISOString().slice(0, 19).replace(/[:T]/g, '-');

        const link = document.createElement('a');
        link.href = 'data:text/csv;charset=utf-8,' + encodeURIComponent(csv);
        link.download = `Bulk_Fee_Payment_Results_${stamp}.csv`;
        link.style.display = 'none';
        link.click();
    } catch (error) {
        console.error('Download results failed:', error);
        this.showToast('Error', 'Unable to download the results file.', 'error');
    }
}

parseCsvText(text) {
    const rows = [];
    let row = [];
    let cell = '';
    let inQuotes = false;
    const clean = text.replace(/^\uFEFF/, '');
    for (let i = 0; i < clean.length; i++) {
        const ch = clean[i];
        if (inQuotes) {
            if (ch === '"' && clean[i + 1] === '"') { cell += '"'; i++; }
            else if (ch === '"') { inQuotes = false; }
            else { cell += ch; }
        } else if (ch === '"') {
            inQuotes = true;
        } else if (ch === ',') {
            row.push(cell); cell = '';
        } else if (ch === '\n' || ch === '\r') {
            if (ch === '\r' && clean[i + 1] === '\n') i++;
            row.push(cell); cell = '';
            if (row.some(c => c.trim() !== '')) rows.push(row);
            row = [];
        } else {
            cell += ch;
        }
    }
    row.push(cell);
    if (row.some(c => c.trim() !== '')) rows.push(row);
    return rows;
}

// Accepts YYYY-MM-DD, DD/MM/YYYY and DD-MM-YYYY (day first). Returns YYYY-MM-DD or null.
normalizeDate(value) {
    const v = String(value || '').trim();
    let y;
    let m;
    let d;
    let match = v.match(/^(\d{4})-(\d{1,2})-(\d{1,2})$/);
    if (match) {
        y = Number(match[1]); m = Number(match[2]); d = Number(match[3]);
    } else {
        match = v.match(/^(\d{1,2})[/-](\d{1,2})[/-](\d{4})$/);
        if (!match) {
            return null;
        }
        d = Number(match[1]); m = Number(match[2]); y = Number(match[3]);
    }
    const dt = new Date(Date.UTC(y, m - 1, d));
    if (dt.getUTCFullYear() !== y || dt.getUTCMonth() !== m - 1 || dt.getUTCDate() !== d) {
        return null;
    }
    return `${y}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
}

// File-level problems go in fileErrors. Row-level problems stay on the row so ALL records are listed.
parseBulkCsv(text) {
    const expected = ['USN', 'Fee_Assignment', 'Payment_Date', 'Payment_Option', 'Payment_Amount',
        'Transaction_ID', 'CRM_Receipt_Number', 'Settlement_UTR'];
    const table = this.parseCsvText(text);

    if (table.length < 2) {
        return { rows: [], fileErrors: ['The file has no data rows.'] };
    }

    // The template ships with instruction lines above the header, which users are told to
    // delete before uploading. Find the header row instead of assuming it is the first one,
    // so a file that still carries those lines is read correctly rather than rejected with
    // a misleading "Missing required column(s)".
    const headerIndex = table.findIndex(
        r => expected.every(h => r.map(c => c.trim()).includes(h))
    );
    if (headerIndex === -1) {
        const firstRow = table[0].map(h => h.trim());
        const missing = expected.filter(h => !firstRow.includes(h));
        return { rows: [], fileErrors: [`Missing required column(s): ${missing.join(', ')}`] };
    }

    const dataRowCount = table.length - headerIndex - 1;
    if (dataRowCount < 1) {
        return { rows: [], fileErrors: ['The file has no data rows.'] };
    }
    if (dataRowCount > BULK_MAX_ROWS) {
        return { rows: [], fileErrors: [`The file has ${dataRowCount} rows. The maximum is ${BULK_MAX_ROWS} per upload.`] };
    }
    const headers = table[headerIndex].map(h => h.trim());

    const validOptions = this.paymentOptions.map(o => o.value);
    const now = new Date();
    const today = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;
    // PKDSU-246: the same Transaction ID / CRM Receipt / Settlement UTR may be reused for
    // several part payments against the SAME fee assignment, so in-file duplicates are only
    // flagged when the reference is reused against a DIFFERENT fee assignment.
    const seen = { Transaction_ID: new Map(), CRM_Receipt_Number: new Map(), Settlement_UTR: new Map() };
    const rows = [];

    for (let i = headerIndex + 1; i < table.length; i++) {
        const line = i + 1;
        const rec = {};
        headers.forEach((h, idx) => { rec[h] = (table[i][idx] || '').trim(); });
        const errs = [];

        // Mandatory fields. PKDSU-242: reported as one message naming every missing field
        // rather than one message per field, so the row never shows a pile of sentences.
        const missingFields = expected.filter(h => !rec[h]);
        if (missingFields.length > 0) {
            errs.push(`Required field(s) missing: ${missingFields.join(', ')}.`);
        }

        const date = rec.Payment_Date ? this.normalizeDate(rec.Payment_Date) : null;
        if (rec.Payment_Date && !date) {
            errs.push('Payment_Date must be a real date as DD/MM/YYYY, DD-MM-YYYY or YYYY-MM-DD.');
        } else if (date && date > today) {
            errs.push('Payment_Date cannot be in the future.');
        }
        if (rec.Payment_Option && !validOptions.includes(rec.Payment_Option)) {
            errs.push(`Payment_Option must be one of ${validOptions.join(', ')}.`);
        }
        const amount = Number(String(rec.Payment_Amount).replace(/,/g, ''));
        if (rec.Payment_Amount && (!Number.isFinite(amount) || amount <= 0)) {
            errs.push('Payment_Amount must be a number greater than 0.');
        } else if (rec.Payment_Amount && Math.round(amount * 100) !== amount * 100 && Math.abs(amount * 100 - Math.round(amount * 100)) > 1e-6) {
            errs.push('Payment_Amount cannot have more than 2 decimal places.');
        }
        // Reusing a reference is allowed for part payments against the same fee assignment,
        // but not across two different fee assignments.
        const assignmentKey = `${rec.USN || ''}|${rec.Fee_Assignment || ''}`;
        Object.keys(seen).forEach(h => {
            if (rec[h]) {
                const firstSeenAgainst = seen[h].get(rec[h]);
                if (firstSeenAgainst !== undefined && firstSeenAgainst !== assignmentKey) {
                    errs.push(`${h} is already used for a different fee assignment in this file.`);
                } else if (firstSeenAgainst === undefined) {
                    seen[h].set(rec[h], assignmentKey);
                }
            }
        });

        const base = {
            key: `row-${line}`,
            rowNumber: line,
            usn: rec.USN,
            feeAssignment: rec.Fee_Assignment,
            paymentDate: date || rec.Payment_Date,
            paymentOption: rec.Payment_Option,
            paymentAmount: Number.isFinite(amount) ? amount : null,
            transactionId: rec.Transaction_ID,
            crmReceiptNumber: rec.CRM_Receipt_Number,
            settlementUTR: rec.Settlement_UTR,
            receiptUrl: ''
        };
        // PKDSU-242: show one message at a time. Several sentences joined together were the
        // "multiple messages displayed together" the ticket reports; the row reports the first
        // problem, and the next one surfaces once that is fixed and the file is re-validated.
        rows.push(errs.length > 0
            ? this.withStatus(base, 'Failed', errs[0])
            : this.withStatus(base, 'Pending', 'Not validated yet.'));
    }
    return { rows, fileErrors: [] };
}


    handleSearch() {
        if (!this.usnNumber || this.usnNumber.trim() === '') {
            this.showToast('Error', 'Please enter a USN number', 'error');
            return;
        }

        this.errorMessage = '';
        this.isLoading = true;
        this.studentData = null;
        this.feeTableData = [];
        this.selectedRows = [];
        // Reset PDF viewer when searching for new student

        // Clear validation errors when searching for new student
        this.transactionIdError = '';
        this.crmReceiptNumberError = '';
        this.hasStudentDataValidationErrors = false;  

        this.closePdfViewer();

        getStudentFeeDetails({ usnNumber: this.usnNumber.trim() })
            .then(result => {
                this.studentData = result;

                if (this.transactionId) {
                    this.validateTransactionIdAgainstStudentData();
                }
                if (this.crmReceiptNumber) {
                    this.validateCrmReceiptNumberAgainstStudentData();
                }
                
                this.hasFeeRecords = result.feeAssignmentInstallments && result.feeAssignmentInstallments.length > 0;

                if (this.hasFeeRecords) {
                    // Prepare data for datatable
                    this.feeTableData = result.feeAssignmentInstallments.map(fee => {
                        return {
                            id: fee.id,
                            feeAmount: fee.feeAmount || 0,
                            totalPaidAmount: fee.totalPaidAmount || 0,
                            remainingAmount: fee.remainingAmount || 0,
                            formattedDueDate: fee.formattedDueDate || '',
                            termReference: fee.termReference || '',
                            semesterOrder: this.getSemesterOrder(fee.termReference),
                            // Keep original fee data for processing
                            originalFee: fee
                        };
                    });

                    this.feeTableData = this.sortFeeDataBySemester(this.feeTableData);

                    // Store original data for comparison
                    this.originalFeeData = JSON.parse(JSON.stringify(this.feeTableData));

                    // Check payment status and set UI state
                    this.checkPaymentStatus();
                } else {
                    // No fee records - disable payment fields
                    this.isPaymentFieldsDisabled = true;
                    this.showPaymentCompleteMessage = false;
                    this.dynamicFeeTableColumns = [...this.feeTableColumns];
                }

                this.isLoading = false;

                if (this.hasFeeRecords) {
                    this.showToast('Success', 'Student fee details loaded successfully', 'success');
                }

                // Set default payment date to today
                this.paymentDate = new Date().toISOString().split('T')[0];
            })
            .catch(error => {
                console.error('Error fetching student data:', error);
                this.errorMessage = error.body && error.body.message ?
                    error.body.message : 'Error occurred while fetching data';
                this.isLoading = false;
                this.showToast('Error', this.errorMessage, 'error');

                // Reset UI state on error
                this.isPaymentFieldsDisabled = false;
                this.showPaymentCompleteMessage = false;
                this.dynamicFeeTableColumns = [...this.feeTableColumns];
            });
    }

    checkPaymentStatus() {
        // Check if all fees are fully paid
        const allFeesPaid = this.feeTableData.every(fee =>
            fee.remainingAmount === 0 && fee.totalPaidAmount === fee.feeAmount
        );

        if (allFeesPaid) {
            // All fees are paid - disable everything
            this.isPaymentFieldsDisabled = true;
            this.showPaymentCompleteMessage = true;
            this.dynamicFeeTableColumns = this.getColumnsWithoutCheckbox();
        } else {
            // Some fees are unpaid - enable fields
            this.isPaymentFieldsDisabled = false;
            this.showPaymentCompleteMessage = false;
            this.dynamicFeeTableColumns = [...this.feeTableColumns];
        }
    }

    getColumnsWithoutCheckbox() {
        return this.feeTableColumns.map(col => ({
            ...col,
            hideDefaultActions: true
        }));
    }

    handleRowSelection(event) {
        // Don't allow selection if payment fields are disabled
        if (this.isPaymentFieldsDisabled) {
            this.selectedRows = [];
            return;
        }

        const selectedRowsData = event.detail.selectedRows;
        this.selectedRows = selectedRowsData.map(row => row.id);

        console.log('Selected rows:', selectedRowsData);

        if (this.selectedRows.length > 0 && this.paymentAmount > 0) {
            this.validatePaymentAmount();
            this.updateUIWithPaymentAmount();
        } else if (this.selectedRows.length === 0) {
            this.validatePaymentAmount();
            this.resetToOriginalData();
        }
    }


    handleSort(event) {
        this.sortedBy = event.detail.fieldName;
        this.sortedDirection = event.detail.sortDirection;
        this.sortData(this.sortedBy, this.sortedDirection);
    }

    sortData(fieldName, direction) {
        let parseData = JSON.parse(JSON.stringify(this.feeTableData));
        let keyValue = (a) => {
            return a[fieldName];
        };
        let isReverse = direction === 'asc' ? 1 : -1;
        parseData.sort((x, y) => {
            x = keyValue(x) ? keyValue(x) : '';
            y = keyValue(y) ? keyValue(y) : '';
            return isReverse * ((x > y) - (y > x));
        });
        this.feeTableData = parseData;
    }

    // Payment field handlers
    handlePaymentDateChange(event) {
        this.paymentDate = event.target.value;
    }

    handlePaymentOptionChange(event) {
        this.selectedPaymentOption = event.target.value;
    }

    handlePaymentAmountChange(event) {
        this.paymentAmount = parseFloat(event.target.value) || 0;
        this.validatePaymentAmount();

        // Automatically update UI when payment amount changes
        if (this.paymentAmount > 0) {
            if (this.selectedRows.length > 0) {
                this.updateUIWithPaymentAmount();
            } else {
                this.resetToOriginalData();
            }
        } else {
            this.resetToOriginalData();
        }

    }
    get isPayFeeDisabled() {
        return this.isProcessingPayment ||
            !this.isPaymentAmountValid ||
            this.isPaymentFieldsDisabled ||
            this.hasDuplicateErrors;
    }


    // Update UI with payment amount allocation
    updateUIWithPaymentAmount() {
        if (this.selectedRows.length === 0 || !this.paymentAmount) {
            return;
        }

        // Get selected fee records from original data
        const selectedFeeRecords = this.originalFeeData.filter(fee =>
            this.selectedRows.includes(fee.id)
        );

        // Calculate total remaining amount for selected records
        const totalRemainingAmount = selectedFeeRecords.reduce((total, fee) =>
            total + (fee.remainingAmount || 0), 0
        );

        if (this.paymentAmount > totalRemainingAmount) {
            this.showToast('Warning',
                `Payment amount ₹${this.paymentAmount} exceeds total remaining amount ₹${totalRemainingAmount}`,
                'warning'
            );
            // Still show the allocation but with warning
        }

        // Process the payment allocation in UI
        this.allocatePaymentInUI(selectedFeeRecords);
    }

    // Reset UI to original data
    resetToOriginalData() {
        if (this.originalFeeData && this.originalFeeData.length > 0) {
            this.feeTableData = JSON.parse(JSON.stringify(this.originalFeeData));
            this.checkForPaymentChanges();

            // **NEW: Re-check payment status when resetting to original data**
            this.checkPaymentStatus();
        }
    }

    // Fee Allotment handler
    handleFeeAllotment() {
        if (this.selectedRows.length === 0) {
            this.showToast('Warning', 'Please select at least one fee record', 'warning');
            return;
        }

        if (!this.paymentAmount || this.paymentAmount <= 0) {
            this.showToast('Warning', 'Please enter a valid payment amount', 'warning');
            return;
        }

        // Get selected fee records
        const selectedFeeRecords = this.feeTableData.filter(fee =>
            this.selectedRows.includes(fee.id)
        );

        // Calculate total remaining amount for selected records
        const totalRemainingAmount = selectedFeeRecords.reduce((total, fee) =>
            total + (fee.remainingAmount || 0), 0
        );

        if (this.paymentAmount > totalRemainingAmount) {
            this.showToast('Warning',
                `Payment amount ₹${this.paymentAmount} exceeds total remaining amount ₹${totalRemainingAmount}`,
                'warning'
            );
            return;
        }

        // Process the payment allocation
        this.allocatePayment(selectedFeeRecords);
    }

    // Allocate payment to selected fee records (UI only)
    allocatePaymentInUI(selectedFeeRecords) {
        let remainingPayment = this.paymentAmount;

        // Start with original data
        const updatedFeeData = JSON.parse(JSON.stringify(this.originalFeeData));

        // Sort selected records by semester/term number and then by due date.
        const sortedSelectedFeeRecords = [...selectedFeeRecords].sort((a, b) => {
            const semesterDelta = this.getSemesterOrder(a.termReference) - this.getSemesterOrder(b.termReference);
            if (semesterDelta !== 0) {
                return semesterDelta;
            }
            if (a.formattedDueDate && b.formattedDueDate) {
                return new Date(a.formattedDueDate) - new Date(b.formattedDueDate);
            }
            return 0;
        });

        // Allocate payment across selected records
        for (let selectedFee of sortedSelectedFeeRecords) {
            if (remainingPayment <= 0) break;

            const feeIndex = updatedFeeData.findIndex(fee => fee.id === selectedFee.id);
            if (feeIndex !== -1) {
                const currentRemaining = updatedFeeData[feeIndex].remainingAmount || 0;
                const paymentForThisFee = Math.min(remainingPayment, currentRemaining);

                // Update the fee record (UI only) - Now updating totalPaidAmount instead of paidAmount
                updatedFeeData[feeIndex].remainingAmount = currentRemaining - paymentForThisFee;
                updatedFeeData[feeIndex].totalPaidAmount = (updatedFeeData[feeIndex].totalPaidAmount || 0) + paymentForThisFee;

                remainingPayment -= paymentForThisFee;
            }
        }

        // Update the table data
        this.feeTableData = updatedFeeData;

        // **NEW: Check if this UI allocation would complete all payments**
        this.checkPaymentStatusForUI();

        // Check if there are changes to show Pay Fee button
        this.checkForPaymentChanges();
    }

    checkPaymentStatusForUI() {
        // Check if all fees would be fully paid with current UI allocation
        const allFeesWouldBePaid = this.feeTableData.every(fee =>
            fee.remainingAmount === 0 && fee.totalPaidAmount === fee.feeAmount
        );

        if (allFeesWouldBePaid) {
            // Show preview message that payment will complete all fees
            this.showToast('Info', 'This payment will complete all remaining fees.', 'info');
        }
    }

    // Check if there are payment changes to show Pay Fee button - Updated to check totalPaidAmount
    checkForPaymentChanges() {
        const originalById = new Map((this.originalFeeData || []).map(fee => [fee.id, fee]));
        this.hasPaymentChanges = this.feeTableData.some((fee) => {
            const original = originalById.get(fee.id);
            return !!original && (
                Number(fee.totalPaidAmount || 0) !== Number(original.totalPaidAmount || 0) ||
                Number(fee.remainingAmount || 0) !== Number(original.remainingAmount || 0)
            );
        });
    }

    // Handle Pay Fee button click - Updated to send totalPaidAmount
    handlePayFee() {
        if (!this.hasPaymentChanges) {
            this.showToast('Warning', 'No payment changes to save', 'warning');
            return;
        }

        if (!this.paymentDate || !this.selectedPaymentOption || !this.paymentAmount) {
            this.showToast('Error', 'Please ensure all payment fields are filled', 'error');
            return;
        }

        this.isProcessingPayment = true;

        // Prepare updated fee records for database update - Updated to use totalPaidAmount
        const originalById = new Map((this.originalFeeData || []).map(fee => [fee.id, fee]));
        const updatedFeeRecords = this.feeTableData.filter((fee) => {
            const original = originalById.get(fee.id);
            return !!original && (
                Number(fee.totalPaidAmount || 0) !== Number(original.totalPaidAmount || 0) ||
                Number(fee.remainingAmount || 0) !== Number(original.remainingAmount || 0)
            );
        }).map(fee => ({
            id: fee.id,
            totalPaidAmount: fee.totalPaidAmount,
            remainingAmount: fee.remainingAmount
        }));

        // Call Apex method to update database
        updateFeeRecords({
            usnNumber: this.studentData.usnNumber,
            updatedFeeRecords: updatedFeeRecords,
            paymentDate: this.paymentDate,
            paymentMethod: this.selectedPaymentOption,
            paymentAmount: this.paymentAmount,
            transactionId: this.transactionId,
            crmReceiptNumber: this.crmReceiptNumber,
            settlementUTR: this.settlementUTR
        })
            .then(result => {
                // Handle the response which now includes PDF URL
                if (result.success) {
                    this.showToast('Success', result.message, 'success');

                    // Display PDF if URL is available
                    if (result.pdfUrl) {
                        this.displayPdf(result.pdfUrl);
                    } else {
                        // Fallback to fetch PDF URL separately
                        this.fetchLatestReceiptPdf();
                    }
                } else {
                    this.showToast('Warning', result.message || 'Payment processed with warnings', 'warning');
                }

                // Update original data to reflect saved state
                this.originalFeeData = JSON.parse(JSON.stringify(this.feeTableData));
                this.hasPaymentChanges = false;

                // **NEW: Check payment status after successful payment**
                this.checkPaymentStatus();

                // Clear payment fields only if payment is not complete
                if (!this.isPaymentFieldsDisabled) {
                    this.paymentAmount = '';
                    this.selectedPaymentOption = '';
                }

                // Clear selected rows
                this.selectedRows = [];

                this.isProcessingPayment = false;
            })
            .catch(error => {
                console.error('Error updating fee records:', error);
                const errorMessage = error.body && error.body.message ?
                    error.body.message : 'Error occurred while updating fee records';
                this.showToast('Error', errorMessage, 'error');
                this.isProcessingPayment = false;
            });
    }

    // Handle successful payment and fetch PDF URL
    handlePaymentSuccess(result) {
        this.showToast('Success', result, 'success');

        // Fetch the PDF URL by querying the latest receipt record
        this.fetchLatestReceiptPdf();
    }

    // Fetch the latest receipt PDF URL (fallback method)
    fetchLatestReceiptPdf() {
        getLatestReceiptUrl({ usnNumber: this.studentData.usnNumber })
            .then(pdfUrl => {
                if (pdfUrl) {
                    this.displayPdf(pdfUrl);
                } else {
                    this.showToast('Warning', 'PDF receipt was generated but could not be displayed. Please check the records.', 'warning');
                }
            })
            .catch(error => {
                console.error('Error fetching PDF URL:', error);
                this.showToast('Warning', 'Payment processed successfully, but unable to display PDF receipt.', 'warning');
            });
    }

    // Display PDF in modal popup
    displayPdf(pdfUrl) {
        this.pdfUrl = pdfUrl;
        this.showPdfViewer = true;
        this.isPdfLoading = true;
        this.pdfError = false;
    }

    // Handle PDF load success
    handlePdfLoad() {
        this.isPdfLoading = false;
        this.pdfError = false;
    }

    // Handle PDF load error
    handlePdfError() {
        this.isPdfLoading = false;
        this.pdfError = true;
        this.showToast('Warning', 'Unable to display PDF in browser. You can try downloading it.', 'warning');
    }

    // Close PDF viewer
    closePdfViewer() {
        this.showPdfViewer = false;
        this.pdfUrl = '';
        this.isPdfLoading = false;
        this.pdfError = false;
    }

    // Download PDF
    downloadPdf() {
        if (this.pdfUrl) {
            // Create a temporary link element and trigger download
            const link = document.createElement('a');
            link.href = this.pdfUrl;
            link.download = `Receipt_${this.studentData.studentName}_${new Date().toISOString().split('T')[0]}.pdf`;
            link.target = '_blank';
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
        }
    }

    validatePaymentAmount() {
        if (!this.paymentAmount || this.paymentAmount <= 0) {
            this.isPaymentAmountValid = true;
            return;
        }

        const selectedFeeRecords = (this.originalFeeData || []).filter(fee => this.selectedRows.includes(fee.id));
        const rowsToValidate = selectedFeeRecords.length > 0 ? selectedFeeRecords : (this.originalFeeData || []);
        const allowedAmount = rowsToValidate.reduce((total, fee) => total + Number(fee.remainingAmount || 0), 0);

        if (this.paymentAmount > allowedAmount) {
            this.isPaymentAmountValid = false;
            this.showToast(
                'Warning',
                `Payment amount INR ${this.paymentAmount} exceeds allowed amount INR ${allowedAmount}`,
                'warning'
            );
            return;
        }

        this.isPaymentAmountValid = true;
    }

    getSemesterOrder(termReference) {
        if (!termReference) {
            return Number.MAX_SAFE_INTEGER;
        }

        const matchedParts = String(termReference).match(this.termLabelPattern);
        if (matchedParts && matchedParts[2]) {
            return parseInt(matchedParts[2], 10);
        }

        const fallbackNumeric = String(termReference).match(/(\d+)/);
        return fallbackNumeric && fallbackNumeric[1] ? parseInt(fallbackNumeric[1], 10) : Number.MAX_SAFE_INTEGER;
    }

    sortFeeDataBySemester(feeData) {
        return [...feeData].sort((a, b) => {
            const semesterDelta = this.getSemesterOrder(a.termReference) - this.getSemesterOrder(b.termReference);
            if (semesterDelta !== 0) {
                return semesterDelta;
            }

            if (a.formattedDueDate && b.formattedDueDate) {
                return new Date(a.formattedDueDate) - new Date(b.formattedDueDate);
            }
            return 0;
        });
    }

    showToast(title, message, variant) {
    const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: 'dismissable'
        });
        this.dispatchEvent(event);
    }
}