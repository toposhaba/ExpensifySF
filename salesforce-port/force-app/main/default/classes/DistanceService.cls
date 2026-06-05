public with sharing class DistanceService {

    public class DistanceException extends Exception {}

    private static final Decimal KM_PER_MILE = 1.609344;
    private static final String UNIT_MILES = 'mi';
    private static final String UNIT_KILOMETERS = 'km';
    private static final String DISTANCE_EXPENSE_TYPE = 'Distance';

    public class DistanceQuote {
        @AuraEnabled public Decimal distance;
        @AuraEnabled public String unit;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public Decimal ratePerUnit;
        @AuraEnabled public String rateUnit;
        @AuraEnabled public String currencyCode;
        @AuraEnabled public String rateName;
        @AuraEnabled public Id rateId;
    }

    public static Distance_Rate__c resolveRate(Id policyId, String unit) {
        if (policyId == null) {
            throw new DistanceException('Policy is required to resolve a distance rate');
        }
        if (!Schema.SObjectType.Distance_Rate__c.isAccessible()) {
            throw new DistanceException('Insufficient access to read distance rates');
        }

        List<Distance_Rate__c> rates = [
            SELECT Id, Name, Rate_Per_Unit__c, Unit__c, Currency__c, Policy__c
            FROM Distance_Rate__c
            WHERE Policy__c = :policyId
            ORDER BY CreatedDate ASC
        ];

        if (rates.isEmpty()) {
            throw new DistanceException('No distance rate is configured for this policy');
        }

        if (String.isNotBlank(unit)) {
            for (Distance_Rate__c rate : rates) {
                if (rate.Unit__c == unit) {
                    return rate;
                }
            }
        }

        return rates[0];
    }

    public static Decimal convertDistance(Decimal distance, String fromUnit, String toUnit) {
        if (distance == null) {
            return null;
        }
        if (fromUnit == toUnit || String.isBlank(fromUnit) || String.isBlank(toUnit)) {
            return distance;
        }
        if (fromUnit == UNIT_MILES && toUnit == UNIT_KILOMETERS) {
            return distance * KM_PER_MILE;
        }
        if (fromUnit == UNIT_KILOMETERS && toUnit == UNIT_MILES) {
            return distance / KM_PER_MILE;
        }
        return distance;
    }

    public static Decimal computeAmount(Decimal distance, String unit, Distance_Rate__c rate) {
        if (distance == null || distance <= 0) {
            throw new DistanceException('Distance must be greater than zero');
        }
        if (rate == null || rate.Rate_Per_Unit__c == null) {
            throw new DistanceException('A valid distance rate is required');
        }
        Decimal convertedDistance = convertDistance(distance, unit, rate.Unit__c).setScale(2, System.RoundingMode.HALF_UP);
        return (convertedDistance * rate.Rate_Per_Unit__c).setScale(2, System.RoundingMode.HALF_UP);
    }

    public static DistanceQuote quote(Id policyId, Decimal distance, String unit) {
        Distance_Rate__c rate = resolveRate(policyId, unit);
        DistanceQuote result = new DistanceQuote();
        result.distance = distance;
        result.unit = String.isNotBlank(unit) ? unit : rate.Unit__c;
        result.amount = computeAmount(distance, unit, rate);
        result.ratePerUnit = rate.Rate_Per_Unit__c;
        result.rateUnit = rate.Unit__c;
        result.currencyCode = rate.Currency__c;
        result.rateName = rate.Name;
        result.rateId = rate.Id;
        return result;
    }

    public static Expense__c createDistanceExpense(
        Id policyId,
        Decimal distance,
        String unit,
        Date expenseDate,
        String merchant,
        String description,
        Id reportId
    ) {
        if (!Schema.SObjectType.Expense__c.isCreateable()) {
            throw new DistanceException('Insufficient access to create expenses');
        }

        Distance_Rate__c rate = resolveRate(policyId, unit);
        Decimal amount = computeAmount(distance, unit, rate);
        String resolvedUnit = String.isNotBlank(unit) ? unit : rate.Unit__c;

        Expense__c expense = new Expense__c(
            Amount__c = amount,
            Currency__c = rate.Currency__c,
            Expense_Date__c = expenseDate != null ? expenseDate : Date.today(),
            Merchant__c = merchant,
            Description__c = description,
            Expense_Type__c = DISTANCE_EXPENSE_TYPE,
            Distance__c = distance,
            Distance_Unit__c = resolvedUnit,
            Policy__c = policyId,
            Report__c = reportId,
            Reimbursable__c = true,
            Billable__c = false,
            Has_Receipt__c = false
        );

        return ExpenseService.createExpense(expense);
    }

    @AuraEnabled(cacheable=true)
    public static DistanceQuote previewAmount(Id policyId, Decimal distance, String unit) {
        try {
            return quote(policyId, distance, unit);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Id createExpenseFromDistance(Id policyId, Decimal distance, String unit, Date expenseDate, String merchant, String description) {
        try {
            Expense__c expense = createDistanceExpense(policyId, distance, unit, expenseDate, merchant, description, null);
            return expense.Id;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
