import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import publishHallTicket from '@salesforce/apex/ExamCycleHallTicketController.publishHallTicket';

export default class PublishHallTicketQuickAction extends LightningElement {
    @api recordId; // Exam_Cycle__c.Id

    @api async invoke() {
        try {
            await publishHallTicket({ examCycleId: this.recordId });

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Hall ticket has been published for this exam cycle.',
                    variant: 'success'
                })
            );

            this.closeQuickAction();
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: error?.body?.message || 'An unknown error occurred. Check debug logs for details.',
                    variant: 'error'
                })
            );
        }
    }

    closeQuickAction() {
        this.dispatchEvent(new CustomEvent('closequickaction'));
    }
}