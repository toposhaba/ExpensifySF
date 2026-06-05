import { LightningElement, track, wire } from 'lwc';
import getEditableExpenses from '@salesforce/apex/BulkEditService.getEditableExpenses';
import applyEdits from '@salesforce/apex/BulkEditService.applyEdits';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

const STATUS_OPTIONS = [
    { label: 'Draft', value: 'Draft' },
    { label: 'Pending', value: 'Pending' },
    { label: 'Approved', value: 'Approved' },
    { label: 'Rejected', value: 'Rejected' },
    { label: 'On Hold', value: 'On_Hold' }
];

const TYPE_OPTIONS = [
    { label: 'Cash/Manual', value: 'Cash' },
    { label: 'Distance/Mileage', value: 'Distance' },
    { label: 'Per Diem', value: 'Per_Diem' },
    { label: 'Card Transaction', value: 'Card' },
    { label: 'Time', value: 'Time' }
];

export default class BulkEditExpenses extends LightningElement {
    @track expenses = [];
    @track selectedRows = [];
    @track draftValues = [];
    @track isLoading = true;

    bulkField = '';
    bulkValue;
    wiredResult;

    columns = [
        { label: 'Date', fieldName: 'Expense_Date__c', type: 'date-local', editable: true, sortable: true },
        { label: 'Merchant', fieldName: 'Merchant__c', type: 'text', editable: true, sortable: true },
        {
            label: 'Amount', fieldName: 'Amount__c', type: 'currency', editable: true, sortable: true,
            typeAttributes: { currencyCode: { fieldName: 'Currency__c' } }
        },
        { label: 'Category', fieldName: 'categoryName', type: 'text' },
        { label: 'Status', fieldName: 'Status__c', type: 'text', editable: true },
        { label: 'Type', fieldName: 'Expense_Type__c', type: 'text', editable: true },
        { label: 'Description', fieldName: 'Description__c', type: 'text', editable: true },
        { label: 'Billable', fieldName: 'Billable__c', type: 'boolean', editable: true },
        { label: 'Reimbursable', fieldName: 'Reimbursable__c', type: 'boolean', editable: true },
        { label: 'Report', fieldName: 'reportName', type: 'text' }
    ];

    fieldOptions = [
        { label: 'Merchant', value: 'Merchant__c' },
        { label: 'Amount', value: 'Amount__c' },
        { label: 'Expense Date', value: 'Expense_Date__c' },
        { label: 'Description', value: 'Description__c' },
        { label: 'Status', value: 'Status__c' },
        { label: 'Expense Type', value: 'Expense_Type__c' },
        { label: 'Billable', value: 'Billable__c' },
        { label: 'Reimbursable', value: 'Reimbursable__c' }
    ];

    statusOptions = STATUS_OPTIONS;
    typeOptions = TYPE_OPTIONS;

    @wire(getEditableExpenses)
    wiredExpenses(result) {
        this.wiredResult = result;
        this.isLoading = false;
        if (result.data) {
            this.expenses = result.data.map((exp) => ({
                ...exp,
                categoryName: exp.Category__r ? exp.Category__r.Name : '',
                reportName: exp.Report__r ? exp.Report__r.Name : 'Unreported'
            }));
        } else if (result.error) {
            this.showToast('Error', this.reduceError(result.error), 'error');
        }
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

    get applyDisabled() {
        return !this.hasSelectedRows || !this.bulkField;
    }

    handleFieldChange(event) {
        this.bulkField = event.detail.value;
        this.bulkValue = undefined;
    }

    handleValueChange(event) {
        if (this.isCheckboxField) {
            this.bulkValue = event.detail.checked;
        } else {
            this.bulkValue = event.detail.value;
        }
    }

    get isTextField() {
        return this.bulkField === 'Merchant__c' || this.bulkField === 'Description__c';
    }

    get isNumberField() {
        return this.bulkField === 'Amount__c';
    }

    get isDateField() {
        return this.bulkField === 'Expense_Date__c';
    }

    get isCheckboxField() {
        return this.bulkField === 'Billable__c' || this.bulkField === 'Reimbursable__c';
    }

    get isStatusField() {
        return this.bulkField === 'Status__c';
    }

    get isTypeField() {
        return this.bulkField === 'Expense_Type__c';
    }

    async handleApplyBulk() {
        if (this.applyDisabled) {
            return;
        }
        const value = this.isCheckboxField ? !!this.bulkValue : this.bulkValue;
        if (!this.isCheckboxField && (value === undefined || value === null || value === '')) {
            this.showToast('Missing value', 'Enter a value to apply', 'warning');
            return;
        }

        const fieldValues = {};
        fieldValues[this.bulkField] = value;
        const expenseIds = this.selectedRows.map((row) => row.Id);

        this.isLoading = true;
        try {
            const results = await applyEdits({ expenseIds, fieldValues });
            this.reportResults(results);
            this.bulkField = '';
            this.bulkValue = undefined;
            await refreshApex(this.wiredResult);
        } catch (error) {
            this.showToast('Error', this.reduceError(error), 'error');
        }
        this.isLoading = false;
    }

    async handleSave(event) {
        const drafts = event.detail.draftValues;
        this.isLoading = true;
        const allResults = [];
        try {
            for (const draft of drafts) {
                const fieldValues = { ...draft };
                delete fieldValues.Id;
                const results = await applyEdits({ expenseIds: [draft.Id], fieldValues });
                allResults.push(...results);
            }
            this.reportResults(allResults);
            this.draftValues = [];
            await refreshApex(this.wiredResult);
        } catch (error) {
            this.showToast('Error', this.reduceError(error), 'error');
        }
        this.isLoading = false;
    }

    reportResults(results) {
        const failures = (results || []).filter((r) => !r.isSuccess);
        const successCount = (results || []).length - failures.length;
        if (failures.length === 0) {
            this.showToast('Success', `${successCount} expense(s) updated`, 'success');
        } else {
            const detail = failures.map((f) => f.errorMessage).join('; ');
            this.showToast(
                'Partial update',
                `${successCount} succeeded, ${failures.length} failed: ${detail}`,
                failures.length === results.length ? 'error' : 'warning'
            );
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    reduceError(error) {
        return error?.body?.message || error?.message || 'Unexpected error';
    }
}
