public with sharing class TaxService {

    public class TaxException extends Exception {}

    @AuraEnabled(cacheable=true)
    public static List<Tax_Rate__c> getTaxRates(Id policyId) {
        if (!Schema.SObjectType.Tax_Rate__c.isAccessible()) {
            throw new TaxException('Insufficient access to read tax rates');
        }
        return [
            SELECT Id, Name, Rate_Percent__c, Code__c, Enabled__c, Policy__c
            FROM Tax_Rate__c
            WHERE Policy__c = :policyId
            ORDER BY Name
        ];
    }

    public static Tax_Rate__c createTaxRate(Tax_Rate__c taxRate) {
        validateTaxRate(taxRate);
        if (!Schema.SObjectType.Tax_Rate__c.isCreateable()) {
            throw new TaxException('Insufficient access to create tax rates');
        }
        insert taxRate;
        return taxRate;
    }

    public static Tax_Rate__c updateTaxRate(Tax_Rate__c taxRate) {
        if (taxRate.Id == null) {
            throw new TaxException('Tax rate Id is required for update');
        }
        validateTaxRate(taxRate);
        if (!Schema.SObjectType.Tax_Rate__c.isUpdateable()) {
            throw new TaxException('Insufficient access to update tax rates');
        }
        update taxRate;
        return taxRate;
    }

    public static void deleteTaxRate(Id taxRateId) {
        if (taxRateId == null) {
            throw new TaxException('Tax rate Id is required');
        }
        if (!Schema.SObjectType.Tax_Rate__c.isDeletable()) {
            throw new TaxException('Insufficient access to delete tax rates');
        }
        Tax_Rate__c rate = [SELECT Id FROM Tax_Rate__c WHERE Id = :taxRateId LIMIT 1];
        delete rate;
    }

    public static Expense__c computeTax(Id expenseId, Id taxRateId) {
        if (expenseId == null || taxRateId == null) {
            throw new TaxException('Expense and tax rate are required');
        }
        if (!Schema.SObjectType.Tax_Rate__c.isAccessible()) {
            throw new TaxException('Insufficient access to read tax rates');
        }
        Tax_Rate__c rate = [
            SELECT Id, Rate_Percent__c, Enabled__c
            FROM Tax_Rate__c
            WHERE Id = :taxRateId
            LIMIT 1
        ];
        if (!rate.Enabled__c) {
            throw new TaxException('Tax rate is disabled and cannot be applied');
        }
        if (!Schema.SObjectType.Expense__c.isAccessible() || !Schema.SObjectType.Expense__c.isUpdateable()) {
            throw new TaxException('Insufficient access to update expenses');
        }
        Expense__c expense = [
            SELECT Id, Amount__c
            FROM Expense__c
            WHERE Id = :expenseId
            LIMIT 1
        ];
        Decimal ratePercent = rate.Rate_Percent__c != null ? rate.Rate_Percent__c : 0;
        Decimal amount = expense.Amount__c != null ? expense.Amount__c : 0;
        expense.Tax_Rate__c = ratePercent;
        expense.Tax_Amount__c = (amount * ratePercent / 100).setScale(2, System.RoundingMode.HALF_UP);
        update expense;
        return expense;
    }

    @AuraEnabled
    public static Tax_Rate__c saveTaxRate(Id recordId, Id policyId, String name, Decimal ratePercent, String code, Boolean enabled) {
        try {
            Tax_Rate__c rate = new Tax_Rate__c(
                Policy__c = policyId,
                Name = name,
                Rate_Percent__c = ratePercent,
                Code__c = code,
                Enabled__c = enabled == null ? true : enabled
            );
            if (recordId != null) {
                rate.Id = recordId;
                return updateTaxRate(rate);
            }
            return createTaxRate(rate);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void removeTaxRate(Id taxRateId) {
        try {
            deleteTaxRate(taxRateId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Id applyTax(Id expenseId, Id taxRateId) {
        try {
            Expense__c expense = computeTax(expenseId, taxRateId);
            return expense.Id;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static void validateTaxRate(Tax_Rate__c taxRate) {
        if (taxRate.Policy__c == null) {
            throw new TaxException('Policy is required');
        }
        if (String.isBlank(taxRate.Name)) {
            throw new TaxException('Tax rate name is required');
        }
        if (taxRate.Rate_Percent__c == null) {
            throw new TaxException('Rate percent is required');
        }
        if (taxRate.Rate_Percent__c < 0 || taxRate.Rate_Percent__c > 100) {
            throw new TaxException('Rate percent must be between 0 and 100');
        }
    }
}
