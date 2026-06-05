import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getTaxRates from '@salesforce/apex/ExpenseController.getTaxRates';
import createTaxRate from '@salesforce/apex/ExpenseController.createTaxRate';
import updateTaxRate from '@salesforce/apex/ExpenseController.updateTaxRate';

const COLUMNS = [
    { label: 'Name', fieldName: 'name', type: 'text', editable: true },
    { label: 'Rate (%)', fieldName: 'rate', type: 'number', editable: true, typeAttributes: { minimumFractionDigits: 2 } },
    { label: 'Code', fieldName: 'code', type: 'text', editable: true },
    { label: 'Enabled', fieldName: 'enabled', type: 'boolean', editable: true },
    { label: 'Default', fieldName: 'isDefault', type: 'boolean', editable: true }
];

export default class TaxManager extends LightningElement {
    @track taxRates = [];
    @track columns = COLUMNS;
    @track isLoading = false;
    @track showCreateModal = false;
    @track draftValues = [];
    @track newTaxRate = {
        name: '',
        rate: null,
        code: '',
        enabled: true,
        isDefault: false
    };

    @wire(getTaxRates)
    wiredTaxRates({ error, data }) {
        if (data) {
            this.taxRates = data;
        } else if (error) {
            this.showToast('Error', 'Failed to load tax rates', 'error');
        }
    }

    handleOpenCreateModal() {
        this.showCreateModal = true;
    }

    handleCloseCreateModal() {
        this.showCreateModal = false;
        this.resetNewTaxRate();
    }

    handleInputChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        this.newTaxRate = { ...this.newTaxRate, [field]: value };
    }

    async handleCreateTaxRate() {
        if (!this.newTaxRate.name || this.newTaxRate.rate === null || !this.newTaxRate.code) {
            this.showToast('Error', 'Please fill in all required fields', 'error');
            return;
        }
        this.isLoading = true;
        try {
            await createTaxRate({ taxRate: this.newTaxRate });
            this.showToast('Success', 'Tax rate created successfully', 'success');
            this.handleCloseCreateModal();
            return refreshApex(this.wiredTaxRates);
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to create tax rate', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleSave(event) {
        const updatedFields = event.detail.draftValues;
        this.isLoading = true;
        try {
            await updateTaxRate({ taxRates: updatedFields });
            this.showToast('Success', 'Tax rates updated successfully', 'success');
            this.draftValues = [];
            return refreshApex(this.wiredTaxRates);
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to update tax rates', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    resetNewTaxRate() {
        this.newTaxRate = {
            name: '',
            rate: null,
            code: '',
            enabled: true,
            isDefault: false
        };
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
