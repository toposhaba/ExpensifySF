import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const COLUMNS = [
    { label: 'Card Name', fieldName: 'cardName', type: 'text' },
    { label: 'Cardholder', fieldName: 'cardholder', type: 'text' },
    { label: 'Status', fieldName: 'status', type: 'text' },
    { label: 'Spend Limit', fieldName: 'spendLimit', type: 'currency' },
    { label: 'Available', fieldName: 'available', type: 'currency' },
    { label: 'Last Four', fieldName: 'lastFour', type: 'text' },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [
                { label: 'Freeze', name: 'freeze' },
                { label: 'Unfreeze', name: 'unfreeze' },
                { label: 'Update Limit', name: 'updateLimit' }
            ]
        }
    }
];

export default class CardManager extends LightningElement {
    @track cards = [];
    @track columns = COLUMNS;
    @track isIssueModalOpen = false;
    @track isLimitModalOpen = false;
    @track newCard = { cardholder: '', spendLimit: 0 };
    @track selectedCard = null;
    @track newLimit = 0;
    @track isLoading = false;

    get userOptions() {
        return [
            { label: 'Alice Johnson', value: 'Alice Johnson' },
            { label: 'Bob Smith', value: 'Bob Smith' },
            { label: 'Carol Williams', value: 'Carol Williams' },
            { label: 'David Brown', value: 'David Brown' },
            { label: 'Eva Martinez', value: 'Eva Martinez' }
        ];
    }

    get cardCount() {
        return this.cards.length;
    }

    get activeCardCount() {
        return this.cards.filter(c => c.status === 'Active').length;
    }

    get frozenCardCount() {
        return this.cards.filter(c => c.status === 'Frozen').length;
    }

    connectedCallback() {
        this.loadCards();
    }

    loadCards() {
        this.isLoading = true;
        this.cards = [
            { id: '1', cardName: 'Engineering Team Card', cardholder: 'Alice Johnson', status: 'Active', spendLimit: 5000, available: 3200, lastFour: '4532' },
            { id: '2', cardName: 'Marketing Expenses', cardholder: 'Bob Smith', status: 'Active', spendLimit: 3000, available: 1850, lastFour: '7891' },
            { id: '3', cardName: 'Travel Card', cardholder: 'Carol Williams', status: 'Frozen', spendLimit: 10000, available: 10000, lastFour: '2345' },
            { id: '4', cardName: 'Office Supplies', cardholder: 'David Brown', status: 'Active', spendLimit: 1500, available: 920, lastFour: '6789' }
        ];
        this.isLoading = false;
    }

    handleOpenIssueModal() {
        this.newCard = { cardholder: '', spendLimit: 0 };
        this.isIssueModalOpen = true;
    }

    handleCloseIssueModal() {
        this.isIssueModalOpen = false;
    }

    handleCardholderChange(event) {
        this.newCard = { ...this.newCard, cardholder: event.detail.value };
    }

    handleSpendLimitChange(event) {
        this.newCard = { ...this.newCard, spendLimit: parseFloat(event.target.value) };
    }

    handleIssueCard() {
        if (!this.newCard.cardholder || !this.newCard.spendLimit) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: 'Please select a cardholder and set a spend limit.',
                variant: 'error'
            }));
            return;
        }
        const lastFour = String(Math.floor(1000 + Math.random() * 9000));
        const card = {
            id: String(Date.now()),
            cardName: `${this.newCard.cardholder}'s Card`,
            cardholder: this.newCard.cardholder,
            status: 'Active',
            spendLimit: this.newCard.spendLimit,
            available: this.newCard.spendLimit,
            lastFour: lastFour
        };
        this.cards = [...this.cards, card];
        this.isIssueModalOpen = false;
        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message: `Card issued to ${card.cardholder} with limit $${card.spendLimit}.`,
            variant: 'success'
        }));
    }

    handleRowAction(event) {
        const action = event.detail.action;
        const row = event.detail.row;

        switch (action.name) {
            case 'freeze':
                this.freezeCard(row);
                break;
            case 'unfreeze':
                this.unfreezeCard(row);
                break;
            case 'updateLimit':
                this.openLimitModal(row);
                break;
            default:
                break;
        }
    }

    freezeCard(row) {
        this.cards = this.cards.map(c => {
            if (c.id === row.id) {
                return { ...c, status: 'Frozen' };
            }
            return c;
        });
        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message: `Card ending in ${row.lastFour} has been frozen.`,
            variant: 'success'
        }));
    }

    unfreezeCard(row) {
        this.cards = this.cards.map(c => {
            if (c.id === row.id) {
                return { ...c, status: 'Active' };
            }
            return c;
        });
        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message: `Card ending in ${row.lastFour} has been unfrozen.`,
            variant: 'success'
        }));
    }

    openLimitModal(row) {
        this.selectedCard = row;
        this.newLimit = row.spendLimit;
        this.isLimitModalOpen = true;
    }

    handleCloseLimitModal() {
        this.isLimitModalOpen = false;
        this.selectedCard = null;
    }

    handleNewLimitChange(event) {
        this.newLimit = parseFloat(event.target.value);
    }

    handleUpdateLimit() {
        if (!this.newLimit || this.newLimit <= 0) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: 'Please enter a valid limit.',
                variant: 'error'
            }));
            return;
        }
        this.cards = this.cards.map(c => {
            if (c.id === this.selectedCard.id) {
                const spent = c.spendLimit - c.available;
                const newAvailable = Math.max(0, this.newLimit - spent);
                return { ...c, spendLimit: this.newLimit, available: newAvailable };
            }
            return c;
        });
        this.isLimitModalOpen = false;
        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message: `Spend limit updated to $${this.newLimit} for card ending in ${this.selectedCard.lastFour}.`,
            variant: 'success'
        }));
    }
}
