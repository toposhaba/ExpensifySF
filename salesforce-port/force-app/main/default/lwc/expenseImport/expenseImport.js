import { LightningElement, track, wire } from 'lwc';
import importExpenses from '@salesforce/apex/ExpenseImportService.importExpenses';
import getMyPolicies from '@salesforce/apex/ExpenseController.getMyPolicies';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const RESULT_COLUMNS = [
    { label: 'Row', fieldName: 'rowNumber', type: 'number', initialWidth: 70 },
    { label: 'Status', fieldName: 'statusLabel', type: 'text', initialWidth: 100 },
    { label: 'Merchant', fieldName: 'merchant', type: 'text' },
    { label: 'Amount', fieldName: 'amount', type: 'currency', initialWidth: 120 },
    { label: 'Date', fieldName: 'expenseDate', type: 'text', initialWidth: 120 },
    { label: 'Detail', fieldName: 'detail', type: 'text' }
];

export default class ExpenseImport extends LightningElement {
    @track csvBody = '';
    @track policies = [];
    @track selectedPolicyId;
    @track isLoading = false;
    @track summary;
    @track rows = [];

    resultColumns = RESULT_COLUMNS;

    @wire(getMyPolicies)
    wiredPolicies({ data }) {
        if (data) {
            this.policies = data;
            if (data.length > 0 && !this.selectedPolicyId) {
                this.selectedPolicyId = data[0].Id;
            }
        }
    }

    get policyOptions() {
        return this.policies.map((p) => ({ label: p.Name, value: p.Id }));
    }

    get hasResults() {
        return this.summary != null;
    }

    get hasErrors() {
        return this.summary != null && this.summary.errorCount > 0;
    }

    get isImportDisabled() {
        return this.isLoading || !this.csvBody;
    }

    get summaryVariant() {
        return this.hasErrors ? 'warning' : 'success';
    }

    handlePolicyChange(event) {
        this.selectedPolicyId = event.detail.value;
    }

    handleTextChange(event) {
        this.csvBody = event.target.value;
    }

    handleFileChange(event) {
        const file = event.target.files && event.target.files[0];
        if (!file) {
            return;
        }
        const reader = new FileReader();
        reader.onload = () => {
            this.csvBody = reader.result;
        };
        reader.onerror = () => {
            this.showToast('Error', 'Could not read the selected file', 'error');
        };
        reader.readAsText(file);
    }

    async handleImport() {
        if (!this.csvBody) {
            this.showToast('Error', 'Please provide CSV data', 'error');
            return;
        }

        this.isLoading = true;
        this.summary = undefined;
        this.rows = [];

        try {
            const result = await importExpenses({
                csvBody: this.csvBody,
                policyId: this.selectedPolicyId,
                reportId: null
            });
            this.summary = result;
            this.rows = result.rows.map((row) => ({
                rowNumber: row.rowNumber,
                statusLabel: row.isSuccess ? 'Imported' : 'Error',
                merchant: row.merchant,
                amount: row.amount,
                expenseDate: row.expenseDate,
                detail: row.isSuccess ? row.expenseId : row.errorMessage
            }));

            const variant = result.errorCount > 0 ? 'warning' : 'success';
            this.showToast(
                'Import complete',
                `${result.successCount} of ${result.totalRows} rows imported`,
                variant
            );
        } catch (error) {
            this.showToast('Import failed', error.body ? error.body.message : 'Unexpected error', 'error');
        }

        this.isLoading = false;
    }

    handleClear() {
        this.csvBody = '';
        this.summary = undefined;
        this.rows = [];
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
