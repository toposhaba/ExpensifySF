import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getApprovalWorkflow from '@salesforce/apex/ExpenseController.getApprovalWorkflow';
import addApprover from '@salesforce/apex/ExpenseController.addApprover';
import removeApprover from '@salesforce/apex/ExpenseController.removeApprover';
import reorderApprover from '@salesforce/apex/ExpenseController.reorderApprover';

export default class ApprovalWorkflowBuilder extends LightningElement {
    @track approvers = [];
    @track isLoading = false;
    @track showAddModal = false;
    @track newApprover = {
        name: '',
        email: '',
        approvalLimit: null
    };

    @wire(getApprovalWorkflow)
    wiredWorkflow({ error, data }) {
        if (data) {
            this.approvers = data.map((approver, index) => ({
                ...approver,
                order: index + 1,
                isFirst: index === 0,
                isLast: index === data.length - 1
            }));
        } else if (error) {
            this.showToast('Error', 'Failed to load approval workflow', 'error');
        }
    }

    handleOpenAddModal() {
        this.showAddModal = true;
    }

    handleCloseAddModal() {
        this.showAddModal = false;
        this.resetNewApprover();
    }

    handleInputChange(event) {
        const field = event.target.dataset.field;
        this.newApprover = { ...this.newApprover, [field]: event.target.value };
    }

    async handleAddApprover() {
        if (!this.newApprover.name || !this.newApprover.email) {
            this.showToast('Error', 'Please fill in all required fields', 'error');
            return;
        }
        this.isLoading = true;
        try {
            await addApprover({ approver: this.newApprover });
            this.showToast('Success', 'Approver added successfully', 'success');
            this.handleCloseAddModal();
            return refreshApex(this.wiredWorkflow);
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to add approver', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleRemove(event) {
        const approverId = event.target.dataset.id;
        this.isLoading = true;
        try {
            await removeApprover({ approverId });
            this.showToast('Success', 'Approver removed', 'success');
            return refreshApex(this.wiredWorkflow);
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to remove approver', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleMoveUp(event) {
        const approverId = event.target.dataset.id;
        this.isLoading = true;
        try {
            await reorderApprover({ approverId, direction: 'up' });
            this.showToast('Success', 'Approver moved up', 'success');
            return refreshApex(this.wiredWorkflow);
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to reorder', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleMoveDown(event) {
        const approverId = event.target.dataset.id;
        this.isLoading = true;
        try {
            await reorderApprover({ approverId, direction: 'down' });
            this.showToast('Success', 'Approver moved down', 'success');
            return refreshApex(this.wiredWorkflow);
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to reorder', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    resetNewApprover() {
        this.newApprover = {
            name: '',
            email: '',
            approvalLimit: null
        };
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
