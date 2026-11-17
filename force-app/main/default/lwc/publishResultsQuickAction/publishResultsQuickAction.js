import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import publishResults from '@salesforce/apex/ResultPublishController.publishResults';

export default class PublishResultsQuickAction extends LightningElement {
    @api recordId; // hed__Term__c.Id

    @api async invoke() {
        try {
            await publishResults({ termId: this.recordId });
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Results have been published successfully.',
                    variant: 'success'
                })
            );
            // Close the quick action modal after success
            this.closeQuickAction();
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: error.body?.message || 'An unknown error occurred. Check debug logs for details.',
                    variant: 'error'
                })
            );
        }
    }

    closeQuickAction() {
        const closeAction = new CustomEvent('closequickaction');
        this.dispatchEvent(closeAction);
    }
}