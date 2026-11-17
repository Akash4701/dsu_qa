import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getErrorMessage } from 'c/errorUtils';
import { NavigationMixin } from 'lightning/navigation';
import { CurrentPageReference } from 'lightning/navigation';
import { wire } from 'lwc';
import getCourseOfferings from '@salesforce/apex/FeedbackSchedulerController.getCourseOfferings';
import getFeedbackType from '@salesforce/apex/FeedbackSchedulerController.getFeedbackType';
import createSchedulerWithItems from '@salesforce/apex/FeedbackSchedulerController.createSchedulerWithItems';

export default class FeedbackSchedulerForm extends NavigationMixin(LightningElement) {
    @api objectApiName = 'Feedback_Scheduler__c';
    @api recordId;
    @track description;
    
    @track feedbackMasterId;
    @track termId;
    @track startDate;
    @track endDate;
    @track feedbackType;
    
    @track courseOfferings = [];
    @track selectedOfferingIds = [];
    @track selectedOfferingsDisplay = [];
    
    @track showModal = false;
    @track isLoadingOfferings = false;
    @track isSaving = false;
    @track isAllSelected = false;

    get showCourseOfferingsSection() {
    if (!this.feedbackType) return false;
    const t = this.feedbackType.toLowerCase();
    return t.includes('interim') || t.includes('final');
}
@wire(CurrentPageReference)
handlePageChange(pageRef) {
    if (pageRef && pageRef.type === 'standard__objectPage'
        && pageRef.attributes?.actionName === 'new') {
        this.resetForm();
    }
}

    handleDescriptionChange(event) {
    this.description = event.detail.value;
    }


    get hasCourseOfferings() {
        return this.courseOfferings && this.courseOfferings.length > 0;
    }

    get hasSelectedOfferings() {
        return this.selectedOfferingsDisplay && this.selectedOfferingsDisplay.length > 0;
    }

    get isConfirmDisabled() {
    return !this.courseOfferings.some(o => o.isSelected);
}

    handleFeedbackMasterChange(event) {
    const val = event.target.value;
    this.feedbackMasterId = val;
    this.feedbackType = null;

    if (!val || !/^[a-zA-Z0-9]{15,18}$/.test(val)) {
        console.log('Invalid Feedback Master Id:', val);
        return;
    }

    getFeedbackType({ feedbackMasterId: val })
        .then(result => {
            this.feedbackType = result;
            this.selectedOfferingIds = [];
            this.selectedOfferingsDisplay = [];
        })
        .catch(error => {
            const msg = getErrorMessage(error);
            this.showToast('Error', 'Failed to fetch feedback type: ' + msg, 'error');
            console.error('getFeedbackType error:', error);
        });
}



    handleTermChange(event) {
    const val = event.target.value;
    this.termId = val;

    this.selectedOfferingIds = [];
    this.selectedOfferingsDisplay = [];
    this.courseOfferings = [];
}


    handleStartDateChange(event) {
        this.startDate = event.detail.value;
    }

    handleEndDateChange(event) {
        this.endDate = event.detail.value;
    }

    openCourseOfferingModal() {
        if (!this.termId) {
            this.showToast('Warning', 'Please select a Term first', 'warning');
            return;
        }

        this.isLoadingOfferings = true;
        this.showModal = true;

        getCourseOfferings({ termId: this.termId })
            .then(result => {
                this.courseOfferings = result.map(offering => {
                    let courseName = '';
                    let courseCode = '';
                    let facultyName = '';
                    let dateRange = '';

                    if (offering.hed__Course__r) {
                        courseName = offering.hed__Course__r.Name || '';
                        courseCode = offering.hed__Course__r.hed__Course_ID__c || '';
                    }

                    if (offering.hed__Faculty__r) {
                        facultyName = offering.hed__Faculty__r.Name || '';
                    }

                    if (offering.hed__Start_Date__c && offering.hed__End_Date__c) {
                        dateRange = `${offering.hed__Start_Date__c} to ${offering.hed__End_Date__c}`;
                    }

                    return {
                        Id: offering.Id,
                        Name: offering.Name,
                        isSelected: this.selectedOfferingIds.includes(offering.Id),
                        courseName: courseName,
                        courseCode: courseCode,
                        facultyName: facultyName,
                        dateRange: dateRange
                    };
                });
                this.isLoadingOfferings = false;
                this.updateSelectAllState();
            })
            .catch(error => {
                this.showToast('Error', 'Failed to load course offerings: ' + getErrorMessage(error), 'error');
                console.error('Error loading course offerings:', error);
                this.isLoadingOfferings = false;
                this.showModal = false;
            });
    }

    closeCourseOfferingModal() {
        this.showModal = false;
    }

    handleOfferingSelection(event) {
    const offeringId = event.target.name;
    const isChecked = event.target.checked;

    this.courseOfferings = this.courseOfferings.map(offering => {
        if (offering.Id === offeringId) {
            return { ...offering, isSelected: isChecked };
        }
        return offering;
    });

    this.selectedOfferingIds = this.courseOfferings
        .filter(o => o.isSelected)
        .map(o => o.Id);

    this.updateSelectAllState();
}


    handleSelectAll(event) {
        const isChecked = event.target.checked;
        this.isAllSelected = isChecked;

        this.courseOfferings = this.courseOfferings.map(offering => ({
            ...offering,
            isSelected: isChecked
        }));
    }

    updateSelectAllState() {
        const selectedCount = this.courseOfferings.filter(o => o.isSelected).length;
        this.isAllSelected = selectedCount === this.courseOfferings.length && this.courseOfferings.length > 0;
    }

    handleConfirmSelection() {
        this.selectedOfferingIds = this.courseOfferings
            .filter(offering => offering.isSelected)
            .map(offering => offering.Id);

        this.selectedOfferingsDisplay = this.courseOfferings
            .filter(offering => offering.isSelected)
            .map(offering => ({
                id: offering.Id,
                name: offering.Name
            }));

        this.showModal = false;
    }

    handleRemoveOffering(event) {
        const offeringId = event.detail.item.name;
        this.selectedOfferingIds = this.selectedOfferingIds.filter(id => id !== offeringId);
        this.selectedOfferingsDisplay = this.selectedOfferingsDisplay.filter(o => o.id !== offeringId);
    }

    handleSave() {
    if (!this.feedbackMasterId || !this.termId || !this.startDate || !this.endDate) {
        this.showToast('Error', 'Please fill all required fields', 'error');
        return;
    }

    this.isSaving = true;

    if (this.showCourseOfferingsSection) {
        if (this.selectedOfferingIds.length === 0) {
            this.showToast('Error', 'Please select at least one Course Offering', 'error');
            this.isSaving = false;
            return;
        }

        this.createScheduler(this.selectedOfferingIds);
        return;
    }

    this.createScheduler([]);
}

createScheduler(offeringIds) {
    createSchedulerWithItems({
        feedbackMasterId: this.feedbackMasterId,
        termId: this.termId,
        startDate: this.startDate,
        dueDate: this.endDate,
        feedbackName: this.description,
        courseOfferingIds: offeringIds
    })
    .then(result => {
        this.showToast('Success', 'Feedback Scheduler created successfully', 'success');
            this.isSaving = false;  
        this.navigateToRecord(result);
    })
    .catch(error => {
        this.showToast('Error', getErrorMessage(error), 'error');
        console.error(error);
        this.isSaving = false;
    });
}


    handleCancel() {
        this.navigateToListView();
    }

    navigateToRecord(recordId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: 'Feedback_Scheduler__c',
                actionName: 'view'
            }
        });
    }

    navigateToListView() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Feedback_Scheduler__c',
                actionName: 'list'
            },
            state: {
                filterName: 'Recent'
            }
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }
    connectedCallback() {
    this.resetForm();
}


    @api invoke() {
    }
    resetForm() {
    this.feedbackMasterId = null;
    this.termId = null;
    this.startDate = null;
    this.endDate = null;
    this.feedbackType = null;

    this.courseOfferings = [];
    this.selectedOfferingIds = [];
    this.selectedOfferingsDisplay = [];

    this.showModal = false;
    this.isLoadingOfferings = false;
    this.isSaving = false;
    this.isAllSelected = false;
    this.description = null;

}

}