import { LightningElement, api,track } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import sendDebIdToNode from '@salesforce/apex/AffiliationController.sendDebIdToNode';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi'

export default class SendDebIdButton extends LightningElement {
    @api recordId; // This receives the current record ID
    @track isLoading;
    @api
    invoke() {
        this.isLoading = true;
        // Call Apex method with the recordId
        sendDebIdToNode({ affiliationId: this.recordId })
            .then(result => {
                this.isLoading = false;
                this.dispatchEvent(
                    new ShowToastEvent({
                        title:'success',
                        message: 'Deb ID sent successfully',
                        variant: 'success',
                    })
                );
                console.log('Success response message:', result);
                this.dispatchEvent(new CloseActionScreenEvent());
                notifyRecordUpdateAvailable([{ recordId : this.recordId}]);

                // Optionally, you can show a toast here
            })
            .catch(error => {
                this.isLoading = false;
                 this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: error.body ? error.body.message : 'Something went wrong while sending admission details.',
                        variant: 'error',
                    })
                );
                // Close quick action screen (optional: remove this line if you want the screen to stay open on error)
                this.dispatchEvent(new CloseActionScreenEvent());
                console.error('Error response message:', error?.body?.message || error.message);
            })
            .finally(() => {
                this.isLoading = false;
                // Close the Quick Action (headless)
                this.dispatchEvent(new CloseActionScreenEvent());
            });
    }
}