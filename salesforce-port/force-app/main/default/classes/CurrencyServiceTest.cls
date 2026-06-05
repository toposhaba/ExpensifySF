@isTest
private class CurrencyServiceTest {

    private static void setRates() {
        CurrencyService.rateOverride = new Map<String, Decimal>{
            'USD->EUR' => 0.900000,
            'EUR->USD' => 1.111111,
            'GBP->USD' => 1.250000
        };
    }

    @isTest
    static void testConvertMath() {
        setRates();
        Test.startTest();
        Decimal result = CurrencyService.convert(100, 'USD', 'EUR');
        Test.stopTest();
        System.assertEquals(90.000000, result, 'USD to EUR should multiply by rate');
    }

    @isTest
    static void testConvertCaseAndTrim() {
        setRates();
        Test.startTest();
        Decimal result = CurrencyService.convert(10, ' gbp ', 'usd');
        Test.stopTest();
        System.assertEquals(12.500000, result, 'Lookup should be case and whitespace insensitive');
    }

    @isTest
    static void testSameCurrencyPassthrough() {
        setRates();
        Test.startTest();
        Decimal result = CurrencyService.convert(42.50, 'USD', 'USD');
        Test.stopTest();
        System.assertEquals(42.50, result, 'Same currency should return original amount');
    }

    @isTest
    static void testMissingRateThrows() {
        setRates();
        Test.startTest();
        try {
            CurrencyService.convert(100, 'USD', 'JPY');
            System.assert(false, 'Should throw for missing rate');
        } catch (CurrencyService.CurrencyException e) {
            System.assert(e.getMessage().contains('No conversion rate found'), e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testConvertNullAmount() {
        setRates();
        Test.startTest();
        try {
            CurrencyService.convert(null, 'USD', 'EUR');
            System.assert(false, 'Should throw for null amount');
        } catch (CurrencyService.CurrencyException e) {
            System.assert(e.getMessage().contains('Amount is required'), e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testConvertBlankCurrency() {
        setRates();
        Test.startTest();
        try {
            CurrencyService.convert(100, '', 'EUR');
            System.assert(false, 'Should throw for blank currency');
        } catch (CurrencyService.CurrencyException e) {
            System.assert(e.getMessage().contains('required'), e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testSetConvertedAmount() {
        setRates();
        Expense__c expense = new Expense__c(
            Amount__c = 200,
            Currency__c = 'USD',
            Expense_Date__c = Date.today(),
            Expense_Type__c = 'Cash'
        );
        insert expense;

        Test.startTest();
        CurrencyService.setConvertedAmount(expense.Id, 'EUR');
        Test.stopTest();

        Expense__c updated = [
            SELECT Converted_Amount__c, Base_Currency__c FROM Expense__c WHERE Id = :expense.Id
        ];
        System.assertEquals(180.00, updated.Converted_Amount__c, 'Converted amount should be rounded to 2 decimals');
        System.assertEquals('EUR', updated.Base_Currency__c, 'Base currency should be stored');
    }

    @isTest
    static void testSetConvertedAmountMissingId() {
        Test.startTest();
        try {
            CurrencyService.setConvertedAmount(null, 'EUR');
            System.assert(false, 'Should throw for null expense id');
        } catch (CurrencyService.CurrencyException e) {
            System.assert(e.getMessage().contains('Expense Id is required'), e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testSetConvertedAmountBlankBase() {
        Expense__c expense = new Expense__c(
            Amount__c = 50,
            Currency__c = 'USD',
            Expense_Date__c = Date.today(),
            Expense_Type__c = 'Cash'
        );
        insert expense;

        Test.startTest();
        try {
            CurrencyService.setConvertedAmount(expense.Id, '   ');
            System.assert(false, 'Should throw for blank base currency');
        } catch (CurrencyService.CurrencyException e) {
            System.assert(e.getMessage().contains('Base currency is required'), e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testInvocableConvertAmount() {
        setRates();
        InvocableConvertCurrency.Request req = new InvocableConvertCurrency.Request();
        req.amount = 100;
        req.fromCurrency = 'USD';
        req.toCurrency = 'EUR';

        Test.startTest();
        List<InvocableConvertCurrency.Results> results = InvocableConvertCurrency.execute(
            new List<InvocableConvertCurrency.Request>{req}
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(true, results[0].isSuccess);
        System.assertEquals(90.000000, results[0].convertedAmount);
    }

    @isTest
    static void testInvocableSetOnExpense() {
        setRates();
        Expense__c expense = new Expense__c(
            Amount__c = 100,
            Currency__c = 'USD',
            Expense_Date__c = Date.today(),
            Expense_Type__c = 'Cash'
        );
        insert expense;

        InvocableConvertCurrency.Request req = new InvocableConvertCurrency.Request();
        req.expenseId = expense.Id;
        req.toCurrency = 'EUR';

        Test.startTest();
        List<InvocableConvertCurrency.Results> results = InvocableConvertCurrency.execute(
            new List<InvocableConvertCurrency.Request>{req}
        );
        Test.stopTest();

        System.assertEquals(true, results[0].isSuccess);
        System.assertEquals(expense.Id, results[0].expenseId);
        System.assertEquals(90.00, results[0].convertedAmount);
    }

    @isTest
    static void testInvocableError() {
        setRates();
        InvocableConvertCurrency.Request req = new InvocableConvertCurrency.Request();
        req.amount = 100;
        req.fromCurrency = 'USD';
        req.toCurrency = 'JPY';

        Test.startTest();
        List<InvocableConvertCurrency.Results> results = InvocableConvertCurrency.execute(
            new List<InvocableConvertCurrency.Request>{req}
        );
        Test.stopTest();

        System.assertEquals(false, results[0].isSuccess);
        System.assertNotEquals(null, results[0].errorMessage);
    }

    @isTest
    static void testGetRateFromCmdt() {
        Test.startTest();
        Decimal rate = CurrencyService.getRate('XXX', 'YYY');
        Test.stopTest();
        System.assertEquals(null, rate, 'Unknown pair should return null from CMDT');
    }
}
