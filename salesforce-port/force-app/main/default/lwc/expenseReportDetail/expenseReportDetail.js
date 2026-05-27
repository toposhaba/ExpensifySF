import { LightningElement, api, wire, track } from 'lwc';
import getReport from '@salesforce/apex/ExpenseController.getReport';
import getExpensesByReport from '@salesforce/apex/ExpenseController.getExpensesByReport';
import getViolations from '@salesforce/apex/ExpenseController.getViolations';
import approveReport from '@salesforce/apex/ExpenseController.approveReport';
import rejectReport from '@salesforce/apex/ExpenseController.rejectReport';
import submitReport from '@salesforce/apex/ExpenseController.submitReport';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class ExpenseReportDetail extends LightningElement {
    @api reportId;
    @track report = {};
    @track expenses = [];
    @track isLoading = true;
    @track showRejectModal = false;
    @track rejectReason = '';

    expenseColumns = [
        { label: 'Date', fieldName: 'Expense_Date__c', type: 'date' },
        { label: 'Merchant', fieldName: 'Merchant__c', type: 'text' },
        { label: 'Amount', fieldName: 'Amount__c', type: 'currency' },
        { label: 'Category', fieldName: 'categoryName', type: 'text' },
        { label: 'Status', fieldName: 'Status__c', type: 'text' },
        { label: 'Type', fieldName: 'Expense_Type__c', type: 'text' },
        { label: 'Receipt', fieldName: 'Has_Receipt__c', type: 'boolean' }
    ];

    connectedCallback() {
        this.loadData();
    }

    async loadData() {
        this.isLoading = true;
        try {
            const [reportData, expenseData] = await Promise.all([
                getReport({ reportId: this.reportId }),
                getExpensesByReport({ reportId: this.reportId })
            ]);
            this.report = reportData;
            this.expenses = expenseData.map(exp => ({
                ...exp,
                categoryName: exp.Category__r ? exp.Category__r.Name : ''
            }));
        } catch (error) {
            this.showError('Failed to load report details');
        }
        this.isLoading = false;
    }

    get canSubmit() {
        return this.report.Status__c === 'Open' || this.report.Status__c === 'Rejected';
    }

    get canApprove() {
        return this.report.Status__c === 'Submitted';
    }

    get canReject() {
        return this.report.Status__c === 'Submitted';
    }

    get statusBadgeClass() {
        const classes = {
            'Open': 'slds-badge slds-theme_default',
            'Submitted': 'slds-badge slds-theme_warning',
            'Approved': 'slds-badge slds-theme_success',
            'Rejected': 'slds-badge slds-theme_error',
            'Reimbursed': 'slds-badge slds-theme_info'
        };
        return classes[this.report.Status__c] || 'slds-badge';
    }

    async handleSubmit() {
        this.isLoading = true;
        try {
            await submitReport({ reportId: this.reportId });
            this.showSuccess('Report submitted for approval');
            await this.loadData();
        } catch (error) {
            this.showError(error.body?.message || 'Failed to submit');
        }
        this.isLoading = false;
    }

    async handleApprove() {
        this.isLoading = true;
        try {
            await approveReport({ reportId: this.reportId });
            this.showSuccess('Report approved');
            await this.loadData();
        } catch (error) {
            this.showError(error.body?.message || 'Failed to approve');
        }
        this.isLoading = false;
    }

    handleRejectClick() {
        this.showRejectModal = true;
    }

    handleRejectReasonChange(event) {
        this.rejectReason = event.target.value;
    }

    async handleReject() {
        this.isLoading = true;
        try {
            await rejectReport({ reportId: this.reportId, reason: this.rejectReason });
            this.showSuccess('Report rejected');
            this.showRejectModal = false;
            await this.loadData();
        } catch (error) {
            this.showError(error.body?.message || 'Failed to reject');
        }
        this.isLoading = false;
    }

    handleRejectModalClose() {
        this.showRejectModal = false;
        this.rejectReason = '';
    }

    showSuccess(message) {
        this.dispatchEvent(new ShowToastEvent({ title: 'Success', message, variant: 'success' }));
    }

    showError(message) {
        this.dispatchEvent(new ShowToastEvent({ title: 'Error', message, variant: 'error' }));
    }
}
