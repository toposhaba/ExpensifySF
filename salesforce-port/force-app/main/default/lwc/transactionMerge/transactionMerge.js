import { LightningElement, track } from 'lwc';
import getExpensesForMerge from '@salesforce/apex/ExpenseMergeService.getExpensesForMerge';
import applyMerge from '@salesforce/apex/ExpenseMergeService.applyMerge';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const FIELD_DEFS = [
    { field: 'Amount__c', label: 'Amount' },
    { field: 'Currency__c', label: 'Currency' },
    { field: 'Merchant__c', label: 'Merchant' },
    { field: 'Expense_Date__c', label: 'Date' },
    { field: 'Category__c', label: 'Category', displayKey: 'CategoryName' },
    { field: 'Tag__c', label: 'Tag', displayKey: 'TagName' },
    { field: 'Description__c', label: 'Description' },
    { field: 'Expense_Type__c', label: 'Type' },
    { field: 'Tax_Amount__c', label: 'Tax Amount' },
    { field: 'Receipt_URL__c', label: 'Receipt URL' },
    { field: 'Has_Receipt__c', label: 'Has Receipt' },
    { field: 'Billable__c', label: 'Billable' },
    { field: 'Reimbursable__c', label: 'Reimbursable' }
];

export default class TransactionMerge extends LightningElement {
    @track firstExpenseId;
    @track secondExpenseId;
    @track expenseA;
    @track expenseB;
    @track survivorId;
    @track selections = {};
    @track isLoading = false;
    @track isLoaded = false;

    get survivorOptions() {
        if (!this.isLoaded) {
            return [];
        }
        return [
            { label: this.expenseLabel(this.expenseA), value: this.expenseA.Id },
            { label: this.expenseLabel(this.expenseB), value: this.expenseB.Id }
        ];
    }

    get rows() {
        if (!this.isLoaded) {
            return [];
        }
        return FIELD_DEFS.map((def) => {
            const valueA = this.displayValue(this.expenseA, def);
            const valueB = this.displayValue(this.expenseB, def);
            const selected = this.selections[def.field] || this.survivorId;
            return {
                field: def.field,
                label: def.label,
                valueA,
                valueB,
                selected,
                options: [
                    { label: valueA === '' ? '(empty)' : valueA, value: this.expenseA.Id },
                    { label: valueB === '' ? '(empty)' : valueB, value: this.expenseB.Id }
                ]
            };
        });
    }

    get canMerge() {
        return this.isLoaded && !this.isLoading && !!this.survivorId;
    }

    expenseLabel(expense) {
        return `${expense.Name} — ${expense.Merchant__c || ''} (${expense.Currency__c} ${expense.Amount__c})`;
    }

    displayValue(expense, def) {
        if (def.displayKey) {
            return expense[def.displayKey] || '';
        }
        const value = expense[def.field];
        if (value === undefined || value === null) {
            return '';
        }
        if (typeof value === 'boolean') {
            return value ? 'Yes' : 'No';
        }
        return String(value);
    }

    handleFirstIdChange(event) {
        this.firstExpenseId = event.target.value;
    }

    handleSecondIdChange(event) {
        this.secondExpenseId = event.target.value;
    }

    async handleLoad() {
        if (!this.firstExpenseId || !this.secondExpenseId) {
            this.showError('Enter both expense Ids');
            return;
        }
        if (this.firstExpenseId === this.secondExpenseId) {
            this.showError('Choose two different expenses');
            return;
        }

        this.isLoading = true;
        try {
            const results = await getExpensesForMerge({
                firstExpenseId: this.firstExpenseId,
                secondExpenseId: this.secondExpenseId
            });

            if (!results || results.length < 2) {
                this.showError('Both expenses could not be found');
                this.isLoading = false;
                return;
            }

            const byId = {};
            results.forEach((exp) => {
                const flattened = { ...exp };
                flattened.CategoryName = exp.Category__r ? exp.Category__r.Name : '';
                flattened.TagName = exp.Tag__r ? exp.Tag__r.Name : '';
                byId[exp.Id] = flattened;
            });

            this.expenseA = byId[this.firstExpenseId];
            this.expenseB = byId[this.secondExpenseId];
            this.survivorId = this.expenseA.Id;
            this.selections = {};
            this.isLoaded = true;
        } catch (error) {
            this.showError(this.errorMessage(error));
        }
        this.isLoading = false;
    }

    handleSurvivorChange(event) {
        this.survivorId = event.detail.value;
    }

    handleSelectionChange(event) {
        const field = event.target.dataset.field;
        this.selections = { ...this.selections, [field]: event.detail.value };
    }

    async handleMerge() {
        if (!this.survivorId) {
            this.showError('Select which expense to keep');
            return;
        }

        const otherId = this.survivorId === this.expenseA.Id ? this.expenseB.Id : this.expenseA.Id;
        const fieldNames = [];
        const fieldSourceExpenseIds = [];
        FIELD_DEFS.forEach((def) => {
            const source = this.selections[def.field] || this.survivorId;
            fieldNames.push(def.field);
            fieldSourceExpenseIds.push(source);
        });

        this.isLoading = true;
        try {
            await applyMerge({
                survivorId: this.survivorId,
                otherId,
                fieldNames,
                fieldSourceExpenseIds
            });
            this.showSuccess('Expenses merged successfully');
            this.handleReset();
        } catch (error) {
            this.showError(this.errorMessage(error));
        }
        this.isLoading = false;
    }

    handleReset() {
        this.expenseA = undefined;
        this.expenseB = undefined;
        this.survivorId = undefined;
        this.selections = {};
        this.isLoaded = false;
    }

    errorMessage(error) {
        return error && error.body && error.body.message ? error.body.message : 'Something went wrong';
    }

    showSuccess(message) {
        this.dispatchEvent(new ShowToastEvent({ title: 'Success', message, variant: 'success' }));
    }

    showError(message) {
        this.dispatchEvent(new ShowToastEvent({ title: 'Error', message, variant: 'error' }));
    }
}
