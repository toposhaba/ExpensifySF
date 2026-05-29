import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class ReceiptViewer extends LightningElement {
    @api expenseId;
    @track receipts = [];
    @track isLoading = false;

    get hasReceipts() {
        return this.receipts.length > 0;
    }

    get acceptedFormats() {
        return ['.pdf', '.png', '.jpg', '.jpeg', '.gif'];
    }

    connectedCallback() {
        this.loadReceipts();
    }

    loadReceipts() {
        this.isLoading = true;
        this.receipts = [
            { id: '1', name: 'receipt_lunch.png', url: '/sfc/servlet.shepherd/version/download/1', thumbnailUrl: '/sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB120BY90&versionId=1', size: '245 KB', uploadDate: '2024-01-15' },
            { id: '2', name: 'hotel_invoice.pdf', url: '/sfc/servlet.shepherd/version/download/2', thumbnailUrl: '', size: '1.2 MB', uploadDate: '2024-01-14' }
        ];
        this.isLoading = false;
    }

    handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        const newReceipts = uploadedFiles.map((file, index) => ({
            id: String(Date.now() + index),
            name: file.name,
            url: `/sfc/servlet.shepherd/version/download/${file.documentId}`,
            thumbnailUrl: '',
            size: '',
            uploadDate: new Date().toISOString().split('T')[0]
        }));
        this.receipts = [...this.receipts, ...newReceipts];
        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message: `${uploadedFiles.length} receipt(s) uploaded successfully.`,
            variant: 'success'
        }));
    }

    handleRemove(event) {
        const receiptId = event.target.dataset.id;
        this.receipts = this.receipts.filter(r => r.id !== receiptId);
        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message: 'Receipt removed.',
            variant: 'success'
        }));
    }

    handlePreview(event) {
        const url = event.target.dataset.url;
        window.open(url, '_blank');
    }
}
