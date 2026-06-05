import { LightningElement, track, wire } from 'lwc';
import getMyTrips from '@salesforce/apex/TravelService.getMyTrips';
import getReservationsForTrip from '@salesforce/apex/TravelService.getReservationsForTrip';
import deleteTripRecord from '@salesforce/apex/TravelService.deleteTripRecord';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

export default class TripList extends LightningElement {
    @track trips = [];
    @track reservations = [];
    @track selectedTripId;
    @track isLoading = true;
    @track isLoadingReservations = false;
    wiredTripResult;

    tripColumns = [
        { label: 'Trip', fieldName: 'Name', type: 'text', sortable: true },
        { label: 'Destination', fieldName: 'Destination__c', type: 'text' },
        { label: 'Traveler', fieldName: 'travelerName', type: 'text' },
        { label: 'Start', fieldName: 'Start_Date__c', type: 'date' },
        { label: 'End', fieldName: 'End_Date__c', type: 'date' },
        { label: 'Status', fieldName: 'Status__c', type: 'text',
          cellAttributes: { class: { fieldName: 'statusClass' } } },
        { type: 'action', typeAttributes: { rowActions: [
            { label: 'View Reservations', name: 'view' },
            { label: 'Delete', name: 'delete' }
        ]}}
    ];

    reservationColumns = [
        { label: 'Type', fieldName: 'Type__c', type: 'text' },
        { label: 'Vendor', fieldName: 'Vendor__c', type: 'text' },
        { label: 'Cost', fieldName: 'Cost__c', type: 'currency',
          typeAttributes: { currencyCode: { fieldName: 'Currency__c' } } },
        { label: 'Start', fieldName: 'Start__c', type: 'date',
          typeAttributes: { year: 'numeric', month: 'short', day: '2-digit', hour: '2-digit', minute: '2-digit' } },
        { label: 'End', fieldName: 'End__c', type: 'date',
          typeAttributes: { year: 'numeric', month: 'short', day: '2-digit', hour: '2-digit', minute: '2-digit' } },
        { label: 'Confirmation', fieldName: 'Confirmation__c', type: 'text' }
    ];

    @wire(getMyTrips)
    wiredTrips(result) {
        this.wiredTripResult = result;
        this.isLoading = false;
        if (result.data) {
            this.trips = result.data.map(trip => ({
                ...trip,
                travelerName: trip.Traveler__r ? trip.Traveler__r.Name : '',
                statusClass: this.getStatusClass(trip.Status__c)
            }));
        }
    }

    getStatusClass(status) {
        const classes = {
            Planned: 'slds-text-color_weak',
            Booked: 'slds-text-color_default',
            Completed: 'slds-text-color_success'
        };
        return classes[status] || '';
    }

    handleRowAction(event) {
        const action = event.detail.action;
        const row = event.detail.row;
        switch (action.name) {
            case 'view':
                this.loadReservations(row.Id);
                break;
            case 'delete':
                this.handleDelete(row.Id);
                break;
            default:
                break;
        }
    }

    async loadReservations(tripId) {
        this.selectedTripId = tripId;
        this.isLoadingReservations = true;
        try {
            this.reservations = await getReservationsForTrip({ tripId });
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error.body?.message || 'Failed to load reservations',
                variant: 'error'
            }));
        }
        this.isLoadingReservations = false;
    }

    async handleDelete(tripId) {
        this.isLoading = true;
        try {
            await deleteTripRecord({ tripId });
            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: 'Trip deleted',
                variant: 'success'
            }));
            if (this.selectedTripId === tripId) {
                this.selectedTripId = null;
                this.reservations = [];
            }
            await refreshApex(this.wiredTripResult);
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error.body?.message || 'Failed to delete trip',
                variant: 'error'
            }));
        }
        this.isLoading = false;
    }

    get hasSelectedTrip() {
        return !!this.selectedTripId;
    }

    get hasReservations() {
        return this.reservations.length > 0;
    }
}
