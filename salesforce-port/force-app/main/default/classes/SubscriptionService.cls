public with sharing class SubscriptionService {

    public class SubscriptionException extends Exception {}

    public static final String PLAN_FREE = 'Free';
    public static final String PLAN_COLLECT = 'Collect';
    public static final String PLAN_CONTROL = 'Control';

    public static final String CYCLE_MONTHLY = 'Monthly';
    public static final String CYCLE_ANNUAL = 'Annual';

    public static final String STATUS_ACTIVE = 'Active';
    public static final String STATUS_PAST_DUE = 'PastDue';
    public static final String STATUS_CANCELLED = 'Cancelled';

    private static final Integer ANNUAL_MONTHS_CHARGED = 10;

    private static final Map<String, Decimal> MONTHLY_RATE_PER_SEAT = new Map<String, Decimal>{
        PLAN_FREE => 0,
        PLAN_COLLECT => 5,
        PLAN_CONTROL => 9
    };

    private static final Set<String> SUBSCRIPTION_FIELDS = new Set<String>{
        'Policy__c', 'Plan__c', 'Seats__c', 'Billing_Cycle__c',
        'Status__c', 'Renewal_Date__c', 'Amount__c', 'Currency__c'
    };

    public static Decimal computeAmount(String plan, Integer seats, String billingCycle) {
        if (!MONTHLY_RATE_PER_SEAT.containsKey(plan)) {
            throw new SubscriptionException('Unknown plan: ' + plan);
        }
        Integer seatCount = (seats == null || seats < 0) ? 0 : seats;
        Decimal monthlyRate = MONTHLY_RATE_PER_SEAT.get(plan);
        Decimal multiplier = (billingCycle == CYCLE_ANNUAL) ? ANNUAL_MONTHS_CHARGED : 1;
        return (monthlyRate * seatCount * multiplier).setScale(2, System.RoundingMode.HALF_UP);
    }

    private static Date computeRenewalDate(String billingCycle) {
        return (billingCycle == CYCLE_ANNUAL) ? Date.today().addYears(1) : Date.today().addMonths(1);
    }

    public static Subscription__c createSubscription(Id policyId, String plan, Integer seats, String billingCycle, String currencyCode) {
        assertSubscriptionCreateable();
        if (String.isBlank(plan) || !MONTHLY_RATE_PER_SEAT.containsKey(plan)) {
            throw new SubscriptionException('A valid plan is required');
        }
        if (seats == null || seats < 0) {
            throw new SubscriptionException('Seats must be zero or greater');
        }
        String cycle = String.isBlank(billingCycle) ? CYCLE_MONTHLY : billingCycle;
        if (cycle != CYCLE_MONTHLY && cycle != CYCLE_ANNUAL) {
            throw new SubscriptionException('Billing cycle must be Monthly or Annual');
        }

        Subscription__c sub = new Subscription__c(
            Policy__c = policyId,
            Plan__c = plan,
            Seats__c = seats,
            Billing_Cycle__c = cycle,
            Status__c = STATUS_ACTIVE,
            Renewal_Date__c = computeRenewalDate(cycle),
            Currency__c = String.isBlank(currencyCode) ? 'USD' : currencyCode,
            Amount__c = computeAmount(plan, seats, cycle)
        );
        insert sub;
        return sub;
    }

    public static Subscription__c changePlan(Id subscriptionId, String newPlan) {
        if (String.isBlank(newPlan) || !MONTHLY_RATE_PER_SEAT.containsKey(newPlan)) {
            throw new SubscriptionException('A valid plan is required');
        }
        assertSubscriptionUpdateable();
        Subscription__c sub = loadSubscription(subscriptionId);
        if (sub.Status__c == STATUS_CANCELLED) {
            throw new SubscriptionException('Cannot change the plan of a cancelled subscription');
        }
        sub.Plan__c = newPlan;
        sub.Amount__c = computeAmount(newPlan, integerOf(sub.Seats__c), sub.Billing_Cycle__c);
        update sub;
        return sub;
    }

    public static Subscription__c updateSeats(Id subscriptionId, Integer newSeats) {
        if (newSeats == null || newSeats < 0) {
            throw new SubscriptionException('Seats must be zero or greater');
        }
        assertSubscriptionUpdateable();
        Subscription__c sub = loadSubscription(subscriptionId);
        if (sub.Status__c == STATUS_CANCELLED) {
            throw new SubscriptionException('Cannot change seats on a cancelled subscription');
        }
        sub.Seats__c = newSeats;
        sub.Amount__c = computeAmount(sub.Plan__c, newSeats, sub.Billing_Cycle__c);
        update sub;
        return sub;
    }

    public static Subscription__c cancelSubscription(Id subscriptionId) {
        assertSubscriptionUpdateable();
        Subscription__c sub = loadSubscription(subscriptionId);
        sub.Status__c = STATUS_CANCELLED;
        sub.Amount__c = 0;
        sub.Renewal_Date__c = null;
        update sub;
        return sub;
    }

    private static Integer integerOf(Decimal value) {
        return value == null ? 0 : value.intValue();
    }

    private static Subscription__c loadSubscription(Id subscriptionId) {
        if (subscriptionId == null) {
            throw new SubscriptionException('Subscription Id is required');
        }
        assertSubscriptionReadable();
        List<Subscription__c> subs = [
            SELECT Id, Policy__c, Plan__c, Seats__c, Billing_Cycle__c,
                   Status__c, Renewal_Date__c, Amount__c, Currency__c
            FROM Subscription__c
            WHERE Id = :subscriptionId
            LIMIT 1
        ];
        if (subs.isEmpty()) {
            throw new SubscriptionException('Subscription could not be found');
        }
        return subs.get(0);
    }

    private static void assertSubscriptionCreateable() {
        Schema.DescribeSObjectResult describe = Schema.SObjectType.Subscription__c;
        if (!describe.isCreateable()) {
            throw new SubscriptionException('Insufficient access to create subscriptions');
        }
        assertFieldsAccess(describe, true);
    }

    private static void assertSubscriptionUpdateable() {
        Schema.DescribeSObjectResult describe = Schema.SObjectType.Subscription__c;
        if (!describe.isUpdateable()) {
            throw new SubscriptionException('Insufficient access to update subscriptions');
        }
        assertFieldsAccess(describe, false);
    }

    private static void assertSubscriptionReadable() {
        Schema.DescribeSObjectResult describe = Schema.SObjectType.Subscription__c;
        if (!describe.isAccessible()) {
            throw new SubscriptionException('Insufficient access to read subscriptions');
        }
    }

    private static void assertFieldsAccess(Schema.DescribeSObjectResult describe, Boolean forCreate) {
        Map<String, Schema.SObjectField> fieldMap = describe.fields.getMap();
        for (String fieldName : SUBSCRIPTION_FIELDS) {
            Schema.SObjectField field = fieldMap.get(fieldName);
            if (field == null) {
                throw new SubscriptionException('Missing field ' + fieldName);
            }
            Schema.DescribeFieldResult fieldDescribe = field.getDescribe();
            Boolean ok = forCreate ? fieldDescribe.isCreateable() : fieldDescribe.isUpdateable();
            if (!ok) {
                throw new SubscriptionException('Insufficient access to field ' + fieldName);
            }
        }
    }

    @AuraEnabled
    public static Subscription__c createSubscriptionApex(Id policyId, String plan, Integer seats, String billingCycle, String currencyCode) {
        try {
            return createSubscription(policyId, plan, seats, billingCycle, currencyCode);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Subscription__c changePlanApex(Id subscriptionId, String newPlan) {
        try {
            return changePlan(subscriptionId, newPlan);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Subscription__c updateSeatsApex(Id subscriptionId, Integer newSeats) {
        try {
            return updateSeats(subscriptionId, newSeats);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Subscription__c cancelSubscriptionApex(Id subscriptionId) {
        try {
            return cancelSubscription(subscriptionId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Subscription__c> listSubscriptions(Id policyId) {
        assertSubscriptionReadable();
        if (policyId == null) {
            return [
                SELECT Id, Name, Policy__c, Plan__c, Seats__c, Billing_Cycle__c,
                       Status__c, Renewal_Date__c, Amount__c, Currency__c
                FROM Subscription__c
                ORDER BY CreatedDate DESC
            ];
        }
        return [
            SELECT Id, Name, Policy__c, Plan__c, Seats__c, Billing_Cycle__c,
                   Status__c, Renewal_Date__c, Amount__c, Currency__c
            FROM Subscription__c
            WHERE Policy__c = :policyId
            ORDER BY CreatedDate DESC
        ];
    }

    @AuraEnabled(cacheable=true)
    public static Subscription__c getSubscription(Id subscriptionId) {
        return loadSubscription(subscriptionId);
    }
}
