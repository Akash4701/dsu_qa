import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getSchedulePage from '@salesforce/apex/FeedbackHomeController.getSchedulePage';
import { reduceErrors, handleError } from 'c/errorUtils';
import { rateTone, statusTone, scheduleTiming, formatWindow, recordPage, newRecordPage, plural, DEFAULT_TARGET_RATE } from 'c/feedbackHomeUtils';

const SEARCH_DEBOUNCE_MS = 300;
const ALL = 'All';
const STATUS_ORDER = [ALL, 'Live', 'Scheduled', 'Closed'];
const SORTS = [
    { label: 'Newest first', value: 'newest' },
    { label: 'Closing soon', value: 'closing' },
    { label: 'Name A–Z', value: 'name' }
];

/**
 * Schedules as a server-paged table. Search, status (derived from dates), sorting and paging all run in
 * SOQL (FeedbackHomeController.getSchedulePage); response roll-ups are aggregated only for the visible page.
 */
export default class FeedbackSchedulesPanel extends NavigationMixin(LightningElement) {
    page;
    error;
    loading = true;
    wiredResult;
    searchText = '';
    debounce;

    // wire parameters
    appliedSearch = '';
    status = ALL;
    sortKey = 'newest';
    pageSize = 25;
    pageNumber = 1;

    @wire(getSchedulePage, {
        search: '$appliedSearch',
        status: '$status',
        sortKey: '$sortKey',
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
            handleError(this, error, { context: 'feedbackSchedulesPanel', toast: false });
        }
        this.loading = !data && !error;
    }

    disconnectedCallback() {
        clearTimeout(this.debounce);
    }

    get target() {
        return DEFAULT_TARGET_RATE;
    }

    get chips() {
        const counts = {};
        (this.page ? this.page.statusCounts : []).forEach((c) => {
            counts[c.status] = c.count;
        });
        return STATUS_ORDER.map((label) => ({
            label,
            count: counts[label] === undefined ? '' : counts[label],
            pressed: String(label === this.status)
        }));
    }

    get sortOptions() {
        return SORTS.map((s) => ({ ...s, selected: s.value === this.sortKey }));
    }

    get rows() {
        return (this.page ? this.page.rows : []).map((r) => {
            const timing = scheduleTiming(r);
            return {
                ...r,
                statusTone: statusTone(r.status),
                rateTone: rateTone(r.rate, DEFAULT_TARGET_RATE),
                window: formatWindow(r.startDate, r.endDate),
                caption: timing.caption,
                captionClass: timing.urgent ? 'fh-small caption_urgent' : 'fh-small fh-muted',
                responseLabel: `${r.submitted} of ${r.total}`,
                hasItems: r.total > 0
            };
        });
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
        return !!this.appliedSearch || this.status !== ALL;
    }
    get emptyMessage() {
        return this.hasFilters ? 'No schedules match your search or filters.' : 'Schedule a feedback round to collect responses from students and faculty.';
    }
    get wrapClass() {
        return this.loading && this.page ? 'fh-table-wrap is-loading' : 'fh-table-wrap';
    }
    get resultLabel() {
        return plural(this.total, 'schedule');
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

    handleChip(event) {
        const label = event.currentTarget.dataset.label;
        this.applyFilter(() => {
            this.status = label;
        });
    }

    handleSort(event) {
        const value = event.target.value;
        this.applyFilter(() => {
            this.sortKey = value;
        });
    }

    handleClear() {
        this.searchText = '';
        this.applyFilter(() => {
            this.appliedSearch = '';
            this.status = ALL;
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
        this[NavigationMixin.Navigate](newRecordPage('Feedback_Scheduler__c'));
    }

    handleOpenRecord(event) {
        this[NavigationMixin.Navigate](recordPage(event.currentTarget.dataset.id));
    }

    handleOpenResponses(event) {
        this.dispatchEvent(new CustomEvent('openresponses', { detail: { schedulerId: event.currentTarget.dataset.id } }));
    }
}