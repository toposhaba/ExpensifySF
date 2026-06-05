import { LightningElement, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getMyPolicies from '@salesforce/apex/ExpenseController.getMyPolicies';
import getCards from '@salesforce/apex/CardService.getCards';
import getTransactions from '@salesforce/apex/CardService.getTransactions';
import importFromCsv from '@salesforce/apex/CardService.importFromCsv';
import matchTransaction from '@salesforce/apex/CardService.matchTransaction';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const TXN_COLUMNS = [
    { label: 'Posted', fieldName: 'Posted_Date__c', type: 'date-local', initialWidth: 130 },
    { label: 'Merchant', fieldName: 'Merchant__c', type: 'text' },
    { label: 'Amount', fieldName: 'Amount__c', type: 'currency', initialWidth: 130 },
    { label: 'Currency', fieldName: 'Currency__c', type: 'text', initialWidth: 100 },
    { label: 'Status', fieldName: 'Status__c', type: 'text', initialWidth: 120 },
    {
        type: 'button',
        initialWidth: 170,
        typeAttributes: {
            label: 'Create Expense',
            name: 'match',
            variant: 'brand-outline',
            disabled: { fieldName: 'isMatched' }
        }
    }
];

export default class CompanyCards extends LightningElement {
    @track policies = [];
    @track selectedPolicyId;
    @track cards = [];
    @track selectedCardId;
    @track transactions = [];
    @track csvBody = '';
    @track isLoading = false;

    txnColumns = TXN_COLUMNS;
    wiredTransactionsResult;

    @wire(getMyPolicies)
    wiredPolicies({ data }) {
        if (data) {
            this.policies = data;
            if (data.length > 0 && !this.selectedPolicyId) {
                this.selectedPolicyId = data[0].Id;
                this.loadCards();
            }
        }
    }

    @wire(getTransactions, { cardId: '$selectedCardId' })
    wiredTransactions(result) {
        this.wiredTransactionsResult = result;
        if (result.data) {
            this.transactions = result.data.map((row) => ({
                ...row,
                isMatched: row.Status__c === 'Matched'
            }));
        }
    }

    get policyOptions() {
        return this.policies.map((p) => ({ label: p.Name, value: p.Id }));
    }

    get cardOptions() {
        return this.cards.map((c) => ({
            label: c.Card_Name__c ? `${c.Card_Name__c} ••${c.Last_Four__c || ''}` : c.Name,
            value: c.Id
        }));
    }

    get hasCards() {
        return this.cards.length > 0;
    }

    get hasTransactions() {
        return this.transactions.length > 0;
    }

    get isImportDisabled() {
        return this.isLoading || !this.selectedCardId || !this.csvBody;
    }

    handlePolicyChange(event) {
        this.selectedPolicyId = event.detail.value;
        this.selectedCardId = undefined;
        this.transactions = [];
        this.loadCards();
    }

    handleCardChange(event) {
        this.selectedCardId = event.detail.value;
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

    async loadCards() {
        if (!this.selectedPolicyId) {
            return;
        }
        try {
            this.cards = await getCards({ policyId: this.selectedPolicyId });
            if (this.cards.length > 0 && !this.selectedCardId) {
                this.selectedCardId = this.cards[0].Id;
            }
        } catch (error) {
            this.showToast('Error', this.errorMessage(error), 'error');
        }
    }

    async handleImport() {
        if (!this.selectedCardId || !this.csvBody) {
            this.showToast('Error', 'Select a card and provide CSV data', 'error');
            return;
        }

        this.isLoading = true;
        try {
            const result = await importFromCsv({
                cardId: this.selectedCardId,
                csvBody: this.csvBody
            });
            const variant = result.errorCount > 0 ? 'warning' : 'success';
            this.showToast(
                'Import complete',
                `${result.importedCount} imported, ${result.duplicateCount} duplicates, ${result.errorCount} errors`,
                variant
            );
            this.csvBody = '';
            await refreshApex(this.wiredTransactionsResult);
        } catch (error) {
            this.showToast('Import failed', this.errorMessage(error), 'error');
        }
        this.isLoading = false;
    }

    async handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        if (actionName !== 'match') {
            return;
        }

        this.isLoading = true;
        try {
            await matchTransaction({ transactionId: row.Id, expenseId: null });
            this.showToast('Matched', 'Expense created and linked to transaction', 'success');
            await refreshApex(this.wiredTransactionsResult);
        } catch (error) {
            this.showToast('Match failed', this.errorMessage(error), 'error');
        }
        this.isLoading = false;
    }

    errorMessage(error) {
        return error && error.body && error.body.message ? error.body.message : 'Unexpected error';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
