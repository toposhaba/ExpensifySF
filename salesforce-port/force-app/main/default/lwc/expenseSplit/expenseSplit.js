import { LightningElement, api, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getParentExpense from '@salesforce/apex/ExpenseSplitService.getParentExpense';
import listSplits from '@salesforce/apex/ExpenseSplitService.listSplits';
import createSplitsApex from '@salesforce/apex/ExpenseSplitService.createSplitsApex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const SPLIT_COLUMNS = [
    { label: 'Split', fieldName: 'Name', type: 'text' },
    { label: 'User', fieldName: 'userName', type: 'text' },
    { label: 'Amount', fieldName: 'Split_Amount__c', type: 'currency' },
    { label: 'Percentage', fieldName: 'Split_Percentage__c', type: 'number' }
];

export default class ExpenseSplit extends LightningElement {
    @api recordId;
    @track mode = 'Share';
    @track rows = [];
    @track parentExpense;
    @track existingSplits = [];
    @track isLoading = false;

    columns = SPLIT_COLUMNS;
    rowKey = 0;
    wiredSplitsResult;

    modeOptions = [
        { label: 'Even / Share', value: 'Share' },
        { label: 'Custom Amounts', value: 'Amount' }
    ];

    connectedCallback() {
        this.addRow();
        this.addRow();
    }

    @wire(getParentExpense, { parentExpenseId: '$recordId' })
    wiredParent({ data }) {
        if (data) {
            this.parentExpense = data;
        }
    }

    @wire(listSplits, { parentExpenseId: '$recordId' })
    wiredSplits(result) {
        this.wiredSplitsResult = result;
        if (result.data) {
            this.existingSplits = result.data.map((split) => ({
                Id: split.Id,
                Name: split.Name,
                userName: split.Split_User__r ? split.Split_User__r.Name : split.Split_User__c,
                Split_Amount__c: split.Split_Amount__c,
                Split_Percentage__c: split.Split_Percentage__c
            }));
        }
    }

    get isShareMode() {
        return this.mode === 'Share';
    }

    get parentAmount() {
        return this.parentExpense ? this.parentExpense.Amount__c : 0;
    }

    get hasExistingSplits() {
        return this.existingSplits && this.existingSplits.length > 0;
    }

    get allocatedTotal() {
        return this.rows.reduce((sum, row) => sum + (parseFloat(row.amount) || 0), 0);
    }

    get remainingAmount() {
        return (this.parentAmount || 0) - this.allocatedTotal;
    }

    get isAmountBalanced() {
        return Math.abs(this.remainingAmount) < 0.01;
    }

    handleModeChange(event) {
        this.mode = event.detail.value;
    }

    handleUserChange(event) {
        const key = event.target.dataset.key;
        const row = this.rows.find((item) => item.key === key);
        if (row) {
            row.userId = event.detail.recordId;
        }
    }

    handleAmountChange(event) {
        const key = event.target.dataset.key;
        const row = this.rows.find((item) => item.key === key);
        if (row) {
            row.amount = event.target.value;
        }
    }

    handleShareChange(event) {
        const key = event.target.dataset.key;
        const row = this.rows.find((item) => item.key === key);
        if (row) {
            row.share = event.target.value;
        }
    }

    addRow() {
        this.rowKey += 1;
        this.rows = [
            ...this.rows,
            { key: `row-${this.rowKey}`, userId: null, amount: null, share: null }
        ];
    }

    handleAddRow() {
        this.addRow();
    }

    handleRemoveRow(event) {
        const key = event.target.dataset.key;
        this.rows = this.rows.filter((item) => item.key !== key);
    }

    async handleCreate() {
        if (!this.validate()) {
            return;
        }
        this.isLoading = true;
        try {
            const inputs = this.rows.map((row) => ({
                userId: row.userId,
                amount: row.amount ? parseFloat(row.amount) : null,
                share: row.share ? parseFloat(row.share) : null
            }));
            await createSplitsApex({ parentExpenseId: this.recordId, inputs, mode: this.mode });
            this.showToast('Success', 'Expense split created', 'success');
            this.resetRows();
            await refreshApex(this.wiredSplitsResult);
        } catch (error) {
            this.showToast('Error', this.parseError(error), 'error');
        }
        this.isLoading = false;
    }

    validate() {
        if (!this.rows.length) {
            this.showToast('Error', 'Add at least one split', 'error');
            return false;
        }
        for (const row of this.rows) {
            if (!row.userId) {
                this.showToast('Error', 'Each split requires a user', 'error');
                return false;
            }
            if (this.mode === 'Amount' && (!row.amount || parseFloat(row.amount) <= 0)) {
                this.showToast('Error', 'Each split requires an amount greater than zero', 'error');
                return false;
            }
        }
        if (this.mode === 'Amount' && !this.isAmountBalanced) {
            this.showToast('Error', 'Split amounts must equal the parent expense amount', 'error');
            return false;
        }
        return true;
    }

    resetRows() {
        this.rows = [];
        this.addRow();
        this.addRow();
    }

    parseError(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }
        return 'Failed to create split';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
