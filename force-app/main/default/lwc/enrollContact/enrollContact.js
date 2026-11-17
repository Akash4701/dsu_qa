import { LightningElement, api } from 'lwc';
import sendUserDetails  from '@salesforce/apex/ContactController.sendUserDetails';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class SendContactToExternal extends LightningElement {
    @api recordId;

    handleClick() {
        sendUserDetails({ contactId1: this.recordId })
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