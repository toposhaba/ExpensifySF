import { LightningElement, track, wire } from 'lwc';
import getMyExpenses from '@salesforce/apex/ExpenseController.getMyExpenses';
import getMyReports from '@salesforce/apex/ExpenseController.getMyReports';
import getDashboardData from '@salesforce/apex/ExpenseController.getDashboardData';

export default class ExpenseApp extends LightningElement {
    @track currentView = 'dashboard';
    @track selectedRecordId;
    @track dashboardData = {};

    get isDashboard() { return this.currentView === 'dashboard'; }
    get isExpenses() { return this.currentView === 'expenses'; }
    get isReports() { return this.currentView === 'reports'; }
    get isWorkspaces() { return this.currentView === 'workspaces'; }
    get isSearch() { return this.currentView === 'search'; }

    get navItems() {
        return [
            { label: 'Dashboard', value: 'dashboard', icon: 'utility:home' },
            { label: 'Expenses', value: 'expenses', icon: 'utility:money' },
            { label: 'Reports', value: 'reports', icon: 'utility:file' },
            { label: 'Workspaces', value: 'workspaces', icon: 'utility:company' },
            { label: 'Search', value: 'search', icon: 'utility:search' }
        ];
    }

    handleNavigation(event) {
        this.currentView = event.currentTarget.dataset.view;
        this.selectedRecordId = null;
    }

    handleExpenseCreated() {
        this.currentView = 'expenses';
    }

    handleReportSelected(event) {
        this.selectedRecordId = event.detail.reportId;
        this.currentView = 'reportDetail';
    }

    handleBack() {
        if (this.currentView === 'reportDetail') {
            this.currentView = 'reports';
        }
        this.selectedRecordId = null;
    }
}
