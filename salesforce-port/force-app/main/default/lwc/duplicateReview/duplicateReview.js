import { LightningElement, api, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getDuplicateViolationsForExpense from '@salesforce/apex/DuplicateDetectionService.getDuplicateViolationsForExpense';
import checkForDuplicates from '@salesforce/apex/DuplicateDetectionService.checkForDuplicates';
import keepDuplicate from '@salesforce/apex/DuplicateDetectionService.keepDuplicate';
import removeDuplicateViolation from '@salesforce/apex/DuplicateDetectionService.removeDuplicateViolation';

export default class DuplicateReview extends LightningElement {
    @api recordId;
    @track isLoading = false;
    wiredViolations;
    violations = [];

    @wire(getDuplicateViolationsForExpense, { expenseId: '$recordId' })
    wiredResult(result) {
        this.wiredViolations = result;
        if (result.data) {
            this.violations = result.data.map((v) => this.decorate(v));
        } else if (result.error) {
            this.showError('Failed to load duplicate violations');
        }
    }

    decorate(violation) {
        const dup = violation.Duplicate_Expense__r || {};
        const status = violation.Status__c || 'Open';
        return {
            id: violation.Id,
            status,
            isOpen: status === 'Open',
            message: violation.Message__c,
            merchant: dup.Merchant__c,
            amount: dup.Amount__c,
            currency: dup.Currency__c,
            expenseDate: dup.Expense_Date__c,
            duplicateName: dup.Name
        };
    }

    get hasViolations() {
        return this.violations.length > 0;
    }

    get hasNoViolations() {
        return !this.isLoading && this.violations.length === 0;
    }

    get hasOpenViolations() {
        return this.violations.some((v) => v.isOpen);
    }

    async handleCheck() {
        this.isLoading = true;
        try {
            const count = await checkForDuplicates({ expenseId: this.recordId });
            await refreshApex(this.wiredViolations);
            this.showSuccess(count > 0 ? `Found ${count} potential duplicate(s)` : 'No duplicates found');
        } catch (error) {
            this.showError(error.body?.message || 'Failed to check for duplicates');
        }
        this.isLoading = false;
    }

    async handleKeep(event) {
        await this.runAction(keepDuplicate, event.target.dataset.id, 'Marked as not a duplicate');
    }

    async handleRemove(event) {
        await this.runAction(removeDuplicateViolation, event.target.dataset.id, 'Duplicate resolved');
    }

    async runAction(apexMethod, violationId, successMessage) {
        this.isLoading = true;
        try {
            await apexMethod({ violationId });
            await refreshApex(this.wiredViolations);
            this.showSuccess(successMessage);
        } catch (error) {
            this.showError(error.body?.message || 'Action failed');
        }
        this.isLoading = false;
    }

    showSuccess(message) {
        this.dispatchEvent(new ShowToastEvent({ title: 'Success', message, variant: 'success' }));
    }

    showError(message) {
        this.dispatchEvent(new ShowToastEvent({ title: 'Error', message, variant: 'error' }));
    }
}
