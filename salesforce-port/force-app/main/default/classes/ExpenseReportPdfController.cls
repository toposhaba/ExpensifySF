public with sharing class ExpenseReportPdfController {

    public Expense_Report__c report { get; private set; }
    public List<Expense__c> expenses { get; private set; }

    public ExpenseReportPdfController() {
        String reportId = ApexPages.currentPage().getParameters().get('id');
        if (String.isNotBlank(reportId)) {
            load((Id) reportId);
        }
    }

    public ExpenseReportPdfController(Id reportId) {
        load(reportId);
    }

    private void load(Id reportId) {
        if (!Schema.sObjectType.Expense_Report__c.isAccessible()
            || !Schema.sObjectType.Expense__c.isAccessible()) {
            return;
        }
        report = ExpenseReportService.getReport(reportId);
        expenses = ExpenseService.getExpensesByReport(reportId);
    }

    public Boolean getHasExpenses() {
        return expenses != null && !expenses.isEmpty();
    }

    public Date getGeneratedDate() {
        return Date.today();
    }
}
