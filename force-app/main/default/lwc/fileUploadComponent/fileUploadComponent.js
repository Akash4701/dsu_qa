import { LightningElement, api } from 'lwc';
import uploadAndGetPublicUrl from '@salesforce/apex/fileUploadController.uploadAndGetPublicUrl';
import saveFileRecord from '@salesforce/apex/fileUploadController.saveFileRecord';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class FileUploadComponent extends LightningElement {
    @api recordId;

    fileName = '';
    fileUrl = '';
    selectedFile;
    disableFile = false;
    disableUrl = false;

    // Handle file change
    handleFileChange(event) {
        const file = event.target.files[0];
        if (!file) return;

        this.selectedFile = file;
        this.fileName = file.name;
        this.disableUrl = true;
    }

    // Handle URL change
    handleUrlChange(event) {
        this.fileUrl = event.target.value;
        if (this.fileUrl.length > 0) {
            this.disableFile = true;
        } else {
            this.disableFile = false;
        }
    }

    // Remove selected file
    removeSelectedFile() {
        this.selectedFile = null;
        this.fileName = '';
        this.disableUrl = false;
    }

    // Handle file name change
    handleNameChange(event) {
        this.fileName = event.target.value;
    }

    // Save the file
    async handleSave() {
        try {
            let url = this.fileUrl;

            if (this.selectedFile) {
                const base64 = await this.readFileAsBase64(this.selectedFile);
                url = await uploadAndGetPublicUrl({ fileName: this.fileName, base64Content: base64 });
            }

            if (!url || !this.fileName) {
                this.showToast('Error', 'File URL or Name is required.', 'error');
                return;
            }

            await saveFileRecord({
                announcementId: this.recordId,
                fileUrl: url,
                fileName: this.fileName
            });

            this.showToast('Success', 'File saved successfully!', 'success');
            this.dispatchEvent(new CloseActionScreenEvent());

        } catch (err) {
            this.showToast('Error', err.body?.message || err.message, 'error');
        }
    }

    // Handle cancel
    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    // Convert file to base64
    readFileAsBase64(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => {
                const base64 = reader.result.split(',')[1];
                resolve(base64);
            };
            reader.onerror = reject;
            reader.readAsDataURL(file);
        });
    }

    // Toast utility
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}