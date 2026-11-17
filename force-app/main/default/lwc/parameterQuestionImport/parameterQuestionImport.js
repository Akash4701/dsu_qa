import { LightningElement, api } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { RefreshEvent } from 'lightning/refresh';
import { reduceErrors, showToast } from 'c/errorUtils';

import saveQuestions from
    '@salesforce/apex/ParameterQuestionImportController.saveQuestions';

const HEADERS = [
    'Question Label',
    'Question Type',
    'Active',
    'Mandatory',
    'Section Points',
    'Max Grade',
    'Section Label',
    'Order',
    'Sub Label',
    'Answers'
];

const QUESTION_TYPES = [
    'Graded',
    'Yes/No',
    'Comment',
    'Multiple Choice',
    'Rating',
    'Dropdown',
    'Likert Scale'
];
const CHOICE_TYPES = ['Multiple Choice', 'Dropdown', 'Likert Scale'];
const BOOLEAN_VALUES = ['true', 'false', 'yes', 'no', '1', '0'];
const FORBIDDEN_HEADERS = ['Questionnaire', 'Created By', 'Owner', 'Last Modified By'];
const MAX_LENGTHS = {
    'Question Label': 2000,
    'Section Points': 131072,
    'Section Label': 255,
    'Sub Label': 255,
    'Answers': 32768
};

// Kept in step with ParameterQuestionImportController.MAX_ROWS.
const MAX_ROWS = 2000;
const MAX_FILE_BYTES = 2 * 1024 * 1024;
const PREVIEW_ROWS = 10;
const MAX_ERROR_ROWS_SHOWN = 100;

const STEP_SELECT = 'select';
const STEP_REVIEW = 'review';
const STEP_DONE = 'done';

export default class ParameterQuestionImport extends LightningElement {
    @api recordId;

    headers = HEADERS;
    columnCount = 0;
    step = STEP_SELECT;

    fileName = '';
    fileSizeLabel = '';
    validRows = [];
    errorRows = [];
    totalRows = 0;
    // A problem with the file as a whole (wrong type, missing columns...), as opposed to bad rows.
    fileError = '';
    // A problem from the save itself.
    saveError = '';
    importedCount = 0;
    isLoading = false;

    // ---- view state ----

    get isSelectStep() {
        return this.step === STEP_SELECT;
    }

    get isReviewStep() {
        return this.step === STEP_REVIEW;
    }

    get isDoneStep() {
        return this.step === STEP_DONE;
    }

    get hasFile() {
        return !!this.fileName;
    }

    get hasFileError() {
        return !!this.fileError;
    }

    get hasSaveError() {
        return !!this.saveError;
    }

    get hasErrorRows() {
        return this.errorRows.length > 0;
    }

    get validCount() {
        return this.validRows.length;
    }

    get errorCount() {
        return this.errorRows.length;
    }

    get canImport() {
        return this.isReviewStep && !this.hasErrorRows && this.validCount > 0 && !this.isLoading;
    }

    get importDisabled() {
        return !this.canImport;
    }

    get importLabel() {
        if (this.isLoading) {
            return 'Importing…';
        }
        const count = this.validCount;
        return count > 0 && !this.hasErrorRows
            ? `Import ${count} question${count === 1 ? '' : 's'}`
            : 'Import';
    }

    get readyLabel() {
        const count = this.validCount;
        return `${count} question${count === 1 ? '' : 's'} ready to import`;
    }

    get errorSummaryLabel() {
        const count = this.errorCount;
        return `${count} row${count === 1 ? '' : 's'} need${count === 1 ? 's' : ''} fixing`;
    }

    get errorRowsShown() {
        return this.errorRows.slice(0, MAX_ERROR_ROWS_SHOWN);
    }

    get hiddenErrorCount() {
        return Math.max(0, this.errorRows.length - MAX_ERROR_ROWS_SHOWN);
    }

    get hasHiddenErrors() {
        return this.hiddenErrorCount > 0;
    }

    get previewRows() {
        return this.validRows.slice(0, PREVIEW_ROWS).map(row => ({
            key: `preview-${row.rowNumber}`,
            rowNumber: row.rowNumber,
            label: row.data['Question Label'],
            type: row.data['Question Type'],
            section: row.data['Section Label'] || '—',
            order: row.data.Order || '—',
            active: this.yesNo(row.data.Active, 'Yes'),
            mandatory: this.yesNo(row.data.Mandatory, 'No')
        }));
    }

    get previewNote() {
        return this.validCount > PREVIEW_ROWS
            ? `Showing the first ${PREVIEW_ROWS} of ${this.validCount} questions.`
            : '';
    }

    get doneMessage() {
        const count = this.importedCount;
        return `${count} question${count === 1 ? ' was' : 's were'} added to this questionnaire.`;
    }

    get maxRowsLabel() {
        return MAX_ROWS.toLocaleString();
    }

    // ---- actions ----

    downloadTemplate() {
        this.downloadText(
            this.csvLine(HEADERS) + '\r\n',
            'Question_Import_Template.csv'
        );
    }

    downloadFailed() {
        if (!this.errorRows.length) {
            return;
        }
        const lines = [
            this.csvLine([...HEADERS, 'Problem']),
            ...this.errorRows.map(row => this.csvLine([...row.values, row.problems]))
        ];
        this.downloadText(lines.join('\r\n'), 'Question_Import_Rows_To_Fix.csv');
    }

    closeAction() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    removeFile() {
        this.resetFile();
        const input = this.template.querySelector('lightning-input[data-id="file"]');
        if (input) {
            input.value = null;
        }
    }

    async handleFileChange(event) {
        this.resetFile();

        const file = event.target.files?.[0];
        if (!file) {
            return;
        }

        this.fileName = file.name;
        this.fileSizeLabel = this.formatSize(file.size);

        try {
            if (!file.name.toLowerCase().endsWith('.csv')) {
                throw new Error('Choose a CSV file.');
            }
            if (file.size > MAX_FILE_BYTES) {
                throw new Error(
                    `This file is ${this.fileSizeLabel}. The limit is ${this.formatSize(MAX_FILE_BYTES)}. Split it into smaller files.`
                );
            }

            const rows = this.parseCsv(await file.text());
            const columnIndexes = this.readHeader(rows);
            this.readRows(rows, columnIndexes);
            this.step = STEP_REVIEW;
        } catch (error) {
            this.fileError = error.message || 'Unable to read the CSV file.';
        }
    }

    async handleImport() {
        if (!this.canImport) {
            return;
        }
        if (!this.recordId) {
            this.saveError = 'The current Questionnaire record was not identified.';
            return;
        }

        this.isLoading = true;
        this.saveError = '';

        try {
            const rowsJson = JSON.stringify(
                this.validRows.map(row => ({ ...row.data, _row: row.rowNumber }))
            );
            this.importedCount = await saveQuestions({
                questionnaireId: this.recordId,
                rowsJson
            });

            this.step = STEP_DONE;
            showToast(this, {
                title: 'Import complete',
                message: this.doneMessage,
                variant: 'success'
            });
            // Refresh the questionnaire page so the new questions show in its related list.
            this.dispatchEvent(new RefreshEvent());
        } catch (error) {
            this.saveError = reduceErrors(error).join(' ') || 'Import failed.';
        } finally {
            this.isLoading = false;
        }
    }

    // ---- reading the file ----

    resetFile() {
        this.step = STEP_SELECT;
        this.fileName = '';
        this.fileSizeLabel = '';
        this.validRows = [];
        this.errorRows = [];
        this.totalRows = 0;
        this.fileError = '';
        this.saveError = '';
    }

    // Checks the header row and returns, for each expected column, its position in the file.
    readHeader(rows) {
        if (rows.length < 2) {
            throw new Error('The CSV needs a header and at least one data row.');
        }

        const actual = rows[0].map((value, index) =>
            (index === 0 ? value.replace(/^﻿/, '') : value).trim()
        );

        const duplicates = actual.filter((header, index) => actual.indexOf(header) !== index);
        if (duplicates.length) {
            throw new Error(`Duplicate columns: ${[...new Set(duplicates)].join(', ')}`);
        }

        const missing = HEADERS.filter(header => !actual.includes(header));
        if (missing.length) {
            throw new Error(`Missing columns: ${missing.join(', ')}`);
        }

        const forbidden = FORBIDDEN_HEADERS.filter(header => actual.includes(header));
        if (forbidden.length) {
            throw new Error(`Remove these columns: ${forbidden.join(', ')}`);
        }

        this.columnCount = actual.length;
        return HEADERS.map(header => actual.indexOf(header));
    }

    readRows(rows, columnIndexes) {
        const dataRows = rows.slice(1)
            .map((row, index) => ({ row, rowNumber: index + 2 }))
            .filter(({ row }) => row.some(value => value.trim() !== ''));

        if (!dataRows.length) {
            throw new Error('No data rows found.');
        }
        if (dataRows.length > MAX_ROWS) {
            throw new Error(
                `This file has ${dataRows.length} questions. One import can contain at most ${this.maxRowsLabel}. Split it into smaller files.`
            );
        }

        this.totalRows = dataRows.length;
        const valid = [];
        const failed = [];

        dataRows.forEach(({ row, rowNumber }) => {
            const values = columnIndexes.map(index => (row[index] || '').trim());
            const data = Object.fromEntries(HEADERS.map((header, i) => [header, values[i]]));
            const problems = row.length !== this.columnCount
                ? [`Expected ${this.columnCount} columns but found ${row.length}.`]
                : this.validateRow(data);

            if (problems.length) {
                failed.push({
                    key: `error-${rowNumber}`,
                    rowNumber,
                    values,
                    problems: problems.join(' ')
                });
            } else {
                valid.push({ rowNumber, values, data });
            }
        });

        this.validRows = valid;
        this.errorRows = failed;
    }

    validateRow(data) {
        const problems = [];

        if (!data['Question Label']) {
            problems.push('Question Label is required.');
        }

        if (!QUESTION_TYPES.includes(data['Question Type'])) {
            problems.push(`Question Type must be one of: ${QUESTION_TYPES.join(', ')}.`);
        }

        if (CHOICE_TYPES.includes(data['Question Type'])) {
            const choices = (data['Answers'] || '').split(';').map(c => c.trim()).filter(Boolean);
            if (!choices.length) {
                problems.push(`${data['Question Type']} needs its choices in Answers, separated by semicolons.`);
            } else if (data['Question Type'] === 'Likert Scale' && choices.length < 2) {
                problems.push('Likert Scale needs at least 2 choices in Answers.');
            }
        }

        for (const field of ['Active', 'Mandatory']) {
            if (data[field] && !BOOLEAN_VALUES.includes(data[field].toLowerCase())) {
                problems.push(`${field} must be true or false.`);
            }
        }

        for (const field of ['Max Grade', 'Order']) {
            if (!data[field]) {
                continue;
            }
            if (!/^-?\d+$/.test(data[field])) {
                problems.push(`${field} must be a whole number.`);
            } else if (field === 'Max Grade' && Math.abs(Number(data[field])) > 999) {
                problems.push('Max Grade must be between -999 and 999.');
            } else if (
                field === 'Order' &&
                data[field].replace(/^-/, '').replace(/^0+/, '').length > 18
            ) {
                problems.push('Order must not exceed 18 digits.');
            }
        }

        for (const [field, maxLength] of Object.entries(MAX_LENGTHS)) {
            if (data[field].length > maxLength) {
                problems.push(`${field} must not exceed ${maxLength} characters.`);
            }
        }

        return problems;
    }

    // CSV parser that supports quoted values and commas.
    parseCsv(text) {
        const rows = [];
        let row = [];
        let cell = '';
        let quoted = false;
        let closedQuote = false;

        for (let i = 0; i < text.length; i++) {
            const char = text[i];

            if (quoted) {
                if (char === '"' && text[i + 1] === '"') {
                    cell += '"';
                    i++;
                } else if (char === '"') {
                    quoted = false;
                    closedQuote = true;
                } else {
                    cell += char;
                }
                continue;
            }

            if (closedQuote && char !== ',' && char !== '\n' && char !== '\r') {
                if (char.trim()) {
                    throw new Error('The CSV contains invalid quoted values.');
                }
                continue;
            }

            if (char === '"') {
                if (cell.length) {
                    throw new Error('The CSV contains invalid quoted values.');
                }
                quoted = true;
            } else if (char === ',') {
                row.push(cell);
                cell = '';
                closedQuote = false;
            } else if (char === '\n' || char === '\r') {
                if (char === '\r' && text[i + 1] === '\n') {
                    i++;
                }
                row.push(cell);
                rows.push(row);
                row = [];
                cell = '';
                closedQuote = false;
            } else {
                cell += char;
            }
        }

        if (quoted) {
            throw new Error('The CSV contains an unclosed quoted value.');
        }

        if (cell.length || row.length || closedQuote) {
            row.push(cell);
            rows.push(row);
        }

        return rows;
    }

    // ---- small helpers ----

    yesNo(value, defaultValue) {
        const text = (value || '').toLowerCase();
        if (!text) {
            return defaultValue;
        }
        return ['true', 'yes', '1'].includes(text) ? 'Yes' : 'No';
    }

    formatSize(bytes) {
        if (bytes < 1024) {
            return `${bytes} B`;
        }
        if (bytes < 1024 * 1024) {
            return `${(bytes / 1024).toFixed(1)} KB`;
        }
        return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
    }

    csvLine(values) {
        return values.map(value => this.escapeCsv(value)).join(',');
    }

    escapeCsv(value) {
        const text = String(value ?? '');
        return /[",\r\n]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
    }

    downloadText(text, filename) {
        let url;
        try {
            // The BOM makes Excel read the file as UTF-8.
            const blob = new Blob(['﻿' + text]);
            url = URL.createObjectURL(blob);

            const anchor = document.createElement('a');
            anchor.href = url;
            anchor.download = filename;
            anchor.style.display = 'none';

            const container = this.template.querySelector('.download-container');
            container?.appendChild(anchor);
            anchor.click();
            anchor.remove();
        } catch (error) {
            this.saveError = `The file could not be downloaded: ${error?.message || 'unknown error'}.`;
        } finally {
            if (url) {
                setTimeout(() => URL.revokeObjectURL(url), 1000);
            }
        }
    }
}