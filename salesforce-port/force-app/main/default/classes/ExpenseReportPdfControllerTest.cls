@isTest
private class ExpenseReportPdfControllerTest {

    private static Id seedReport() {
        Expense_Policy__c policy = new Expense_Policy__c(
            Name = 'PDF Policy',
            Currency__c = 'USD',
            Type__c = 'Corporate',
            Approval_Mode__c = 'Basic'
        );
        insert policy;

        Expense_Report__c report = new Expense_Report__c(
            Status__c = 'Open',
            Currency__c = 'USD',
            Policy__c = policy.Id
        );
        insert report;

        insert new Expense__c(
            Amount__c = 75.00,
            Currency__c = 'USD',
            Merchant__c = 'Airline',
            Expense_Date__c = Date.today(),
            Expense_Type__c = 'Card',
            Status__c = 'Draft',
            Report__c = report.Id
        );
        return report.Id;
    }

    @isTest
    static void testControllerWithReport() {
        Id reportId = seedReport();

        Test.startTest();
        Test.setCurrentPage(Page.expenseReportPdf);
        ApexPages.currentPage().getParameters().put('id', reportId);
        ExpenseReportPdfController ctrl = new ExpenseReportPdfController();
        Test.stopTest();

        System.assertNotEquals(null, ctrl.report, 'Report should be loaded');
        System.assertEquals(reportId, ctrl.report.Id, 'Loaded report should match the id param');
        System.assertEquals(true, ctrl.getHasExpenses(), 'Report should have expenses');
        System.assertEquals(1, ctrl.expenses.size(), 'One expense expected');
        System.assertEquals(Date.today(), ctrl.getGeneratedDate(), 'Generated date should be today');
    }

    @isTest
    static void testControllerConstructorWithId() {
        Id reportId = seedReport();

        Test.startTest();
        ExpenseReportPdfController ctrl = new ExpenseReportPdfController(reportId);
        Test.stopTest();

        System.assertNotEquals(null, ctrl.report, 'Report should be loaded via id constructor');
        System.assertEquals('Airline', ctrl.expenses[0].Merchant__c, 'Expense merchant should match');
    }

    @isTest
    static void testControllerNoParam() {
        Test.startTest();
        Test.setCurrentPage(Page.expenseReportPdf);
        ExpenseReportPdfController ctrl = new ExpenseReportPdfController();
        Test.stopTest();

        System.assertEquals(null, ctrl.report, 'No report should be loaded without an id');
        System.assertEquals(false, ctrl.getHasExpenses(), 'No expenses without a report');
    }
}
