import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getOptions from '@salesforce/apex/AnnouncementAudienceController.getOptions';
import saveAudience from '@salesforce/apex/AnnouncementAudienceController.saveAudience';

// PKDSU-199: replaces the standard New Announcement dialog so the audience (Accounts and Program
// Plans, saved as Announcement Audience rows) can be chosen while creating the announcement.
// Nothing selected = visible to all students.
export default class AnnouncementNew extends NavigationMixin(LightningElement) {
    accountOptions = [];
    allProgramPlans = [];
    selectedAccountIds = [];
    selectedProgramPlanIds = [];
    isActiveDefault = true;
    isSaving = false;

    @wire(getOptions)
    wiredOptions({ data, error }) {
        if (data) {
            this.accountOptions = data.accounts.map(({ label, value }) => ({ label, value }));
            this.allProgramPlans = data.programPlans;
        } else if (error) {
            this.toast('Error', this.errorMessage(error), 'error');
        }
    }

    // Program Plans of the selected Accounts (all when none selected); selected plans always stay listed
    get programPlanOptions() {
        const accounts = new Set(this.selectedAccountIds);
        const selected = new Set(this.selectedProgramPlanIds);
        return this.allProgramPlans
            .filter((plan) => !accounts.size || accounts.has(plan.accountId) || selected.has(plan.value))
            .map(({ label, value }) => ({ label, value }));
    }

    get audienceSummary() {
        const accounts = this.selectedAccountIds.length;
        const plans = this.selectedProgramPlanIds.length;
        if (!accounts && !plans) {
            return 'Visible to all students';
        }
        const parts = [];
        if (accounts) {
            parts.push(`${accounts} Account${accounts === 1 ? '' : 's'}`);
        }
        if (plans) {
            parts.push(`${plans} Program Plan${plans === 1 ? '' : 's'}`);
        }
        return `Visible to ${parts.join(' and ')}`;
    }

    handleAccountChange(event) {
        this.selectedAccountIds = event.detail.value;
    }

    handleProgramPlanChange(event) {
        this.selectedProgramPlanIds = event.detail.value;
    }

    handleSave() {
        this.isSaving = true;
        // Submits the record form; the audience is saved once the announcement exists
        this.template.querySelector('[data-id="submit"]').click();
    }

    async handleSuccess(event) {
        const recordId = event.detail.id;
        try {
            await saveAudience({
                announcementId: recordId,
                accountIds: this.selectedAccountIds,
                programPlanIds: this.selectedProgramPlanIds
            });
            this.toast('Announcement created', this.audienceSummary, 'success');
        } catch (error) {
            // The announcement exists; the audience can be fixed from the Announcement Audiences related list
            this.toast('Announcement created, audience not saved', this.errorMessage(error), 'warning');
        }
        this.isSaving = false;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId, objectApiName: 'Announcement__c', actionName: 'view' }
        });
    }

    handleError() {
        // Field errors are shown by lightning-messages
        this.isSaving = false;
    }

    handleCancel() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Announcement__c', actionName: 'list' },
            state: { filterName: 'Recent' }
        });
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    errorMessage(error) {
        return (error && error.body && error.body.message) || (error && error.message) || 'Something went wrong';
    }
}