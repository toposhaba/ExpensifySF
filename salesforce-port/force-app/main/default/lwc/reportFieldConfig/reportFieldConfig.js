import { LightningElement, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getMyPolicies from '@salesforce/apex/ExpenseController.getMyPolicies';
import getFieldDefs from '@salesforce/apex/ReportFieldService.getFieldDefs';
import createFieldDef from '@salesforce/apex/ReportFieldService.createFieldDef';
import deleteFieldDef from '@salesforce/apex/ReportFieldService.deleteFieldDef';

const FIELD_TYPE_OPTIONS = [
    { label: 'Text', value: 'Text' },
    { label: 'Number', value: 'Number' },
    { label: 'Date', value: 'Date' },
    { label: 'Dropdown', value: 'Dropdown' }
];

const COLUMNS = [
    { label: 'Name', fieldName: 'Name', type: 'text' },
    { label: 'Type', fieldName: 'Field_Type__c', type: 'text' },
    { label: 'Required', fieldName: 'Required__c', type: 'boolean' },
    { label: 'Default', fieldName: 'Default_Value__c', type: 'text' },
    {
        type: 'button-icon',
        fixedWidth: 60,
        typeAttributes: {
            iconName: 'utility:delete',
            name: 'delete',
            title: 'Delete',
            variant: 'bare',
            alternativeText: 'Delete'
        }
    }
];

export default class ReportFieldConfig extends LightningElement {
    @track policies = [];
    @track selectedPolicyId;
    @track fieldName = '';
    @track fieldType = 'Text';
    @track options = '';
    @track defaultValue = '';
    @track required = false;
    @track isSaving = false;

    fieldTypeOptions = FIELD_TYPE_OPTIONS;
    columns = COLUMNS;
    wiredDefs;

    @wire(getMyPolicies)
    wiredPolicies({ data }) {
        if (data) {
            this.policies = data;
            if (data.length > 0 && !this.selectedPolicyId) {
                this.selectedPolicyId = data[0].Id;
            }
        }
    }

    @wire(getFieldDefs, { policyId: '$selectedPolicyId' })
    wiredFieldDefs(result) {
        this.wiredDefs = result;
        if (result.data) {
            this.fieldDefs = result.data;
        }
    }

    @track fieldDefs = [];

    get policyOptions() {
        return this.policies.map((p) => ({ label: p.Name, value: p.Id }));
    }

    get hasPolicies() {
        return this.policies.length > 0;
    }

    get isDropdown() {
        return this.fieldType === 'Dropdown';
    }

    get isSaveDisabled() {
        return this.isSaving || !this.selectedPolicyId || !this.fieldName;
    }

    handlePolicyChange(event) {
        this.selectedPolicyId = event.detail.value;
    }

    handleNameChange(event) {
        this.fieldName = event.detail.value;
    }

    handleTypeChange(event) {
        this.fieldType = event.detail.value;
    }

    handleOptionsChange(event) {
        this.options = event.detail.value;
    }

    handleDefaultChange(event) {
        this.defaultValue = event.detail.value;
    }

    handleRequiredChange(event) {
        this.required = event.detail.checked;
    }

    async handleCreate() {
        this.isSaving = true;
        const fieldDef = {
            sobjectType: 'Report_Field__c',
            Name: this.fieldName,
            Policy__c: this.selectedPolicyId,
            Field_Type__c: this.fieldType,
            Options__c: this.isDropdown ? this.options : null,
            Default_Value__c: this.defaultValue,
            Required__c: this.required
        };
        try {
            await createFieldDef({ fieldDef });
            this.resetForm();
            await refreshApex(this.wiredDefs);
            this.showToast('Success', 'Report field created', 'success');
        } catch (error) {
            this.showToast('Error', this.reduceError(error), 'error');
        }
        this.isSaving = false;
    }

    async handleRowAction(event) {
        const action = event.detail.action;
        const row = event.detail.row;
        if (action.name === 'delete') {
            try {
                await deleteFieldDef({ fieldDefId: row.Id });
                await refreshApex(this.wiredDefs);
                this.showToast('Success', 'Report field deleted', 'success');
            } catch (error) {
                this.showToast('Error', this.reduceError(error), 'error');
            }
        }
    }

    resetForm() {
        this.fieldName = '';
        this.fieldType = 'Text';
        this.options = '';
        this.defaultValue = '';
        this.required = false;
    }

    reduceError(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }
        return 'An unexpected error occurred';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
