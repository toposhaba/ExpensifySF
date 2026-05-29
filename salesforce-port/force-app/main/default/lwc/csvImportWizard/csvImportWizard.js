import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class CsvImportWizard extends LightningElement {
    @track currentStep = 1;
    @track csvText = '';
    @track parsedData = [];
    @track columns = [];
    @track importedCount = 0;
    @track isImporting = false;
    @track fileName = '';

    get isStep1() {
        return this.currentStep === 1;
    }

    get isStep2() {
        return this.currentStep === 2;
    }

    get isStep3() {
        return this.currentStep === 3;
    }

    get isStepComplete() {
        return this.currentStep === 4;
    }

    get canProceedStep1() {
        return this.csvText.trim().length > 0;
    }

    get canProceedStep2() {
        return this.parsedData.length > 0;
    }

    get recordCount() {
        return this.parsedData.length;
    }

    get progressValue() {
        if (this.currentStep === 1) return 33;
        if (this.currentStep === 2) return 66;
        if (this.currentStep >= 3) return 100;
        return 0;
    }

    get stepIndicator() {
        return `Step ${this.currentStep} of 3`;
    }

    handleTextChange(event) {
        this.csvText = event.target.value;
    }

    handleFileChange(event) {
        const file = event.target.files[0];
        if (!file) return;
        this.fileName = file.name;
        const reader = new FileReader();
        reader.onload = (e) => {
            this.csvText = e.target.result;
        };
        reader.readAsText(file);
    }

    handleNext() {
        if (this.currentStep === 1) {
            this.parseCSV();
            if (this.parsedData.length > 0) {
                this.currentStep = 2;
            }
        } else if (this.currentStep === 2) {
            this.currentStep = 3;
        }
    }

    handleBack() {
        if (this.currentStep > 1) {
            this.currentStep--;
        }
    }

    handleConfirmImport() {
        this.isImporting = true;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            this.importedCount = this.parsedData.length;
            this.isImporting = false;
            this.currentStep = 4;
            this.dispatchEvent(new ShowToastEvent({
                title: 'Import Complete',
                message: `${this.importedCount} records imported successfully.`,
                variant: 'success'
            }));
        }, 2000);
    }

    handleReset() {
        this.currentStep = 1;
        this.csvText = '';
        this.parsedData = [];
        this.columns = [];
        this.importedCount = 0;
        this.fileName = '';
    }

    parseCSV() {
        const lines = this.csvText.trim().split('\n');
        if (lines.length < 2) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: 'CSV must have a header row and at least one data row.',
                variant: 'error'
            }));
            return;
        }

        const headers = lines[0].split(',').map(h => h.trim());
        this.columns = headers.map(header => ({
            label: header,
            fieldName: header.toLowerCase().replace(/\s+/g, '_'),
            type: 'text'
        }));

        this.parsedData = [];
        for (let i = 1; i < lines.length; i++) {
            const values = lines[i].split(',').map(v => v.trim());
            if (values.length === headers.length) {
                const row = { id: String(i) };
                headers.forEach((header, index) => {
                    row[header.toLowerCase().replace(/\s+/g, '_')] = values[index];
                });
                this.parsedData.push(row);
            }
        }

        if (this.parsedData.length === 0) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: 'No valid data rows found.',
                variant: 'error'
            }));
        }
    }
}
