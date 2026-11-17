import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getSectionPage from '@salesforce/apex/FeedbackHomeController.getSectionPage';
import { reduceErrors, handleError } from 'c/errorUtils';
import { statusTone, recordPage, newRecordPage, plural } from 'c/feedbackHomeUtils';

const SEARCH_DEBOUNCE_MS = 300;
const TYPE_FILTERS = [
    { label: 'All', value: null },
    { label: 'Feedback', value: 'Feedback' },
    { label: 'Interview', value: 'Interview' }
];

/**
 * Parameter Sections as a server-paged table. Search, record-type and active filters and paging all run
 * in SOQL (FeedbackHomeController.getSectionPage), so the list stays fast with thousands of records.
 */
export default class FeedbackSectionsPanel extends NavigationMixin(LightningElement) {
    page;
    error;
    loading = true;
    wiredResult;
    searchText = '';
    debounce;

    // wire parameters
    appliedSearch = '';
    recordType = null;
    activeOnly = false;
    pageSize = 25;
    pageNumber = 1;

    @wire(getSectionPage, {
        recordTypeDeveloperName: '$recordType',
        search: '$appliedSearch',
        activeOnly: '$activeOnly',
        pageSize: '$pageSize',
        pageNumber: '$pageNumber'
    })
    wiredPage(result) {
        this.wiredResult = result;
        const { data, error } = result;
        if (data) {
            this.page = data;
            this.error = undefined;
            // The server clamps an out-of-range page (e.g. a filter shrank the list): follow it.
            if (data.pageNumber !== this.pageNumber) {
                this.pageNumber = data.pageNumber;
            }
        } else if (error) {
            this.page = undefined;
            this.error = reduceErrors(error).join(' ');
            handleError(this, error, { context: 'feedbackSectionsPanel', toast: false });
        }
        this.loading = !data && !error;
    }

    disconnectedCallback() {
        clearTimeout(this.debounce);
    }

    get typeChips() {
        return TYPE_FILTERS.map((f) => ({ label: f.label, value: f.value || '', pressed: String(f.value === this.recordType) }));
    }

    get activeOnlyPressed() {
        return String(this.activeOnly);
    }

    get rows() {
        return (this.page ? this.page.rows : []).map((r) => ({
            ...r,
            activeLabel: r.active ? 'Active' : 'Inactive',
            activeTone: statusTone(r.active ? 'Active' : 'Inactive'),
            typeTone: r.recordType === 'Interview' ? 'info' : 'success',
            parameterLabel: plural(r.parameterCount, 'parameter'),
            emptyParams: r.parameterCount === 0,
            rowClass: r.active ? '' : 'row_off'
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
        return !this.loading && !this.error && this.page && !this.hasRows;
    }
    get hasFilters() {
        return !!this.appliedSearch || this.recordType !== null || this.activeOnly;
    }
    get emptyMessage() {
        return this.hasFilters ? 'No sections match your search or filters.' : 'Create your first Parameter Section to start building feedback forms.';
    }
    get wrapClass() {
        return this.loading && this.page ? 'fh-table-wrap is-loading' : 'fh-table-wrap';
    }
    get resultLabel() {
        return plural(this.total, 'section');
    }

    // ----- filters: every change returns to page 1 -----
    handleSearch(event) {
        this.searchText = event.target.value;
        clearTimeout(this.debounce);
        this.debounce = setTimeout(() => {
            this.applyFilter(() => {
                this.appliedSearch = this.searchText.trim();
            });
        }, SEARCH_DEBOUNCE_MS);
    }

    handleType(event) {
        const value = event.currentTarget.dataset.value || null;
        this.applyFilter(() => {
            this.recordType = value;
        });
    }

    handleToggleActive() {
        this.applyFilter(() => {
            this.activeOnly = !this.activeOnly;
        });
    }

    handleClear() {
        this.searchText = '';
        this.applyFilter(() => {
            this.appliedSearch = '';
            this.recordType = null;
            this.activeOnly = false;
        });
    }

    applyFilter(change) {
        this.loading = true;
        change();
        this.pageNumber = 1;
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
        this.loading = true;
        refreshApex(this.wiredResult).finally(() => {
            this.loading = false;
        });
    }

    handleNew() {
        this[NavigationMixin.Navigate](newRecordPage('Questionnaire_Metadata__c'));
    }

    handleOpenRecord(event) {
        this[NavigationMixin.Navigate](recordPage(event.currentTarget.dataset.id));
    }

    handleOpenParameters(event) {
        this.dispatchEvent(new CustomEvent('openparameters', { detail: { sectionId: event.currentTarget.dataset.id } }));
    }
}