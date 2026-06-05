import { LightningElement, track, wire } from 'lwc';
import importConfig from '@salesforce/apex/ConfigImportService.importConfig';
import getMyPolicies from '@salesforce/apex/ExpenseController.getMyPolicies';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const RESULT_COLUMNS = [
    { label: 'Row', fieldName: 'rowNumber', type: 'number', initialWidth: 70 },
    { label: 'Status', fieldName: 'statusLabel', type: 'text', initialWidth: 100 },
    { label: 'Name', fieldName: 'name', type: 'text' },
    { label: 'Action', fieldName: 'action', type: 'text', initialWidth: 110 },
    { label: 'Detail', fieldName: 'detail', type: 'text' }
];

const IMPORT_TYPE_OPTIONS = [
    { label: 'Categories', value: 'Categories' },
    { label: 'Tags', value: 'Tags' },
    { label: 'Members', value: 'Members' }
];

const PLACEHOLDERS = {
    Categories: 'Name,GL Code,Enabled,Max Amount,Receipt Required',
    Tags: 'Name,GL Code,Enabled',
    Members: 'Email,Role'
};

export default class ConfigImport extends LightningElement {
    @track csvBody = '';
    @track policies = [];
    @track selectedPolicyId;
    @track importType = 'Categories';
    @track isLoading = false;
    @track summary;
    @track rows = [];

    resultColumns = RESULT_COLUMNS;
    importTypeOptions = IMPORT_TYPE_OPTIONS;

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

    get csvPlaceholder() {
        return PLACEHOLDERS[this.importType];
    }

    get hasResults() {
        return this.summary != null;
    }

    get isImportDisabled() {
        return this.isLoading || !this.csvBody || !this.selectedPolicyId;
    }

    handlePolicyChange(event) {
        this.selectedPolicyId = event.detail.value;
    }

    handleTypeChange(event) {
        this.importType = event.detail.value;
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
            const result = await importConfig({
                csvBody: this.csvBody,
                policyId: this.selectedPolicyId,
                importType: this.importType
            });
            this.summary = result;
            this.rows = result.rows.map((row) => ({
                rowNumber: row.rowNumber,
                statusLabel: row.isSuccess ? 'Imported' : 'Error',
                name: row.name,
                action: row.isSuccess ? row.action : '',
                detail: row.isSuccess ? row.recordId : row.errorMessage
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
