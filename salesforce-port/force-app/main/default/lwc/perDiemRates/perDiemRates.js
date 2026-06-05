import { LightningElement, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getMyPolicies from '@salesforce/apex/ExpenseController.getMyPolicies';
import getPerDiemRates from '@salesforce/apex/PerDiemService.getPerDiemRates';
import addPerDiemRate from '@salesforce/apex/PerDiemService.addPerDiemRate';
import updatePerDiemRate from '@salesforce/apex/PerDiemService.updatePerDiemRate';
import removePerDiemRate from '@salesforce/apex/PerDiemService.removePerDiemRate';

export default class PerDiemRates extends LightningElement {
    @track policies = [];
    @track selectedPolicyId;
    @track rates = [];
    @track isLoading = false;

    editingRateId;
    draftDestination;
    draftSubRateName;
    draftDailyRate;
    draftMealRate;
    draftCurrency = 'USD';

    wiredRatesResult;

    @wire(getMyPolicies)
    wiredPolicies({ data }) {
        if (data) {
            this.policies = data.map((p) => ({ label: p.Name, value: p.Id }));
            if (data.length > 0 && !this.selectedPolicyId) {
                this.selectedPolicyId = data[0].Id;
            }
        }
    }

    @wire(getPerDiemRates, { policyId: '$selectedPolicyId' })
    wiredRates(result) {
        this.wiredRatesResult = result;
        if (result.data) {
            this.rates = result.data.map((r) => ({
                id: r.Id,
                destination: r.Destination__c,
                subRateName: r.Sub_Rate_Name__c,
                dailyRate: r.Daily_Rate__c,
                mealRate: r.Meal_Rate__c,
                currency: r.Currency__c
            }));
        } else if (result.error) {
            this.showError(result.error);
        }
    }

    get hasPolicies() {
        return this.policies.length > 0;
    }

    get hasRates() {
        return this.rates.length > 0;
    }

    get isAddDisabled() {
        return !this.selectedPolicyId || !this.draftDestination || this.draftDailyRate === undefined || this.draftDailyRate === null;
    }

    get isEditing() {
        return !!this.editingRateId;
    }

    handlePolicyChange(event) {
        this.selectedPolicyId = event.detail.value;
        this.resetForm();
    }

    handleDestinationChange(event) {
        this.draftDestination = event.detail.value;
    }

    handleSubRateNameChange(event) {
        this.draftSubRateName = event.detail.value;
    }

    handleDailyRateChange(event) {
        this.draftDailyRate = event.detail.value;
    }

    handleMealRateChange(event) {
        this.draftMealRate = event.detail.value;
    }

    handleCurrencyChange(event) {
        this.draftCurrency = event.detail.value;
    }

    async handleSave() {
        if (this.isAddDisabled) {
            return;
        }
        this.isLoading = true;
        const params = {
            destination: this.draftDestination,
            subRateName: this.draftSubRateName || null,
            dailyRate: parseFloat(this.draftDailyRate),
            mealRate: this.draftMealRate ? parseFloat(this.draftMealRate) : null,
            currencyCode: this.draftCurrency || 'USD'
        };
        try {
            if (this.editingRateId) {
                await updatePerDiemRate({ rateId: this.editingRateId, ...params });
                this.showSuccess('Per diem rate updated');
            } else {
                await addPerDiemRate({ policyId: this.selectedPolicyId, ...params });
                this.showSuccess('Per diem rate added');
            }
            this.resetForm();
            await refreshApex(this.wiredRatesResult);
        } catch (error) {
            this.showError(error);
        }
        this.isLoading = false;
    }

    handleEdit(event) {
        const rateId = event.currentTarget.dataset.id;
        const rate = this.rates.find((r) => r.id === rateId);
        if (!rate) {
            return;
        }
        this.editingRateId = rate.id;
        this.draftDestination = rate.destination;
        this.draftSubRateName = rate.subRateName;
        this.draftDailyRate = rate.dailyRate;
        this.draftMealRate = rate.mealRate;
        this.draftCurrency = rate.currency;
    }

    async handleDelete(event) {
        const rateId = event.currentTarget.dataset.id;
        this.isLoading = true;
        try {
            await removePerDiemRate({ rateId });
            this.showSuccess('Per diem rate removed');
            if (this.editingRateId === rateId) {
                this.resetForm();
            }
            await refreshApex(this.wiredRatesResult);
        } catch (error) {
            this.showError(error);
        }
        this.isLoading = false;
    }

    handleCancel() {
        this.resetForm();
    }

    resetForm() {
        this.editingRateId = undefined;
        this.draftDestination = undefined;
        this.draftSubRateName = undefined;
        this.draftDailyRate = undefined;
        this.draftMealRate = undefined;
        this.draftCurrency = 'USD';
        const inputs = this.template.querySelectorAll('[data-form="rate"]');
        inputs.forEach((input) => {
            // eslint-disable-next-line no-param-reassign
            input.value = null;
        });
    }

    showSuccess(message) {
        this.dispatchEvent(new ShowToastEvent({ title: 'Success', message, variant: 'success' }));
    }

    showError(error) {
        const message = error && error.body && error.body.message ? error.body.message : 'An unexpected error occurred';
        this.dispatchEvent(new ShowToastEvent({ title: 'Error', message, variant: 'error' }));
    }
}
