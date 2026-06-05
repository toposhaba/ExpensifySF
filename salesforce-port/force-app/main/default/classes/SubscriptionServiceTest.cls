@isTest
private class SubscriptionServiceTest {

    private static Expense_Policy__c buildPolicy() {
        Expense_Policy__c policy = new Expense_Policy__c(
            Name = 'Billing Policy',
            Currency__c = 'USD',
            Approval_Mode__c = 'Basic'
        );
        insert policy;
        return policy;
    }

    @isTest
    static void testComputeAmountMonthly() {
        Test.startTest();
        Decimal control = SubscriptionService.computeAmount('Control', 10, 'Monthly');
        Decimal collectAmount = SubscriptionService.computeAmount('Collect', 4, 'Monthly');
        Decimal free = SubscriptionService.computeAmount('Free', 25, 'Monthly');
        Test.stopTest();

        System.assertEquals(90.00, control, 'Control monthly should be 9 * 10 seats');
        System.assertEquals(20.00, collectAmount, 'Collect monthly should be 5 * 4 seats');
        System.assertEquals(0.00, free, 'Free plan should always be zero');
    }

    @isTest
    static void testComputeAmountAnnual() {
        Test.startTest();
        Decimal control = SubscriptionService.computeAmount('Control', 10, 'Annual');
        Decimal collectAnnual = SubscriptionService.computeAmount('Collect', 3, 'Annual');
        Test.stopTest();

        System.assertEquals(900.00, control, 'Control annual should be 9 * 10 seats * 10 months');
        System.assertEquals(150.00, collectAnnual, 'Collect annual should be 5 * 3 seats * 10 months');
    }

    @isTest
    static void testComputeAmountUnknownPlanThrows() {
        Test.startTest();
        try {
            SubscriptionService.computeAmount('Enterprise', 5, 'Monthly');
            System.assert(false, 'Should have thrown for unknown plan');
        } catch (SubscriptionService.SubscriptionException e) {
            System.assert(e.getMessage().contains('Unknown plan'), 'Expected unknown plan error');
        }
        Test.stopTest();
    }

    @isTest
    static void testCreateSubscription() {
        Expense_Policy__c policy = buildPolicy();

        Test.startTest();
        Subscription__c sub = SubscriptionService.createSubscription(policy.Id, 'Control', 10, 'Monthly', 'USD');
        Test.stopTest();

        System.assertNotEquals(null, sub.Id, 'Subscription should be inserted');
        System.assertEquals('Control', sub.Plan__c, 'Plan should be stored');
        System.assertEquals(10, sub.Seats__c, 'Seats should be stored');
        System.assertEquals('Active', sub.Status__c, 'New subscription should be Active');
        System.assertEquals(90.00, sub.Amount__c, 'Amount should be computed from plan and seats');
        System.assertEquals(Date.today().addMonths(1), sub.Renewal_Date__c, 'Monthly renewal should be one month out');
    }

    @isTest
    static void testCreateSubscriptionDefaults() {
        Expense_Policy__c policy = buildPolicy();

        Test.startTest();
        Subscription__c sub = SubscriptionService.createSubscription(policy.Id, 'Collect', 2, null, null);
        Test.stopTest();

        System.assertEquals('Monthly', sub.Billing_Cycle__c, 'Billing cycle should default to Monthly');
        System.assertEquals('USD', sub.Currency__c, 'Currency should default to USD');
        System.assertEquals(10.00, sub.Amount__c, 'Collect 2 seats monthly should be 10');
    }

    @isTest
    static void testCreateSubscriptionInvalidPlanThrows() {
        Expense_Policy__c policy = buildPolicy();
        Test.startTest();
        try {
            SubscriptionService.createSubscription(policy.Id, 'Bogus', 1, 'Monthly', 'USD');
            System.assert(false, 'Should have thrown for invalid plan');
        } catch (SubscriptionService.SubscriptionException e) {
            System.assert(e.getMessage().contains('valid plan'), 'Expected valid plan error');
        }
        Test.stopTest();
    }

    @isTest
    static void testCreateSubscriptionNegativeSeatsThrows() {
        Expense_Policy__c policy = buildPolicy();
        Test.startTest();
        try {
            SubscriptionService.createSubscription(policy.Id, 'Collect', -1, 'Monthly', 'USD');
            System.assert(false, 'Should have thrown for negative seats');
        } catch (SubscriptionService.SubscriptionException e) {
            System.assert(e.getMessage().contains('zero or greater'), 'Expected seats error');
        }
        Test.stopTest();
    }

    @isTest
    static void testChangePlan() {
        Expense_Policy__c policy = buildPolicy();
        Subscription__c sub = SubscriptionService.createSubscription(policy.Id, 'Control', 10, 'Monthly', 'USD');

        Test.startTest();
        Subscription__c updated = SubscriptionService.changePlan(sub.Id, 'Collect');
        Test.stopTest();

        System.assertEquals('Collect', updated.Plan__c, 'Plan should change to Collect');
        System.assertEquals(50.00, updated.Amount__c, 'Amount should recompute for Collect 10 seats');
    }

    @isTest
    static void testChangePlanInvalidThrows() {
        Expense_Policy__c policy = buildPolicy();
        Subscription__c sub = SubscriptionService.createSubscription(policy.Id, 'Collect', 5, 'Monthly', 'USD');
        Test.startTest();
        try {
            SubscriptionService.changePlan(sub.Id, 'Nope');
            System.assert(false, 'Should have thrown for invalid plan');
        } catch (SubscriptionService.SubscriptionException e) {
            System.assert(e.getMessage().contains('valid plan'), 'Expected valid plan error');
        }
        Test.stopTest();
    }

    @isTest
    static void testUpdateSeats() {
        Expense_Policy__c policy = buildPolicy();
        Subscription__c sub = SubscriptionService.createSubscription(policy.Id, 'Control', 10, 'Monthly', 'USD');

        Test.startTest();
        Subscription__c updated = SubscriptionService.updateSeats(sub.Id, 20);
        Test.stopTest();

        System.assertEquals(20, updated.Seats__c, 'Seats should update to 20');
        System.assertEquals(180.00, updated.Amount__c, 'Amount should recompute for 20 seats');
    }

    @isTest
    static void testUpdateSeatsNegativeThrows() {
        Expense_Policy__c policy = buildPolicy();
        Subscription__c sub = SubscriptionService.createSubscription(policy.Id, 'Control', 10, 'Monthly', 'USD');
        Test.startTest();
        try {
            SubscriptionService.updateSeats(sub.Id, -5);
            System.assert(false, 'Should have thrown for negative seats');
        } catch (SubscriptionService.SubscriptionException e) {
            System.assert(e.getMessage().contains('zero or greater'), 'Expected seats error');
        }
        Test.stopTest();
    }

    @isTest
    static void testCancelSubscription() {
        Expense_Policy__c policy = buildPolicy();
        Subscription__c sub = SubscriptionService.createSubscription(policy.Id, 'Control', 10, 'Annual', 'USD');

        Test.startTest();
        Subscription__c cancelled = SubscriptionService.cancelSubscription(sub.Id);
        Test.stopTest();

        System.assertEquals('Cancelled', cancelled.Status__c, 'Status should be Cancelled');
        System.assertEquals(0, cancelled.Amount__c, 'Cancelled subscription amount should be zero');
        System.assertEquals(null, cancelled.Renewal_Date__c, 'Cancelled subscription should clear renewal date');
    }

    @isTest
    static void testChangePlanAfterCancelThrows() {
        Expense_Policy__c policy = buildPolicy();
        Subscription__c sub = SubscriptionService.createSubscription(policy.Id, 'Control', 10, 'Monthly', 'USD');
        SubscriptionService.cancelSubscription(sub.Id);

        Test.startTest();
        try {
            SubscriptionService.changePlan(sub.Id, 'Collect');
            System.assert(false, 'Should have thrown for cancelled subscription');
        } catch (SubscriptionService.SubscriptionException e) {
            System.assert(e.getMessage().contains('cancelled'), 'Expected cancelled subscription error');
        }
        Test.stopTest();
    }

    @isTest
    static void testLoadMissingSubscriptionThrows() {
        Test.startTest();
        try {
            SubscriptionService.changePlan(null, 'Collect');
            System.assert(false, 'Should have thrown for null id');
        } catch (SubscriptionService.SubscriptionException e) {
            System.assert(e.getMessage().contains('required'), 'Expected required id error');
        }
        Test.stopTest();
    }

    @isTest
    static void testListAndGetSubscription() {
        Expense_Policy__c policy = buildPolicy();
        Subscription__c sub = SubscriptionService.createSubscription(policy.Id, 'Collect', 3, 'Monthly', 'USD');

        Test.startTest();
        List<Subscription__c> byPolicy = SubscriptionService.listSubscriptions(policy.Id);
        List<Subscription__c> all = SubscriptionService.listSubscriptions(null);
        Subscription__c fetched = SubscriptionService.getSubscription(sub.Id);
        Test.stopTest();

        System.assertEquals(1, byPolicy.size(), 'One subscription should match the policy');
        System.assertEquals(true, all.size() >= 1, 'All subscriptions should include the new record');
        System.assertEquals(sub.Id, fetched.Id, 'getSubscription should return the record');
    }

    @isTest
    static void testApexWrappers() {
        Expense_Policy__c policy = buildPolicy();

        Test.startTest();
        Subscription__c sub = SubscriptionService.createSubscriptionApex(policy.Id, 'Control', 5, 'Monthly', 'USD');
        SubscriptionService.changePlanApex(sub.Id, 'Collect');
        SubscriptionService.updateSeatsApex(sub.Id, 8);
        Subscription__c cancelled = SubscriptionService.cancelSubscriptionApex(sub.Id);
        Test.stopTest();

        System.assertEquals('Cancelled', cancelled.Status__c, 'Aura wrappers should drive the lifecycle');
    }

    @isTest
    static void testApexWrapperError() {
        Test.startTest();
        try {
            SubscriptionService.createSubscriptionApex(null, 'Bogus', 1, 'Monthly', 'USD');
            System.assert(false, 'Should have thrown via Aura wrapper');
        } catch (Exception e) {
            System.assert(true, 'Aura wrapper surfaced the error');
        }
        Test.stopTest();
    }

    @isTest
    static void testInvocableCreate() {
        Expense_Policy__c policy = buildPolicy();
        InvocableChangeSubscription.Request req = new InvocableChangeSubscription.Request();
        req.action = 'Create';
        req.policyId = policy.Id;
        req.plan = 'Control';
        req.seats = 10;
        req.billingCycle = 'Monthly';
        req.currencyCode = 'USD';

        Test.startTest();
        List<InvocableChangeSubscription.Results> results = InvocableChangeSubscription.execute(
            new List<InvocableChangeSubscription.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(true, results.get(0).isSuccess, 'Invocable create should succeed');
        System.assertEquals(90.00, results.get(0).amount, 'Amount should be returned');
        System.assertEquals(10, results.get(0).seats, 'Seats should be returned');
    }

    @isTest
    static void testInvocableChangeSeatsAndCancel() {
        Expense_Policy__c policy = buildPolicy();
        Subscription__c sub = SubscriptionService.createSubscription(policy.Id, 'Control', 10, 'Monthly', 'USD');

        InvocableChangeSubscription.Request planReq = new InvocableChangeSubscription.Request();
        planReq.action = 'ChangePlan';
        planReq.subscriptionId = sub.Id;
        planReq.plan = 'Collect';

        InvocableChangeSubscription.Request seatReq = new InvocableChangeSubscription.Request();
        seatReq.action = 'UpdateSeats';
        seatReq.subscriptionId = sub.Id;
        seatReq.seats = 4;

        InvocableChangeSubscription.Request cancelReq = new InvocableChangeSubscription.Request();
        cancelReq.action = 'Cancel';
        cancelReq.subscriptionId = sub.Id;

        Test.startTest();
        List<InvocableChangeSubscription.Results> results = InvocableChangeSubscription.execute(
            new List<InvocableChangeSubscription.Request>{ planReq, seatReq, cancelReq }
        );
        Test.stopTest();

        System.assertEquals('Collect', results.get(0).plan, 'Plan change should be reflected');
        System.assertEquals(20.00, results.get(1).amount, 'Seat change should recompute amount for Collect 4 seats');
        System.assertEquals('Cancelled', results.get(2).status, 'Cancel should set status');
    }

    @isTest
    static void testInvocableUnknownActionFails() {
        InvocableChangeSubscription.Request req = new InvocableChangeSubscription.Request();
        req.action = 'Frobnicate';

        Test.startTest();
        List<InvocableChangeSubscription.Results> results = InvocableChangeSubscription.execute(
            new List<InvocableChangeSubscription.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(false, results.get(0).isSuccess, 'Unknown action should fail');
        System.assertNotEquals(null, results.get(0).errorMessage, 'Error message should be populated');
    }
}
