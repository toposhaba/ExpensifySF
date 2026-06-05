@isTest
private class TravelServiceTest {

    @TestSetup
    static void setupTestData() {
        Expense_Policy__c policy = new Expense_Policy__c(
            Name = 'Travel Policy',
            Currency__c = 'USD',
            Type__c = 'Corporate',
            Approval_Mode__c = 'Basic'
        );
        insert policy;

        Trip__c trip = new Trip__c(
            Name = 'Q1 Sales Trip',
            Traveler__c = UserInfo.getUserId(),
            Policy__c = policy.Id,
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addDays(5),
            Destination__c = 'New York',
            Status__c = 'Planned'
        );
        insert trip;
    }

    @isTest
    static void testCreateTrip() {
        Expense_Policy__c policy = [SELECT Id FROM Expense_Policy__c LIMIT 1];

        Trip__c trip = new Trip__c(
            Name = 'Conference Trip',
            Traveler__c = UserInfo.getUserId(),
            Policy__c = policy.Id,
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addDays(3),
            Destination__c = 'Chicago'
        );

        Test.startTest();
        Trip__c result = TravelService.createTrip(trip);
        Test.stopTest();

        System.assertNotEquals(null, result.Id, 'Trip should be created');
        Trip__c saved = [SELECT Name, Destination__c, Status__c FROM Trip__c WHERE Id = :result.Id];
        System.assertEquals('Conference Trip', saved.Name);
        System.assertEquals('Chicago', saved.Destination__c);
        System.assertEquals('Planned', saved.Status__c, 'Status should default to Planned');
    }

    @isTest
    static void testCreateTrip_MissingName() {
        Trip__c trip = new Trip__c(
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addDays(2)
        );

        Test.startTest();
        try {
            TravelService.createTrip(trip);
            System.assert(false, 'Should have thrown exception');
        } catch (TravelService.TravelException e) {
            System.assert(e.getMessage().contains('name'), 'Should mention name requirement');
        }
        Test.stopTest();
    }

    @isTest
    static void testCreateTrip_InvalidDates() {
        Trip__c trip = new Trip__c(
            Name = 'Bad Dates Trip',
            Start_Date__c = Date.today().addDays(5),
            End_Date__c = Date.today()
        );

        Test.startTest();
        try {
            TravelService.createTrip(trip);
            System.assert(false, 'Should have thrown exception');
        } catch (TravelService.TravelException e) {
            System.assert(e.getMessage().contains('End date'), 'Should mention date order');
        }
        Test.stopTest();
    }

    @isTest
    static void testUpdateTrip() {
        Trip__c trip = [SELECT Id, Name FROM Trip__c LIMIT 1];
        trip.Status__c = 'Booked';
        trip.Destination__c = 'Boston';

        Test.startTest();
        Trip__c result = TravelService.updateTrip(trip);
        Test.stopTest();

        Trip__c saved = [SELECT Status__c, Destination__c FROM Trip__c WHERE Id = :result.Id];
        System.assertEquals('Booked', saved.Status__c);
        System.assertEquals('Boston', saved.Destination__c);
    }

    @isTest
    static void testGetTripAndMyTrips() {
        Trip__c existing = [SELECT Id FROM Trip__c LIMIT 1];

        Test.startTest();
        Trip__c fetched = TravelService.getTrip(existing.Id);
        List<Trip__c> myTrips = TravelService.getMyTrips();
        Test.stopTest();

        System.assertEquals(existing.Id, fetched.Id);
        System.assert(!myTrips.isEmpty(), 'Current user should have at least one trip');
    }

    @isTest
    static void testAddReservation() {
        Trip__c trip = [SELECT Id FROM Trip__c LIMIT 1];

        Trip_Reservation__c reservation = new Trip_Reservation__c(
            Trip__c = trip.Id,
            Type__c = 'Flight',
            Vendor__c = 'United',
            Cost__c = 450.00,
            Start__c = DateTime.now(),
            End__c = DateTime.now().addHours(6),
            Confirmation__c = 'ABC123'
        );

        Test.startTest();
        Trip_Reservation__c result = TravelService.addReservation(reservation);
        Test.stopTest();

        System.assertNotEquals(null, result.Id, 'Reservation should be created');
        Trip_Reservation__c saved = [
            SELECT Type__c, Vendor__c, Cost__c, Currency__c, Confirmation__c
            FROM Trip_Reservation__c WHERE Id = :result.Id
        ];
        System.assertEquals('Flight', saved.Type__c);
        System.assertEquals('United', saved.Vendor__c);
        System.assertEquals('USD', saved.Currency__c, 'Currency should default to USD');
        System.assertEquals('ABC123', saved.Confirmation__c);
    }

    @isTest
    static void testAddReservation_NoTrip() {
        Trip_Reservation__c reservation = new Trip_Reservation__c(
            Type__c = 'Hotel'
        );

        Test.startTest();
        try {
            TravelService.addReservation(reservation);
            System.assert(false, 'Should have thrown exception');
        } catch (TravelService.TravelException e) {
            System.assert(e.getMessage().contains('trip'), 'Should require a trip');
        }
        Test.stopTest();
    }

    @isTest
    static void testAddReservation_InvalidDates() {
        Trip__c trip = [SELECT Id FROM Trip__c LIMIT 1];

        Trip_Reservation__c reservation = new Trip_Reservation__c(
            Trip__c = trip.Id,
            Type__c = 'Hotel',
            Start__c = DateTime.now().addDays(2),
            End__c = DateTime.now()
        );

        Test.startTest();
        try {
            TravelService.addReservation(reservation);
            System.assert(false, 'Should have thrown exception');
        } catch (TravelService.TravelException e) {
            System.assert(e.getMessage().contains('end'), 'Should validate reservation dates');
        }
        Test.stopTest();
    }

    @isTest
    static void testUpdateAndDeleteReservation() {
        Trip__c trip = [SELECT Id FROM Trip__c LIMIT 1];
        Trip_Reservation__c reservation = new Trip_Reservation__c(
            Trip__c = trip.Id,
            Type__c = 'Car',
            Vendor__c = 'Hertz',
            Cost__c = 120.00
        );
        insert reservation;

        reservation.Vendor__c = 'Avis';
        TravelService.updateReservation(reservation);
        Trip_Reservation__c updated = [SELECT Vendor__c FROM Trip_Reservation__c WHERE Id = :reservation.Id];
        System.assertEquals('Avis', updated.Vendor__c);

        List<Trip_Reservation__c> forTrip = TravelService.getReservations(trip.Id);
        System.assert(!forTrip.isEmpty(), 'Trip should have reservations');

        Test.startTest();
        TravelService.deleteReservation(reservation.Id);
        Test.stopTest();

        List<Trip_Reservation__c> remaining = [SELECT Id FROM Trip_Reservation__c WHERE Id = :reservation.Id];
        System.assert(remaining.isEmpty(), 'Reservation should be deleted');
    }

    @isTest
    static void testDeleteTripCascadesReservations() {
        Trip__c trip = [SELECT Id FROM Trip__c LIMIT 1];
        insert new Trip_Reservation__c(
            Trip__c = trip.Id,
            Type__c = 'Rail',
            Vendor__c = 'Amtrak'
        );

        Test.startTest();
        TravelService.deleteTrip(trip.Id);
        Test.stopTest();

        System.assert([SELECT Id FROM Trip__c WHERE Id = :trip.Id].isEmpty(), 'Trip should be deleted');
        System.assert(
            [SELECT Id FROM Trip_Reservation__c WHERE Trip__c = :trip.Id].isEmpty(),
            'Reservations should be deleted with trip'
        );
    }

    @isTest
    static void testInvocableCreateTrip() {
        Expense_Policy__c policy = [SELECT Id FROM Expense_Policy__c LIMIT 1];

        InvocableCreateTrip.Request req = new InvocableCreateTrip.Request();
        req.name = 'Invocable Trip';
        req.travelerId = UserInfo.getUserId();
        req.policyId = policy.Id;
        req.startDate = Date.today();
        req.endDate = Date.today().addDays(4);
        req.destination = 'Seattle';
        req.reservationType = 'Flight';
        req.reservationVendor = 'Delta';
        req.reservationCost = 300.00;
        req.reservationStart = DateTime.now();
        req.reservationEnd = DateTime.now().addHours(4);
        req.reservationConfirmation = 'XYZ789';

        Test.startTest();
        List<InvocableCreateTrip.Results> results =
            InvocableCreateTrip.execute(new List<InvocableCreateTrip.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assert(results[0].isSuccess, 'Invocable should succeed');
        System.assertNotEquals(null, results[0].tripId, 'Trip id should be returned');
        System.assertNotEquals(null, results[0].reservationId, 'Reservation id should be returned');
    }

    @isTest
    static void testInvocableCreateTrip_Failure() {
        InvocableCreateTrip.Request req = new InvocableCreateTrip.Request();
        req.name = null;

        Test.startTest();
        List<InvocableCreateTrip.Results> results =
            InvocableCreateTrip.execute(new List<InvocableCreateTrip.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(false, results[0].isSuccess, 'Invocable should report failure');
        System.assertNotEquals(null, results[0].errorMessage, 'Error message should be set');
    }
}
