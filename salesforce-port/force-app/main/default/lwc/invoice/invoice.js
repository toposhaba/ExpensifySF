import { LightningElement, wire, track } from 'lwc';
import getMyInvoices from '@salesforce/apex/InvoiceService.getMyInvoices';
import createInvoiceRecord from '@salesforce/apex/InvoiceService.createInvoiceRecord';
import sendInvoiceRecord from '@salesforce/apex/InvoiceService.sendInvoiceRecord';
import markInvoicePaid from '@salesforce/apex/InvoiceService.markInvoicePaid';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

export default class Invoice extends LightningElement {
    @track invoices = [];
    @track isLoading = true;
    @track showNewInvoiceModal = false;
    @track amount;
    @track currencyCode = 'USD';
    @track recipientEmail = '';
    @track dueDate;
    wiredInvoicesResult;

    columns = [
        { label: 'Invoice #', fieldName: 'Name', type: 'text' },
        { label: 'Recipient', fieldName: 'Recipient_Email__c', type: 'email' },
        { label: 'Amount', fieldName: 'Amount__c', type: 'currency' },
        { label: 'Currency', fieldName: 'Currency__c', type: 'text' },
        { label: 'Status', fieldName: 'Status__c', type: 'text' },
        { label: 'Issued', fieldName: 'Issued_Date__c', type: 'date' },
        { label: 'Due', fieldName: 'Due_Date__c', type: 'date' },
        { type: 'action', typeAttributes: { rowActions: this.getRowActions } }
    ];

    getRowActions(row, doneCallback) {
        const actions = [];
        if (row.Status__c === 'Draft') {
            actions.push({ label: 'Send', name: 'send' });
        }
        if (row.Status__c === 'Sent') {
            actions.push({ label: 'Mark Paid', name: 'markPaid' });
        }
        if (actions.length === 0) {
            actions.push({ label: 'No actions available', name: 'none', disabled: true });
        }
        doneCallback(actions);
    }

    @wire(getMyInvoices)
    wiredInvoices(result) {
        this.wiredInvoicesResult = result;
        this.isLoading = false;
        if (result.data) {
            this.invoices = result.data;
        }
    }

    get hasInvoices() {
        return this.invoices.length > 0;
    }

    handleNewInvoice() {
        this.showNewInvoiceModal = true;
    }

    handleModalClose() {
        this.showNewInvoiceModal = false;
        this.resetForm();
    }

    resetForm() {
        this.amount = undefined;
        this.currencyCode = 'USD';
        this.recipientEmail = '';
        this.dueDate = undefined;
    }

    handleAmountChange(event) {
        this.amount = event.target.value;
    }

    handleCurrencyChange(event) {
        this.currencyCode = event.target.value;
    }

    handleEmailChange(event) {
        this.recipientEmail = event.target.value;
    }

    handleDueDateChange(event) {
        this.dueDate = event.target.value;
    }

    async handleCreateInvoice() {
        this.isLoading = true;
        try {
            const invoice = {
                Amount__c: this.amount,
                Currency__c: this.currencyCode,
                Recipient_Email__c: this.recipientEmail,
                Due_Date__c: this.dueDate
            };
            await createInvoiceRecord({ invoice });
            this.showToast('Success', 'Invoice created', 'success');
            this.showNewInvoiceModal = false;
            this.resetForm();
            await refreshApex(this.wiredInvoicesResult);
        } catch (error) {
            this.showToast('Error', this.extractError(error), 'error');
        }
        this.isLoading = false;
    }

    handleRowAction(event) {
        const action = event.detail.action;
        const row = event.detail.row;
        switch (action.name) {
            case 'send':
                this.handleSend(row.Id);
                break;
            case 'markPaid':
                this.handleMarkPaid(row.Id);
                break;
            default:
                break;
        }
    }

    async handleSend(invoiceId) {
        this.isLoading = true;
        try {
            await sendInvoiceRecord({ invoiceId });
            this.showToast('Success', 'Invoice sent', 'success');
            await refreshApex(this.wiredInvoicesResult);
        } catch (error) {
            this.showToast('Error', this.extractError(error), 'error');
        }
        this.isLoading = false;
    }

    async handleMarkPaid(invoiceId) {
        this.isLoading = true;
        try {
            await markInvoicePaid({ invoiceId });
            this.showToast('Success', 'Invoice marked as paid', 'success');
            await refreshApex(this.wiredInvoicesResult);
        } catch (error) {
            this.showToast('Error', this.extractError(error), 'error');
        }
        this.isLoading = false;
    }

    extractError(error) {
        return error && error.body && error.body.message ? error.body.message : 'Unexpected error';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
