import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getMyBankAccounts from '@salesforce/apex/BankAccountService.getMyBankAccounts';
import createBankAccount from '@salesforce/apex/BankAccountService.createBankAccount';
import makeDefault from '@salesforce/apex/BankAccountService.makeDefault';

const COLUMNS = [
    { label: 'Account Name', fieldName: 'Account_Name__c', type: 'text' },
    { label: 'Bank', fieldName: 'Bank_Name__c', type: 'text' },
    { label: 'Account Number', fieldName: 'Account_Number__c', type: 'text' },
    { label: 'Status', fieldName: 'Status__c', type: 'text' },
    { label: 'Default', fieldName: 'Is_Default__c', type: 'boolean' },
    {
        type: 'button',
        typeAttributes: {
            label: 'Set Default',
            name: 'setDefault',
            variant: 'brand-outline'
        }
    }
];

export default class BankAccountSetup extends LightningElement {
    @track accountName = '';
    @track accountNumber = '';
    @track routingNumber = '';
    @track bankName = '';
    @track isDefault = false;
    @track isSaving = false;

    columns = COLUMNS;
    wiredAccounts;
    accounts = [];

    @wire(getMyBankAccounts)
    wiredBankAccounts(result) {
        this.wiredAccounts = result;
        if (result.data) {
            this.accounts = result.data;
        }
    }

    get hasAccounts() {
        return this.accounts.length > 0;
    }

    get isSaveDisabled() {
        return this.isSaving || !this.accountName || !this.accountNumber;
    }

    handleNameChange(event) {
        this.accountName = event.target.value;
    }

    handleAccountNumberChange(event) {
        this.accountNumber = event.target.value;
    }

    handleRoutingNumberChange(event) {
        this.routingNumber = event.target.value;
    }

    handleBankNameChange(event) {
        this.bankName = event.target.value;
    }

    handleDefaultChange(event) {
        this.isDefault = event.target.checked;
    }

    async handleAdd() {
        this.isSaving = true;
        try {
            await createBankAccount({
                accountName: this.accountName,
                accountNumber: this.accountNumber,
                routingNumber: this.routingNumber,
                bankName: this.bankName,
                policyId: null,
                isDefault: this.isDefault
            });
            this.showToast('Bank Account Added', `${this.accountName} was saved.`, 'success');
            this.resetForm();
            await refreshApex(this.wiredAccounts);
        } catch (error) {
            this.showToast('Add Failed', this.parseError(error), 'error');
        }
        this.isSaving = false;
    }

    async handleRowAction(event) {
        if (event.detail.action.name !== 'setDefault') {
            return;
        }
        try {
            await makeDefault({ bankAccountId: event.detail.row.Id });
            this.showToast('Default Updated', 'Default bank account changed.', 'success');
            await refreshApex(this.wiredAccounts);
        } catch (error) {
            this.showToast('Update Failed', this.parseError(error), 'error');
        }
    }

    resetForm() {
        this.accountName = '';
        this.accountNumber = '';
        this.routingNumber = '';
        this.bankName = '';
        this.isDefault = false;
    }

    parseError(error) {
        return error && error.body && error.body.message
            ? error.body.message
            : 'Unexpected error.';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
