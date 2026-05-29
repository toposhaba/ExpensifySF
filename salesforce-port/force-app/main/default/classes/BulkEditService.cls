public with sharing class BulkEditService {

    public static void updateCategory(List<Id> expenseIds, Id categoryId) {
        List<Expense__c> expenses = new List<Expense__c>();
        for (Id expId : expenseIds) {
            expenses.add(new Expense__c(Id = expId, Category__c = categoryId));
        }
        update expenses;
    }

    public static void updateTag(List<Id> expenseIds, Id tagId) {
        List<Expense__c> expenses = new List<Expense__c>();
        for (Id expId : expenseIds) {
            expenses.add(new Expense__c(Id = expId, Tag__c = tagId));
        }
        update expenses;
    }

    public static void updateBillable(List<Id> expenseIds, Boolean billable) {
        List<Expense__c> expenses = new List<Expense__c>();
        for (Id expId : expenseIds) {
            expenses.add(new Expense__c(Id = expId, Billable__c = billable));
        }
        update expenses;
    }

    public static void updateReimbursable(List<Id> expenseIds, Boolean reimbursable) {
        List<Expense__c> expenses = new List<Expense__c>();
        for (Id expId : expenseIds) {
            expenses.add(new Expense__c(Id = expId, Reimbursable__c = reimbursable));
        }
        update expenses;
    }

    public static void deleteExpenses(List<Id> expenseIds) {
        List<Expense__c> expenses = [SELECT Id, Report__c FROM Expense__c WHERE Id IN :expenseIds];
        Set<Id> reportIds = new Set<Id>();
        for (Expense__c exp : expenses) {
            if (exp.Report__c != null) reportIds.add(exp.Report__c);
        }
        delete expenses;
        for (Id reportId : reportIds) {
            ExpenseService.updateReportTotals(reportId);
        }
    }

    public static void submitMultipleReports(List<Id> reportIds) {
        for (Id reportId : reportIds) {
            try {
                ExpenseReportService.submitReport(reportId);
            } catch (Exception e) {
                continue;
            }
        }
    }

    public static void approveMultipleReports(List<Id> reportIds) {
        for (Id reportId : reportIds) {
            try {
                ExpenseReportService.approveReport(reportId);
            } catch (Exception e) {
                continue;
            }
        }
    }
}
