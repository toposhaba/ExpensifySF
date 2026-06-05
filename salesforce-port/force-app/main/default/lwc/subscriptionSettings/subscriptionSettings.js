import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import listSubscriptions from '@salesforce/apex/SubscriptionService.listSubscriptions';
import createSubscriptionApex from '@salesforce/apex/SubscriptionService.createSubscriptionApex';
import changePlanApex from '@salesforce/apex/SubscriptionService.changePlanApex';
import updateSeatsApex from '@salesforce/apex/SubscriptionService.updateSeatsApex';
import cancelSubscriptionApex from '@salesforce/apex/SubscriptionService.cancelSubscriptionApex';

const PLAN_OPTIONS = [
    { label: 'Free', value: 'Free' },
    { label: 'Collect', value: 'Collect' },
    { label: 'Control', value: 'Control' }
];

const CYCLE_OPTIONS = [
    { label: 'Monthly', value: 'Monthly' },
    { label: 'Annual', value: 'Annual' }
];

const COLUMNS = [
    { label: 'Name', fieldName: 'Name', type: 'text' },
    { label: 'Plan', fieldName: 'Plan__c', type: 'text' },
    { label: 'Seats', fieldName: 'Seats__c', type: 'number' },
    { label: 'Billing Cycle', fieldName: 'Billing_Cycle__c', type: 'text' },
    { label: 'Status', fieldName: 'Status__c', type: 'text' },
    { label: 'Renewal', fieldName: 'Renewal_Date__c', type: 'date-local' },
    { label: 'Amount', fieldName: 'Amount__c', type: 'currency' }
];

export default class SubscriptionSettings extends LightningElement {
    @api policyId;

    @track subscriptions = [];
    @track selectedSubscriptionId;
    @track isLoading = false;

    plan = 'Free';
    seats = 1;
    billingCycle = 'Monthly';
    currencyCode = 'USD';
    newSeats = 1;
    changePlanValue = 'Free';

    planOptions = PLAN_OPTIONS;
    cycleOptions = CYCLE_OPTIONS;
    columns = COLUMNS;

    connectedCallback() {
        this.loadSubscriptions();
    }

    async loadSubscriptions() {
        this.isLoading = true;
        try {
            this.subscriptions = await listSubscriptions({ policyId: this.policyId });
        } catch (error) {
            this.showError(error);
        }
        this.isLoading = false;
    }

    get hasSubscriptions() {
        return this.subscriptions.length > 0;
    }

    get hasSelection() {
        return !!this.selectedSubscriptionId;
    }

    handlePlanChange(event) {
        this.plan = event.detail.value;
    }

    handleSeatsChange(event) {
        this.seats = event.detail.value;
    }

    handleCycleChange(event) {
        this.billingCycle = event.detail.value;
    }

    handleCurrencyChange(event) {
        this.currencyCode = event.detail.value;
    }

    handleChangePlanValue(event) {
        this.changePlanValue = event.detail.value;
    }

    handleNewSeatsChange(event) {
        this.newSeats = event.detail.value;
    }

    handleRowSelection(event) {
        const selected = event.detail.selectedRows;
        this.selectedSubscriptionId = selected.length > 0 ? selected[0].Id : undefined;
    }

    async handleCreate() {
        this.isLoading = true;
        try {
            await createSubscriptionApex({
                policyId: this.policyId,
                plan: this.plan,
                seats: parseInt(this.seats, 10),
                billingCycle: this.billingCycle,
                currencyCode: this.currencyCode
            });
            this.showSuccess('Subscription created');
            await this.loadSubscriptions();
        } catch (error) {
            this.showError(error);
        }
        this.isLoading = false;
    }

    async handleChangePlan() {
        if (!this.requireSelection()) {
            return;
        }
        this.isLoading = true;
        try {
            await changePlanApex({
                subscriptionId: this.selectedSubscriptionId,
                newPlan: this.changePlanValue
            });
            this.showSuccess('Plan updated');
            await this.loadSubscriptions();
        } catch (error) {
            this.showError(error);
        }
        this.isLoading = false;
    }

    async handleUpdateSeats() {
        if (!this.requireSelection()) {
            return;
        }
        this.isLoading = true;
        try {
            await updateSeatsApex({
                subscriptionId: this.selectedSubscriptionId,
                newSeats: parseInt(this.newSeats, 10)
            });
            this.showSuccess('Seats updated');
            await this.loadSubscriptions();
        } catch (error) {
            this.showError(error);
        }
        this.isLoading = false;
    }

    async handleCancel() {
        if (!this.requireSelection()) {
            return;
        }
        this.isLoading = true;
        try {
            await cancelSubscriptionApex({ subscriptionId: this.selectedSubscriptionId });
            this.showSuccess('Subscription cancelled');
            await this.loadSubscriptions();
        } catch (error) {
            this.showError(error);
        }
        this.isLoading = false;
    }

    requireSelection() {
        if (!this.selectedSubscriptionId) {
            this.showSuccess('Select a subscription first');
            return false;
        }
        return true;
    }

    showSuccess(message) {
        this.dispatchEvent(new ShowToastEvent({ title: 'Subscription', message, variant: 'success' }));
    }

    showError(error) {
        const message = error && error.body && error.body.message ? error.body.message : 'Something went wrong';
        this.dispatchEvent(new ShowToastEvent({ title: 'Error', message, variant: 'error' }));
    }
}
