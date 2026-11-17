import { LightningElement,api } from 'lwc';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';


import populateGrade from "@salesforce/apex/populateGradingOnFinalSubController.populateGrade";

export default class PopulateGradingOnFinalSubmission extends LightningElement {
    @api recordId;

    @api async invoke(){
        try {
            await populateGrade({courseOfferingId : this.recordId});
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Grades Populated',
                    message: 'Grades Successfully Assigned',
                    variant: 'success',
                })
            );
        }catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error Assigning Grades',
                    message: error.body.message,
                    variant: 'error',
                })
            );
        }

    }
}