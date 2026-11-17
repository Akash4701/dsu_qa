import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import getAffiliationInfo from '@salesforce/apex/StudentIdCardController.getAffiliationInfo';
import generateIdCard from '@salesforce/apex/StudentIdCardController.generateIdCard';

export default class IdCardGenerator extends LightningElement {
    @api recordId; // hed__Affiliation__c.Id

    info;
    loadError;
    isLoading = false;

    @wire(getAffiliationInfo, { affiliationId: '$recordId' })
    wiredInfo({ data, error }) {
        if (data) {
            this.info = data;
            this.loadError = undefined;
        } else if (error) {
            this.loadError = error?.body?.message || 'Unable to load affiliation details.';
        }
    }

    get alreadyGenerated() {
        return this.info && this.info.status === 'Generated';
    }

    get isGenerateDisabled() {
        return this.isLoading || !this.info || !this.info.ready;
    }

    handleGenerate() {
        this.isLoading = true;
        generateIdCard({ affiliationId: this.recordId })
            .then(() => {
                this.showToast('Success', 'Student E-ID card generated and saved to Files.', 'success');
                this.closeQuickAction();
            })
            .catch((error) => {
                const message = error?.body?.message || 'Unknown error while generating the ID card.';
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