import { LightningElement, wire, track } from 'lwc';
import getWalletForCurrentUser from '@salesforce/apex/WalletService.getWalletForCurrentUser';
import getPaymentsForWallet from '@salesforce/apex/WalletService.getPaymentsForWallet';

export default class WalletSettings extends LightningElement {
    @track wallet = {};
    @track payments = [];
    @track isLoading = true;
    @track errorMessage;

    paymentColumns = [
        { label: 'Payment', fieldName: 'Name', type: 'text' },
        { label: 'Report', fieldName: 'reportName', type: 'text' },
        { label: 'Amount', fieldName: 'Amount__c', type: 'currency' },
        { label: 'Method', fieldName: 'Payment_Method__c', type: 'text' },
        { label: 'Status', fieldName: 'Status__c', type: 'text' },
        { label: 'Date', fieldName: 'Payment_Date__c', type: 'date' }
    ];

    @wire(getWalletForCurrentUser)
    wiredWallet({ data, error }) {
        if (data) {
            this.wallet = data;
            this.loadPayments();
        } else if (error) {
            this.errorMessage = this.reduceError(error);
            this.isLoading = false;
        }
    }

    async loadPayments() {
        if (!this.wallet || !this.wallet.Id) {
            this.isLoading = false;
            return;
        }
        try {
            const data = await getPaymentsForWallet({ walletId: this.wallet.Id });
            this.payments = data.map(p => ({
                ...p,
                reportName: p.Report__r ? p.Report__r.Name : ''
            }));
        } catch (error) {
            this.errorMessage = this.reduceError(error);
        }
        this.isLoading = false;
    }

    get hasWallet() {
        return this.wallet && this.wallet.Id;
    }

    get hasPayments() {
        return this.payments.length > 0;
    }

    get currencyCode() {
        return this.wallet && this.wallet.Currency__c ? this.wallet.Currency__c : 'USD';
    }

    reduceError(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }
        return 'An unexpected error occurred.';
    }
}
