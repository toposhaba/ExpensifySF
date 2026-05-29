import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPolicies from '@salesforce/apex/ExpenseController.getPolicies';
import getReports from '@salesforce/apex/ExpenseController.getReports';
import createDistanceExpense from '@salesforce/apex/ExpenseController.createDistanceExpense';
import getDistanceRates from '@salesforce/apex/ExpenseController.getDistanceRates';

const UNIT_OPTIONS = [
    { label: 'Miles (mi)', value: 'mi' },
    { label: 'Kilometers (km)', value: 'km' }
];

export default class DistanceExpenseForm extends LightningElement {
    @track policyId = '';
    @track distance = null;
    @track unit = 'mi';
    @track reportId = '';
    @track calculatedAmount = 0;
    @track isLoading = false;
    @track policies = [];
    @track reports = [];
    @track ratePerUnit = 0;
    unitOptions = UNIT_OPTIONS;

    @wire(getPolicies)
    wiredPolicies({ error, data }) {
        if (data) {
            this.policies = data.map(p => ({ label: p.name, value: p.id }));
        } else if (error) {
            this.showToast('Error', 'Failed to load policies', 'error');
        }
    }

    @wire(getReports)
    wiredReports({ error, data }) {
        if (data) {
            this.reports = [
                { label: '-- None --', value: '' },
                ...data.map(r => ({ label: r.name, value: r.id }))
            ];
        } else if (error) {
            this.showToast('Error', 'Failed to load reports', 'error');
        }
    }

    handlePolicyChange(event) {
        this.policyId = event.detail.value;
        this.loadDistanceRate();
    }

    handleDistanceChange(event) {
        this.distance = parseFloat(event.detail.value);
        this.calculateAmount();
    }

    handleUnitChange(event) {
        this.unit = event.detail.value;
        this.loadDistanceRate();
    }

    handleReportChange(event) {
        this.reportId = event.detail.value;
    }

    async loadDistanceRate() {
        if (!this.policyId) return;
        try {
            const rates = await getDistanceRates({ policyId: this.policyId });
            const rate = rates.find(r => r.unit === this.unit);
            this.ratePerUnit = rate ? rate.rate : 0;
            this.calculateAmount();
        } catch (error) {
            this.ratePerUnit = 0;
            this.calculateAmount();
        }
    }

    calculateAmount() {
        if (this.distance && this.ratePerUnit) {
            this.calculatedAmount = (this.distance * this.ratePerUnit).toFixed(2);
        } else {
            this.calculatedAmount = 0;
        }
    }

    get formattedAmount() {
        return `$${this.calculatedAmount}`;
    }

    get isSaveDisabled() {
        return !this.policyId || !this.distance || this.distance <= 0;
    }

    async handleSave() {
        if (this.isSaveDisabled) {
            this.showToast('Error', 'Please fill in required fields', 'error');
            return;
        }
        this.isLoading = true;
        try {
            await createDistanceExpense({
                policyId: this.policyId,
                distance: this.distance,
                unit: this.unit,
                reportId: this.reportId || null
            });
            this.showToast('Success', 'Distance expense created successfully', 'success');
            this.resetForm();
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to create distance expense', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    resetForm() {
        this.distance = null;
        this.reportId = '';
        this.calculatedAmount = 0;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
