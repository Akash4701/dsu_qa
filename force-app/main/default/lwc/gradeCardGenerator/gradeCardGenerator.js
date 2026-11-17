import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import startGradeCardBatch from '@salesforce/apex/GradeCardController.startGradeCardBatch';

export default class GradeCardGenerator extends LightningElement {
    @api recordId;
    isLoading = false;
    isInitialized = true;

    handleGenerate() {
        this.isLoading = true;

        startGradeCardBatch({ termId: this.recordId })
            .then((jobId) => {
                const msg = `Batch started. Grade cards will be generated in background. Job Id: ${jobId}`;
                this.showToast('Success', msg, 'success');
                this.closeQuickAction();
            })
            .catch(error => {
                const message = error?.body?.message ? error.body.message : 'Unknown error occurred';
                this.showToast('Error', message, 'error');
                this.isLoading = false;
            });
    }

    handleCancel() {
        this.closeQuickAction();
    }

    closeQuickAction() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}