import { LightningElement, wire, track } from 'lwc';
import getMyPolicies from '@salesforce/apex/ExpenseController.getMyPolicies';
import getPolicy from '@salesforce/apex/ExpenseController.getPolicy';
import getCategories from '@salesforce/apex/ExpenseController.getCategories';
import getTags from '@salesforce/apex/ExpenseController.getTags';
import getPolicyMembers from '@salesforce/apex/ExpenseController.getPolicyMembers';

export default class WorkspaceSettings extends LightningElement {
    @track policies = [];
    @track selectedPolicyId;
    @track policy = {};
    @track categories = [];
    @track tags = [];
    @track members = [];
    @track isLoading = true;
    @track activeTab = 'overview';

    memberColumns = [
        { label: 'Name', fieldName: 'userName', type: 'text' },
        { label: 'Email', fieldName: 'userEmail', type: 'text' },
        { label: 'Role', fieldName: 'Role__c', type: 'text' },
        { label: 'Submits To', fieldName: 'submitsToName', type: 'text' }
    ];

    categoryColumns = [
        { label: 'Name', fieldName: 'Name', type: 'text' },
        { label: 'GL Code', fieldName: 'GL_Code__c', type: 'text' },
        { label: 'Enabled', fieldName: 'Enabled__c', type: 'boolean' },
        { label: 'Max Amount', fieldName: 'Max_Amount__c', type: 'currency' },
        { label: 'Receipt Required', fieldName: 'Receipt_Required__c', type: 'boolean' }
    ];

    tagColumns = [
        { label: 'Name', fieldName: 'Name', type: 'text' },
        { label: 'GL Code', fieldName: 'GL_Code__c', type: 'text' },
        { label: 'Enabled', fieldName: 'Enabled__c', type: 'boolean' }
    ];

    @wire(getMyPolicies)
    wiredPolicies({ data }) {
        this.isLoading = false;
        if (data) {
            this.policies = data;
            if (data.length > 0 && !this.selectedPolicyId) {
                this.selectedPolicyId = data[0].Id;
                this.loadPolicyDetails();
            }
        }
    }

    async loadPolicyDetails() {
        if (!this.selectedPolicyId) return;
        this.isLoading = true;
        try {
            const [policyData, cats, tgs, mems] = await Promise.all([
                getPolicy({ policyId: this.selectedPolicyId }),
                getCategories({ policyId: this.selectedPolicyId }),
                getTags({ policyId: this.selectedPolicyId }),
                getPolicyMembers({ policyId: this.selectedPolicyId })
            ]);
            this.policy = policyData;
            this.categories = cats;
            this.tags = tgs;
            this.members = mems.map(m => ({
                ...m,
                userName: m.User__r ? m.User__r.Name : '',
                userEmail: m.User__r ? m.User__r.Email : '',
                submitsToName: m.Submits_To__r ? m.Submits_To__r.Name : ''
            }));
        } catch (error) {
            console.error('Failed to load policy details', error);
        }
        this.isLoading = false;
    }

    handlePolicySelect(event) {
        this.selectedPolicyId = event.currentTarget.dataset.id;
        this.loadPolicyDetails();
    }

    handleTabChange(event) {
        this.activeTab = event.target.value;
    }

    get hasPolicies() {
        return this.policies.length > 0;
    }

    get isOverview() { return this.activeTab === 'overview'; }
    get isMembers() { return this.activeTab === 'members'; }
    get isCategories() { return this.activeTab === 'categories'; }
    get isTags() { return this.activeTab === 'tags'; }
}
