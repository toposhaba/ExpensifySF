import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getExpenseRules from '@salesforce/apex/ExpenseController.getExpenseRules';
import createExpenseRule from '@salesforce/apex/ExpenseController.createExpenseRule';
import applyExpenseRules from '@salesforce/apex/ExpenseController.applyExpenseRules';

const COLUMNS = [
    { label: 'Rule Name', fieldName: 'name', type: 'text' },
    { label: 'Merchant Pattern', fieldName: 'merchantPattern', type: 'text' },
    { label: 'Category', fieldName: 'category', type: 'text' },
    { label: 'Tag', fieldName: 'tag', type: 'text' },
    { label: 'Enabled', fieldName: 'enabled', type: 'boolean' }
];

export default class ExpenseRuleManager extends LightningElement {
    @track rules = [];
    @track columns = COLUMNS;
    @track isLoading = false;
    @track showCreateModal = false;
    @track selectedRows = [];
    @track newRule = {
        name: '',
        merchantPattern: '',
        category: '',
        tag: '',
        enabled: true
    };

    @wire(getExpenseRules)
    wiredRules({ error, data }) {
        if (data) {
            this.rules = data;
        } else if (error) {
            this.showToast('Error', 'Failed to load expense rules', 'error');
        }
    }

    handleOpenCreateModal() {
        this.showCreateModal = true;
    }

    handleCloseCreateModal() {
        this.showCreateModal = false;
        this.resetNewRule();
    }

    handleInputChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        this.newRule = { ...this.newRule, [field]: value };
    }

    handleRowSelection(event) {
        this.selectedRows = event.detail.selectedRows;
    }

    async handleCreateRule() {
        if (!this.newRule.name || !this.newRule.merchantPattern) {
            this.showToast('Error', 'Please fill in all required fields', 'error');
            return;
        }
        this.isLoading = true;
        try {
            await createExpenseRule({ rule: this.newRule });
            this.showToast('Success', 'Expense rule created successfully', 'success');
            this.handleCloseCreateModal();
            return refreshApex(this.wiredRules);
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to create rule', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleApplyRules() {
        if (this.selectedRows.length === 0) {
            this.showToast('Error', 'Please select expenses to apply rules to', 'error');
            return;
        }
        const expenseIds = this.selectedRows.map(row => row.id);
        this.isLoading = true;
        try {
            const result = await applyExpenseRules({ expenseIds });
            this.showToast('Success', `Rules applied to ${result} expenses`, 'success');
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to apply rules', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    resetNewRule() {
        this.newRule = {
            name: '',
            merchantPattern: '',
            category: '',
            tag: '',
            enabled: true
        };
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
