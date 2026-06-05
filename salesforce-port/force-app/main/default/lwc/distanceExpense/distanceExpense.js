import { LightningElement, track, wire } from 'lwc';
import getMyPolicies from '@salesforce/apex/ExpenseController.getMyPolicies';
import previewAmount from '@salesforce/apex/DistanceService.previewAmount';
import createExpenseFromDistance from '@salesforce/apex/DistanceService.createExpenseFromDistance';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class DistanceExpense extends LightningElement {
    @track policies = [];
    @track selectedPolicyId;
    @track distance;
    @track unit = 'mi';
    @track expenseDate = new Date().toISOString().split('T')[0];
    @track merchant;
    @track description;
    @track previewedAmount;
    @track previewedCurrency;
    @track previewError;
    @track isLoading = false;

    unitOptions = [
        { label: 'Miles', value: 'mi' },
        { label: 'Kilometers', value: 'km' }
    ];

    get policyOptions() {
        return this.policies.map((p) => ({ label: p.Name, value: p.Id }));
    }

    get hasPreview() {
        return this.previewedAmount != null;
    }

    get canPreview() {
        return this.selectedPolicyId && this.distance > 0;
    }

    get previewDisabled() {
        return !this.canPreview || this.isLoading;
    }

    get createDisabled() {
        return !this.hasPreview || this.isLoading;
    }

    get formattedAmount() {
        if (this.previewedAmount == null) {
            return '';
        }
        return `${this.previewedAmount} ${this.previewedCurrency || ''}`.trim();
    }

    @wire(getMyPolicies)
    wiredPolicies({ data }) {
        if (data) {
            this.policies = data;
            if (data.length > 0 && !this.selectedPolicyId) {
                this.selectedPolicyId = data[0].Id;
            }
        }
    }

    handlePolicyChange(event) {
        this.selectedPolicyId = event.detail.value;
        this.resetPreview();
    }

    handleDistanceChange(event) {
        this.distance = event.target.value ? parseFloat(event.target.value) : null;
        this.resetPreview();
    }

    handleUnitChange(event) {
        this.unit = event.detail.value;
        this.resetPreview();
    }

    handleDateChange(event) {
        this.expenseDate = event.target.value;
    }

    handleMerchantChange(event) {
        this.merchant = event.target.value;
    }

    handleDescriptionChange(event) {
        this.description = event.target.value;
    }

    resetPreview() {
        this.previewedAmount = null;
        this.previewedCurrency = null;
        this.previewError = null;
    }

    async handlePreview() {
        if (!this.canPreview) {
            return;
        }
        this.isLoading = true;
        this.previewError = null;
        try {
            const quote = await previewAmount({
                policyId: this.selectedPolicyId,
                distance: this.distance,
                unit: this.unit
            });
            this.previewedAmount = quote.amount;
            this.previewedCurrency = quote.currencyCode;
        } catch (error) {
            this.previewError = this.extractError(error);
            this.resetPreviewAmount();
        }
        this.isLoading = false;
    }

    resetPreviewAmount() {
        this.previewedAmount = null;
        this.previewedCurrency = null;
    }

    async handleCreate() {
        if (!this.hasPreview) {
            return;
        }
        this.isLoading = true;
        try {
            await createExpenseFromDistance({
                policyId: this.selectedPolicyId,
                distance: this.distance,
                unit: this.unit,
                expenseDate: this.expenseDate,
                merchant: this.merchant,
                description: this.description
            });
            this.showToast('Success', 'Distance expense created', 'success');
            this.distance = null;
            this.merchant = null;
            this.description = null;
            this.resetPreview();
        } catch (error) {
            this.showToast('Error', this.extractError(error), 'error');
        }
        this.isLoading = false;
    }

    extractError(error) {
        return error && error.body && error.body.message ? error.body.message : 'Something went wrong';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
