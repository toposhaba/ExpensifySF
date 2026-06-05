public with sharing class PerDiemService {

    public class PerDiemException extends Exception {}

    public static List<Per_Diem_Rate__c> getRates(Id policyId) {
        if (policyId == null) {
            throw new PerDiemException('Policy is required');
        }
        return [
            SELECT Id, Name, Destination__c, Sub_Rate_Name__c, Daily_Rate__c,
                   Meal_Rate__c, Currency__c, Policy__c
            FROM Per_Diem_Rate__c
            WHERE Policy__c = :policyId
            WITH USER_MODE
            ORDER BY Destination__c ASC, Sub_Rate_Name__c ASC NULLS FIRST
        ];
    }

    public static Per_Diem_Rate__c createRate(
        Id policyId,
        String destination,
        String subRateName,
        Decimal dailyRate,
        Decimal mealRate,
        String currencyCode
    ) {
        if (policyId == null) {
            throw new PerDiemException('Policy is required');
        }
        if (String.isBlank(destination)) {
            throw new PerDiemException('Destination is required');
        }
        if (dailyRate == null || dailyRate < 0) {
            throw new PerDiemException('Daily rate must be zero or greater');
        }

        Per_Diem_Rate__c rate = new Per_Diem_Rate__c(
            Name = buildRateName(destination, subRateName),
            Policy__c = policyId,
            Destination__c = destination,
            Sub_Rate_Name__c = subRateName,
            Daily_Rate__c = dailyRate,
            Meal_Rate__c = mealRate,
            Currency__c = String.isBlank(currencyCode) ? 'USD' : currencyCode
        );
        insert as user rate;
        return rate;
    }

    public static Per_Diem_Rate__c updateRate(
        Id rateId,
        String destination,
        String subRateName,
        Decimal dailyRate,
        Decimal mealRate,
        String currencyCode
    ) {
        if (rateId == null) {
            throw new PerDiemException('Rate is required');
        }
        if (String.isBlank(destination)) {
            throw new PerDiemException('Destination is required');
        }
        if (dailyRate == null || dailyRate < 0) {
            throw new PerDiemException('Daily rate must be zero or greater');
        }

        Per_Diem_Rate__c rate = new Per_Diem_Rate__c(
            Id = rateId,
            Name = buildRateName(destination, subRateName),
            Destination__c = destination,
            Sub_Rate_Name__c = subRateName,
            Daily_Rate__c = dailyRate,
            Meal_Rate__c = mealRate,
            Currency__c = String.isBlank(currencyCode) ? 'USD' : currencyCode
        );
        update as user rate;
        return rate;
    }

    public static void deleteRate(Id rateId) {
        if (rateId == null) {
            throw new PerDiemException('Rate is required');
        }
        List<Per_Diem_Rate__c> rates = [
            SELECT Id
            FROM Per_Diem_Rate__c
            WHERE Id = :rateId
            WITH USER_MODE
            LIMIT 1
        ];
        if (rates.isEmpty()) {
            throw new PerDiemException('Rate not found');
        }
        delete as user rates;
    }

    public static Per_Diem_Rate__c getRateForDestination(Id policyId, String destination) {
        if (policyId == null) {
            throw new PerDiemException('Policy is required');
        }
        if (String.isBlank(destination)) {
            throw new PerDiemException('Destination is required');
        }
        List<Per_Diem_Rate__c> rates = [
            SELECT Id, Destination__c, Sub_Rate_Name__c, Daily_Rate__c, Meal_Rate__c, Currency__c
            FROM Per_Diem_Rate__c
            WHERE Policy__c = :policyId AND Destination__c = :destination
            WITH USER_MODE
            ORDER BY Sub_Rate_Name__c ASC NULLS FIRST
            LIMIT 1
        ];
        if (rates.isEmpty()) {
            throw new PerDiemException('No per diem rate found for destination ' + destination);
        }
        return rates[0];
    }

    public static Expense__c createPerDiemExpense(
        Id policyId,
        String destination,
        Integer numberOfDays,
        Date expenseDate,
        Id reportId
    ) {
        if (numberOfDays == null || numberOfDays <= 0) {
            throw new PerDiemException('Number of days must be greater than zero');
        }

        Per_Diem_Rate__c rate = getRateForDestination(policyId, destination);

        Decimal dailyTotal = rate.Daily_Rate__c == null ? 0 : rate.Daily_Rate__c;
        if (rate.Meal_Rate__c != null) {
            dailyTotal += rate.Meal_Rate__c;
        }
        Decimal amount = dailyTotal * numberOfDays;

        Expense__c expense = new Expense__c(
            Amount__c = amount,
            Currency__c = String.isBlank(rate.Currency__c) ? 'USD' : rate.Currency__c,
            Merchant__c = destination,
            Expense_Date__c = expenseDate == null ? Date.today() : expenseDate,
            Expense_Type__c = 'Per_Diem',
            Policy__c = policyId,
            Report__c = reportId,
            Reimbursable__c = true,
            Description__c = numberOfDays + ' day(s) per diem - ' +
                (String.isBlank(rate.Sub_Rate_Name__c) ? destination : rate.Sub_Rate_Name__c)
        );
        return ExpenseService.createExpense(expense);
    }

    private static String buildRateName(String destination, String subRateName) {
        String baseName = String.isBlank(subRateName) ? destination : destination + ' - ' + subRateName;
        if (baseName.length() > 80) {
            return baseName.substring(0, 80);
        }
        return baseName;
    }

    @AuraEnabled(cacheable=true)
    public static List<Per_Diem_Rate__c> getPerDiemRates(Id policyId) {
        return getRates(policyId);
    }

    @AuraEnabled
    public static Per_Diem_Rate__c addPerDiemRate(
        Id policyId,
        String destination,
        String subRateName,
        Decimal dailyRate,
        Decimal mealRate,
        String currencyCode
    ) {
        return createRate(policyId, destination, subRateName, dailyRate, mealRate, currencyCode);
    }

    @AuraEnabled
    public static Per_Diem_Rate__c updatePerDiemRate(
        Id rateId,
        String destination,
        String subRateName,
        Decimal dailyRate,
        Decimal mealRate,
        String currencyCode
    ) {
        return updateRate(rateId, destination, subRateName, dailyRate, mealRate, currencyCode);
    }

    @AuraEnabled
    public static void removePerDiemRate(Id rateId) {
        deleteRate(rateId);
    }

    @AuraEnabled
    public static Expense__c generatePerDiemExpense(
        Id policyId,
        String destination,
        Integer numberOfDays,
        Date expenseDate,
        Id reportId
    ) {
        return createPerDiemExpense(policyId, destination, numberOfDays, expenseDate, reportId);
    }
}
