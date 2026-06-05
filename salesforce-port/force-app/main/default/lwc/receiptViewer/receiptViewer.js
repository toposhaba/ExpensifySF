import { LightningElement, api, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getReceiptsForExpense from '@salesforce/apex/ReceiptService.getReceiptsForExpense';
import detachReceipt from '@salesforce/apex/ReceiptService.detachReceipt';

export default class ReceiptViewer extends NavigationMixin(LightningElement) {
    @api recordId;
    @track receipts = [];
    wiredResult;
    isLoading = false;

    @wire(getReceiptsForExpense, { expenseId: '$recordId' })
    wiredReceipts(result) {
        this.wiredResult = result;
        if (result.data) {
            this.receipts = result.data.map((rec) => ({
                ...rec,
                statusVariant: this.resolveVariant(rec.Scan_Status__c)
            }));
        }
    }

    get hasReceipts() {
        return this.receipts && this.receipts.length > 0;
    }

    resolveVariant(status) {
        switch (status) {
            case 'Completed':
                return 'success';
            case 'Failed':
                return 'error';
            case 'Processing':
                return 'warning';
            default:
                return 'inverse';
        }
    }

    handlePreview(event) {
        const documentId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__namedPage',
            attributes: { pageName: 'filePreview' },
            state: { selectedRecordId: documentId }
        });
    }

    async handleDelete(event) {
        const receiptId = event.currentTarget.dataset.receipt;
        this.isLoading = true;
        try {
            await detachReceipt({ receiptId });
            this.showToast('Success', 'Receipt removed', 'success');
            await this.refresh();
        } catch (error) {
            this.showToast('Error', this.resolveError(error), 'error');
        }
        this.isLoading = false;
    }

    async handleRefresh() {
        this.isLoading = true;
        await this.refresh();
        this.isLoading = false;
    }

    refresh() {
        return refreshApex(this.wiredResult);
    }

    resolveError(error) {
        return error?.body?.message || error?.message || 'Something went wrong';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
