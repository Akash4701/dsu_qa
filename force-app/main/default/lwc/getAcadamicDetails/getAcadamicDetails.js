import { LightningElement, api,track } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';


import sendAdmissionDetails from '@salesforce/apex/AffiliationController.sendAdmissionDetails';

export default class GetAcademicDetails extends LightningElement {
    @api recordId;
    @track isLoading = false;    
    @api
    invoke(){
        this.isLoading = true;
       setTimeout(()=>{
         sendAdmissionDetails({ affiliationId: this.recordId })
            .then(result => {
                this.isLoading = false;
                // Show success toast
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Admission details sent successfully.',
                        variant: 'success',
                    })
                );
                console.log('result',result);
                // Close quick action screen
                this.dispatchEvent(new CloseActionScreenEvent());
                notifyRecordUpdateAvailable([{ recordId : this.recordId }]);
            })
            .catch(error => {
                this.isLoading = false;
                // Show error toast
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: error.body ? error.body.message : 'Something went wrong while sending admission details.',
                        variant: 'error',
                    })
                );
                // Close quick action screen (optional: remove this line if you want the screen to stay open on error)
                this.dispatchEvent(new CloseActionScreenEvent());
            });
        

            
    },100);
}
}