public with sharing class InvocableChangeSubscription {

    @InvocableMethod(label='Change Subscription' description='Creates or modifies a subscription plan, seats, or status and recomputes the amount' category='Subscription Management')
    public static List<Results> execute(List<Request> requests) {
        List<Results> responseList = new List<Results>();
        for (Request req : requests) {
            Results res = new Results();
            try {
                Subscription__c sub = applyAction(req);
                res.subscriptionId = sub.Id;
                res.plan = sub.Plan__c;
                res.seats = sub.Seats__c == null ? null : Integer.valueOf(sub.Seats__c);
                res.status = sub.Status__c;
                res.amount = sub.Amount__c;
                res.isSuccess = true;
            } catch (Exception e) {
                res.isSuccess = false;
                res.errorMessage = e.getMessage();
            }
            responseList.add(res);
        }
        return responseList;
    }

    private static Subscription__c applyAction(Request req) {
        String action = String.isBlank(req.action) ? 'Create' : req.action;
        if (action == 'Create') {
            return SubscriptionService.createSubscription(req.policyId, req.plan, req.seats, req.billingCycle, req.currencyCode);
        } else if (action == 'ChangePlan') {
            return SubscriptionService.changePlan(req.subscriptionId, req.plan);
        } else if (action == 'UpdateSeats') {
            return SubscriptionService.updateSeats(req.subscriptionId, req.seats);
        } else if (action == 'Cancel') {
            return SubscriptionService.cancelSubscription(req.subscriptionId);
        }
        throw new SubscriptionService.SubscriptionException('Unknown action: ' + action);
    }

    public class Request {
        @InvocableVariable(label='Action' description='Create, ChangePlan, UpdateSeats, or Cancel' required=true)
        public String action;

        @InvocableVariable(label='Subscription Id' required=false)
        public Id subscriptionId;

        @InvocableVariable(label='Policy Id' required=false)
        public Id policyId;

        @InvocableVariable(label='Plan' required=false)
        public String plan;

        @InvocableVariable(label='Seats' required=false)
        public Integer seats;

        @InvocableVariable(label='Billing Cycle' required=false)
        public String billingCycle;

        @InvocableVariable(label='Currency Code' required=false)
        public String currencyCode;
    }

    public class Results {
        @InvocableVariable(label='Subscription Id')
        public Id subscriptionId;

        @InvocableVariable(label='Plan')
        public String plan;

        @InvocableVariable(label='Seats')
        public Integer seats;

        @InvocableVariable(label='Status')
        public String status;

        @InvocableVariable(label='Amount')
        public Decimal amount;

        @InvocableVariable(label='Is Success')
        public Boolean isSuccess;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }
}
