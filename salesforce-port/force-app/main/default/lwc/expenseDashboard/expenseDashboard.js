import { LightningElement, wire, track } from 'lwc';
import getDashboardData from '@salesforce/apex/ExpenseController.getDashboardData';

export default class ExpenseDashboard extends LightningElement {
    @track dashboardData = {};
    @track isLoading = true;

    @wire(getDashboardData)
    wiredDashboard({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.dashboardData = data;
        }
    }

    get monthlySpend() {
        return this.dashboardData.monthlySpend || 0;
    }

    get pendingApprovals() {
        return this.dashboardData.pendingApprovals || 0;
    }

    get unreportedExpenses() {
        return this.dashboardData.unreportedExpenses || 0;
    }

    get openReports() {
        return this.dashboardData.openReports || 0;
    }

    get formattedMonthlySpend() {
        return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(this.monthlySpend);
    }
}
