import { LightningElement, wire, track, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getOptions from '@salesforce/apex/EventFormController.getPicklistValues';
import saveData from '@salesforce/apex/EventFormController.saveData';

export default class EventHandler extends NavigationMixin(LightningElement) {
    @track isEventGroup = false;
    @track isLoading = false;
    @track selectedValues = [];
    @track eventGroupId;
    @track imageUrl;
    @track imageFile;
    @track isFileInputVisible = true;
    @track fields = {
        Id: '',
        contentDocumentId: '',
        isEventGroup: false,
        eventTitle: '',
        eventGroupId: '',
        eventGroupTitle: '',
        eventTypes: '',
        description: '',
        agenda: '',
        startdate: '',
        enddate: '',
        image: '',
        imageFileName: '',
        maximumNumberOfParticipants: null
    };
    @track parentOptions = [];
    @track apiname = 'Event_Master__c';
    @track objecticonname = 'standard:event';
    @track recordtype = 'Event_Group';

    @wire(getOptions, { objectName: 'Event_Master__c', fieldNames: ['Event_Type__c'] })
    wiredOptions({ error, data }) {
        if (data) {
            console.log('data', data);
            this.parentOptions = data?.Event_Type__c?.map(option => ({
                label: option.label,
                value: option.label,
                show: true,
                checked: false
            }));
            console.log('this.options', this.parentOptions);
        } else if (error) {
            console.error('Error fetching picklist values:', error);
        }
    }

    handleCheckboxChange(event) {
        this.isLoading = true;
        this.isEventGroup = event.target.checked;
        this.fields.isEventGroup = this.isEventGroup;
        this.isLoading = false;
    }

    handleLookupUpdate(event) {
        const selectedRecord = event.detail.selectedRecord;
        if (selectedRecord && selectedRecord.Id) {
            console.log('Selected Record ID: ' + selectedRecord.Id);
            this.selectedRecordId = selectedRecord.Id;
            this.eventGroupId = selectedRecord.Id;
            this.fields.eventGroupId = this.eventGroupId;
        }
    }

    handleSelection(event) {
        this.selectedValues = event.detail;
        this.fields.eventTypes = this.selectedValues;
        console.log('Selected values:', this.selectedValues);
    }

    handleInputChange(event) {
        const field = event.target.dataset.id;
        const value = event.target.value;
        this.fields[field] = value;

        this.validateField(field, event.target);

        if (field === 'startdate' || field === 'enddate') {
            this.validateDateRange();
        }
    }

    validateDateRange() {
        const start = this.fields.startdate;
        const end = this.fields.enddate;

        const today = new Date();
        today.setHours(0, 0, 0, 0); // Reset time to compare just the date

        let isValid = true;

        const startInput = this.template.querySelector('[data-id="startdate"]');
        const endInput = this.template.querySelector('[data-id="enddate"]');

        if (start) {
            const startDate = new Date(start);
            if (startDate < today) {
                this.setCustomValidity(startInput, false, 'Start Date cannot be in the past.');
                isValid = false;
            } else {
                this.setCustomValidity(startInput, true, '');
            }
        }

        if (end) {
            const endDate = new Date(end);
            if (endDate < today) {
                this.setCustomValidity(endInput, false, 'End Date cannot be in the past.');
                isValid = false;
            } else {
                this.setCustomValidity(endInput, true, '');
            }
        }

        if (start && end && new Date(start) > new Date(end)) {
            this.setCustomValidity(startInput, false, 'Start Date must be earlier than End Date.');
            this.setCustomValidity(endInput, false, 'End Date must be later than Start Date.');
            isValid = false;
        }

        return isValid;
    }

    handleCancel() {
        const evt = new ShowToastEvent({
            title: 'Canceled',
            message: 'Canceled creating Event',
            variant: 'error',
        });
        this.dispatchEvent(evt);
        history.back();
        this.dispatchEvent(new CustomEvent('close'));
    }

    async handleSaveAndProceed() {
        if (this.imageFile) {
            this.fields.image = await this.convertToBase64(this.imageFile);
        }
        if (!this.validateEventFields() || !this.validateDateRange()) {
            this.showToast(
                'Error',
                'Please fix all the errors in the form before saving.',
                'error'
            );
            return;
        }

        saveData({ eventData: JSON.stringify(this.fields) })
            .then(result => {
                console.log('Data saved successfully:', result);
                this.fields.Id = result;
                this.navigateToRecord(result);
            })
            .catch(error => {
                console.error('Error saving data:', error);
            });
    }

    async handleSaveAsDraft() {
        if (this.imageFile) {
            this.fields.image = await this.convertToBase64(this.imageFile);
        }

        if (!this.validateEventFields() || !this.validateDateRange()) {
            this.showToast(
                'Error',
                'Please fix all the errors in the form before saving.',
                'error'
            );
            return;
        }

        saveData({ eventData: JSON.stringify(this.fields) })
            .then(result => {
                console.log('Data saved successfully:', result);
                this.fields.Id = result;
                // Navigate to the record page using the ID returned from Apex
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: result,
                        objectApiName: 'Event_Master__c',
                        actionName: 'view'
                    }
                });
            })
            .catch(error => {
                console.error('Error saving data:', error);
            });
    }

    navigateToRecord(recordId) {
        if (this.isEventGroup) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: recordId,
                    objectApiName: 'Event_Master__c',
                    actionName: 'view'
                }
            });
        } else {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: recordId,
                    objectApiName: 'Event_Master__c',
                    actionName: 'edit'
                }
            });
        }

    }

    handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        this.fields.contentDocumentId = uploadedFiles[0].documentId;
        console.log('Files uploaded: ', uploadedFiles);
        console.log('Files uploaded: ', this.fields.contentDocumentId);
    }

    handleFileChange(event) {
        console.log('event', event);
        console.log('event', event.target.files[0].name);
        const file = event.target.files[0];
        if (file) {
            this.createImagePreview(file);
            this.imageFile = file;
            this.fields.imageFileName = event.target.files[0].name;
            this.isFileInputVisible = false; // Hide file input when image is selected
        }
    }

    openFileDialog() {
        // Open the hidden file input
        this.template.querySelector('input[type="file"]').click();
    }

    createImagePreview(file) {
        const reader = new FileReader();
        reader.onloadend = () => {
            this.imageUrl = reader.result;
        };
        reader.readAsDataURL(file);
    }

    removeImage() {
        this.imageUrl = null;
        this.imageFile = null;
        this.isFileInputVisible = true; // Show file input again
    }

    convertToBase64(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onloadend = () => resolve(reader.result.split(',')[1]); // Remove the data URL prefix
            reader.onerror = reject;
            reader.readAsDataURL(file);
        });
    }

    validateEventFields() {
        let fieldsToValidate = [
            'description',
            'agenda',
            'enddate',
            'startdate',
            'maximumNumberOfParticipants'
        ];

        fieldsToValidate.push(this.isEventGroup ? 'eventGroupTitle' : 'eventTitle');

        let isValid = true;

        fieldsToValidate.forEach(field => {
            const inputField = this.template.querySelector(`[data-id="${field}"]`);
            if (!this.validateField(field, inputField)) {
                isValid = false;
            }
        });

        return isValid;
    }

    validateField(field, inputElement) {
        const value = this.fields[field];

        // Required field
        if (!this.isValidInput(value)) {
            this.setCustomValidity(inputElement, false, 'This field is required.');
            return false;
        }

        // Specific field validations
        if ((field === 'description' || field === 'agenda') &&
            (value.length < 10 || value.length > 1000)) {
            this.setCustomValidity(inputElement, false, `${field} should be between 10 and 1000 characters.`);
            return false;
        }

        if (field === 'maximumNumberOfParticipants' && Number(value) < 0) {
            this.setCustomValidity(inputElement, false, 'Maximum Number of Participants should be greater than 0.');
            return false;
        }

        this.setCustomValidity(inputElement, true, '');
        return true;
    }


    isValidInput(value) {
        return !(value === '' || value === null || value === undefined);
    }

    get todayDate() {
        const today = new Date();
        const yyyy = today.getFullYear();
        const mm = String(today.getMonth() + 1).padStart(2, '0');
        const dd = String(today.getDate()).padStart(2, '0');
        return `${yyyy}-${mm}-${dd}`;
    }

    setCustomValidity(inputField, isValid, message) {
        if (inputField) {
            inputField.setCustomValidity(isValid ? '' : message);
            inputField.reportValidity();
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}