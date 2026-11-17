import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { getRecord } from 'lightning/uiRecordApi';
import { refreshApex } from '@salesforce/apex';
import USER_ID from '@salesforce/user/Id';
import FIRST_NAME from '@salesforce/schema/User.FirstName';
import getOverview from '@salesforce/apex/FeedbackHomeController.getOverview';
import { reduceErrors, handleError } from 'c/errorUtils';
import { greeting, newRecordPage } from 'c/feedbackHomeUtils';

const TAB_OVERVIEW = 'overview';
const TAB_SECTIONS = 'sections';
const TAB_PARAMETERS = 'parameters';
const TAB_SCHEDULING = 'scheduling';
const TAB_RESPONSES = 'responses';
const TAB_REPORTS = 'reports';

const TABS = [
    { value: TAB_OVERVIEW, label: 'Overview', icon: 'utility:home' },
    { value: TAB_SECTIONS, label: 'Parameter Sections', icon: 'utility:layers' },
    { value: TAB_PARAMETERS, label: 'Parameters', icon: 'utility:checklist' },
    { value: TAB_SCHEDULING, label: 'Scheduling', icon: 'utility:event' },
    { value: TAB_RESPONSES, label: 'Responses', icon: 'utility:chart' },
    { value: TAB_REPORTS, label: 'Reports', icon: 'utility:table' }
];

/**
 * Container for the Feedback Management home. Owns the overview load (one Apex call shared by the hero,
 * the tab counts and the Overview tab) and the navigation state: active tab and drill-down ids.
 * The other panels load their own data when they are shown.
 */
export default class FeedbackHome extends NavigationMixin(LightningElement) {
    activeTab = TAB_OVERVIEW;
    sectionId = null;
    schedulerId = null;

    overview;
    overviewError;
    loading = true;
    updatedAt;
    firstName;
    wiredOverviewResult;

    @wire(getRecord, { recordId: USER_ID, fields: [FIRST_NAME] })
    wiredUser({ data }) {
        if (data) {
            this.firstName = data.fields.FirstName.value;
        }
    }

    @wire(getOverview)
    wiredOverview(result) {
        this.wiredOverviewResult = result;
        const { data, error } = result;
        if (data) {
            this.overview = data;
            this.overviewError = undefined;
            this.updatedAt = new Date();
        } else if (error) {
            this.overview = undefined;
            this.overviewError = reduceErrors(error).join(' ');
            handleError(this, error, { context: 'feedbackHome.overview', toast: false });
        }
        this.loading = !data && !error;
    }

    // ----- view model -----
    get greetingText() {
        return this.firstName ? `${greeting()}, ${this.firstName}` : greeting();
    }

    get todayLabel() {
        return new Date().toLocaleDateString(undefined, { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' });
    }

    get updatedLabel() {
        return this.updatedAt ? `Updated ${this.updatedAt.toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' })}` : '';
    }

    get counts() {
        const o = this.overview;
        return {
            [TAB_SECTIONS]: o ? o.activeSectionCount : null,
            [TAB_PARAMETERS]: o ? o.activeParameterCount : null,
            [TAB_SCHEDULING]: o ? o.scheduleCount : null
        };
    }

    get tabs() {
        return TABS.map((tab) => {
            const count = this.counts[tab.value];
            const selected = tab.value === this.activeTab;
            return {
                ...tab,
                selected: String(selected),
                tabindex: selected ? '0' : '-1',
                count,
                hasCount: count !== null && count !== undefined
            };
        });
    }

    get isOverview() {
        return this.activeTab === TAB_OVERVIEW;
    }
    get isSections() {
        return this.activeTab === TAB_SECTIONS;
    }
    get isParameters() {
        return this.activeTab === TAB_PARAMETERS;
    }
    get isScheduling() {
        return this.activeTab === TAB_SCHEDULING;
    }
    get isResponses() {
        return this.activeTab === TAB_RESPONSES;
    }
    get isReports() {
        return this.activeTab === TAB_REPORTS;
    }

    // ----- navigation -----
    selectTab(value) {
        this.activeTab = value;
    }

    handleTabClick(event) {
        this.selectTab(event.currentTarget.dataset.value);
    }

    handleTabKeydown(event) {
        const keys = { ArrowRight: 1, ArrowLeft: -1 };
        if (!(event.key in keys)) {
            return;
        }
        event.preventDefault();
        const index = TABS.findIndex((t) => t.value === this.activeTab);
        const next = TABS[(index + keys[event.key] + TABS.length) % TABS.length];
        this.selectTab(next.value);
        this.template.querySelector(`[data-value="${next.value}"]`)?.focus();
    }

    handleOpenTab(event) {
        this.selectTab(event.detail.tab);
    }

    handleOpenParameters(event) {
        this.sectionId = event.detail.sectionId;
        this.selectTab(TAB_PARAMETERS);
    }

    handleOpenResponses(event) {
        this.schedulerId = event.detail.schedulerId;
        this.selectTab(TAB_RESPONSES);
    }

    // ----- actions -----
    handleRefresh() {
        this.loading = true;
        refreshApex(this.wiredOverviewResult).finally(() => {
            this.loading = false;
        });
    }

    handleNewSchedule() {
        this[NavigationMixin.Navigate](newRecordPage('Feedback_Scheduler__c'));
    }

    handleNewSection() {
        this[NavigationMixin.Navigate](newRecordPage('Questionnaire_Metadata__c'));
    }
}