import { LightningElement, api } from 'lwc';

export default class ModalPopupUtilityComponent extends LightningElement {

    _modalSize;
    // showSpinner = true;

    @api showSpinner;

    @api
    get modalSize() {
        return this._modalSize;
    };

    set modalSize(value) {
        let size = value?.toLowerCase();
        switch (size) {
            case 'large':
                this._modalSize = 'slds-modal slds-fade-in-open slds-modal_large';
                break;

            case 'medium':
                this._modalSize = 'slds-modal slds-fade-in-open slds-modal_medium';
                break;

            case 'small':
                this._modalSize = 'slds-modal slds-fade-in-open slds-modal_small';
                break;

            default:
                this._modalSize = 'slds-modal slds-fade-in-open slds-modal_small';
                break;
        }
    }


    connectedcallback() {
        console.log('inside utility component:::', this.title);
    }


    handleFooterChange(event) {
        const footerElem = this.template.querySelector('.slds-modal__footer')
        if (footerElem) {
            footerElem.classList.remove('slds-hide')
        }
    }

    handleHeaderChange(event) {
        console.log('header change event::');
        const headerElem = this.template.querySelector('.slds-modal__header ')
        if (headerElem) {
            headerElem.classList.remove('slds-hide')
        }
    }

    closePopupHandler(event) {
        this.dispatchEvent(new CustomEvent('closepopup', {
            detail: {
                msg: 'Close Popup'
            }
        }))
    };
}