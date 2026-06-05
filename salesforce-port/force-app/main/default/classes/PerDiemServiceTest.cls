@isTest
private class PerDiemServiceTest {

    @TestSetup
    static void setupData() {
        Expense_Policy__c policy = new Expense_Policy__c(
            Name = 'Per Diem Policy',
            Currency__c = 'USD',
            Type__c = 'Corporate'
        );
        insert policy;
    }

    private static Expense_Policy__c getPolicy() {
        return [SELECT Id FROM Expense_Policy__c WHERE Name = 'Per Diem Policy' LIMIT 1];
    }

    @isTest
    static void testCreateAndGetRates() {
        Expense_Policy__c policy = getPolicy();

        Test.startTest();
        PerDiemService.createRate(policy.Id, 'London', 'Standard', 200, 50, 'GBP');
        PerDiemService.createRate(policy.Id, 'Austin', 'Standard', 100, null, 'USD');
        Test.stopTest();

        List<Per_Diem_Rate__c> rates = PerDiemService.getRates(policy.Id);
        System.assertEquals(2, rates.size());
        System.assertEquals('Austin', rates[0].Destination__c);
        System.assertEquals(100, rates[0].Daily_Rate__c);
        System.assertEquals('London', rates[1].Destination__c);
        System.assertEquals(50, rates[1].Meal_Rate__c);
        System.assertEquals('GBP', rates[1].Currency__c);
    }

    @isTest
    static void testCreateRateValidation() {
        Expense_Policy__c policy = getPolicy();

        Test.startTest();
        try {
            PerDiemService.createRate(null, 'London', 'Standard', 200, null, 'USD');
            System.assert(false, 'Should throw for missing policy');
        } catch (PerDiemService.PerDiemException e) {
            System.assert(e.getMessage().contains('Policy'));
        }

        try {
            PerDiemService.createRate(policy.Id, '', 'Standard', 200, null, 'USD');
            System.assert(false, 'Should throw for blank destination');
        } catch (PerDiemService.PerDiemException e) {
            System.assert(e.getMessage().contains('Destination'));
        }

        try {
            PerDiemService.createRate(policy.Id, 'London', 'Standard', -1, null, 'USD');
            System.assert(false, 'Should throw for negative rate');
        } catch (PerDiemService.PerDiemException e) {
            System.assert(e.getMessage().contains('Daily rate'));
        }
        Test.stopTest();
    }

    @isTest
    static void testUpdateRate() {
        Expense_Policy__c policy = getPolicy();
        Per_Diem_Rate__c rate = PerDiemService.createRate(policy.Id, 'Paris', 'Standard', 150, null, 'EUR');

        Test.startTest();
        PerDiemService.updateRate(rate.Id, 'Paris', 'Premium', 175, 40, 'EUR');
        Test.stopTest();

        Per_Diem_Rate__c saved = [
            SELECT Destination__c, Sub_Rate_Name__c, Daily_Rate__c, Meal_Rate__c, Currency__c
            FROM Per_Diem_Rate__c WHERE Id = :rate.Id
        ];
        System.assertEquals('Premium', saved.Sub_Rate_Name__c);
        System.assertEquals(175, saved.Daily_Rate__c);
        System.assertEquals(40, saved.Meal_Rate__c);
    }

    @isTest
    static void testUpdateRateValidation() {
        Test.startTest();
        try {
            PerDiemService.updateRate(null, 'Paris', 'Standard', 150, null, 'EUR');
            System.assert(false, 'Should throw for missing rate');
        } catch (PerDiemService.PerDiemException e) {
            System.assert(e.getMessage().contains('Rate'));
        }
        Test.stopTest();
    }

    @isTest
    static void testDeleteRate() {
        Expense_Policy__c policy = getPolicy();
        Per_Diem_Rate__c rate = PerDiemService.createRate(policy.Id, 'Tokyo', 'Standard', 300, null, 'JPY');

        Test.startTest();
        PerDiemService.deleteRate(rate.Id);
        Test.stopTest();

        System.assertEquals(0, PerDiemService.getRates(policy.Id).size());
    }

    @isTest
    static void testDeleteRateValidation() {
        Test.startTest();
        try {
            PerDiemService.deleteRate(null);
            System.assert(false, 'Should throw for missing rate');
        } catch (PerDiemService.PerDiemException e) {
            System.assert(e.getMessage().contains('Rate'));
        }
        Test.stopTest();
    }

    @isTest
    static void testGetRatesValidation() {
        Test.startTest();
        try {
            PerDiemService.getRates(null);
            System.assert(false, 'Should throw for missing policy');
        } catch (PerDiemService.PerDiemException e) {
            System.assert(e.getMessage().contains('Policy'));
        }
        Test.stopTest();
    }

    @isTest
    static void testCreatePerDiemExpenseAmount() {
        Expense_Policy__c policy = getPolicy();
        PerDiemService.createRate(policy.Id, 'Denver', 'Standard', 100, null, 'USD');

        Test.startTest();
        Expense__c expense = PerDiemService.createPerDiemExpense(policy.Id, 'Denver', 3, Date.today(), null);
        Test.stopTest();

        System.assertNotEquals(null, expense.Id);
        System.assertEquals(300, expense.Amount__c);
        System.assertEquals('Per_Diem', expense.Expense_Type__c);
        System.assertEquals('Denver', expense.Merchant__c);
        System.assertEquals('USD', expense.Currency__c);
    }

    @isTest
    static void testCreatePerDiemExpenseWithMeal() {
        Expense_Policy__c policy = getPolicy();
        PerDiemService.createRate(policy.Id, 'Seattle', 'Standard', 120, 30, 'USD');

        Test.startTest();
        Expense__c expense = PerDiemService.createPerDiemExpense(policy.Id, 'Seattle', 2, null, null);
        Test.stopTest();

        System.assertEquals(300, expense.Amount__c);
    }

    @isTest
    static void testCreatePerDiemMissingRateError() {
        Expense_Policy__c policy = getPolicy();

        Test.startTest();
        try {
            PerDiemService.createPerDiemExpense(policy.Id, 'Atlantis', 3, Date.today(), null);
            System.assert(false, 'Should throw when no rate exists');
        } catch (PerDiemService.PerDiemException e) {
            System.assert(e.getMessage().contains('No per diem rate'));
        }
        Test.stopTest();
    }

    @isTest
    static void testCreatePerDiemInvalidDays() {
        Expense_Policy__c policy = getPolicy();
        PerDiemService.createRate(policy.Id, 'Miami', 'Standard', 100, null, 'USD');

        Test.startTest();
        try {
            PerDiemService.createPerDiemExpense(policy.Id, 'Miami', 0, Date.today(), null);
            System.assert(false, 'Should throw for zero days');
        } catch (PerDiemService.PerDiemException e) {
            System.assert(e.getMessage().contains('Number of days'));
        }
        Test.stopTest();
    }

    @isTest
    static void testInvocableSuccess() {
        Expense_Policy__c policy = getPolicy();
        PerDiemService.createRate(policy.Id, 'Boston', 'Standard', 110, null, 'USD');

        InvocableCreatePerDiem.Request req = new InvocableCreatePerDiem.Request();
        req.policyId = policy.Id;
        req.destination = 'Boston';
        req.numberOfDays = 4;
        req.expenseDate = Date.today();

        Test.startTest();
        List<InvocableCreatePerDiem.Results> results = InvocableCreatePerDiem.execute(
            new List<InvocableCreatePerDiem.Request>{req}
        );
        Test.stopTest();

        System.assertEquals(true, results[0].isSuccess);
        System.assertEquals(440, results[0].amount);
        System.assertNotEquals(null, results[0].expenseId);
    }

    @isTest
    static void testInvocableError() {
        Expense_Policy__c policy = getPolicy();

        InvocableCreatePerDiem.Request req = new InvocableCreatePerDiem.Request();
        req.policyId = policy.Id;
        req.destination = 'Nowhere';
        req.numberOfDays = 2;

        Test.startTest();
        List<InvocableCreatePerDiem.Results> results = InvocableCreatePerDiem.execute(
            new List<InvocableCreatePerDiem.Request>{req}
        );
        Test.stopTest();

        System.assertEquals(false, results[0].isSuccess);
        System.assertNotEquals(null, results[0].errorMessage);
    }

    @isTest
    static void testAuraWrappers() {
        Expense_Policy__c policy = getPolicy();

        Test.startTest();
        Per_Diem_Rate__c rate = PerDiemService.addPerDiemRate(policy.Id, 'Lisbon', 'Standard', 90, 20, 'EUR');
        PerDiemService.updatePerDiemRate(rate.Id, 'Lisbon', 'Standard', 95, 20, 'EUR');
        List<Per_Diem_Rate__c> rates = PerDiemService.getPerDiemRates(policy.Id);
        Expense__c expense = PerDiemService.generatePerDiemExpense(policy.Id, 'Lisbon', 2, Date.today(), null);
        PerDiemService.removePerDiemRate(rate.Id);
        Test.stopTest();

        System.assertEquals(1, rates.size());
        System.assertEquals(230, expense.Amount__c);
        System.assertEquals(0, PerDiemService.getPerDiemRates(policy.Id).size());
    }
}
