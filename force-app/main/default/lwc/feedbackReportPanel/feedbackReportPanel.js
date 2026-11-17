import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getReportPage from '@salesforce/apex/FeedbackHomeController.getReportPage';
import getReportFilters from '@salesforce/apex/FeedbackHomeController.getReportFilters';
import { reduceErrors, handleError, showToast } from 'c/errorUtils';
import { statusTone, initials, plural, downloadCsv } from 'c/feedbackHomeUtils';

const SEARCH_DEBOUNCE_MS = 300;
const DASH = '—';

// Same columns, in the same order, as the agreed feedback report format.
const CSV_COLUMNS = [
    { label: 'Student Name', field: 'student' },
    { label: 'USN', field: 'usn' },
    { label: 'Program', field: 'program' },
    { label: 'Program Plan', field: 'programPlan' },
    { label: 'Semester', field: 'term' },
    { label: 'Parameter Section', field: 'section' },
    { label: 'Q. No.', field: 'questionNo' },
    { label: 'Question', field: 'question' },
    { label: 'Question Type', field: 'questionType' },
    { label: 'Answer / Rating', field: 'answer' },
    { label: 'Submitted On', field: 'submittedExport' },
    { label: 'Feedback Status', field: 'status' }
];

function formatDateTime(value) {
    if (!value) {
        return DASH;
    }
    return new Date(value).toLocaleString(undefined, {
        day: 'numeric',
        month: 'short',
        year: 'numeric',
        hour: 'numeric',
        minute: '2-digit'
    });
}

/**
 * Collected feedback answers as a flat, filterable report: one row per answer with the student's USN
 * (from their Affiliation) alongside program, plan, semester, section, question and answer.
 * Search, filters and paging all run server-side (FeedbackHomeController.getReportPage); the CSV export
 * covers the rows currently on screen.
 */
export default class FeedbackReportPanel extends LightningElement {
    page;
    filters;
    error;
    loading = true;
    wiredResult;
    debounce;

    searchText = '';

    // Wire parameters. Empty filters are null, not undefined: an undefined reactive parameter would keep the wire dormant.
    appliedSearch = null;
    feedbackType = null;
    termId = null;
    fromDate = null;
    toDate = null;
    pageSize = 25;
    pageNumber = 1;

    @wire(getReportFilters)
    wiredFilters({ data, error }) {
        if (data) {
            this.filters = data;
        } else if (error) {
            // The filters are a convenience; the report itself still works without them.
            handleError(this, error, { context: 'feedbackReportPanel.filters', toast: false });
        }
    }

    @wire(getReportPage, {
        search: '$appliedSearch',
        feedbackType: '$feedbackType',
        termId: '$termId',
        fromDate: '$fromDate',
        toDate: '$toDate',
        pageSize: '$pageSize',
        pageNumber: '$pageNumber'
    })
    wiredPage(result) {
        this.wiredResult = result;
        const { data, error } = result;
        if (data) {
            this.page = data;
            this.error = undefined;
            if (data.pageNumber !== this.pageNumber) {
                this.pageNumber = data.pageNumber;
            }
        } else if (error) {
            this.page = undefined;
            this.error = reduceErrors(error).join(' ');
            handleError(this, error, { context: 'feedbackReportPanel', toast: false });
        }
        this.loading = !data && !error;
    }

    disconnectedCallback() {
        clearTimeout(this.debounce);
    }

    // ----- view model -----
    get typeOptions() {
        return (this.filters ? this.filters.feedbackTypes : []).map((o) => ({ ...o, selected: o.value === this.feedbackType }));
    }

    get termOptions() {
        return (this.filters ? this.filters.terms : []).map((o) => ({ ...o, selected: o.value === this.termId }));
    }

    get noType() {
        return !this.feedbackType;
    }

    get noTerm() {
        return !this.termId;
    }

    get rows() {
        return (this.page ? this.page.rows : []).map((r) => ({
            ...r,
            avatar: initials(r.student),
            studentLabel: r.student || 'Unknown student',
            usnLabel: r.usn || 'USN not found',
            usnClass: r.usn ? 'usn' : 'usn usn_missing',
            programLabel: r.program || DASH,
            programPlanLabel: r.programPlan || DASH,
            termLabel: r.term || DASH,
            sectionLabel: r.section || DASH,
            feedbackTypeLabel: r.feedbackType || '',
            questionNoLabel: r.questionNo === null || r.questionNo === undefined ? DASH : r.questionNo,
            answerLabel: r.answer || DASH,
            submittedLabel: formatDateTime(r.submittedOn),
            submittedExport: r.submittedOn ? new Date(r.submittedOn).toLocaleString() : '',
            statusLabel: r.status || 'Unknown',
            statusTone: statusTone(r.status)
        }));
    }

    get total() {
        return this.page ? this.page.total : 0;
    }
    get totalPages() {
        return this.page ? this.page.totalPages : 1;
    }
    get truncated() {
        return this.page ? this.page.truncated : false;
    }
    get hasRows() {
        return this.rows.length > 0;
    }
    get showSkeleton() {
        return this.loading && !this.page;
    }
    get isEmpty() {
        return !this.loading && !this.error && !!this.page && !this.hasRows;
    }
    get hasFilters() {
        return !!(this.appliedSearch || this.feedbackType || this.termId || this.fromDate || this.toDate);
    }
    get emptyMessage() {
        return this.hasFilters
            ? 'No answers match these filters. Try widening the dates or clearing a filter.'
            : 'Answers appear here once students submit feedback.';
    }
    get emptyAction() {
        return this.hasFilters ? 'Clear filters' : undefined;
    }
    get wrapClass() {
        return this.loading && this.page ? 'fh-table-wrap is-loading' : 'fh-table-wrap';
    }
    get resultLabel() {
        if (this.error) {
            return 'Report unavailable';
        }
        if (!this.page) {
            return 'Loading answers…';
        }
        return `${plural(this.total, 'answer')}${this.hasFilters ? ' match your filters' : ''}`;
    }
    get cannotExport() {
        return !this.hasRows;
    }

    // ----- filters: every change returns to page 1 -----
    applyFilter(change) {
        this.loading = true;
        change();
        this.pageNumber = 1;
    }

    handleSearch(event) {
        this.searchText = event.target.value;
        clearTimeout(this.debounce);
        this.debounce = setTimeout(() => {
            this.applyFilter(() => {
                this.appliedSearch = this.searchText.trim() || null;
            });
        }, SEARCH_DEBOUNCE_MS);
    }

    handleType(event) {
        const value = event.target.value || null;
        this.applyFilter(() => {
            this.feedbackType = value;
        });
    }

    handleTerm(event) {
        const value = event.target.value || null;
        this.applyFilter(() => {
            this.termId = value;
        });
    }

    handleFrom(event) {
        const value = event.target.value || null;
        this.applyFilter(() => {
            this.fromDate = value;
        });
    }

    handleTo(event) {
        const value = event.target.value || null;
        this.applyFilter(() => {
            this.toDate = value;
        });
    }

    handleClear() {
        clearTimeout(this.debounce);
        this.searchText = '';
        this.applyFilter(() => {
            this.appliedSearch = null;
            this.feedbackType = null;
            this.termId = null;
            this.fromDate = null;
            this.toDate = null;
        });
    }

    // ----- paging -----
    handlePageChange(event) {
        this.loading = true;
        this.pageNumber = event.detail.page;
    }

    handleSizeChange(event) {
        this.loading = true;
        this.pageSize = event.detail.size;
        this.pageNumber = 1;
    }

    // ----- actions -----
    handleRefresh() {
        if (!this.wiredResult) {
            return;
        }
        this.loading = true;
        refreshApex(this.wiredResult).finally(() => {
            this.loading = false;
        });
    }

    handleExport() {
        downloadCsv('feedback_report.csv', CSV_COLUMNS, this.rows);
        showToast(this, { title: 'Export ready', message: `${plural(this.rows.length, 'row')} exported from this page.`, variant: 'success' });
    }
}