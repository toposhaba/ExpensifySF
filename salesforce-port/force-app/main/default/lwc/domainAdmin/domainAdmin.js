import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getMyDomains from '@salesforce/apex/DomainService.getMyDomains';
import getMembers from '@salesforce/apex/DomainService.getMembers';
import createDomainByName from '@salesforce/apex/DomainService.createDomainByName';
import verifyDomain from '@salesforce/apex/DomainService.verifyDomain';
import deleteDomain from '@salesforce/apex/DomainService.deleteDomain';
import addMemberToDomain from '@salesforce/apex/DomainService.addMemberToDomain';
import removeMember from '@salesforce/apex/DomainService.removeMember';

const MEMBER_COLUMNS = [
    { label: 'Member', fieldName: 'userName', type: 'text' },
    { label: 'Email', fieldName: 'userEmail', type: 'text' },
    { label: 'Role', fieldName: 'Role__c', type: 'text' },
    {
        type: 'button-icon',
        fixedWidth: 60,
        typeAttributes: {
            iconName: 'utility:delete',
            name: 'remove',
            title: 'Remove',
            variant: 'border-filled',
            alternativeText: 'Remove'
        }
    }
];

export default class DomainAdmin extends LightningElement {
    @track domains = [];
    @track selectedDomainId;
    @track selectedDomain = {};
    @track members = [];
    @track isLoading = true;
    @track newDomainName = '';
    @track newMemberUserId = '';
    @track newMemberRole = 'Member';

    memberColumns = MEMBER_COLUMNS;

    roleOptions = [
        { label: 'Member', value: 'Member' },
        { label: 'Admin', value: 'Admin' }
    ];

    connectedCallback() {
        this.loadDomains();
    }

    async loadDomains() {
        this.isLoading = true;
        try {
            const data = await getMyDomains();
            this.domains = data;
            if (data.length > 0) {
                if (!this.selectedDomainId || !data.some((d) => d.Id === this.selectedDomainId)) {
                    this.selectedDomainId = data[0].Id;
                }
                await this.loadDomainDetails();
            } else {
                this.selectedDomainId = undefined;
                this.selectedDomain = {};
                this.members = [];
            }
        } catch (error) {
            this.showError(error);
        }
        this.isLoading = false;
    }

    async loadDomainDetails() {
        if (!this.selectedDomainId) {
            return;
        }
        this.isLoading = true;
        try {
            this.selectedDomain = this.domains.find((d) => d.Id === this.selectedDomainId) || {};
            const mems = await getMembers({ domainId: this.selectedDomainId });
            this.members = mems.map((m) => ({
                ...m,
                userName: m.User__r ? m.User__r.Name : '',
                userEmail: m.User__r ? m.User__r.Email : ''
            }));
        } catch (error) {
            this.showError(error);
        }
        this.isLoading = false;
    }

    handleDomainSelect(event) {
        this.selectedDomainId = event.currentTarget.dataset.id;
        this.loadDomainDetails();
    }

    handleNewDomainNameChange(event) {
        this.newDomainName = event.target.value;
    }

    handleNewMemberUserIdChange(event) {
        this.newMemberUserId = event.target.value;
    }

    handleNewMemberRoleChange(event) {
        this.newMemberRole = event.detail.value;
    }

    async handleCreateDomain() {
        if (!this.newDomainName) {
            this.showToast('Validation', 'Domain name is required', 'warning');
            return;
        }
        this.isLoading = true;
        try {
            const created = await createDomainByName({ domainName: this.newDomainName, defaultPolicyId: null });
            this.newDomainName = '';
            this.selectedDomainId = created.Id;
            await this.loadDomains();
            this.showToast('Success', 'Domain created', 'success');
        } catch (error) {
            this.showError(error);
            this.isLoading = false;
        }
    }

    async handleVerifyDomain() {
        this.isLoading = true;
        try {
            await verifyDomain({ domainId: this.selectedDomainId });
            await this.loadDomains();
            this.showToast('Success', 'Domain verified', 'success');
        } catch (error) {
            this.showError(error);
            this.isLoading = false;
        }
    }

    async handleDeleteDomain() {
        this.isLoading = true;
        try {
            await deleteDomain({ domainId: this.selectedDomainId });
            this.selectedDomainId = undefined;
            await this.loadDomains();
            this.showToast('Success', 'Domain deleted', 'success');
        } catch (error) {
            this.showError(error);
            this.isLoading = false;
        }
    }

    async handleAddMember() {
        if (!this.newMemberUserId) {
            this.showToast('Validation', 'User Id is required', 'warning');
            return;
        }
        this.isLoading = true;
        try {
            await addMemberToDomain({
                domainId: this.selectedDomainId,
                userId: this.newMemberUserId,
                role: this.newMemberRole
            });
            this.newMemberUserId = '';
            this.newMemberRole = 'Member';
            await this.loadDomainDetails();
            this.showToast('Success', 'Member added', 'success');
        } catch (error) {
            this.showError(error);
            this.isLoading = false;
        }
    }

    async handleMemberRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        if (actionName === 'remove') {
            this.isLoading = true;
            try {
                await removeMember({ domainId: this.selectedDomainId, userId: row.User__c });
                await this.loadDomainDetails();
                this.showToast('Success', 'Member removed', 'success');
            } catch (error) {
                this.showError(error);
                this.isLoading = false;
            }
        }
    }

    get hasDomains() {
        return this.domains.length > 0;
    }

    get hasSelectedDomain() {
        return !!this.selectedDomainId;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    showError(error) {
        const message = error && error.body && error.body.message ? error.body.message : 'An unexpected error occurred';
        this.showToast('Error', message, 'error');
    }
}
