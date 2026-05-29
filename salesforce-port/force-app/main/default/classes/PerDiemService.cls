public with sharing class PerDiemService {

    public static Expense__c createPerDiemExpense(Id policyId, Id reportId, String destination, Date startDate, Date endDate) {
        List<Per_Diem_Rate__c> rates = [
            SELECT Daily_Rate__c, Currency__c FROM Per_Diem_Rate__c
            WHERE Policy__c = :policyId AND Destination__c = :destination LIMIT 1
        ];

        if (rates.isEmpty()) {
            throw new PerDiemException('No per diem rate found for destination: ' + destination);
        }

        Integer days = startDate.daysBetween(endDate) + 1;
        Decimal totalAmount = rates[0].Daily_Rate__c * days;

        Expense__c expense = new Expense__c(
            Amount__c = totalAmount,
            Currency__c = rates[0].Currency__c,
            Merchant__c = 'Per Diem - ' + destination,
            Expense_Date__c = startDate,
            Expense_Type__c = 'Per_Diem',
            Status__c = 'Draft',
            Policy__c = policyId,
            Report__c = reportId,
            Description__c = 'Per diem: ' + destination + ' (' + days + ' days @ ' + rates[0].Daily_Rate__c + '/day)',
            Reimbursable__c = true
        );

        return ExpenseService.createExpense(expense);
    }

    public static List<Per_Diem_Rate__c> getRates(Id policyId) {
        return [
            SELECT Id, Name, Destination__c, Daily_Rate__c, Currency__c
            FROM Per_Diem_Rate__c WHERE Policy__c = :policyId ORDER BY Destination__c
        ];
    }

    public static Per_Diem_Rate__c createRate(Per_Diem_Rate__c rate) {
        insert rate;
        return rate;
    }

    public static void deleteRate(Id rateId) {
        delete [SELECT Id FROM Per_Diem_Rate__c WHERE Id = :rateId];
    }

    public static void importRates(Id policyId, String csvContent) {
        List<String> lines = csvContent.split('\n');
        List<Per_Diem_Rate__c> rates = new List<Per_Diem_Rate__c>();

        for (Integer i = 1; i < lines.size(); i++) {
            List<String> parts = lines[i].split(',');
            if (parts.size() >= 3) {
                rates.add(new Per_Diem_Rate__c(
                    Policy__c = policyId,
                    Name = parts[0].trim(),
                    Destination__c = parts[0].trim(),
                    Daily_Rate__c = Decimal.valueOf(parts[1].trim()),
                    Currency__c = parts[2].trim()
                ));
            }
        }
        if (!rates.isEmpty()) insert rates;
    }

    public class PerDiemException extends Exception {}
}
