import { LightningElement, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getMyPolicies from '@salesforce/apex/ExpenseController.getMyPolicies';
import getCategories from '@salesforce/apex/ExpenseController.getCategories';
import getTags from '@salesforce/apex/ExpenseController.getTags';
import getRules from '@salesforce/apex/ExpenseRuleService.getRules';
import createRule from '@salesforce/apex/ExpenseRuleService.createRule';
import updateRule from '@salesforce/apex/ExpenseRuleService.updateRule';
import deleteRule from '@salesforce/apex/ExpenseRuleService.deleteRule';

const MATCH_TYPE_OPTIONS = [
    { label: 'Contains', value: 'Contains' },
    { label: 'Equals', value: 'Equals' },
    { label: 'Starts With', value: 'StartsWith' }
];

export default class PolicyRules extends LightningElement {
    @track policyOptions = [];
    @track selectedPolicyId;
    @track rules = [];
    @track categoryOptions = [];
    @track tagOptions = [];
    @track isLoading = false;

    newMerchant;
    newMatchType = 'Contains';
    newCategoryId;
    newTagId;

    matchTypeOptions = MATCH_TYPE_OPTIONS;

    @wire(getMyPolicies)
    wiredPolicies({ data }) {
        if (data) {
            this.policyOptions = data.map((p) => ({ label: p.Name, value: p.Id }));
            if (data.length > 0 && !this.selectedPolicyId) {
                this.selectedPolicyId = data[0].Id;
                this.loadRules();
            }
        }
    }

    get hasPolicies() {
        return this.policyOptions.length > 0;
    }

    get hasRules() {
        return this.rules.length > 0;
    }

    get isAddDisabled() {
        return !this.selectedPolicyId || !this.newMerchant;
    }

    get categoryChoices() {
        return [{ label: '-- None --', value: '' }, ...this.categoryOptions];
    }

    get tagChoices() {
        return [{ label: '-- None --', value: '' }, ...this.tagOptions];
    }

    handlePolicyChange(event) {
        this.selectedPolicyId = event.detail.value;
        this.resetForm();
        this.loadRules();
    }

    handleMerchantChange(event) {
        this.newMerchant = event.detail.value;
    }

    handleMatchTypeChange(event) {
        this.newMatchType = event.detail.value;
    }

    handleCategoryChange(event) {
        this.newCategoryId = event.detail.value;
    }

    handleTagChange(event) {
        this.newTagId = event.detail.value;
    }

    async loadRules() {
        if (!this.selectedPolicyId) {
            return;
        }
        this.isLoading = true;
        try {
            const [rules, cats, tags] = await Promise.all([
                getRules({ policyId: this.selectedPolicyId }),
                getCategories({ policyId: this.selectedPolicyId }),
                getTags({ policyId: this.selectedPolicyId })
            ]);
            this.categoryOptions = cats.map((c) => ({ label: c.Name, value: c.Id }));
            this.tagOptions = tags.map((t) => ({ label: t.Name, value: t.Id }));
            this.rules = rules.map((r) => ({
                id: r.Id,
                name: r.Name,
                merchantMatch: r.Merchant_Match__c,
                matchType: r.Match_Type__c,
                categoryId: r.Apply_Category__c,
                categoryName: r.Apply_Category__r ? r.Apply_Category__r.Name : '',
                tagId: r.Apply_Tag__c,
                tagName: r.Apply_Tag__r ? r.Apply_Tag__r.Name : '',
                enabled: r.Enabled__c
            }));
        } catch (error) {
            this.showError(error);
        }
        this.isLoading = false;
    }

    async handleAddRule() {
        if (this.isAddDisabled) {
            return;
        }
        this.isLoading = true;
        try {
            await createRule({
                policyId: this.selectedPolicyId,
                merchantMatch: this.newMerchant,
                matchType: this.newMatchType,
                applyCategoryId: this.newCategoryId || null,
                applyTagId: this.newTagId || null,
                enabled: true
            });
            this.showSuccess('Rule added');
            this.resetForm();
            await this.loadRules();
        } catch (error) {
            this.showError(error);
            this.isLoading = false;
        }
    }

    async handleToggleEnabled(event) {
        const ruleId = event.currentTarget.dataset.id;
        const rule = this.rules.find((r) => r.id === ruleId);
        if (!rule) {
            return;
        }
        this.isLoading = true;
        try {
            await updateRule({
                ruleId,
                merchantMatch: null,
                matchType: null,
                applyCategoryId: rule.categoryId || null,
                applyTagId: rule.tagId || null,
                enabled: !rule.enabled
            });
            await this.loadRules();
        } catch (error) {
            this.showError(error);
            this.isLoading = false;
        }
    }

    async handleDeleteRule(event) {
        const ruleId = event.currentTarget.dataset.id;
        this.isLoading = true;
        try {
            await deleteRule({ ruleId });
            this.showSuccess('Rule removed');
            await this.loadRules();
        } catch (error) {
            this.showError(error);
            this.isLoading = false;
        }
    }

    resetForm() {
        this.newMerchant = undefined;
        this.newMatchType = 'Contains';
        this.newCategoryId = undefined;
        this.newTagId = undefined;
        const inputs = this.template.querySelectorAll('[data-form="new-rule"]');
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
