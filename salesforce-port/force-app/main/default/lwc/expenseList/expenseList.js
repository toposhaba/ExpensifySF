import { LightningElement, track, wire } from 'lwc';
import getMyExpenses from '@salesforce/apex/ExpenseController.getMyExpenses';
import deleteExpense from '@salesforce/apex/ExpenseController.deleteExpense';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

export default class ExpenseList extends LightningElement {
    @track expenses = [];
    @track showForm = false;
    @track selectedExpenseId;
    @track isLoading = true;
    @track selectedRows = [];
    wiredExpenseResult;

    columns = [
        { label: 'Date', fieldName: 'Expense_Date__c', type: 'date', sortable: true },
        { label: 'Merchant', fieldName: 'Merchant__c', type: 'text', sortable: true },
        { label: 'Amount', fieldName: 'Amount__c', type: 'currency', sortable: true,
          typeAttributes: { currencyCode: { fieldName: 'Currency__c' } } },
        { label: 'Category', fieldName: 'categoryName', type: 'text' },
        { label: 'Status', fieldName: 'Status__c', type: 'text',
          cellAttributes: { class: { fieldName: 'statusClass' } } },
        { label: 'Type', fieldName: 'Expense_Type__c', type: 'text' },
        { label: 'Report', fieldName: 'reportName', type: 'text' },
        { type: 'action', typeAttributes: { rowActions: [
            { label: 'Edit', name: 'edit' },
            { label: 'Delete', name: 'delete' }
        ]}}
    ];

    @wire(getMyExpenses)
    wiredExpenses(result) {
        this.wiredExpenseResult = result;
        this.isLoading = false;
        if (result.data) {
            this.expenses = result.data.map(exp => ({
                ...exp,
                categoryName: exp.Category__r ? exp.Category__r.Name : '',
                reportName: exp.Report__r ? exp.Report__r.Name : 'Unreported',
                statusClass: this.getStatusClass(exp.Status__c)
            }));
        }
    }

    getStatusClass(status) {
        const classes = {
            'Draft': 'slds-text-color_weak',
            'Pending': 'slds-text-color_default',
            'Approved': 'slds-text-color_success',
            'Rejected': 'slds-text-color_error',
            'On_Hold': 'slds-text-color_inverse'
        };
        return classes[status] || '';
    }

    handleNewExpense() {
        this.selectedExpenseId = null;
        this.showForm = true;
    }

    handleRowAction(event) {
        const action = event.detail.action;
        const row = event.detail.row;

        switch (action.name) {
            case 'edit':
                this.selectedExpenseId = row.Id;
                this.showForm = true;
                break;
            case 'delete':
                this.handleDelete(row.Id);
                break;
        }
    }

    async handleDelete(expenseId) {
        this.isLoading = true;
        try {
            await deleteExpense({ expenseId });
            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: 'Expense deleted',
                variant: 'success'
            }));
            await refreshApex(this.wiredExpenseResult);
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error.body?.message || 'Failed to delete expense',
                variant: 'error'
            }));
        }
        this.isLoading = false;
    }

    handleFormClose() {
        this.showForm = false;
        this.selectedExpenseId = null;
        refreshApex(this.wiredExpenseResult);
    }

    handleRowSelection(event) {
        this.selectedRows = event.detail.selectedRows;
    }

    get hasSelectedRows() {
        return this.selectedRows.length > 0;
    }

    get selectedCount() {
        return this.selectedRows.length;
    }
}
