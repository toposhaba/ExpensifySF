public with sharing class DistanceExpenseService {

    public static Expense__c createDistanceExpense(Id policyId, Id reportId, Decimal distance, String unit) {
        List<Distance_Rate__c> rates = [
            SELECT Rate_Per_Unit__c, Currency__c FROM Distance_Rate__c
            WHERE Policy__c = :policyId AND Unit__c = :unit LIMIT 1
        ];

        if (rates.isEmpty()) {
            throw new DistanceException('No distance rate configured for unit: ' + unit);
        }

        Decimal amount = (distance * rates[0].Rate_Per_Unit__c).setScale(2, RoundingMode.HALF_UP);

        Expense__c expense = new Expense__c(
            Amount__c = amount,
            Currency__c = rates[0].Currency__c,
            Merchant__c = distance + ' ' + (unit == 'mi' ? 'miles' : 'km'),
            Expense_Date__c = Date.today(),
            Expense_Type__c = 'Distance',
            Status__c = 'Draft',
            Policy__c = policyId,
            Report__c = reportId,
            Distance__c = distance,
            Distance_Unit__c = unit,
            Reimbursable__c = true,
            Description__c = 'Distance: ' + distance + ' ' + unit + ' @ ' + rates[0].Rate_Per_Unit__c + '/' + unit
        );

        return ExpenseService.createExpense(expense);
    }

    public static void addWaypoint(Id expenseId, Decimal latitude, Decimal longitude, String address, Integer sequence) {
        Waypoint__c wp = new Waypoint__c(
            Expense__c = expenseId,
            Latitude__c = latitude,
            Longitude__c = longitude,
            Address__c = address,
            Sequence__c = sequence
        );
        insert wp;
    }

    public static List<Waypoint__c> getWaypoints(Id expenseId) {
        return [
            SELECT Id, Latitude__c, Longitude__c, Address__c, Sequence__c
            FROM Waypoint__c WHERE Expense__c = :expenseId ORDER BY Sequence__c
        ];
    }

    public static void recalculateAmount(Id expenseId) {
        Expense__c expense = [
            SELECT Id, Distance__c, Distance_Unit__c, Policy__c FROM Expense__c WHERE Id = :expenseId LIMIT 1
        ];

        if (expense.Policy__c == null || expense.Distance__c == null) return;

        List<Distance_Rate__c> rates = [
            SELECT Rate_Per_Unit__c, Currency__c FROM Distance_Rate__c
            WHERE Policy__c = :expense.Policy__c AND Unit__c = :expense.Distance_Unit__c LIMIT 1
        ];

        if (!rates.isEmpty()) {
            expense.Amount__c = (expense.Distance__c * rates[0].Rate_Per_Unit__c).setScale(2, RoundingMode.HALF_UP);
            update expense;
        }
    }

    public class DistanceException extends Exception {}
}
