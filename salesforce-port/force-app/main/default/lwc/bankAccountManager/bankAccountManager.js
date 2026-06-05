import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const COLUMNS = [
    { label: 'Account Name', fieldName: 'accountName', type: 'text' },
    { label: 'Bank', fieldName: 'bank', type: 'text' },
    { label: 'Type', fieldName: 'accountType', type: 'text' },
    { label: 'Last Four', fieldName: 'lastFour', type: 'text' },
    { label: 'Status', fieldName: 'status', type: 'text' },
    { label: 'Default', fieldName: 'isDefault', type: 'boolean' },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [
                { label: 'Set Default', name: 'setDefault' },
                { label: 'Deactivate', name: 'deactivate' }
            ]
        }
    }
];

export default class BankAccountManager extends LightningElement {
    @track accounts = [];
    @track columns = COLUMNS;
    @track walletBalance = 2450.75;
    @track isAddModalOpen = false;
    @track isLoading = false;
    @track newAccount = {
        accountName: '',
        bank: '',
        accountType: 'Checking',
        routingNumber: '',
        accountNumber: ''
    };

    get accountTypeOptions() {
        return [
            { label: 'Checking', value: 'Checking' },
            { label: 'Savings', value: 'Savings' }
        ];
    }

    get bankOptions() {
        return [
            { label: 'Chase', value: 'Chase' },
            { label: 'Bank of America', value: 'Bank of America' },
            { label: 'Wells Fargo', value: 'Wells Fargo' },
            { label: 'Citibank', value: 'Citibank' },
            { label: 'US Bank', value: 'US Bank' },
            { label: 'Capital One', value: 'Capital One' }
        ];
    }

    get activeAccountCount() {
        return this.accounts.filter(a => a.status === 'Active').length;
    }

    get formattedWalletBalance() {
        return `$${this.walletBalance.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
    }

    connectedCallback() {
        this.loadAccounts();
    }

    loadAccounts() {
        this.isLoading = true;
        this.accounts = [
            { id: '1', accountName: 'Primary Checking', bank: 'Chase', accountType: 'Checking', lastFour: '4523', status: 'Active', isDefault: true },
            { id: '2', accountName: 'Business Savings', bank: 'Bank of America', accountType: 'Savings', lastFour: '8901', status: 'Active', isDefault: false },
            { id: '3', accountName: 'Expense Account', bank: 'Wells Fargo', accountType: 'Checking', lastFour: '3456', status: 'Active', isDefault: false },
            { id: '4', accountName: 'Old Account', bank: 'Citibank', accountType: 'Checking', lastFour: '7890', status: 'Inactive', isDefault: false }
        ];
        this.isLoading = false;
    }

    handleOpenAddModal() {
        this.newAccount = {
            accountName: '',
            bank: '',
            accountType: 'Checking',
            routingNumber: '',
            accountNumber: ''
        };
        this.isAddModalOpen = true;
    }

    handleCloseAddModal() {
        this.isAddModalOpen = false;
    }

    handleAccountNameChange(event) {
        this.newAccount = { ...this.newAccount, accountName: event.target.value };
    }

    handleBankChange(event) {
        this.newAccount = { ...this.newAccount, bank: event.detail.value };
    }

    handleAccountTypeChange(event) {
        this.newAccount = { ...this.newAccount, accountType: event.detail.value };
    }

    handleRoutingNumberChange(event) {
        this.newAccount = { ...this.newAccount, routingNumber: event.target.value };
    }

    handleAccountNumberChange(event) {
        this.newAccount = { ...this.newAccount, accountNumber: event.target.value };
    }

    handleAddAccount() {
        if (!this.newAccount.accountName || !this.newAccount.bank || !this.newAccount.routingNumber || !this.newAccount.accountNumber) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: 'Please fill in all required fields.',
                variant: 'error'
            }));
            return;
        }
        if (this.newAccount.routingNumber.length !== 9) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: 'Routing number must be 9 digits.',
                variant: 'error'
            }));
            return;
        }
        const lastFour = this.newAccount.accountNumber.slice(-4);
        const account = {
            id: String(Date.now()),
            accountName: this.newAccount.accountName,
            bank: this.newAccount.bank,
            accountType: this.newAccount.accountType,
            lastFour: lastFour,
            status: 'Active',
            isDefault: false
        };
        this.accounts = [...this.accounts, account];
        this.isAddModalOpen = false;
        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message: `Account "${account.accountName}" added successfully.`,
            variant: 'success'
        }));
    }

    handleRowAction(event) {
        const action = event.detail.action;
        const row = event.detail.row;

        switch (action.name) {
            case 'setDefault':
                this.setDefaultAccount(row);
                break;
            case 'deactivate':
                this.deactivateAccount(row);
                break;
            default:
                break;
        }
    }

    setDefaultAccount(row) {
        if (row.status !== 'Active') {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: 'Cannot set an inactive account as default.',
                variant: 'error'
            }));
            return;
        }
        this.accounts = this.accounts.map(a => ({
            ...a,
            isDefault: a.id === row.id
        }));
        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message: `"${row.accountName}" is now the default account.`,
            variant: 'success'
        }));
    }

    deactivateAccount(row) {
        if (row.isDefault) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: 'Cannot deactivate the default account. Set another account as default first.',
                variant: 'error'
            }));
            return;
        }
        this.accounts = this.accounts.map(a => {
            if (a.id === row.id) {
                return { ...a, status: 'Inactive' };
            }
            return a;
        });
        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message: `"${row.accountName}" has been deactivated.`,
            variant: 'success'
        }));
    }
}
