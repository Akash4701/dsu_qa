import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import calculateSgpaForTerm from '@salesforce/apex/CalculateSgpaController.calculateSgpaForTerm';

export default class GenerateSGPA extends LightningElement {

    @api recordId; // This will be hed__Term__c.Id

    @api async invoke() {
        try {
            await calculateSgpaForTerm({ termId: this.recordId });
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'SGPA Populated',
                    message: 'SGPA Successfully Calculated and Assigned',
                    variant: 'success',
                })
            );
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error Calculating SGPA',
                    message: error.body.message,
                    variant: 'error',
                })
            );
        }
    }
}