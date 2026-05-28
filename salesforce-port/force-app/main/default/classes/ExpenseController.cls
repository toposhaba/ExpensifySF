public with sharing class ExpenseController {

    @AuraEnabled(cacheable=true)
    public static List<Expense__c> getMyExpenses() {
        return ExpenseService.getExpensesByUser(UserInfo.getUserId());
    }

    @AuraEnabled(cacheable=true)
    public static List<Expense__c> getUnreportedExpenses() {
        return ExpenseService.getUnreportedExpenses(UserInfo.getUserId());
    }

    @AuraEnabled(cacheable=true)
    public static List<Expense__c> getExpensesByReport(Id reportId) {
        return ExpenseService.getExpensesByReport(reportId);
    }

    @AuraEnabled(cacheable=true)
    public static Expense__c getExpense(Id expenseId) {
        return ExpenseService.getExpense(expenseId);
    }

    @AuraEnabled
    public static Expense__c createExpense(Expense__c expense) {
        return ExpenseService.createExpense(expense);
    }

    @AuraEnabled
    public static Expense__c updateExpense(Expense__c expense) {
        return ExpenseService.updateExpense(expense);
    }

    @AuraEnabled
    public static void deleteExpense(Id expenseId) {
        ExpenseService.deleteExpense(expenseId);
    }

    @AuraEnabled
    public static void holdExpense(Id expenseId, String reason) {
        ExpenseService.holdExpense(expenseId, reason);
    }

    @AuraEnabled
    public static void unholdExpense(Id expenseId) {
        ExpenseService.unholdExpense(expenseId);
    }

    @AuraEnabled
    public static void assignToReport(List<Id> expenseIds, Id reportId) {
        ExpenseService.assignToReport(expenseIds, reportId);
    }

    @AuraEnabled(cacheable=true)
    public static List<Expense_Report__c> getMyReports() {
        return ExpenseReportService.getReportsByUser(UserInfo.getUserId());
    }

    @AuraEnabled(cacheable=true)
    public static List<Expense_Report__c> getReportsToApprove() {
        return ExpenseReportService.getReportsToApprove(UserInfo.getUserId());
    }

    @AuraEnabled(cacheable=true)
    public static Expense_Report__c getReport(Id reportId) {
        return ExpenseReportService.getReport(reportId);
    }

    @AuraEnabled
    public static Expense_Report__c createReport(Expense_Report__c report) {
        return ExpenseReportService.createReport(report);
    }

    @AuraEnabled
    public static Expense_Report__c submitReport(Id reportId) {
        return ExpenseReportService.submitReport(reportId);
    }

    @AuraEnabled
    public static Expense_Report__c approveReport(Id reportId) {
        return ExpenseReportService.approveReport(reportId);
    }

    @AuraEnabled
    public static Expense_Report__c rejectReport(Id reportId, String reason) {
        return ExpenseReportService.rejectReport(reportId, reason);
    }

    @AuraEnabled
    public static Expense_Report__c reopenReport(Id reportId) {
        return ExpenseReportService.reopenReport(reportId);
    }

    @AuraEnabled(cacheable=true)
    public static List<Expense_Policy__c> getMyPolicies() {
        return PolicyService.getPoliciesForUser(UserInfo.getUserId());
    }

    @AuraEnabled(cacheable=true)
    public static Expense_Policy__c getPolicy(Id policyId) {
        return PolicyService.getPolicy(policyId);
    }

    @AuraEnabled(cacheable=true)
    public static List<Expense_Category__c> getCategories(Id policyId) {
        return PolicyService.getCategories(policyId);
    }

    @AuraEnabled(cacheable=true)
    public static List<Expense_Tag__c> getTags(Id policyId) {
        return PolicyService.getTags(policyId);
    }

    @AuraEnabled(cacheable=true)
    public static List<Policy_Member__c> getPolicyMembers(Id policyId) {
        return PolicyService.getMembers(policyId);
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getDashboardData() {
        Id userId = UserInfo.getUserId();
        Map<String, Object> data = new Map<String, Object>();

        AggregateResult[] totalSpend = [
            SELECT SUM(Amount__c) total
            FROM Expense__c
            WHERE OwnerId = :userId
            AND Expense_Date__c = THIS_MONTH
        ];
        data.put('monthlySpend', totalSpend[0].get('total'));

        Integer pendingCount = [
            SELECT COUNT()
            FROM Expense_Report__c
            WHERE Approver__c = :userId AND Status__c = 'Submitted'
        ];
        data.put('pendingApprovals', pendingCount);

        Integer unreportedCount = [
            SELECT COUNT()
            FROM Expense__c
            WHERE OwnerId = :userId AND Report__c = null
        ];
        data.put('unreportedExpenses', unreportedCount);

        Integer openReports = [
            SELECT COUNT()
            FROM Expense_Report__c
            WHERE OwnerId = :userId AND Status__c = 'Open'
        ];
        data.put('openReports', openReports);

        List<AggregateResult> byCategory = [
            SELECT Category__r.Name catName, SUM(Amount__c) total
            FROM Expense__c
            WHERE OwnerId = :userId AND Expense_Date__c = THIS_MONTH
            GROUP BY Category__r.Name
            ORDER BY SUM(Amount__c) DESC
            LIMIT 10
        ];
        data.put('spendByCategory', byCategory);

        return data;
    }

    @AuraEnabled(cacheable=true)
    public static List<Expense__c> searchExpenses(String searchTerm, String status, Id policyId, Date startDate, Date endDate) {
        String query = 'SELECT Id, Name, Amount__c, Currency__c, Merchant__c, Expense_Date__c, ' +
                       'Category__r.Name, Tag__r.Name, Status__c, Expense_Type__c, Report__c, Report__r.Name ' +
                       'FROM Expense__c WHERE OwnerId = \'' + UserInfo.getUserId() + '\'';

        if (String.isNotBlank(searchTerm)) {
            String term = '%' + String.escapeSingleQuotes(searchTerm) + '%';
            query += ' AND (Merchant__c LIKE \'' + term + '\' OR Description__c LIKE \'' + term + '\')';
        }
        if (String.isNotBlank(status)) {
            query += ' AND Status__c = \'' + String.escapeSingleQuotes(status) + '\'';
        }
        if (policyId != null) {
            query += ' AND Policy__c = \'' + policyId + '\'';
        }
        if (startDate != null) {
            query += ' AND Expense_Date__c >= ' + String.valueOf(startDate);
        }
        if (endDate != null) {
            query += ' AND Expense_Date__c <= ' + String.valueOf(endDate);
        }

        query += ' ORDER BY Expense_Date__c DESC LIMIT 200';
        return Database.query(query);
    }

    @AuraEnabled
    public static void bulkUpdateCategory(List<Id> expenseIds, Id categoryId) {
        List<Expense__c> expenses = new List<Expense__c>();
        for (Id expId : expenseIds) {
            expenses.add(new Expense__c(Id = expId, Category__c = categoryId));
        }
        update expenses;
    }

    @AuraEnabled
    public static void bulkUpdateTag(List<Id> expenseIds, Id tagId) {
        List<Expense__c> expenses = new List<Expense__c>();
        for (Id expId : expenseIds) {
            expenses.add(new Expense__c(Id = expId, Tag__c = tagId));
        }
        update expenses;
    }

    @AuraEnabled(cacheable=true)
    public static List<Expense_Violation__c> getViolations(Id expenseId) {
        return [
            SELECT Id, Violation_Type__c, Message__c, CreatedDate
            FROM Expense_Violation__c
            WHERE Expense__c = :expenseId
            ORDER BY CreatedDate DESC
        ];
    }
}
