import { LightningElement, api, track, wire } from 'lwc';
import createExpense from '@salesforce/apex/ExpenseController.createExpense';
import updateExpense from '@salesforce/apex/ExpenseController.updateExpense';
import getExpense from '@salesforce/apex/ExpenseController.getExpense';
import getCategories from '@salesforce/apex/ExpenseController.getCategories';
import getTags from '@salesforce/apex/ExpenseController.getTags';
import getMyPolicies from '@salesforce/apex/ExpenseController.getMyPolicies';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class ExpenseForm extends LightningElement {
    @api expenseId;
    @track expense = {};
    @track isLoading = false;
    @track categories = [];
    @track tags = [];
    @track policies = [];
    @track selectedPolicyId;

    expenseTypeOptions = [
        { label: 'Cash/Manual', value: 'Cash' },
        { label: 'Distance/Mileage', value: 'Distance' },
        { label: 'Per Diem', value: 'Per_Diem' },
        { label: 'Card Transaction', value: 'Card' },
        { label: 'Time', value: 'Time' }
    ];

    currencyOptions = [
        { label: 'USD', value: 'USD' },
        { label: 'EUR', value: 'EUR' },
        { label: 'GBP', value: 'GBP' },
        { label: 'CAD', value: 'CAD' },
        { label: 'AUD', value: 'AUD' },
        { label: 'JPY', value: 'JPY' }
    ];

    distanceUnitOptions = [
        { label: 'Miles', value: 'mi' },
        { label: 'Kilometers', value: 'km' }
    ];

    get isEditMode() {
        return this.expenseId != null;
    }

    get formTitle() {
        return this.isEditMode ? 'Edit Expense' : 'New Expense';
    }

    get isDistanceType() {
        return this.expense.Expense_Type__c === 'Distance';
    }

    get categoryOptions() {
        return this.categories.map(cat => ({ label: cat.Name, value: cat.Id }));
    }

    get tagOptions() {
        return this.tags.map(tag => ({ label: tag.Name, value: tag.Id }));
    }

    get policyOptions() {
        return this.policies.map(p => ({ label: p.Name, value: p.Id }));
    }

    @wire(getMyPolicies)
    wiredPolicies({ data }) {
        if (data) {
            this.policies = data;
            if (data.length > 0 && !this.selectedPolicyId) {
                this.selectedPolicyId = data[0].Id;
                this.loadCategoriesAndTags();
            }
        }
    }

    connectedCallback() {
        if (this.expenseId) {
            this.loadExpense();
        } else {
            this.expense = {
                Expense_Type__c: 'Cash',
                Currency__c: 'USD',
                Expense_Date__c: new Date().toISOString().split('T')[0],
                Reimbursable__c: true,
                Billable__c: false
            };
        }
    }

    async loadExpense() {
        this.isLoading = true;
        try {
            this.expense = await getExpense({ expenseId: this.expenseId });
            this.selectedPolicyId = this.expense.Policy__c;
            if (this.selectedPolicyId) {
                this.loadCategoriesAndTags();
            }
        } catch (error) {
            this.showError('Failed to load expense');
        }
        this.isLoading = false;
    }

    async loadCategoriesAndTags() {
        if (!this.selectedPolicyId) return;
        try {
            const [cats, tgs] = await Promise.all([
                getCategories({ policyId: this.selectedPolicyId }),
                getTags({ policyId: this.selectedPolicyId })
            ]);
            this.categories = cats;
            this.tags = tgs;
        } catch (error) {
            console.error('Failed to load categories/tags', error);
        }
    }

    handleFieldChange(event) {
        const field = event.target.dataset.field;
        let value = event.target.value;

        if (event.target.type === 'checkbox') {
            value = event.target.checked;
        }

        this.expense = { ...this.expense, [field]: value };

        if (field === 'Policy__c') {
            this.selectedPolicyId = value;
            this.loadCategoriesAndTags();
        }
    }

    async handleSave() {
        if (!this.validateForm()) return;

        this.isLoading = true;
        try {
            const expenseData = {
                Amount__c: parseFloat(this.expense.Amount__c),
                Currency__c: this.expense.Currency__c,
                Merchant__c: this.expense.Merchant__c,
                Expense_Date__c: this.expense.Expense_Date__c,
                Category__c: this.expense.Category__c || null,
                Tag__c: this.expense.Tag__c || null,
                Description__c: this.expense.Description__c,
                Billable__c: this.expense.Billable__c,
                Reimbursable__c: this.expense.Reimbursable__c,
                Expense_Type__c: this.expense.Expense_Type__c,
                Policy__c: this.selectedPolicyId,
                Tax_Amount__c: this.expense.Tax_Amount__c ? parseFloat(this.expense.Tax_Amount__c) : null,
                Distance__c: this.expense.Distance__c ? parseFloat(this.expense.Distance__c) : null,
                Distance_Unit__c: this.expense.Distance_Unit__c
            };

            if (this.isEditMode) {
                expenseData.Id = this.expenseId;
                await updateExpense({ expense: expenseData });
                this.showSuccess('Expense updated successfully');
            } else {
                await createExpense({ expense: expenseData });
                this.showSuccess('Expense created successfully');
            }

            this.handleClose();
        } catch (error) {
            this.showError(error.body?.message || 'Failed to save expense');
        }
        this.isLoading = false;
    }

    validateForm() {
        const allValid = [...this.template.querySelectorAll('lightning-input, lightning-combobox')]
            .reduce((validSoFar, inputCmp) => {
                inputCmp.reportValidity();
                return validSoFar && inputCmp.checkValidity();
            }, true);
        return allValid;
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    showSuccess(message) {
        this.dispatchEvent(new ShowToastEvent({ title: 'Success', message, variant: 'success' }));
    }

    showError(message) {
        this.dispatchEvent(new ShowToastEvent({ title: 'Error', message, variant: 'error' }));
    }
}
