public with sharing class CurrencyConversionService {

    public static Decimal convert(Decimal amount, String fromCurrency, String toCurrency) {
        if (fromCurrency == toCurrency) return amount;

        List<Currency_Rate__c> rates = [
            SELECT Rate__c FROM Currency_Rate__c
            WHERE From_Currency__c = :fromCurrency AND To_Currency__c = :toCurrency
            AND Effective_Date__c <= TODAY
            ORDER BY Effective_Date__c DESC LIMIT 1
        ];

        if (rates.isEmpty()) {
            List<Currency_Rate__c> inverse = [
                SELECT Rate__c FROM Currency_Rate__c
                WHERE From_Currency__c = :toCurrency AND To_Currency__c = :fromCurrency
                AND Effective_Date__c <= TODAY
                ORDER BY Effective_Date__c DESC LIMIT 1
            ];
            if (inverse.isEmpty()) {
                throw new CurrencyException('No exchange rate found for ' + fromCurrency + ' to ' + toCurrency);
            }
            return (amount / inverse[0].Rate__c).setScale(2, RoundingMode.HALF_UP);
        }

        return (amount * rates[0].Rate__c).setScale(2, RoundingMode.HALF_UP);
    }

    public static void upsertRate(String fromCurrency, String toCurrency, Decimal rate, Date effectiveDate) {
        List<Currency_Rate__c> existing = [
            SELECT Id FROM Currency_Rate__c
            WHERE From_Currency__c = :fromCurrency AND To_Currency__c = :toCurrency
            AND Effective_Date__c = :effectiveDate LIMIT 1
        ];

        Currency_Rate__c cr;
        if (!existing.isEmpty()) {
            cr = new Currency_Rate__c(Id = existing[0].Id, Rate__c = rate);
        } else {
            cr = new Currency_Rate__c(
                From_Currency__c = fromCurrency,
                To_Currency__c = toCurrency,
                Rate__c = rate,
                Effective_Date__c = effectiveDate
            );
        }
        upsert cr;
    }

    public static Decimal getRate(String fromCurrency, String toCurrency) {
        if (fromCurrency == toCurrency) return 1.0;

        List<Currency_Rate__c> rates = [
            SELECT Rate__c FROM Currency_Rate__c
            WHERE From_Currency__c = :fromCurrency AND To_Currency__c = :toCurrency
            AND Effective_Date__c <= TODAY
            ORDER BY Effective_Date__c DESC LIMIT 1
        ];
        return rates.isEmpty() ? null : rates[0].Rate__c;
    }

    public class CurrencyException extends Exception {}
}
