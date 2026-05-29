import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import findDuplicates from '@salesforce/apex/ExpenseController.findDuplicates';
import mergeDuplicates from '@salesforce/apex/ExpenseController.mergeDuplicates';

export default class DuplicateReview extends LightningElement {
    @track duplicateGroups = [];
    @track isLoading = false;
    @track selectedKeepIds = {};
    @track hasDuplicates = false;

    async handleFindDuplicates() {
        this.isLoading = true;
        try {
            const result = await findDuplicates();
            this.duplicateGroups = result.map((group, index) => ({
                ...group,
                groupIndex: index,
                expenses: group.expenses.map(exp => ({
                    ...exp,
                    isSelected: false
                }))
            }));
            this.hasDuplicates = this.duplicateGroups.length > 0;
            if (!this.hasDuplicates) {
                this.showToast('Info', 'No duplicates found', 'info');
            }
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to find duplicates', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleSelectKeep(event) {
        const groupIndex = parseInt(event.target.dataset.group, 10);
        const expenseId = event.target.dataset.id;
        this.selectedKeepIds = { ...this.selectedKeepIds, [groupIndex]: expenseId };
    }

    async handleMerge(event) {
        const groupIndex = parseInt(event.target.dataset.group, 10);
        const keepId = this.selectedKeepIds[groupIndex];

        if (!keepId) {
            this.showToast('Error', 'Please select an expense to keep', 'error');
            return;
        }

        const group = this.duplicateGroups[groupIndex];
        const mergeIds = group.expenses
            .filter(exp => exp.id !== keepId)
            .map(exp => exp.id);

        this.isLoading = true;
        try {
            await mergeDuplicates({ keepId, mergeIds });
            this.showToast('Success', 'Duplicates merged successfully', 'success');
            this.duplicateGroups = this.duplicateGroups.filter((_, i) => i !== groupIndex);
            this.hasDuplicates = this.duplicateGroups.length > 0;
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to merge duplicates', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    isKeepSelected(groupIndex, expenseId) {
        return this.selectedKeepIds[groupIndex] === expenseId;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
