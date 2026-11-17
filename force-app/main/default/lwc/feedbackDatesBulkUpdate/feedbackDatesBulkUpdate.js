import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getErrorMessage } from 'c/errorUtils';
import { CurrentPageReference } from 'lightning/navigation';
import getFeedbackSchedulers from '@salesforce/apex/FeedbackDatesBulkUpdateController.getFeedbackSchedulers';
import getUniqueCourseOfferings from '@salesforce/apex/FeedbackDatesBulkUpdateController.getUniqueCourseOfferings';
import updateFeedbackDates from '@salesforce/apex/FeedbackDatesBulkUpdateController.updateFeedbackDates';

const SCHEDULER_COLUMNS = [
    { label: 'Feedback Scheduler', fieldName: 'Name' },
    { label: 'Description', fieldName: 'Description__c' },
    { label: 'Term', fieldName: 'termName' },
    { label: 'Start Date', fieldName: 'Start_Date__c', type: 'date-local' },
    { label: 'End Date', fieldName: 'End_Date__c', type: 'date-local' }
];

const COURSE_OFFERING_COLUMNS = [
    { label: 'Course Offering', fieldName: 'courseOfferingName' },
    { label: 'Feedback Start Date', fieldName: 'startDate', type: 'date-local', editable: true },
    { label: 'Feedback End Date', fieldName: 'endDate', type: 'date-local', editable: true }
];

export default class FeedbackDatesBulkUpdate extends LightningElement {
    @api recordId;

    isLoading = false;
    step = 1;

    schedulerColumns = SCHEDULER_COLUMNS;
    courseOfferingColumns = COURSE_OFFERING_COLUMNS;

    schedulers = [];
    selectedSchedulerIds = [];

    courseOfferings = [];
    draftValues = [];

    wiredSchedulersResult;

    resolvedRecordId;
    pageRefApplied = false;

    get isSingleSchedulerMode() {
        return !!this.resolvedRecordId;
    }

    @wire(CurrentPageReference)
    setCurrentPageReference(pageRef) {
        if (this.pageRefApplied) {
            return;
        }
        const idFromPageRef =
            pageRef?.attributes?.recordId ||
            pageRef?.state?.recordId ||
            pageRef?.state?.inContextOfRef?.attributes?.recordId;
        const idToUse = this.recordId || idFromPageRef;
        if (idToUse) {
            this.pageRefApplied = true;
            this.resolvedRecordId = idToUse;
            this.selectedSchedulerIds = [idToUse];
            this.loadCourseOfferings();
        }
    }

    connectedCallback() {
        if (this.recordId && !this.pageRefApplied) {
            this.pageRefApplied = true;
            this.resolvedRecordId = this.recordId;
            this.selectedSchedulerIds = [this.recordId];
            this.loadCourseOfferings();
        }
    }

    @wire(getFeedbackSchedulers)
    wiredSchedulers(result) {
        this.wiredSchedulersResult = result;
        const { data, error } = result;
        if (data) {
            this.schedulers = data.map((fs) => ({
                ...fs,
                termName: fs.Term__r ? fs.Term__r.Name : ''
            }));
        } else if (error) {
            this.showToast('Error', this.reduceError(error), 'error');
        }
    }

    get isStepOne() {
        return this.step === 1 && !this.isSingleSchedulerMode;
    }

    get isStepTwo() {
        return this.step === 2;
    }

    get isNextDisabled() {
        return this.selectedSchedulerIds.length === 0;
    }

    handleSchedulerSelection(event) {
        this.selectedSchedulerIds = event.detail.selectedRows.map((row) => row.Id);
    }

    handleNext() {
        if (this.selectedSchedulerIds.length === 0) {
            this.showToast('Error', 'Select at least one Feedback Scheduler.', 'error');
            return;
        }
        return this.loadCourseOfferings();
    }

    loadCourseOfferings() {
        this.isLoading = true;
        return getUniqueCourseOfferings({ selectedSchedulerIds: this.selectedSchedulerIds })
            .then((data) => {
                this.courseOfferings = data.map((wrapper) => ({ ...wrapper }));
                this.draftValues = [];
                this.step = 2;
            })
            .catch((error) => {
                this.showToast('Error', this.reduceError(error), 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleBack() {
        if (this.isSingleSchedulerMode) {
            return;
        }
        this.step = 1;
        this.courseOfferings = [];
        this.draftValues = [];
    }

    handleCellChange(event) {
        // cellchange only carries the just-edited cell, so merge it into the
        // existing drafts instead of replacing them (otherwise editing a second
        // column discards the first edit).
        const merged = [...this.draftValues];
        event.detail.draftValues.forEach((draft) => {
            const index = merged.findIndex((d) => d.courseOfferingId === draft.courseOfferingId);
            if (index === -1) {
                merged.push({ ...draft });
            } else {
                merged[index] = { ...merged[index], ...draft };
            }
        });
        this.draftValues = merged;
    }

    handleCancelEdit() {
        this.draftValues = [];
    }

    handleSave(event) {
        const draftValues = event.detail.draftValues;
        if (!draftValues || draftValues.length === 0) {
            this.showToast('Info', 'No changes to save.', 'info');
            return;
        }

        const draftsByCourseOfferingId = new Map();
        draftValues.forEach((draft) => {
            draftsByCourseOfferingId.set(draft.courseOfferingId, draft);
        });

        const wrappers = this.courseOfferings
            .filter((co) => draftsByCourseOfferingId.has(co.courseOfferingId))
            .map((co) => {
                const draft = draftsByCourseOfferingId.get(co.courseOfferingId);
                return {
                    courseOfferingId: co.courseOfferingId,
                    startDate: draft.startDate !== undefined ? draft.startDate : co.startDate,
                    endDate: draft.endDate !== undefined ? draft.endDate : co.endDate
                };
            });

        this.isLoading = true;
        updateFeedbackDates({
            courseOfferingDatesJson: JSON.stringify(wrappers),
            selectedSchedulerIds: this.selectedSchedulerIds
        })
            .then(() => {
                this.showToast('Success', 'Feedback dates updated successfully.', 'success');
                this.draftValues = [];
                return this.loadCourseOfferings();
            })
            .catch((error) => {
                this.showToast('Error', this.reduceError(error), 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    reduceError(error) {
        if (error && error.body && error.body.message) {
            return getErrorMessage(error);
        }
        return 'An unknown error occurred.';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}