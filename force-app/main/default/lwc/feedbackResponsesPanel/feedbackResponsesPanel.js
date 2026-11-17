import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getSchedules from '@salesforce/apex/FeedbackHomeController.getSchedules';
import getScheduleItems from '@salesforce/apex/FeedbackHomeController.getScheduleItems';
import { reduceErrors, handleError, showToast } from 'c/errorUtils';
import {
    rateTone,
    statusTone,
    scheduleTiming,
    formatWindow,
    initials,
    recordPage,
    matchesSearch,
    plural,
    downloadCsv,
    DEFAULT_TARGET_RATE
} from 'c/feedbackHomeUtils';

const STATUS_FILTERS = ['All', 'Pending', 'Submitted'];
const CSV_COLUMNS = [
    { label: 'Feedback item', field: 'name' },
    { label: 'Respondent', field: 'assignee' },
    { label: 'Course offering', field: 'courseOffering' },
    { label: 'Start date', field: 'startDate' },
    { label: 'End date', field: 'endDate' },
    { label: 'Reminders sent', field: 'reminders' },
    { label: 'Status', field: 'status' }
];

export default class FeedbackResponsesPanel extends NavigationMixin(LightningElement) {
    schedules = [];
    items = [];
    selected;
    status = 'All';
    search = '';
    error;
    loadingItems = false;
    schedulesLoaded = false;
    itemsResult;

    @api
    get schedulerId() {
        return this.selected;
    }
    set schedulerId(value) {
        this.selected = value || undefined;
    }

    @wire(getSchedules)
    wiredSchedules({ data, error }) {
        if (data) {
            this.schedules = data;
            this.schedulesLoaded = true;
            if (!this.selected && data.length > 0) {
                this.selected = data[0].id;
            }
        } else if (error) {
            this.schedulesLoaded = true;
            this.error = reduceErrors(error).join(' ');
            handleError(this, error, { context: 'feedbackResponsesPanel.schedules', toast: false });
        }
    }

    // An undefined schedule id keeps the wire dormant until a schedule is picked.
    @wire(getScheduleItems, { schedulerId: '$selected', status: '$status' })
    wiredItems(result) {
        this.itemsResult = result;
        const { data, error } = result;
        if (data) {
            this.items = data;
            this.error = undefined;
        } else if (error) {
            this.items = [];
            this.error = reduceErrors(error).join(' ');
            handleError(this, error, { context: 'feedbackResponsesPanel.items', toast: false });
        }
        this.loadingItems = false;
    }

    get scheduleOptions() {
        return this.schedules.map((s) => ({ label: `${s.name} · ${s.status}`, value: s.id, selected: s.id === this.selected }));
    }

    get current() {
        return this.schedules.find((s) => s.id === this.selected);
    }

    get hasCurrent() {
        return !!this.current;
    }

    get summary() {
        const s = this.current;
        if (!s) {
            return null;
        }
        const timing = scheduleTiming(s);
        return {
            ...s,
            rateTone: rateTone(s.rate, DEFAULT_TARGET_RATE),
            statusTone: statusTone(s.status),
            window: formatWindow(s.startDate, s.endDate),
            caption: timing.caption,
            donutSub: `of ${plural(s.total, 'item')}`,
            gap: s.rate >= DEFAULT_TARGET_RATE ? 'Target met' : `${DEFAULT_TARGET_RATE - s.rate} points below the ${DEFAULT_TARGET_RATE}% target`
        };
    }

    get chips() {
        return STATUS_FILTERS.map((label) => ({ label, pressed: String(label === this.status) }));
    }

    get filteredItems() {
        return this.items.filter((i) => matchesSearch(this.search, i.assignee, i.name, i.courseOffering));
    }

    get visibleItems() {
        return this.filteredItems.map((i) => ({
            ...i,
            statusTone: statusTone(i.status),
            avatar: initials(i.assignee),
            respondent: i.assignee || 'Unassigned',
            window: formatWindow(i.startDate, i.endDate),
            remindersLabel: i.reminders ? plural(i.reminders, 'reminder') : 'None sent'
        }));
    }

    get resultLabel() {
        return plural(this.filteredItems.length, 'item');
    }

    get hasItems() {
        return this.filteredItems.length > 0;
    }

    get noSchedule() {
        return this.schedulesLoaded && this.schedules.length === 0 && !this.error;
    }

    get showSkeleton() {
        return !this.schedulesLoaded;
    }

    get showItemsSkeleton() {
        return this.loadingItems && this.items.length === 0;
    }

    get isEmpty() {
        return !!this.selected && !this.loadingItems && !this.error && !this.hasItems;
    }

    get cannotExport() {
        return !this.hasItems;
    }

    handleSchedule(event) {
        this.loadingItems = true;
        this.selected = event.target.value;
    }

    handleChip(event) {
        this.loadingItems = true;
        this.status = event.currentTarget.dataset.label;
    }

    handleSearch(event) {
        this.search = event.target.value;
    }

    handleRefresh() {
        if (!this.itemsResult) {
            return;
        }
        this.loadingItems = true;
        refreshApex(this.itemsResult).finally(() => {
            this.loadingItems = false;
        });
    }

    handleExport() {
        const name = this.current ? this.current.name : 'feedback';
        downloadCsv(`${name.replace(/[^\w-]+/g, '_')}_responses.csv`, CSV_COLUMNS, this.filteredItems);
        showToast(this, { title: 'Export ready', message: `${this.resultLabel} exported.`, variant: 'success' });
    }

    handleOpenRecord(event) {
        this[NavigationMixin.Navigate](recordPage(event.currentTarget.dataset.id));
    }
}