import { LightningElement, api } from 'lwc';
import processPassportPhoto from '@salesforce/apex/ContactPhotoActionHandler.processPassportPhoto';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class UploadPassportPhotoQuick extends LightningElement {
    @api recordId;
    
    @api
    invoke(){
        processPassportPhoto({ contactId: this.recordId })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Success',
                    message: 'Passport photo saved to Contact.',
                    variant: 'success'
                }));
                this.dispatchEvent(new CloseActionScreenEvent());
            })
            .catch(error => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error',
                    message: error.body?.message || 'Unexpected error.',
                    variant: 'error'
                }));
                this.dispatchEvent(new CloseActionScreenEvent());
            });
    }
}