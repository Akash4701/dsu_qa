import { LightningElement, api } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';
import { RefreshEvent } from 'lightning/refresh';
import getConfig from '@salesforce/apex/AnnouncementProgramPlanController.getConfig';
import saveMappings from '@salesforce/apex/AnnouncementProgramPlanController.saveMappings';

// PKDSU-199: "Program Plans" action on Announcement - limits the announcement to selected
// Program Plans and semesters. No Program Plans selected = visible to all students.
export default class AnnouncementProgramPlans extends LightningElement {
    programPlanOptions = [];
    semesterOptions = [];
    selectedProgramPlanIds = [];
    selectedSemesters = [];
    isLoading = true;
    _recordId;

    // Quick actions receive recordId after construction, so load once it arrives
    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        this._recordId = value;
        if (value) {
            this.loadConfig();
        }
    }

    get noProgramPlansSelected() {
        return this.selectedProgramPlanIds.length === 0;
    }

    get visibilitySummary() {
        if (this.noProgramPlansSelected) {
            return 'Visible to all students';
        }
        const plans = this.selectedProgramPlanIds.length;
        const semesters = this.selectedSemesters.length
            ? this.selectedSemesters.join(', ')
            : 'all semesters';
        return `Visible to ${plans} Program Plan${plans === 1 ? '' : 's'}, ${semesters}`;
    }

    async loadConfig() {
        this.isLoading = true;
        try {
            const config = await getConfig({ announcementId: this._recordId });
            this.programPlanOptions = config.programPlans;
            this.semesterOptions = config.semesters;
            this.selectedProgramPlanIds = config.selectedProgramPlanIds || [];
            this.selectedSemesters = config.selectedSemesters || [];
        } catch (error) {
            this.toast('Error', this.errorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleProgramPlanChange(event) {
        this.selectedProgramPlanIds = event.detail.value;
        if (this.noProgramPlansSelected) {
            this.selectedSemesters = [];
        }
    }

    handleSemesterChange(event) {
        this.selectedSemesters = event.detail.value;
    }

    async handleSave() {
        this.isLoading = true;
        try {
            await saveMappings({
                announcementId: this._recordId,
                programPlanIds: this.selectedProgramPlanIds,
                semesters: this.selectedSemesters
            });
            this.toast('Saved', this.visibilitySummary, 'success');
            getRecordNotifyChange([{ recordId: this._recordId }]);
            this.dispatchEvent(new RefreshEvent());
            this.dispatchEvent(new CloseActionScreenEvent());
        } catch (error) {
            this.toast('Error', this.errorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    errorMessage(error) {
        return (error && error.body && error.body.message) || (error && error.message) || 'Something went wrong';
    }
}