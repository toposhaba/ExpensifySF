import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class AccountingConnections extends LightningElement {
    @track providers = [
        { id: 'quickbooks', name: 'QuickBooks Online', icon: 'standard:account', connected: true, lastSync: '2024-01-15 09:30 AM', status: 'Connected' },
        { id: 'xero', name: 'Xero', icon: 'standard:record', connected: false, lastSync: '', status: 'Disconnected' },
        { id: 'netsuite', name: 'NetSuite', icon: 'standard:opportunity', connected: true, lastSync: '2024-01-14 03:45 PM', status: 'Connected' },
        { id: 'sage', name: 'Sage Intacct', icon: 'standard:report', connected: false, lastSync: '', status: 'Disconnected' }
    ];
    @track isSyncModalOpen = false;
    @track selectedProvider = null;
    @track selectedReportId = '';
    @track isSyncing = false;

    get reportOptions() {
        return [
            { label: 'Monthly Expense Report - Jan 2024', value: 'RPT-001' },
            { label: 'Weekly Team Expenses - W3', value: 'RPT-002' },
            { label: 'Q4 Travel Summary', value: 'RPT-003' },
            { label: 'Department Budget Review', value: 'RPT-004' }
        ];
    }

    handleToggleConnection(event) {
        const providerId = event.target.dataset.id;
        this.providers = this.providers.map(p => {
            if (p.id === providerId) {
                const nowConnected = !p.connected;
                return {
                    ...p,
                    connected: nowConnected,
                    status: nowConnected ? 'Connected' : 'Disconnected',
                    lastSync: nowConnected ? new Date().toLocaleString() : ''
                };
            }
            return p;
        });
        const provider = this.providers.find(p => p.id === providerId);
        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message: `${provider.name} ${provider.connected ? 'connected' : 'disconnected'} successfully.`,
            variant: 'success'
        }));
    }

    handleOpenSyncModal(event) {
        const providerId = event.target.dataset.id;
        this.selectedProvider = this.providers.find(p => p.id === providerId);
        this.selectedReportId = '';
        this.isSyncModalOpen = true;
    }

    handleCloseSyncModal() {
        this.isSyncModalOpen = false;
        this.selectedProvider = null;
    }

    handleReportChange(event) {
        this.selectedReportId = event.detail.value;
    }

    handleSyncReport() {
        if (!this.selectedReportId) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: 'Please select a report to sync.',
                variant: 'error'
            }));
            return;
        }
        this.isSyncing = true;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            this.isSyncing = false;
            this.isSyncModalOpen = false;
            this.providers = this.providers.map(p => {
                if (p.id === this.selectedProvider.id) {
                    return { ...p, lastSync: new Date().toLocaleString() };
                }
                return p;
            });
            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: `Report ${this.selectedReportId} synced to ${this.selectedProvider.name}.`,
                variant: 'success'
            }));
        }, 1500);
    }

    getConnectionVariant(connected) {
        return connected ? 'destructive' : 'brand';
    }

    getConnectionLabel(connected) {
        return connected ? 'Disconnect' : 'Connect';
    }
}
