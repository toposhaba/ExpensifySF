import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const COLUMNS = [
    { label: 'Destination', fieldName: 'destination', type: 'text', editable: true },
    { label: 'Daily Rate', fieldName: 'dailyRate', type: 'currency', editable: true, typeAttributes: { currencyCode: { fieldName: 'currency' } } },
    { label: 'Currency', fieldName: 'currency', type: 'text', editable: true },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [
                { label: 'Edit', name: 'edit' },
                { label: 'Delete', name: 'delete' }
            ]
        }
    }
];

export default class PerDiemManager extends LightningElement {
    @api policyId;
    @track rates = [];
    @track columns = COLUMNS;
    @track isModalOpen = false;
    @track isImportModalOpen = false;
    @track newRate = { destination: '', dailyRate: 0, currency: 'USD' };
    @track csvContent = '';
    @track isLoading = false;

    connectedCallback() {
        this.loadRates();
    }

    loadRates() {
        this.isLoading = true;
        this.rates = [
            { id: '1', destination: 'New York, NY', dailyRate: 79, currency: 'USD' },
            { id: '2', destination: 'San Francisco, CA', dailyRate: 98, currency: 'USD' },
            { id: '3', destination: 'London, UK', dailyRate: 85, currency: 'GBP' },
            { id: '4', destination: 'Tokyo, Japan', dailyRate: 12000, currency: 'JPY' }
        ];
        this.isLoading = false;
    }

    handleOpenModal() {
        this.newRate = { destination: '', dailyRate: 0, currency: 'USD' };
        this.isModalOpen = true;
    }

    handleCloseModal() {
        this.isModalOpen = false;
    }

    handleOpenImportModal() {
        this.csvContent = '';
        this.isImportModalOpen = true;
    }

    handleCloseImportModal() {
        this.isImportModalOpen = false;
    }

    handleDestinationChange(event) {
        this.newRate = { ...this.newRate, destination: event.target.value };
    }

    handleDailyRateChange(event) {
        this.newRate = { ...this.newRate, dailyRate: parseFloat(event.target.value) };
    }

    handleCurrencyChange(event) {
        this.newRate = { ...this.newRate, currency: event.target.value };
    }

    handleSaveRate() {
        if (!this.newRate.destination || !this.newRate.dailyRate) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: 'Please fill in all required fields.',
                variant: 'error'
            }));
            return;
        }
        const rate = {
            id: String(Date.now()),
            ...this.newRate
        };
        this.rates = [...this.rates, rate];
        this.isModalOpen = false;
        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message: `Per diem rate for ${rate.destination} created.`,
            variant: 'success'
        }));
    }

    handleCsvContentChange(event) {
        this.csvContent = event.target.value;
    }

    handleImportCsv() {
        if (!this.csvContent.trim()) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: 'Please paste CSV content.',
                variant: 'error'
            }));
            return;
        }
        const lines = this.csvContent.trim().split('\n');
        const importedRates = [];
        for (let i = 1; i < lines.length; i++) {
            const parts = lines[i].split(',').map(p => p.trim());
            if (parts.length >= 3) {
                importedRates.push({
                    id: String(Date.now() + i),
                    destination: parts[0],
                    dailyRate: parseFloat(parts[1]),
                    currency: parts[2]
                });
            }
        }
        if (importedRates.length === 0) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: 'No valid rates found in CSV.',
                variant: 'error'
            }));
            return;
        }
        this.rates = [...this.rates, ...importedRates];
        this.isImportModalOpen = false;
        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message: `${importedRates.length} rate(s) imported successfully.`,
            variant: 'success'
        }));
    }

    handleRowAction(event) {
        const action = event.detail.action;
        const row = event.detail.row;
        if (action.name === 'delete') {
            this.rates = this.rates.filter(r => r.id !== row.id);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: `Rate for ${row.destination} deleted.`,
                variant: 'success'
            }));
        } else if (action.name === 'edit') {
            this.newRate = { ...row };
            this.isModalOpen = true;
        }
    }

    handleSave(event) {
        const draftValues = event.detail.draftValues;
        const updated = this.rates.map(rate => {
            const draft = draftValues.find(d => d.id === rate.id);
            return draft ? { ...rate, ...draft } : rate;
        });
        this.rates = updated;
        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message: 'Rates updated.',
            variant: 'success'
        }));
    }

    get currencyOptions() {
        return [
            { label: 'USD', value: 'USD' },
            { label: 'EUR', value: 'EUR' },
            { label: 'GBP', value: 'GBP' },
            { label: 'JPY', value: 'JPY' },
            { label: 'CAD', value: 'CAD' },
            { label: 'AUD', value: 'AUD' }
        ];
    }
}
