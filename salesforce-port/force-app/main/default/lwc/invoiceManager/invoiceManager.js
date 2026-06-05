import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getInvoices from '@salesforce/apex/ExpenseController.getInvoices';
import createInvoice from '@salesforce/apex/ExpenseController.createInvoice';
import sendInvoice from '@salesforce/apex/ExpenseController.sendInvoice';
import markInvoicePaid from '@salesforce/apex/ExpenseController.markInvoicePaid';

const COLUMNS = [
    { label: 'Number', fieldName: 'invoiceNumber', type: 'text' },
    { label: 'Amount', fieldName: 'amount', type: 'currency' },
    { label: 'Recipient', fieldName: 'recipientName', type: 'text' },
    { label: 'Status', fieldName: 'status', type: 'text' },
    { label: 'Due Date', fieldName: 'dueDate', type: 'date' },
    { label: 'Sent Date', fieldName: 'sentDate', type: 'date' },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [
                { label: 'Send', name: 'send' },
                { label: 'Mark Paid', name: 'mark_paid' }
            ]
        }
    }
];

export default class InvoiceManager extends LightningElement {
    @track invoices = [];
    @track columns = COLUMNS;
    @track showCreateModal = false;
    @track isLoading = false;
    @track newInvoice = {
        recipientName: '',
        recipientEmail: '',
        amount: null,
        dueDate: null,
        description: ''
    };

    @wire(getInvoices)
    wiredInvoices({ error, data }) {
        if (data) {
            this.invoices = data;
        } else if (error) {
            this.showToast('Error', 'Failed to load invoices', 'error');
        }
    }

    handleOpenCreateModal() {
        this.showCreateModal = true;
    }

    handleCloseCreateModal() {
        this.showCreateModal = false;
        this.resetNewInvoice();
    }

    handleInputChange(event) {
        const field = event.target.dataset.field;
        this.newInvoice = { ...this.newInvoice, [field]: event.target.value };
    }

    async handleCreateInvoice() {
        if (!this.newInvoice.recipientName || !this.newInvoice.amount || !this.newInvoice.dueDate) {
            this.showToast('Error', 'Please fill in all required fields', 'error');
            return;
        }
        this.isLoading = true;
        try {
            await createInvoice({ invoice: this.newInvoice });
            this.showToast('Success', 'Invoice created successfully', 'success');
            this.handleCloseCreateModal();
            return refreshApex(this.wiredInvoices);
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to create invoice', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleRowAction(event) {
        const action = event.detail.action;
        const row = event.detail.row;
        switch (action.name) {
            case 'send':
                await this.handleSendInvoice(row.id);
                break;
            case 'mark_paid':
                await this.handleMarkPaid(row.id);
                break;
        }
    }

    async handleSendInvoice(invoiceId) {
        this.isLoading = true;
        try {
            await sendInvoice({ invoiceId });
            this.showToast('Success', 'Invoice sent successfully', 'success');
            return refreshApex(this.wiredInvoices);
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to send invoice', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleMarkPaid(invoiceId) {
        this.isLoading = true;
        try {
            await markInvoicePaid({ invoiceId });
            this.showToast('Success', 'Invoice marked as paid', 'success');
            return refreshApex(this.wiredInvoices);
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to mark invoice as paid', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    resetNewInvoice() {
        this.newInvoice = {
            recipientName: '',
            recipientEmail: '',
            amount: null,
            dueDate: null,
            description: ''
        };
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
