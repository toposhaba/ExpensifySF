import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getMyPolicies from '@salesforce/apex/ExpenseController.getMyPolicies';
import getTaxRates from '@salesforce/apex/TaxService.getTaxRates';
import saveTaxRate from '@salesforce/apex/TaxService.saveTaxRate';
import removeTaxRate from '@salesforce/apex/TaxService.removeTaxRate';

const COLUMNS = [
    { label: 'Name', fieldName: 'Name', type: 'text' },
    { label: 'Code', fieldName: 'Code__c', type: 'text' },
    { label: 'Rate (%)', fieldName: 'Rate_Percent__c', type: 'number', typeAttributes: { maximumFractionDigits: 2 } },
    { label: 'Enabled', fieldName: 'Enabled__c', type: 'boolean' },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [
                { label: 'Edit', name: 'edit' },
                { label: 'Delete', name: 'delete' }
            ]
        }
    }
];

export default class TaxRates extends LightningElement {
    @track policies = [];
    @track taxRates = [];
    @track selectedPolicyId;
    @track isLoading = true;
    @track showForm = false;

    recordId;
    draftName = '';
    draftCode = '';
    draftRate;
    draftEnabled = true;

    columns = COLUMNS;

    @wire(getMyPolicies)
    wiredPolicies({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.policies = data.map((p) => ({ label: p.Name, value: p.Id }));
            if (data.length > 0 && !this.selectedPolicyId) {
                this.selectedPolicyId = data[0].Id;
                this.loadTaxRates();
            }
        } else if (error) {
            this.notifyError(error);
        }
    }

    get hasPolicies() {
        return this.policies.length > 0;
    }

    get hasSelectedPolicy() {
        return !!this.selectedPolicyId;
    }

    get formTitle() {
        return this.recordId ? 'Edit Tax Rate' : 'New Tax Rate';
    }

    async loadTaxRates() {
        if (!this.selectedPolicyId) {
            return;
        }
        this.isLoading = true;
        try {
            this.taxRates = await getTaxRates({ policyId: this.selectedPolicyId });
        } catch (error) {
            this.notifyError(error);
        }
        this.isLoading = false;
    }

    handlePolicyChange(event) {
        this.selectedPolicyId = event.detail.value;
        this.loadTaxRates();
    }

    handleNew() {
        this.recordId = null;
        this.draftName = '';
        this.draftCode = '';
        this.draftRate = null;
        this.draftEnabled = true;
        this.showForm = true;
    }

    handleRowAction(event) {
        const action = event.detail.action.name;
        const row = event.detail.row;
        if (action === 'edit') {
            this.recordId = row.Id;
            this.draftName = row.Name;
            this.draftCode = row.Code__c;
            this.draftRate = row.Rate_Percent__c;
            this.draftEnabled = row.Enabled__c;
            this.showForm = true;
        } else if (action === 'delete') {
            this.deleteRow(row.Id);
        }
    }

    handleNameChange(event) {
        this.draftName = event.target.value;
    }

    handleCodeChange(event) {
        this.draftCode = event.target.value;
    }

    handleRateChange(event) {
        this.draftRate = event.target.value;
    }

    handleEnabledChange(event) {
        this.draftEnabled = event.target.checked;
    }

    handleCancel() {
        this.showForm = false;
    }

    async handleSave() {
        this.isLoading = true;
        try {
            await saveTaxRate({
                recordId: this.recordId,
                policyId: this.selectedPolicyId,
                name: this.draftName,
                ratePercent: this.draftRate,
                code: this.draftCode,
                enabled: this.draftEnabled
            });
            this.showForm = false;
            this.notifySuccess('Tax rate saved');
            await this.loadTaxRates();
        } catch (error) {
            this.notifyError(error);
        }
        this.isLoading = false;
    }

    async deleteRow(taxRateId) {
        this.isLoading = true;
        try {
            await removeTaxRate({ taxRateId });
            this.notifySuccess('Tax rate deleted');
            await this.loadTaxRates();
        } catch (error) {
            this.notifyError(error);
        }
        this.isLoading = false;
    }

    notifySuccess(message) {
        this.dispatchEvent(new ShowToastEvent({ title: 'Success', message, variant: 'success' }));
    }

    notifyError(error) {
        const message = error && error.body && error.body.message ? error.body.message : 'An unexpected error occurred';
        this.dispatchEvent(new ShowToastEvent({ title: 'Error', message, variant: 'error' }));
    }
}
