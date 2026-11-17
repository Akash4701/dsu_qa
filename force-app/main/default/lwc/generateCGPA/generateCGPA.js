import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import calculateCgpaForProgramPlan from '@salesforce/apex/CalculateCgpaController.calculateCgpaForProgramPlan';

export default class GenerateCGPA extends LightningElement {
    @api recordId; // hed__Program_Plan__c.Id

    @api async invoke() {
        try {
            await calculateCgpaForProgramPlan({ programPlanId: this.recordId });
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'CGPA Calculation Complete',
                    message: 'CGPA updated for eligible student affiliations.',
                    variant: 'success'
                })
            );
        } catch (error) {
            // Only show error if Apex throws (e.g., governor limit)
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error Calculating CGPA',
                    message: error.body?.message || 'An unknown error occurred. Check debug logs for details.',
                    variant: 'error'
                })
            );
        }
    }
}