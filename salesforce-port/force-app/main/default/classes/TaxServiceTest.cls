@isTest
private class TaxServiceTest {

    @TestSetup
    static void setupTestData() {
        Expense_Policy__c policy = new Expense_Policy__c(
            Name = 'Tax Policy',
            Currency__c = 'USD',
            Type__c = 'Corporate',
            Approval_Mode__c = 'Basic'
        );
        insert policy;

        Tax_Rate__c rate = new Tax_Rate__c(
            Name = 'GST',
            Policy__c = policy.Id,
            Rate_Percent__c = 10,
            Code__c = 'GST10',
            Enabled__c = true
        );
        insert rate;
    }

    private static Expense_Policy__c getPolicy() {
        return [SELECT Id FROM Expense_Policy__c LIMIT 1];
    }

    private static Expense__c buildExpense(Decimal amount) {
        return new Expense__c(
            Amount__c = amount,
            Currency__c = 'USD',
            Merchant__c = 'Vendor',
            Expense_Date__c = Date.today(),
            Expense_Type__c = 'Cash',
            Status__c = 'Draft',
            Reimbursable__c = true,
            Has_Receipt__c = false
        );
    }

    @isTest
    static void testCreateTaxRate() {
        Expense_Policy__c policy = getPolicy();

        Test.startTest();
        Tax_Rate__c created = TaxService.createTaxRate(new Tax_Rate__c(
            Name = 'VAT',
            Policy__c = policy.Id,
            Rate_Percent__c = 20,
            Code__c = 'VAT20',
            Enabled__c = true
        ));
        Test.stopTest();

        System.assertNotEquals(null, created.Id, 'Tax rate should be inserted');
        Tax_Rate__c saved = [SELECT Name, Rate_Percent__c, Code__c, Enabled__c FROM Tax_Rate__c WHERE Id = :created.Id];
        System.assertEquals('VAT', saved.Name, 'Name should be persisted');
        System.assertEquals(20, saved.Rate_Percent__c, 'Rate should be persisted');
        System.assertEquals('VAT20', saved.Code__c, 'Code should be persisted');
        System.assertEquals(true, saved.Enabled__c, 'Enabled should be persisted');
    }

    @isTest
    static void testGetTaxRates() {
        Expense_Policy__c policy = getPolicy();

        Test.startTest();
        List<Tax_Rate__c> rates = TaxService.getTaxRates(policy.Id);
        Test.stopTest();

        System.assertEquals(1, rates.size(), 'Should return the seeded tax rate for the policy');
        System.assertEquals('GST', rates[0].Name, 'Seeded rate should be returned');
    }

    @isTest
    static void testUpdateTaxRate() {
        Tax_Rate__c rate = [SELECT Id, Name, Policy__c, Rate_Percent__c FROM Tax_Rate__c LIMIT 1];
        rate.Rate_Percent__c = 15;
        rate.Name = 'GST Updated';

        Test.startTest();
        TaxService.updateTaxRate(rate);
        Test.stopTest();

        Tax_Rate__c saved = [SELECT Name, Rate_Percent__c FROM Tax_Rate__c WHERE Id = :rate.Id];
        System.assertEquals(15, saved.Rate_Percent__c, 'Rate should be updated');
        System.assertEquals('GST Updated', saved.Name, 'Name should be updated');
    }

    @isTest
    static void testDeleteTaxRate() {
        Tax_Rate__c rate = [SELECT Id FROM Tax_Rate__c LIMIT 1];

        Test.startTest();
        TaxService.deleteTaxRate(rate.Id);
        Test.stopTest();

        List<Tax_Rate__c> remaining = [SELECT Id FROM Tax_Rate__c WHERE Id = :rate.Id];
        System.assert(remaining.isEmpty(), 'Tax rate should be deleted');
    }

    @isTest
    static void testValidationRejectsInvalidRate() {
        Expense_Policy__c policy = getPolicy();

        Test.startTest();
        try {
            TaxService.createTaxRate(new Tax_Rate__c(
                Name = 'Bad',
                Policy__c = policy.Id,
                Rate_Percent__c = 150,
                Enabled__c = true
            ));
            System.assert(false, 'Should have thrown for out of range rate');
        } catch (TaxService.TaxException e) {
            System.assert(e.getMessage().contains('between 0 and 100'), 'Expected range validation error');
        }
        Test.stopTest();
    }

    @isTest
    static void testValidationRejectsMissingPolicy() {
        Test.startTest();
        try {
            TaxService.createTaxRate(new Tax_Rate__c(Name = 'NoPolicy', Rate_Percent__c = 5));
            System.assert(false, 'Should have thrown for missing policy');
        } catch (TaxService.TaxException e) {
            System.assert(e.getMessage().contains('Policy is required'), 'Expected policy validation error');
        }
        Test.stopTest();
    }

    @isTest
    static void testComputeTax() {
        Tax_Rate__c rate = [SELECT Id, Rate_Percent__c FROM Tax_Rate__c LIMIT 1];
        Expense__c expense = buildExpense(200.00);
        insert expense;

        Test.startTest();
        Expense__c result = TaxService.computeTax(expense.Id, rate.Id);
        Test.stopTest();

        Expense__c saved = [SELECT Tax_Amount__c, Tax_Rate__c FROM Expense__c WHERE Id = :expense.Id];
        System.assertEquals(20.00, saved.Tax_Amount__c, 'Tax amount should be 10% of 200');
        System.assertEquals(10, saved.Tax_Rate__c, 'Tax rate percent should be stored on the expense');
        System.assertEquals(expense.Id, result.Id, 'Computed expense should be returned');
    }

    @isTest
    static void testComputeTaxDisabledRateGuard() {
        Expense_Policy__c policy = getPolicy();
        Tax_Rate__c disabledRate = new Tax_Rate__c(
            Name = 'Disabled',
            Policy__c = policy.Id,
            Rate_Percent__c = 5,
            Code__c = 'DIS5',
            Enabled__c = false
        );
        insert disabledRate;

        Expense__c expense = buildExpense(100.00);
        insert expense;

        Test.startTest();
        try {
            TaxService.computeTax(expense.Id, disabledRate.Id);
            System.assert(false, 'Should have thrown for disabled tax rate');
        } catch (TaxService.TaxException e) {
            System.assert(e.getMessage().contains('disabled'), 'Expected disabled rate guard error');
        }
        Test.stopTest();

        Expense__c saved = [SELECT Tax_Amount__c FROM Expense__c WHERE Id = :expense.Id];
        System.assertEquals(null, saved.Tax_Amount__c, 'Tax amount should remain unset for disabled rate');
    }

    @isTest
    static void testComputeTaxRequiresIds() {
        Test.startTest();
        try {
            TaxService.computeTax(null, null);
            System.assert(false, 'Should have thrown for null ids');
        } catch (TaxService.TaxException e) {
            System.assert(e.getMessage().contains('required'), 'Expected required ids error');
        }
        Test.stopTest();
    }

    @isTest
    static void testSaveTaxRateWrapperCreatesAndUpdates() {
        Expense_Policy__c policy = getPolicy();

        Test.startTest();
        Tax_Rate__c created = TaxService.saveTaxRate(null, policy.Id, 'Sales Tax', 8, 'ST8', true);
        Tax_Rate__c updated = TaxService.saveTaxRate(created.Id, policy.Id, 'Sales Tax', 9, 'ST9', false);
        Test.stopTest();

        System.assertNotEquals(null, created.Id, 'Wrapper should create a tax rate');
        Tax_Rate__c saved = [SELECT Rate_Percent__c, Code__c, Enabled__c FROM Tax_Rate__c WHERE Id = :updated.Id];
        System.assertEquals(9, saved.Rate_Percent__c, 'Wrapper should update rate percent');
        System.assertEquals('ST9', saved.Code__c, 'Wrapper should update code');
        System.assertEquals(false, saved.Enabled__c, 'Wrapper should update enabled flag');
    }

    @isTest
    static void testRemoveTaxRateWrapper() {
        Tax_Rate__c rate = [SELECT Id FROM Tax_Rate__c LIMIT 1];

        Test.startTest();
        TaxService.removeTaxRate(rate.Id);
        Test.stopTest();

        List<Tax_Rate__c> remaining = [SELECT Id FROM Tax_Rate__c WHERE Id = :rate.Id];
        System.assert(remaining.isEmpty(), 'Wrapper should delete the tax rate');
    }

    @isTest
    static void testApplyTaxWrapper() {
        Tax_Rate__c rate = [SELECT Id FROM Tax_Rate__c LIMIT 1];
        Expense__c expense = buildExpense(50.00);
        insert expense;

        Test.startTest();
        Id expenseId = TaxService.applyTax(expense.Id, rate.Id);
        Test.stopTest();

        System.assertEquals(expense.Id, expenseId, 'Wrapper should return the expense id');
        Expense__c saved = [SELECT Tax_Amount__c FROM Expense__c WHERE Id = :expense.Id];
        System.assertEquals(5.00, saved.Tax_Amount__c, 'Tax amount should be 10% of 50');
    }

    @isTest
    static void testApplyTaxWrapperHandlesError() {
        Test.startTest();
        try {
            TaxService.applyTax(null, null);
            System.assert(false, 'Should have thrown via AuraHandledException');
        } catch (Exception e) {
            System.assert(true, 'Wrapper surfaced the error');
        }
        Test.stopTest();
    }

    @isTest
    static void testInvocableApplyTax() {
        Tax_Rate__c rate = [SELECT Id FROM Tax_Rate__c LIMIT 1];
        Expense__c expense = buildExpense(300.00);
        insert expense;

        InvocableApplyTax.Request req = new InvocableApplyTax.Request();
        req.expenseId = expense.Id;
        req.taxRateId = rate.Id;

        Test.startTest();
        List<InvocableApplyTax.Results> results = InvocableApplyTax.execute(
            new List<InvocableApplyTax.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(true, results[0].isSuccess, 'Apply tax should succeed');
        System.assertEquals(30.00, results[0].taxAmount, 'Tax amount should be 10% of 300');
        System.assertEquals(10, results[0].taxRate, 'Tax rate should be returned');
    }

    @isTest
    static void testInvocableApplyTaxReportsFailure() {
        Expense__c expense = buildExpense(100.00);
        insert expense;

        InvocableApplyTax.Request req = new InvocableApplyTax.Request();
        req.expenseId = expense.Id;
        req.taxRateId = null;

        Test.startTest();
        List<InvocableApplyTax.Results> results = InvocableApplyTax.execute(
            new List<InvocableApplyTax.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(false, results[0].isSuccess, 'Missing tax rate should fail');
        System.assertNotEquals(null, results[0].errorMessage, 'Error message should be populated');
    }
}
