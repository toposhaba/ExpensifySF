import { LightningElement, track, wire } from 'lwc';
import searchExpenses from '@salesforce/apex/ExpenseController.searchExpenses';
import getMyPolicies from '@salesforce/apex/ExpenseController.getMyPolicies';

export default class ExpenseSearch extends LightningElement {
    @track searchTerm = '';
    @track selectedStatus = '';
    @track selectedPolicy = '';
    @track startDate;
    @track endDate;
    @track results = [];
    @track isLoading = false;
    @track hasSearched = false;
    @track policies = [];

    statusOptions = [
        { label: 'All', value: '' },
        { label: 'Draft', value: 'Draft' },
        { label: 'Pending', value: 'Pending' },
        { label: 'Approved', value: 'Approved' },
        { label: 'Rejected', value: 'Rejected' },
        { label: 'On Hold', value: 'On_Hold' }
    ];

    columns = [
        { label: 'Date', fieldName: 'Expense_Date__c', type: 'date', sortable: true },
        { label: 'Merchant', fieldName: 'Merchant__c', type: 'text', sortable: true },
        { label: 'Amount', fieldName: 'Amount__c', type: 'currency', sortable: true },
        { label: 'Category', fieldName: 'categoryName', type: 'text' },
        { label: 'Status', fieldName: 'Status__c', type: 'text' },
        { label: 'Type', fieldName: 'Expense_Type__c', type: 'text' },
        { label: 'Report', fieldName: 'reportName', type: 'text' }
    ];

    @wire(getMyPolicies)
    wiredPolicies({ data }) {
        if (data) {
            this.policies = [
                { label: 'All Policies', value: '' },
                ...data.map(p => ({ label: p.Name, value: p.Id }))
            ];
        }
    }

    handleSearchTermChange(event) {
        this.searchTerm = event.target.value;
    }

    handleStatusChange(event) {
        this.selectedStatus = event.detail.value;
    }

    handlePolicyChange(event) {
        this.selectedPolicy = event.detail.value;
    }

    handleStartDateChange(event) {
        this.startDate = event.target.value;
    }

    handleEndDateChange(event) {
        this.endDate = event.target.value;
    }

    async handleSearch() {
        this.isLoading = true;
        this.hasSearched = true;
        try {
            const data = await searchExpenses({
                searchTerm: this.searchTerm,
                status: this.selectedStatus,
                policyId: this.selectedPolicy || null,
                startDate: this.startDate || null,
                endDate: this.endDate || null
            });
            this.results = data.map(exp => ({
                ...exp,
                categoryName: exp.Category__r ? exp.Category__r.Name : '',
                reportName: exp.Report__r ? exp.Report__r.Name : 'Unreported'
            }));
        } catch (error) {
            this.results = [];
        }
        this.isLoading = false;
    }

    handleKeyPress(event) {
        if (event.key === 'Enter') {
            this.handleSearch();
        }
    }

    get resultCount() {
        return this.results.length;
    }

    get hasResults() {
        return this.results.length > 0;
    }

    get noResults() {
        return this.hasSearched && this.results.length === 0 && !this.isLoading;
    }
}
