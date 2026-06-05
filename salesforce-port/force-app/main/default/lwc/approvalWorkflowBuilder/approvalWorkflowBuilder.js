import { LightningElement, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getMyPolicies from '@salesforce/apex/ExpenseController.getMyPolicies';
import getApprovalSteps from '@salesforce/apex/ApprovalWorkflowService.getApprovalSteps';
import getApproverOptions from '@salesforce/apex/ApprovalWorkflowService.getApproverOptions';
import addApprovalStep from '@salesforce/apex/ApprovalWorkflowService.addApprovalStep';
import updateApprovalStep from '@salesforce/apex/ApprovalWorkflowService.updateApprovalStep';
import removeApprovalStep from '@salesforce/apex/ApprovalWorkflowService.removeApprovalStep';
import reorderApprovalSteps from '@salesforce/apex/ApprovalWorkflowService.reorderApprovalSteps';

export default class ApprovalWorkflowBuilder extends LightningElement {
    @track policies = [];
    @track selectedPolicyId;
    @track steps = [];
    @track approverOptions = [];
    @track isLoading = false;

    newApproverId;
    newApprovalLimit;
    newOverrideId;

    @wire(getMyPolicies)
    wiredPolicies({ data }) {
        if (data) {
            this.policies = data.map((p) => ({ label: p.Name, value: p.Id }));
            if (data.length > 0 && !this.selectedPolicyId) {
                this.selectedPolicyId = data[0].Id;
                this.loadWorkflow();
            }
        }
    }

    get hasPolicies() {
        return this.policies.length > 0;
    }

    get hasSteps() {
        return this.steps.length > 0;
    }

    get canAddStep() {
        return !!this.selectedPolicyId && !!this.newApproverId;
    }

    get isAddDisabled() {
        return !this.canAddStep;
    }

    handlePolicyChange(event) {
        this.selectedPolicyId = event.detail.value;
        this.resetForm();
        this.loadWorkflow();
    }

    async loadWorkflow() {
        if (!this.selectedPolicyId) {
            return;
        }
        this.isLoading = true;
        try {
            const [steps, options] = await Promise.all([
                getApprovalSteps({ policyId: this.selectedPolicyId }),
                getApproverOptions({ policyId: this.selectedPolicyId })
            ]);
            this.approverOptions = options.map((m) => ({
                label: m.User__r ? m.User__r.Name : m.User__c,
                value: m.User__c
            }));
            this.steps = steps.map((s, index) => ({
                id: s.Id,
                order: s.Order__c,
                approverId: s.Approver__c,
                approverName: s.Approver__r ? s.Approver__r.Name : s.Approver__c,
                approvalLimit: s.Approval_Limit__c,
                overrideId: s.Submits_To_Override__c,
                overrideName: s.Submits_To_Override__r ? s.Submits_To_Override__r.Name : '',
                isActive: s.Is_Active__c,
                isInactive: !s.Is_Active__c,
                isFirst: index === 0,
                isLast: index === steps.length - 1
            }));
        } catch (error) {
            this.showError(error);
        }
        this.isLoading = false;
    }

    handleApproverChange(event) {
        this.newApproverId = event.detail.value;
    }

    handleLimitChange(event) {
        this.newApprovalLimit = event.detail.value;
    }

    handleOverrideChange(event) {
        this.newOverrideId = event.detail.value;
    }

    async handleAddStep() {
        if (!this.canAddStep) {
            return;
        }
        this.isLoading = true;
        try {
            await addApprovalStep({
                policyId: this.selectedPolicyId,
                approverId: this.newApproverId,
                approvalLimit: this.newApprovalLimit ? parseFloat(this.newApprovalLimit) : null,
                submitsToOverride: this.newOverrideId || null
            });
            this.showSuccess('Approval step added');
            this.resetForm();
            await this.loadWorkflow();
        } catch (error) {
            this.showError(error);
            this.isLoading = false;
        }
    }

    async handleRemoveStep(event) {
        const stepId = event.currentTarget.dataset.id;
        this.isLoading = true;
        try {
            await removeApprovalStep({ stepId });
            this.showSuccess('Approval step removed');
            await this.loadWorkflow();
        } catch (error) {
            this.showError(error);
            this.isLoading = false;
        }
    }

    async handleToggleActive(event) {
        const stepId = event.currentTarget.dataset.id;
        const step = this.steps.find((s) => s.id === stepId);
        if (!step) {
            return;
        }
        this.isLoading = true;
        try {
            await updateApprovalStep({
                stepId,
                approverId: null,
                approvalLimit: step.approvalLimit,
                submitsToOverride: step.overrideId || null,
                isActive: !step.isActive
            });
            await this.loadWorkflow();
        } catch (error) {
            this.showError(error);
            this.isLoading = false;
        }
    }

    handleMoveUp(event) {
        const stepId = event.currentTarget.dataset.id;
        this.moveStep(stepId, -1);
    }

    handleMoveDown(event) {
        const stepId = event.currentTarget.dataset.id;
        this.moveStep(stepId, 1);
    }

    async moveStep(stepId, direction) {
        const index = this.steps.findIndex((s) => s.id === stepId);
        const target = index + direction;
        if (index < 0 || target < 0 || target >= this.steps.length) {
            return;
        }
        const ordered = this.steps.map((s) => s.id);
        const [moved] = ordered.splice(index, 1);
        ordered.splice(target, 0, moved);

        this.isLoading = true;
        try {
            await reorderApprovalSteps({ policyId: this.selectedPolicyId, orderedStepIds: ordered });
            await this.loadWorkflow();
        } catch (error) {
            this.showError(error);
            this.isLoading = false;
        }
    }

    resetForm() {
        this.newApproverId = undefined;
        this.newApprovalLimit = undefined;
        this.newOverrideId = undefined;
        const inputs = this.template.querySelectorAll('[data-form="new-step"]');
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
