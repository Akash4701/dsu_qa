import { LightningElement, api } from 'lwc';
import findProgramEnrollment  from '@salesforce/apex/ProgramPlanController.findProgramEnrollment';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class SendContactToExternal extends LightningElement {
    @api recordId;
    @api
    invoke(){
        
        findProgramEnrollment({ programPlanId: this.recordId })
            .then(result => {
                // The message says how many students were queued and about how long it will take. A dismissible
                // toast closes by itself after 5 seconds (or earlier, when the user closes it).
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Sync Enrollment',
                    message: result,
                    variant: 'success',
                    mode: 'dismissible'
                }));
            })
            .catch(error => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error',
                    message: error.body.message,
                    variant: 'error'
                }));
            });
    

    }
   
}