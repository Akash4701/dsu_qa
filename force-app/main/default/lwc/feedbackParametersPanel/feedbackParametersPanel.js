import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getParameters from '@salesforce/apex/FeedbackHomeController.getParameters';
import getParameterSections from '@salesforce/apex/FeedbackHomeController.getParameterSections';
import { reduceErrors, handleError } from 'c/errorUtils';
import { recordPage, newRecordPage, matchesSearch, plural } from 'c/feedbackHomeUtils';

const ALL_SECTIONS = '';
const ALL_TYPES = 'All types';
const UNGROUPED = 'none';

export default class FeedbackParametersPanel extends NavigationMixin(LightningElement) {
    selectedSection = null;
    rows = [];
    sectionOptions = [{ label: 'All sections', value: ALL_SECTIONS }];
    error;
    loading = true;
    search = '';
    typeFilter = ALL_TYPES;
    mandatoryOnly = false;
    collapsed = {};
    wiredResult;

    @api
    get sectionId() {
        return this.selectedSection;
    }
    set sectionId(value) {
        this.selectedSection = value || null;
    }

    @wire(getParameterSections, { recordTypeDeveloperName: null })
    wiredSections({ data }) {
        if (data) {
            this.sectionOptions = [
                { label: 'All sections', value: ALL_SECTIONS },
                ...data.map((s) => ({ label: `${s.name} (${s.recordTypeLabel})`, value: s.id }))
            ];
        }
    }

    @wire(getParameters, { sectionId: '$selectedSection' })
    wiredParameters(result) {
        this.wiredResult = result;
        const { data, error } = result;
        if (data) {
            this.rows = data;
            this.error = undefined;
        } else if (error) {
            this.rows = [];
            this.error = reduceErrors(error).join(' ');
            handleError(this, error, { context: 'feedbackParametersPanel', toast: false });
        }
        this.loading = !data && !error;
    }

    get comboValue() {
        return this.selectedSection || ALL_SECTIONS;
    }

    get sectionSelectOptions() {
        return this.sectionOptions.map((option) => ({ ...option, selected: option.value === this.comboValue }));
    }

    get typeChips() {
        const types = [...new Set(this.rows.map((r) => r.questionType).filter(Boolean))].sort();
        return [ALL_TYPES, ...types].map((label) => ({ label, pressed: String(label === this.typeFilter) }));
    }

    get mandatoryPressed() {
        return String(this.mandatoryOnly);
    }

    get filteredRows() {
        return this.rows
            .filter((r) => this.typeFilter === ALL_TYPES || r.questionType === this.typeFilter)
            .filter((r) => !this.mandatoryOnly || r.mandatory)
            .filter((r) => matchesSearch(this.search, r.question, r.label, r.name, r.sectionName));
    }

    get groups() {
        const byId = new Map();
        this.filteredRows.forEach((r) => {
            const key = r.sectionId || UNGROUPED;
            if (!byId.has(key)) {
                byId.set(key, { id: key, name: r.sectionName || 'No section', items: [] });
            }
            byId.get(key).items.push({
                ...r,
                title: r.question || r.label || r.name,
                position: r.sortOrder === null || r.sortOrder === undefined ? '•' : r.sortOrder,
                maxGradeLabel: r.maxGrade === null || r.maxGrade === undefined ? null : `Max ${r.maxGrade}`,
                rowClass: r.active ? 'param' : 'param param_off'
            });
        });
        return [...byId.values()].map((g) => {
            const open = !this.collapsed[g.id];
            return {
                ...g,
                open,
                countLabel: plural(g.items.length, 'parameter'),
                chevron: open ? 'utility:chevrondown' : 'utility:chevronright',
                expanded: String(open)
            };
        });
    }

    get resultLabel() {
        return plural(this.filteredRows.length, 'parameter');
    }

    get showSkeleton() {
        return this.loading && this.rows.length === 0;
    }

    get hasRows() {
        return this.filteredRows.length > 0;
    }

    get isEmpty() {
        return !this.loading && !this.error && !this.hasRows;
    }

    get emptyMessage() {
        return this.rows.length === 0 ? 'Add parameters to a section so respondents have questions to answer.' : 'No parameters match your filters.';
    }

    handleSection(event) {
        this.loading = true;
        this.selectedSection = event.target.value || null;
    }

    handleSearch(event) {
        this.search = event.target.value;
    }

    handleType(event) {
        this.typeFilter = event.currentTarget.dataset.label;
    }

    handleMandatory() {
        this.mandatoryOnly = !this.mandatoryOnly;
    }

    handleToggleGroup(event) {
        const id = event.currentTarget.dataset.id;
        this.collapsed = { ...this.collapsed, [id]: !this.collapsed[id] };
    }

    handleRefresh() {
        this.loading = true;
        refreshApex(this.wiredResult).finally(() => {
            this.loading = false;
        });
    }

    handleNew() {
        this[NavigationMixin.Navigate](newRecordPage('Question_Metadata__c'));
    }

    handleOpenRecord(event) {
        this[NavigationMixin.Navigate](recordPage(event.currentTarget.dataset.id));
    }
}