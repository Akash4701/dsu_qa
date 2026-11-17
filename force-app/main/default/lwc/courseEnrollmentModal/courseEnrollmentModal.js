import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import ACADEMIC_TERM_NAME from '@salesforce/schema/Academic_Term__c.Name';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class CourseEnrollmentModal extends LightningElement {
    @api recordId; // Academic Term record Id
    academicTermName;

    @wire(getRecord, { recordId: '$recordId', fields: [ACADEMIC_TERM_NAME] })
    wiredTerm({ data, error }) {
        if (data) {
            this.academicTermName = getFieldValue(data, ACADEMIC_TERM_NAME);
        } else if (error) {
            this.academicTermName = 'Unavailable';
        }
    }

    handleSubmit(event) {
        event.preventDefault();
        const fields = event.detail.fields;
        fields.Academic_Term__c = this.recordId;
        this.template.querySelector('lightning-record-edit-form').submit(fields);
    }

    handleSuccess() {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message: 'Course Enrollment created successfully.',
                variant: 'success'
            })
        );
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    handleError(event) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: event.detail.message,
                variant: 'error'
            })
        );
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}