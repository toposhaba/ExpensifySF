import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import canExport from '@salesforce/apex/ExportService.canExport';
import getReportCsv from '@salesforce/apex/ExportService.getReportCsv';

export default class ExpenseExport extends LightningElement {
    @api recordId;
    allowExport = false;
    isLoading = false;

    @wire(canExport)
    wiredCanExport({ data }) {
        if (data !== undefined) {
            this.allowExport = data;
        }
    }

    get exportDisabled() {
        return !this.allowExport || this.isLoading || !this.recordId;
    }

    async handleDownloadCsv() {
        this.isLoading = true;
        try {
            const csv = await getReportCsv({ reportId: this.recordId });
            const encoded = encodeURIComponent(csv);
            const link = document.createElement('a');
            link.href = `data:text/csv;charset=utf-8,${encoded}`;
            link.download = `ExpenseReport-${this.recordId}.csv`;
            link.click();
            this.showToast('Success', 'CSV export ready', 'success');
        } catch (error) {
            this.showToast('Error', this.resolveError(error), 'error');
        }
        this.isLoading = false;
    }

    handleOpenPdf() {
        const url = `/apex/expenseReportPdf?id=${this.recordId}`;
        window.open(url, '_blank');
    }

    resolveError(error) {
        return error && error.body && error.body.message ? error.body.message : 'Failed to export report';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
