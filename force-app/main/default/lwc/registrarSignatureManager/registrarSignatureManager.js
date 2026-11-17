import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningConfirm from 'lightning/confirm';
import getRegistrarSignature from '@salesforce/apex/RegistrarSignatureController.getRegistrarSignature';
import saveRegistrarSignature from '@salesforce/apex/RegistrarSignatureController.saveRegistrarSignature';
import removeRegistrarSignature from '@salesforce/apex/RegistrarSignatureController.removeRegistrarSignature';

const ALLOWED_TYPES = ['image/png', 'image/jpeg'];

export default class RegistrarSignatureManager extends LightningElement {
    info;
    loadError;
    pending; // { fileName, dataUrl, base64 } chosen but not yet saved
    isBusy = false;

    connectedCallback() {
        this.load();
    }

    load() {
        this.isBusy = true;
        getRegistrarSignature()
            .then((data) => {
                this.info = data;
                this.loadError = undefined;
            })
            .catch((error) => {
                this.loadError = this.errorMessage(error, 'Unable to load the Registrar signature.');
            })
            .finally(() => {
                this.isBusy = false;
            });
    }

    get maxKb() {
        return this.info ? Math.floor(this.info.maxBytes / 1024) : 0;
    }

    get uploadLabel() {
        return this.info && this.info.hasSignature ? 'Replace signature' : 'Upload signature';
    }

    get isSaveDisabled() {
        return this.isBusy || !this.pending;
    }

    get isCancelDisabled() {
        return this.isBusy || !this.pending;
    }

    get isRemoveDisabled() {
        return this.isBusy || !this.info || !this.info.hasSignature;
    }

    handleFileChange(event) {
        const file = event.target.files && event.target.files[0];
        // Clear the input so picking the same file again still fires onchange.
        event.target.value = null;
        if (!file) {
            return;
        }
        if (!ALLOWED_TYPES.includes(file.type)) {
            this.showToast('Invalid file', 'The signature must be a PNG or JPG image.', 'error');
            return;
        }
        if (file.size > this.info.maxBytes) {
            this.showToast('File too large',
                `The signature image must be ${this.maxKb} KB or smaller. This file is ${Math.ceil(file.size / 1024)} KB.`,
                'error');
            return;
        }
        const reader = new FileReader();
        reader.onload = () => {
            const dataUrl = reader.result;
            this.pending = {
                fileName: file.name,
                dataUrl,
                base64: dataUrl.substring(dataUrl.indexOf(',') + 1)
            };
        };
        reader.onerror = () => {
            this.showToast('Error', 'The file could not be read.', 'error');
        };
        reader.readAsDataURL(file);
    }

    handleSave() {
        this.isBusy = true;
        saveRegistrarSignature({ fileName: this.pending.fileName, base64Data: this.pending.base64 })
            .then((data) => {
                this.info = data;
                this.pending = undefined;
                this.showToast('Saved', 'Registrar signature updated. New ID cards will use it.', 'success');
            })
            .catch((error) => {
                this.showToast('Error', this.errorMessage(error, 'Unable to save the signature.'), 'error');
            })
            .finally(() => {
                this.isBusy = false;
            });
    }

    handleCancel() {
        this.pending = undefined;
    }

    async handleRemove() {
        const confirmed = await LightningConfirm.open({
            message: 'Remove the Registrar signature? New ID cards will be generated without it.',
            label: 'Remove Registrar Signature',
            theme: 'warning'
        });
        if (!confirmed) {
            return;
        }
        this.isBusy = true;
        removeRegistrarSignature()
            .then((data) => {
                this.info = data;
                this.pending = undefined;
                this.showToast('Removed', 'Registrar signature removed.', 'success');
            })
            .catch((error) => {
                this.showToast('Error', this.errorMessage(error, 'Unable to remove the signature.'), 'error');
            })
            .finally(() => {
                this.isBusy = false;
            });
    }

    errorMessage(error, fallback) {
        return (error && error.body && error.body.message) || fallback;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}