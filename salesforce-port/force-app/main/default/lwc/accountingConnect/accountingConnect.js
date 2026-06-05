import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getConnections from '@salesforce/apex/AccountingSyncService.getConnections';
import getApprovedReports from '@salesforce/apex/AccountingSyncService.getApprovedReports';
import exportReportToProvider from '@salesforce/apex/AccountingSyncService.exportReportToProvider';

export default class AccountingConnect extends LightningElement {
    @track connections = [];
    @track reports = [];
    @track selectedReportId;
    @track selectedProvider;
    @track isExporting = false;

    @wire(getConnections)
    wiredConnections({ data }) {
        if (data) {
            this.connections = data.map((c) => ({
                key: c.QualifiedApiName,
                label: c.MasterLabel,
                provider: c.Provider__c,
                namedCredential: c.Named_Credential__c,
                isActive: c.Is_Active__c,
                statusLabel: c.Is_Active__c ? 'Connected' : 'Not Connected',
                statusClass: c.Is_Active__c
                    ? 'slds-badge slds-theme_success'
                    : 'slds-badge slds-theme_warning'
            }));
        }
    }

    @wire(getApprovedReports)
    wiredReports({ data }) {
        if (data) {
            this.reports = data;
        }
    }

    get hasConnections() {
        return this.connections.length > 0;
    }

    get reportOptions() {
        return this.reports.map((r) => ({ label: r.Name, value: r.Id }));
    }

    get providerOptions() {
        return this.connections
            .filter((c) => c.isActive)
            .map((c) => ({ label: c.label, value: c.provider }));
    }

    get canExportDisabled() {
        return !this.selectedReportId || !this.selectedProvider || this.isExporting;
    }

    handleReportChange(event) {
        this.selectedReportId = event.detail.value;
    }

    handleProviderChange(event) {
        this.selectedProvider = event.detail.value;
    }

    async handleExport() {
        this.isExporting = true;
        try {
            const log = await exportReportToProvider({
                reportId: this.selectedReportId,
                provider: this.selectedProvider
            });
            const isSuccess = log.Status__c === 'Success';
            this.dispatchEvent(
                new ShowToastEvent({
                    title: isSuccess ? 'Export Succeeded' : 'Export Failed',
                    message: isSuccess
                        ? `Report exported to ${this.selectedProvider} (${log.External_Id__c || 'no reference'})`
                        : log.Error_Message__c || 'The export did not complete.',
                    variant: isSuccess ? 'success' : 'error'
                })
            );
        } catch (error) {
            const message =
                error && error.body && error.body.message
                    ? error.body.message
                    : 'Unexpected error during export.';
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Export Failed',
                    message,
                    variant: 'error'
                })
            );
        }
        this.isExporting = false;
    }
}
