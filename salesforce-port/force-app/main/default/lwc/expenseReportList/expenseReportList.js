import { LightningElement, wire, track } from 'lwc';
import getMyReports from '@salesforce/apex/ExpenseController.getMyReports';
import getReportsToApprove from '@salesforce/apex/ExpenseController.getReportsToApprove';
import createReport from '@salesforce/apex/ExpenseController.createReport';
import submitReport from '@salesforce/apex/ExpenseController.submitReport';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

export default class ExpenseReportList extends LightningElement {
    @track reports = [];
    @track approvalReports = [];
    @track isLoading = true;
    @track activeTab = 'my-reports';
    @track showNewReportModal = false;
    @track newReportName = '';
    @track newReportCurrency = 'USD';
    wiredReportsResult;

    columns = [
        { label: 'Report #', fieldName: 'Name', type: 'text' },
        { label: 'Status', fieldName: 'Status__c', type: 'text' },
        { label: 'Total', fieldName: 'Total_Amount__c', type: 'currency' },
        { label: 'Expenses', fieldName: 'Expense_Count__c', type: 'number' },
        { label: 'Policy', fieldName: 'policyName', type: 'text' },
        { label: 'Submitted', fieldName: 'Submitted_Date__c', type: 'date' },
        { label: 'Created', fieldName: 'CreatedDate', type: 'date' },
        { type: 'action', typeAttributes: { rowActions: this.getRowActions }}
    ];

    approvalColumns = [
        { label: 'Report #', fieldName: 'Name', type: 'text' },
        { label: 'Submitter', fieldName: 'ownerName', type: 'text' },
        { label: 'Total', fieldName: 'Total_Amount__c', type: 'currency' },
        { label: 'Expenses', fieldName: 'Expense_Count__c', type: 'number' },
        { label: 'Policy', fieldName: 'policyName', type: 'text' },
        { label: 'Submitted', fieldName: 'Submitted_Date__c', type: 'date' },
        { type: 'action', typeAttributes: { rowActions: [
            { label: 'View', name: 'view' },
            { label: 'Approve', name: 'approve' },
            { label: 'Reject', name: 'reject' }
        ]}}
    ];

    getRowActions(row) {
        const actions = [{ label: 'View', name: 'view' }];
        if (row.Status__c === 'Open' || row.Status__c === 'Rejected') {
            actions.push({ label: 'Submit', name: 'submit' });
        }
        if (row.Status__c === 'Open') {
            actions.push({ label: 'Delete', name: 'delete' });
        }
        return actions;
    }

    @wire(getMyReports)
    wiredReports(result) {
        this.wiredReportsResult = result;
        this.isLoading = false;
        if (result.data) {
            this.reports = result.data.map(r => ({
                ...r,
                policyName: r.Policy__r ? r.Policy__r.Name : ''
            }));
        }
    }

    @wire(getReportsToApprove)
    wiredApprovals({ data }) {
        if (data) {
            this.approvalReports = data.map(r => ({
                ...r,
                policyName: r.Policy__r ? r.Policy__r.Name : '',
                ownerName: r.Owner ? r.Owner.Name : ''
            }));
        }
    }

    handleTabChange(event) {
        this.activeTab = event.target.value;
    }

    handleRowAction(event) {
        const action = event.detail.action;
        const row = event.detail.row;

        switch (action.name) {
            case 'view':
                this.dispatchEvent(new CustomEvent('reportselected', { detail: { reportId: row.Id } }));
                break;
            case 'submit':
                this.handleSubmit(row.Id);
                break;
        }
    }

    async handleSubmit(reportId) {
        this.isLoading = true;
        try {
            await submitReport({ reportId });
            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: 'Report submitted for approval',
                variant: 'success'
            }));
            await refreshApex(this.wiredReportsResult);
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error.body?.message || 'Failed to submit report',
                variant: 'error'
            }));
        }
        this.isLoading = false;
    }

    handleNewReport() {
        this.showNewReportModal = true;
    }

    handleModalClose() {
        this.showNewReportModal = false;
        this.newReportName = '';
    }

    handleReportNameChange(event) {
        this.newReportName = event.target.value;
    }

    async handleCreateReport() {
        this.isLoading = true;
        try {
            const report = {
                Currency__c: this.newReportCurrency,
                Status__c: 'Open'
            };
            await createReport({ report });
            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: 'Report created',
                variant: 'success'
            }));
            this.showNewReportModal = false;
            await refreshApex(this.wiredReportsResult);
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error.body?.message || 'Failed to create report',
                variant: 'error'
            }));
        }
        this.isLoading = false;
    }

    get hasApprovals() {
        return this.approvalReports.length > 0;
    }

    get approvalCount() {
        return this.approvalReports.length;
    }
}
