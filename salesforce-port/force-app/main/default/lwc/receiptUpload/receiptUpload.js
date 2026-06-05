import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import attachReceipt from '@salesforce/apex/ReceiptService.attachReceipt';

export default class ReceiptUpload extends LightningElement {
    @api recordId;
    isLoading = false;

    get acceptedFormats() {
        return ['.png', '.jpg', '.jpeg', '.pdf', '.heic', '.gif'];
    }

    get isDisabled() {
        return !this.recordId;
    }

    async handleUploadFinished(event) {
        const files = event.detail.files || [];
        if (files.length === 0) {
            return;
        }
        this.isLoading = true;
        try {
            for (const file of files) {
                await attachReceipt({ expenseId: this.recordId, contentDocumentId: file.documentId });
            }
            this.showToast('Success', `${files.length} receipt(s) attached`, 'success');
            this.dispatchEvent(new CustomEvent('receiptchange', { bubbles: true, composed: true }));
        } catch (error) {
            this.showToast('Error', this.resolveError(error), 'error');
        }
        this.isLoading = false;
    }

    resolveError(error) {
        return error?.body?.message || error?.message || 'Failed to attach receipt';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
