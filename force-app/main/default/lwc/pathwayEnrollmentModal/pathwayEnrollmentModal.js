import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import PROGRAM_PATHWAY_NAME from '@salesforce/schema/Program_Pathway__c.Name';

export default class PathwayEnrollmentModal extends LightningElement {
    @api recordId; // Program Pathway record
    programPathwayName;

    @wire(getRecord, { recordId: '$recordId', fields: [PROGRAM_PATHWAY_NAME] })
    wiredProgramPathway({ error, data }) {
        if (data) {
            this.programPathwayName = getFieldValue(data, PROGRAM_PATHWAY_NAME);
        } else {
            this.programPathwayName = 'Unknown';
        }
    }

    handleSubmit(event) {
        event.preventDefault();
        const fields = event.detail.fields;
        fields.Program_Pathway__c = this.recordId;
        this.template.querySelector('lightning-record-edit-form').submit(fields);
    }

    handleSuccess() {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message: 'Pathway Enrollment Management created successfully.',
                variant: 'success'
            })
        );
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    handleError(event) {
        const message = event.detail?.message || 'An error occurred while saving.';
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message,
                variant: 'error'
            })
        );
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}