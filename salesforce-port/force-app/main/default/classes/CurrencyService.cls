public with sharing class CurrencyService {

    public class CurrencyException extends Exception {}

    @TestVisible
    private static Map<String, Decimal> rateOverride;

    public static Decimal convert(Decimal amount, String fromCurrency, String toCurrency) {
        if (amount == null) {
            throw new CurrencyException('Amount is required');
        }
        if (String.isBlank(fromCurrency) || String.isBlank(toCurrency)) {
            throw new CurrencyException('Both source and target currencies are required');
        }

        String fromCode = fromCurrency.trim().toUpperCase();
        String toCode = toCurrency.trim().toUpperCase();

        if (fromCode == toCode) {
            return amount;
        }

        Decimal rate = getRate(fromCode, toCode);
        if (rate == null) {
            throw new CurrencyException('No conversion rate found for ' + fromCode + ' to ' + toCode);
        }

        return amount * rate;
    }

    public static Expense__c setConvertedAmount(Id expenseId, String baseCurrency) {
        if (expenseId == null) {
            throw new CurrencyException('Expense Id is required');
        }
        if (String.isBlank(baseCurrency)) {
            throw new CurrencyException('Base currency is required');
        }

        String baseCode = baseCurrency.trim().toUpperCase();

        if (!Schema.SObjectType.Expense__c.isAccessible()
            || !Schema.SObjectType.Expense__c.fields.Amount__c.isAccessible()
            || !Schema.SObjectType.Expense__c.fields.Currency__c.isAccessible()) {
            throw new CurrencyException('Insufficient access to read expense currency fields');
        }

        List<Expense__c> expenses = [
            SELECT Id, Amount__c, Currency__c
            FROM Expense__c
            WHERE Id = :expenseId
            LIMIT 1
        ];
        if (expenses.isEmpty()) {
            throw new CurrencyException('Expense not found');
        }

        Expense__c expense = expenses[0];
        Decimal converted = convert(expense.Amount__c, expense.Currency__c, baseCode);

        if (!Schema.SObjectType.Expense__c.fields.Converted_Amount__c.isUpdateable()
            || !Schema.SObjectType.Expense__c.fields.Base_Currency__c.isUpdateable()) {
            throw new CurrencyException('Insufficient access to update converted amount fields');
        }

        Expense__c toUpdate = new Expense__c(
            Id = expenseId,
            Converted_Amount__c = converted.setScale(2, System.RoundingMode.HALF_UP),
            Base_Currency__c = baseCode
        );
        update toUpdate;
        return toUpdate;
    }

    @TestVisible
    private static Decimal getRate(String fromCode, String toCode) {
        if (rateOverride != null) {
            String key = fromCode + '->' + toCode;
            return rateOverride.containsKey(key) ? rateOverride.get(key) : null;
        }
        List<Currency_Rate__mdt> rates = [
            SELECT Rate__c
            FROM Currency_Rate__mdt
            WHERE From_Currency__c = :fromCode AND To_Currency__c = :toCode
            LIMIT 1
        ];
        return rates.isEmpty() ? null : rates[0].Rate__c;
    }
}
