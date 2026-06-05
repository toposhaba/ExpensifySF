public with sharing class TravelService {

    public static Trip__c createTrip(Trip__c trip) {
        validateTrip(trip);
        if (String.isBlank(trip.Status__c)) {
            trip.Status__c = 'Planned';
        }
        if (!Schema.sObjectType.Trip__c.isCreateable()) {
            throw new TravelException('Insufficient permissions to create trips');
        }
        insert trip;
        return trip;
    }

    public static Trip__c updateTrip(Trip__c trip) {
        validateTrip(trip);
        if (!Schema.sObjectType.Trip__c.isUpdateable()) {
            throw new TravelException('Insufficient permissions to update trips');
        }
        update trip;
        return trip;
    }

    public static void deleteTrip(Id tripId) {
        if (!Schema.sObjectType.Trip__c.isDeletable()) {
            throw new TravelException('Insufficient permissions to delete trips');
        }
        Trip__c trip = [
            SELECT Id
            FROM Trip__c
            WHERE Id = :tripId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        List<Trip_Reservation__c> reservations = [
            SELECT Id
            FROM Trip_Reservation__c
            WHERE Trip__c = :tripId
            WITH SECURITY_ENFORCED
        ];
        if (!reservations.isEmpty()) {
            if (!Schema.sObjectType.Trip_Reservation__c.isDeletable()) {
                throw new TravelException('Insufficient permissions to delete reservations');
            }
            delete reservations;
        }
        delete trip;
    }

    public static Trip__c getTrip(Id tripId) {
        return [
            SELECT Id, Name, Traveler__c, Traveler__r.Name, Policy__c, Policy__r.Name,
                   Start_Date__c, End_Date__c, Destination__c, Status__c,
                   OwnerId, CreatedDate, LastModifiedDate
            FROM Trip__c
            WHERE Id = :tripId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
    }

    public static Trip_Reservation__c addReservation(Trip_Reservation__c reservation) {
        validateReservation(reservation);
        if (String.isBlank(reservation.Currency__c)) {
            reservation.Currency__c = 'USD';
        }
        if (!Schema.sObjectType.Trip_Reservation__c.isCreateable()) {
            throw new TravelException('Insufficient permissions to create reservations');
        }
        insert reservation;
        return reservation;
    }

    public static Trip_Reservation__c updateReservation(Trip_Reservation__c reservation) {
        validateReservation(reservation);
        if (!Schema.sObjectType.Trip_Reservation__c.isUpdateable()) {
            throw new TravelException('Insufficient permissions to update reservations');
        }
        update reservation;
        return reservation;
    }

    public static void deleteReservation(Id reservationId) {
        if (!Schema.sObjectType.Trip_Reservation__c.isDeletable()) {
            throw new TravelException('Insufficient permissions to delete reservations');
        }
        Trip_Reservation__c reservation = [
            SELECT Id
            FROM Trip_Reservation__c
            WHERE Id = :reservationId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        delete reservation;
    }

    public static List<Trip_Reservation__c> getReservations(Id tripId) {
        return [
            SELECT Id, Name, Trip__c, Type__c, Vendor__c, Cost__c, Currency__c,
                   Start__c, End__c, Confirmation__c, CreatedDate
            FROM Trip_Reservation__c
            WHERE Trip__c = :tripId
            WITH SECURITY_ENFORCED
            ORDER BY Start__c ASC NULLS LAST
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Trip__c> getMyTrips() {
        Id currentUserId = UserInfo.getUserId();
        return [
            SELECT Id, Name, Traveler__c, Traveler__r.Name, Policy__c, Policy__r.Name,
                   Start_Date__c, End_Date__c, Destination__c, Status__c, CreatedDate
            FROM Trip__c
            WHERE Traveler__c = :currentUserId OR OwnerId = :currentUserId
            WITH SECURITY_ENFORCED
            ORDER BY Start_Date__c DESC NULLS LAST
            LIMIT 200
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Trip_Reservation__c> getReservationsForTrip(Id tripId) {
        return getReservations(tripId);
    }

    @AuraEnabled
    public static Trip__c createTripRecord(Trip__c trip) {
        try {
            return createTrip(trip);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Trip_Reservation__c addReservationRecord(Trip_Reservation__c reservation) {
        try {
            return addReservation(reservation);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void deleteTripRecord(Id tripId) {
        try {
            deleteTrip(tripId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static void validateTrip(Trip__c trip) {
        if (String.isBlank(trip.Name)) {
            throw new TravelException('Trip name is required');
        }
        Map<String, Object> populated = trip.getPopulatedFieldsAsMap();
        if (populated.containsKey('Start_Date__c') && populated.containsKey('End_Date__c')
            && trip.Start_Date__c != null && trip.End_Date__c != null
            && trip.End_Date__c < trip.Start_Date__c) {
            throw new TravelException('End date cannot be before the start date');
        }
    }

    private static void validateReservation(Trip_Reservation__c reservation) {
        if (reservation.Trip__c == null) {
            throw new TravelException('A reservation must be linked to a trip');
        }
        if (String.isBlank(reservation.Type__c)) {
            throw new TravelException('Reservation type is required');
        }
        if (reservation.Cost__c != null && reservation.Cost__c < 0) {
            throw new TravelException('Cost cannot be negative');
        }
        if (reservation.Start__c != null && reservation.End__c != null
            && reservation.End__c < reservation.Start__c) {
            throw new TravelException('Reservation end cannot be before its start');
        }
    }

    public class TravelException extends Exception {}
}
