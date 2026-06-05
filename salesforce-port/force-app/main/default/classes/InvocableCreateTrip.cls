public with sharing class InvocableCreateTrip {

    @InvocableMethod(label='Create Trip' description='Creates a travel trip with optional first reservation' category='Travel Management')
    public static List<Results> execute(List<Request> requests) {
        List<Results> responseList = new List<Results>();
        for (Request req : requests) {
            Results res = new Results();
            try {
                Trip__c trip = new Trip__c(
                    Name = req.name,
                    Traveler__c = req.travelerId,
                    Policy__c = req.policyId,
                    Start_Date__c = req.startDate,
                    End_Date__c = req.endDate,
                    Destination__c = req.destination,
                    Status__c = req.status != null ? req.status : 'Planned'
                );
                Trip__c created = TravelService.createTrip(trip);
                res.tripId = created.Id;

                if (req.reservationType != null) {
                    Trip_Reservation__c reservation = new Trip_Reservation__c(
                        Trip__c = created.Id,
                        Type__c = req.reservationType,
                        Vendor__c = req.reservationVendor,
                        Cost__c = req.reservationCost,
                        Currency__c = req.reservationCurrency != null ? req.reservationCurrency : 'USD',
                        Start__c = req.reservationStart,
                        End__c = req.reservationEnd,
                        Confirmation__c = req.reservationConfirmation
                    );
                    Trip_Reservation__c createdReservation = TravelService.addReservation(reservation);
                    res.reservationId = createdReservation.Id;
                }

                res.isSuccess = true;
            } catch (Exception e) {
                res.isSuccess = false;
                res.errorMessage = e.getMessage();
            }
            responseList.add(res);
        }
        return responseList;
    }

    public class Request {
        @InvocableVariable(label='Trip Name' required=true)
        public String name;

        @InvocableVariable(label='Traveler Id' required=false)
        public Id travelerId;

        @InvocableVariable(label='Policy Id' required=false)
        public Id policyId;

        @InvocableVariable(label='Start Date' required=false)
        public Date startDate;

        @InvocableVariable(label='End Date' required=false)
        public Date endDate;

        @InvocableVariable(label='Destination' required=false)
        public String destination;

        @InvocableVariable(label='Status' required=false)
        public String status;

        @InvocableVariable(label='Reservation Type' required=false)
        public String reservationType;

        @InvocableVariable(label='Reservation Vendor' required=false)
        public String reservationVendor;

        @InvocableVariable(label='Reservation Cost' required=false)
        public Decimal reservationCost;

        @InvocableVariable(label='Reservation Currency' required=false)
        public String reservationCurrency;

        @InvocableVariable(label='Reservation Start' required=false)
        public DateTime reservationStart;

        @InvocableVariable(label='Reservation End' required=false)
        public DateTime reservationEnd;

        @InvocableVariable(label='Reservation Confirmation' required=false)
        public String reservationConfirmation;
    }

    public class Results {
        @InvocableVariable(label='Trip Id')
        public Id tripId;

        @InvocableVariable(label='Reservation Id')
        public Id reservationId;

        @InvocableVariable(label='Is Success')
        public Boolean isSuccess;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }
}
