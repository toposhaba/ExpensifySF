public with sharing class InvocableCheckViolations {

    @InvocableMethod(label='Check Expense Violations' description='Runs policy violation checks against expenses and creates violation records for any rules that are broken' category='Expense Management')
    public static List<Results> execute(List<Request> requests) {
        List<Results> responseList = new List<Results>();
        for (Request req : requests) {
            Results res = new Results();
            try {
                List<Id> expenseIds = req.expenseIds;
                Integer violationCount = 0;

                for (Id expenseId : expenseIds) {
                    List<Expense_Violation__c> existing = [
                        SELECT Id FROM Expense_Violation__c WHERE Expense__c = :expenseId
                    ];
                    if (!existing.isEmpty()) {
                        delete existing;
                    }

                    Expense__c expense = [
                        SELECT Id, Amount__c, Expense_Date__c, Has_Receipt__c, Category__c, Policy__c
                        FROM Expense__c
                        WHERE Id = :expenseId
                        LIMIT 1
                    ];

                    if (expense.Policy__c == null) {
                        continue;
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
                        violationCount += violations.size();
                    }
                }

                res.violationsFound = violationCount;
                res.expensesChecked = expenseIds.size();
                res.isSuccess = true;
            } catch (Exception e) {
                res.isSuccess = false;
                res.errorMessage = e.getMessage();
            }
            responseList.add(res);
        }
        return responseList;
    }

    public class Request {
        @InvocableVariable(label='Expense Ids' required=true)
        public List<Id> expenseIds;
    }

    public class Results {
        @InvocableVariable(label='Violations Found')
        public Integer violationsFound;

        @InvocableVariable(label='Expenses Checked')
        public Integer expensesChecked;

        @InvocableVariable(label='Is Success')
        public Boolean isSuccess;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }
}
