import { LightningElement, api } from 'lwc';
import handleAfterInsert  from '@salesforce/apex/ProgramEnrollmentTriggerHandler.handleAfterInsert';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class SendContactToExternal extends LightningElement {
    @api recordId;
    @api
    invoke(){
        
        handleAfterInsert({ newEnrollments: this.recordId })
            .then(result => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Success',
                    message: result,
                    variant: 'success'
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