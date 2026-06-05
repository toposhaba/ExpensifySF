@isTest
private class DistanceServiceTest {

    @TestSetup
    static void setupTestData() {
        Expense_Policy__c policy = new Expense_Policy__c(
            Name = 'Distance Policy',
            Currency__c = 'USD',
            Type__c = 'Corporate',
            Approval_Mode__c = 'Basic'
        );
        insert policy;

        insert new List<Distance_Rate__c>{
            new Distance_Rate__c(
                Name = 'Standard Mileage',
                Policy__c = policy.Id,
                Rate_Per_Unit__c = 0.50,
                Unit__c = 'mi',
                Currency__c = 'USD'
            ),
            new Distance_Rate__c(
                Name = 'Standard Kilometer',
                Policy__c = policy.Id,
                Rate_Per_Unit__c = 0.30,
                Unit__c = 'km',
                Currency__c = 'USD'
            )
        };

        Expense_Policy__c emptyPolicy = new Expense_Policy__c(
            Name = 'No Rate Policy',
            Currency__c = 'USD',
            Type__c = 'Corporate',
            Approval_Mode__c = 'Basic'
        );
        insert emptyPolicy;
    }

    private static Expense_Policy__c getPolicy() {
        return [SELECT Id FROM Expense_Policy__c WHERE Name = 'Distance Policy' LIMIT 1];
    }

    private static Expense_Policy__c getEmptyPolicy() {
        return [SELECT Id FROM Expense_Policy__c WHERE Name = 'No Rate Policy' LIMIT 1];
    }

    @isTest
    static void testComputeAmountEqualsDistanceTimesRate() {
        Distance_Rate__c rate = [SELECT Id, Rate_Per_Unit__c, Unit__c, Currency__c, Name FROM Distance_Rate__c WHERE Unit__c = 'mi' LIMIT 1];

        Test.startTest();
        Decimal amount = DistanceService.computeAmount(10, 'mi', rate);
        Test.stopTest();

        System.assertEquals(5.00, amount, 'Amount should equal distance times rate per unit');
    }

    @isTest
    static void testQuoteReturnsExpectedValues() {
        Expense_Policy__c policy = getPolicy();

        Test.startTest();
        DistanceService.DistanceQuote q = DistanceService.quote(policy.Id, 20, 'mi');
        Test.stopTest();

        System.assertEquals(10.00, q.amount, 'Amount should be 20 miles * 0.50');
        System.assertEquals(0.50, q.ratePerUnit, 'Rate per unit should match the mile rate');
        System.assertEquals('mi', q.rateUnit, 'Resolved rate unit should be miles');
        System.assertEquals('USD', q.currencyCode, 'Currency should come from the rate');
    }

    @isTest
    static void testCreateDistanceExpenseAmount() {
        Expense_Policy__c policy = getPolicy();

        Test.startTest();
        Expense__c expense = DistanceService.createDistanceExpense(
            policy.Id, 15, 'mi', Date.today(), 'Client Site', 'Site visit', null
        );
        Test.stopTest();

        Expense__c saved = [
            SELECT Amount__c, Distance__c, Distance_Unit__c, Expense_Type__c, Currency__c, Policy__c
            FROM Expense__c WHERE Id = :expense.Id
        ];
        System.assertEquals(7.50, saved.Amount__c, 'Amount should be 15 miles * 0.50');
        System.assertEquals(15, saved.Distance__c, 'Distance should be persisted');
        System.assertEquals('mi', saved.Distance_Unit__c, 'Distance unit should be persisted');
        System.assertEquals('Distance', saved.Expense_Type__c, 'Expense type should be Distance');
        System.assertEquals('USD', saved.Currency__c, 'Currency should come from the rate');
        System.assertEquals(policy.Id, saved.Policy__c, 'Policy should be linked');
    }

    @isTest
    static void testUnitHandlingResolvesMatchingRate() {
        Expense_Policy__c policy = getPolicy();

        Test.startTest();
        Expense__c expense = DistanceService.createDistanceExpense(
            policy.Id, 10, 'km', Date.today(), null, null, null
        );
        Test.stopTest();

        Expense__c saved = [SELECT Amount__c, Distance_Unit__c FROM Expense__c WHERE Id = :expense.Id];
        System.assertEquals('km', saved.Distance_Unit__c, 'Kilometer rate should be used for km requests');
        System.assertEquals(3.00, saved.Amount__c, 'Amount should be 10 km * 0.30');
    }

    @isTest
    static void testConvertDistance() {
        Test.startTest();
        Decimal milesToKm = DistanceService.convertDistance(10, 'mi', 'km');
        Decimal kmToMiles = DistanceService.convertDistance(16.09344, 'km', 'mi');
        Decimal sameUnit = DistanceService.convertDistance(5, 'mi', 'mi');
        Test.stopTest();

        System.assertEquals(16.09344, milesToKm, '10 miles should convert to kilometers');
        System.assertEquals(10, kmToMiles.setScale(0), '16.09344 km should convert back to 10 miles');
        System.assertEquals(5, sameUnit, 'Same unit conversion should return the original distance');
    }

    @isTest
    static void testMissingRateThrows() {
        Expense_Policy__c emptyPolicy = getEmptyPolicy();

        Test.startTest();
        try {
            DistanceService.createDistanceExpense(emptyPolicy.Id, 10, 'mi', Date.today(), null, null, null);
            System.assert(false, 'Should have thrown for missing rate');
        } catch (DistanceService.DistanceException e) {
            System.assert(e.getMessage().contains('No distance rate'), 'Expected missing-rate error');
        }
        Test.stopTest();
    }

    @isTest
    static void testNullPolicyThrows() {
        Test.startTest();
        try {
            DistanceService.resolveRate(null, 'mi');
            System.assert(false, 'Should have thrown for null policy');
        } catch (DistanceService.DistanceException e) {
            System.assert(e.getMessage().contains('Policy is required'), 'Expected policy required error');
        }
        Test.stopTest();
    }

    @isTest
    static void testInvalidDistanceThrows() {
        Distance_Rate__c rate = [SELECT Id, Rate_Per_Unit__c, Unit__c FROM Distance_Rate__c WHERE Unit__c = 'mi' LIMIT 1];

        Test.startTest();
        try {
            DistanceService.computeAmount(0, 'mi', rate);
            System.assert(false, 'Should have thrown for zero distance');
        } catch (DistanceService.DistanceException e) {
            System.assert(e.getMessage().contains('greater than zero'), 'Expected distance validation error');
        }
        Test.stopTest();
    }

    @isTest
    static void testPreviewAmountAura() {
        Expense_Policy__c policy = getPolicy();

        Test.startTest();
        DistanceService.DistanceQuote q = DistanceService.previewAmount(policy.Id, 4, 'mi');
        Test.stopTest();

        System.assertEquals(2.00, q.amount, 'Preview amount should be 4 miles * 0.50');
    }

    @isTest
    static void testPreviewAmountAuraError() {
        Expense_Policy__c emptyPolicy = getEmptyPolicy();

        Test.startTest();
        try {
            DistanceService.previewAmount(emptyPolicy.Id, 4, 'mi');
            System.assert(false, 'Should have thrown for missing rate');
        } catch (Exception e) {
            System.assert(true, 'Aura wrapper surfaced the error');
        }
        Test.stopTest();
    }

    @isTest
    static void testCreateExpenseFromDistanceAura() {
        Expense_Policy__c policy = getPolicy();

        Test.startTest();
        Id expenseId = DistanceService.createExpenseFromDistance(policy.Id, 8, 'mi', Date.today(), 'Trip', 'Notes');
        Test.stopTest();

        Expense__c saved = [SELECT Amount__c FROM Expense__c WHERE Id = :expenseId];
        System.assertEquals(4.00, saved.Amount__c, 'Amount should be 8 miles * 0.50');
    }

    @isTest
    static void testInvocableCreateDistanceExpense() {
        Expense_Policy__c policy = getPolicy();

        InvocableCreateDistanceExpense.Request req = new InvocableCreateDistanceExpense.Request();
        req.policyId = policy.Id;
        req.distance = 12;
        req.unit = 'mi';
        req.expenseDate = Date.today();
        req.merchant = 'Mileage';

        Test.startTest();
        List<InvocableCreateDistanceExpense.Results> results = InvocableCreateDistanceExpense.execute(
            new List<InvocableCreateDistanceExpense.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(true, results[0].isSuccess, 'Invocable should succeed');
        System.assertEquals(6.00, results[0].amount, 'Amount should be 12 miles * 0.50');
        System.assertNotEquals(null, results[0].expenseId, 'Expense id should be populated');
    }

    @isTest
    static void testInvocableReportsFailure() {
        Expense_Policy__c emptyPolicy = getEmptyPolicy();

        InvocableCreateDistanceExpense.Request req = new InvocableCreateDistanceExpense.Request();
        req.policyId = emptyPolicy.Id;
        req.distance = 12;
        req.unit = 'mi';

        Test.startTest();
        List<InvocableCreateDistanceExpense.Results> results = InvocableCreateDistanceExpense.execute(
            new List<InvocableCreateDistanceExpense.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(false, results[0].isSuccess, 'Invocable should fail without a rate');
        System.assertNotEquals(null, results[0].errorMessage, 'Error message should be populated');
    }
}
