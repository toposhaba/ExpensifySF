public with sharing class ExpenseService {

    public static Expense__c createExpense(Expense__c expense) {
        validateExpense(expense);
        insert expense;
        checkViolations(expense.Id);
        updateReportTotals(expense.Report__c);
        return expense;
    }

    public static List<Expense__c> createExpenses(List<Expense__c> expenses) {
        for (Expense__c exp : expenses) {
            validateExpense(exp);
        }
        insert expenses;
        Set<Id> reportIds = new Set<Id>();
        for (Expense__c exp : expenses) {
            checkViolations(exp.Id);
            if (exp.Report__c != null) {
                reportIds.add(exp.Report__c);
            }
        }
        for (Id reportId : reportIds) {
            updateReportTotals(reportId);
        }
        return expenses;
    }

    public static Expense__c updateExpense(Expense__c expense) {
        validateExpense(expense);
        update expense;
        clearViolations(expense.Id);
        checkViolations(expense.Id);
        updateReportTotals(expense.Report__c);
        return expense;
    }

    public static void deleteExpense(Id expenseId) {
        Expense__c expense = [SELECT Id, Report__c FROM Expense__c WHERE Id = :expenseId LIMIT 1];
        Id reportId = expense.Report__c;
        delete expense;
        if (reportId != null) {
            updateReportTotals(reportId);
        }
    }

    public static Expense__c getExpense(Id expenseId) {
        return [
            SELECT Id, Name, Amount__c, Currency__c, Merchant__c, Expense_Date__c,
                   Category__c, Category__r.Name, Tag__c, Tag__r.Name,
                   Description__c, Billable__c, Reimbursable__c, Tax_Amount__c,
                   Tax_Rate__c, Status__c, Expense_Type__c, Receipt_URL__c,
                   Has_Receipt__c, Distance__c, Distance_Unit__c, Policy__c,
                   Report__c, Report__r.Name, Hold_Reason__c, OwnerId,
                   CreatedDate, LastModifiedDate
            FROM Expense__c
            WHERE Id = :expenseId
            LIMIT 1
        ];
    }

    public static List<Expense__c> getExpensesByReport(Id reportId) {
        return [
            SELECT Id, Name, Amount__c, Currency__c, Merchant__c, Expense_Date__c,
                   Category__c, Category__r.Name, Tag__c, Tag__r.Name,
                   Description__c, Billable__c, Reimbursable__c, Tax_Amount__c,
                   Status__c, Expense_Type__c, Has_Receipt__c, OwnerId
            FROM Expense__c
            WHERE Report__c = :reportId
            ORDER BY Expense_Date__c DESC
        ];
    }

    public static List<Expense__c> getExpensesByUser(Id userId) {
        return [
            SELECT Id, Name, Amount__c, Currency__c, Merchant__c, Expense_Date__c,
                   Category__c, Category__r.Name, Tag__c, Tag__r.Name,
                   Status__c, Expense_Type__c, Report__c, Report__r.Name
            FROM Expense__c
            WHERE OwnerId = :userId
            ORDER BY Expense_Date__c DESC
            LIMIT 200
        ];
    }

    public static List<Expense__c> getUnreportedExpenses(Id userId) {
        return [
            SELECT Id, Name, Amount__c, Currency__c, Merchant__c, Expense_Date__c,
                   Category__c, Category__r.Name, Status__c, Expense_Type__c
            FROM Expense__c
            WHERE OwnerId = :userId AND Report__c = null
            ORDER BY Expense_Date__c DESC
        ];
    }

    public static void holdExpense(Id expenseId, String reason) {
        Expense__c expense = new Expense__c(
            Id = expenseId,
            Status__c = 'On_Hold',
            Hold_Reason__c = reason
        );
        update expense;
    }

    public static void unholdExpense(Id expenseId) {
        Expense__c expense = new Expense__c(
            Id = expenseId,
            Status__c = 'Pending',
            Hold_Reason__c = null
        );
        update expense;
    }

    public static void rejectExpense(Id expenseId) {
        Expense__c expense = new Expense__c(
            Id = expenseId,
            Status__c = 'Rejected'
        );
        update expense;
    }

    public static void assignToReport(List<Id> expenseIds, Id reportId) {
        List<Expense__c> expenses = new List<Expense__c>();
        for (Id expId : expenseIds) {
            expenses.add(new Expense__c(Id = expId, Report__c = reportId));
        }
        update expenses;
        updateReportTotals(reportId);
    }

    public static void removeFromReport(List<Id> expenseIds) {
        List<Expense__c> expenses = [SELECT Id, Report__c FROM Expense__c WHERE Id IN :expenseIds];
        Set<Id> reportIds = new Set<Id>();
        for (Expense__c exp : expenses) {
            if (exp.Report__c != null) {
                reportIds.add(exp.Report__c);
            }
            exp.Report__c = null;
        }
        update expenses;
        for (Id reportId : reportIds) {
            updateReportTotals(reportId);
        }
    }

    private static void validateExpense(Expense__c expense) {
        if (expense.Amount__c == null || expense.Amount__c <= 0) {
            throw new ExpenseException('Amount must be greater than zero');
        }
        if (expense.Expense_Date__c == null) {
            throw new ExpenseException('Expense date is required');
        }
        if (expense.Expense_Date__c > Date.today()) {
            throw new ExpenseException('Expense date cannot be in the future');
        }
    }

    private static void checkViolations(Id expenseId) {
        Expense__c expense = [
            SELECT Id, Amount__c, Expense_Date__c, Has_Receipt__c, Category__c, Policy__c
            FROM Expense__c
            WHERE Id = :expenseId
            LIMIT 1
        ];

        if (expense.Policy__c == null) {
            return;
        }

        Expense_Policy__c policy = [
            SELECT Max_Expense_Amount__c, Max_Expense_Age_Days__c, Receipt_Required_Amount__c
            FROM Expense_Policy__c
            WHERE Id = :expense.Policy__c
            LIMIT 1
        ];

        List<Expense_Violation__c> violations = new List<Expense_Violation__c>();

        if (policy.Max_Expense_Amount__c != null && expense.Amount__c > policy.Max_Expense_Amount__c) {
            violations.add(new Expense_Violation__c(
                Expense__c = expenseId,
                Violation_Type__c = 'Over_Limit',
                Message__c = 'Expense exceeds maximum amount of ' + policy.Max_Expense_Amount__c
            ));
        }

        if (policy.Max_Expense_Age_Days__c != null) {
            Integer daysDiff = Date.today().daysBetween(expense.Expense_Date__c);
            if (Math.abs(daysDiff) > policy.Max_Expense_Age_Days__c) {
                violations.add(new Expense_Violation__c(
                    Expense__c = expenseId,
                    Violation_Type__c = 'Over_Age',
                    Message__c = 'Expense is older than ' + policy.Max_Expense_Age_Days__c + ' days'
                ));
            }
        }

        if (policy.Receipt_Required_Amount__c != null
            && expense.Amount__c >= policy.Receipt_Required_Amount__c
            && !expense.Has_Receipt__c) {
            violations.add(new Expense_Violation__c(
                Expense__c = expenseId,
                Violation_Type__c = 'Receipt_Required',
                Message__c = 'Receipt required for expenses over ' + policy.Receipt_Required_Amount__c
            ));
        }

        if (!violations.isEmpty()) {
            insert violations;
        }
    }

    private static void clearViolations(Id expenseId) {
        List<Expense_Violation__c> existing = [
            SELECT Id FROM Expense_Violation__c WHERE Expense__c = :expenseId
        ];
        if (!existing.isEmpty()) {
            delete existing;
        }
    }

    public static void updateReportTotals(Id reportId) {
        if (reportId == null) return;

        AggregateResult[] results = [
            SELECT SUM(Amount__c) totalAmount, COUNT(Id) expenseCount,
                   SUM(CASE WHEN Reimbursable__c = true THEN Amount__c ELSE 0 END) reimbursableTotal
            FROM Expense__c
            WHERE Report__c = :reportId
        ];

        if (!results.isEmpty()) {
            Decimal total = (Decimal) results[0].get('totalAmount');
            Integer count = (Integer) results[0].get('expenseCount');
            Decimal reimbursable = (Decimal) results[0].get('reimbursableTotal');

            Expense_Report__c report = new Expense_Report__c(
                Id = reportId,
                Total_Amount__c = total != null ? total : 0,
                Expense_Count__c = count != null ? count : 0,
                Reimbursable_Total__c = reimbursable != null ? reimbursable : 0
            );
            update report;
        }
    }

    public class ExpenseException extends Exception {}
}
