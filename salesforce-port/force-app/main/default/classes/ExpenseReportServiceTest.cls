@isTest
private class ExpenseReportServiceTest {

    @TestSetup
    static void setupTestData() {
        Expense_Policy__c policy = new Expense_Policy__c(
            Name = 'Test Policy',
            Currency__c = 'USD',
            Type__c = 'Corporate',
            Approval_Mode__c = 'Basic',
            Auto_Approve_Limit__c = 100
        );
        insert policy;

        Policy_Member__c member = new Policy_Member__c(
            Policy__c = policy.Id,
            User__c = UserInfo.getUserId(),
            Role__c = 'Member'
        );
        insert member;
    }

    @isTest
    static void testCreateReport() {
        Expense_Policy__c policy = [SELECT Id FROM Expense_Policy__c LIMIT 1];

        Test.startTest();
        Expense_Report__c report = ExpenseReportService.createReport(new Expense_Report__c(
            Currency__c = 'USD',
            Policy__c = policy.Id
        ));
        Test.stopTest();

        System.assertNotEquals(null, report.Id);
        System.assertEquals('Open', report.Status__c);
    }

    @isTest
    static void testSubmitReport() {
        Expense_Policy__c policy = [SELECT Id FROM Expense_Policy__c LIMIT 1];

        Expense_Report__c report = new Expense_Report__c(
            Status__c = 'Open',
            Currency__c = 'USD',
            Policy__c = policy.Id
        );
        insert report;

        Expense__c expense = new Expense__c(
            Amount__c = 50.00,
            Currency__c = 'USD',
            Expense_Date__c = Date.today(),
            Expense_Type__c = 'Cash',
            Status__c = 'Draft',
            Report__c = report.Id
        );
        insert expense;

        report.Total_Amount__c = 50.00;
        report.Expense_Count__c = 1;
        update report;

        Test.startTest();
        Expense_Report__c submitted = ExpenseReportService.submitReport(report.Id);
        Test.stopTest();

        System.assertEquals('Approved', submitted.Status__c);
    }

    @isTest
    static void testSubmitReport_NoExpenses() {
        Expense_Report__c report = new Expense_Report__c(
            Status__c = 'Open',
            Currency__c = 'USD'
        );
        insert report;

        Test.startTest();
        try {
            ExpenseReportService.submitReport(report.Id);
            System.assert(false, 'Should throw exception');
        } catch (ExpenseReportService.ReportException e) {
            System.assert(e.getMessage().contains('no expenses'));
        }
        Test.stopTest();
    }

    @isTest
    static void testSubmitReport_AlreadySubmitted() {
        Expense_Report__c report = new Expense_Report__c(
            Status__c = 'Submitted',
            Currency__c = 'USD'
        );
        insert report;

        Test.startTest();
        try {
            ExpenseReportService.submitReport(report.Id);
            System.assert(false, 'Should throw exception');
        } catch (ExpenseReportService.ReportException e) {
            System.assert(e.getMessage().contains('Only open or rejected'));
        }
        Test.stopTest();
    }

    @isTest
    static void testApproveReport() {
        Expense_Report__c report = new Expense_Report__c(
            Status__c = 'Submitted',
            Currency__c = 'USD'
        );
        insert report;

        Test.startTest();
        Expense_Report__c approved = ExpenseReportService.approveReport(report.Id);
        Test.stopTest();

        System.assertEquals('Approved', approved.Status__c);
        System.assertNotEquals(null, approved.Approved_Date__c);
    }

    @isTest
    static void testRejectReport() {
        Expense_Report__c report = new Expense_Report__c(
            Status__c = 'Submitted',
            Currency__c = 'USD'
        );
        insert report;

        Test.startTest();
        Expense_Report__c rejected = ExpenseReportService.rejectReport(report.Id, 'Missing receipts');
        Test.stopTest();

        System.assertEquals('Rejected', rejected.Status__c);
    }

    @isTest
    static void testReopenReport() {
        Expense_Report__c report = new Expense_Report__c(
            Status__c = 'Rejected',
            Currency__c = 'USD',
            Submitted_Date__c = Datetime.now()
        );
        insert report;

        Test.startTest();
        Expense_Report__c reopened = ExpenseReportService.reopenReport(report.Id);
        Test.stopTest();

        Expense_Report__c saved = [SELECT Status__c, Submitted_Date__c FROM Expense_Report__c WHERE Id = :report.Id];
        System.assertEquals('Open', saved.Status__c);
        System.assertEquals(null, saved.Submitted_Date__c);
    }

    @isTest
    static void testMarkReimbursed() {
        Expense_Report__c report = new Expense_Report__c(
            Status__c = 'Approved',
            Currency__c = 'USD'
        );
        insert report;

        Test.startTest();
        ExpenseReportService.markReimbursed(report.Id);
        Test.stopTest();

        Expense_Report__c saved = [SELECT Status__c FROM Expense_Report__c WHERE Id = :report.Id];
        System.assertEquals('Reimbursed', saved.Status__c);
    }

    @isTest
    static void testGetReportsByUser() {
        List<Expense_Report__c> reports = new List<Expense_Report__c>();
        for (Integer i = 0; i < 5; i++) {
            reports.add(new Expense_Report__c(Status__c = 'Open', Currency__c = 'USD'));
        }
        insert reports;

        Test.startTest();
        List<Expense_Report__c> results = ExpenseReportService.getReportsByUser(UserInfo.getUserId());
        Test.stopTest();

        System.assert(results.size() >= 5);
    }

    @isTest
    static void testGetReportsToApprove() {
        Expense_Report__c report = new Expense_Report__c(
            Status__c = 'Submitted',
            Currency__c = 'USD',
            Approver__c = UserInfo.getUserId(),
            Submitted_Date__c = Datetime.now()
        );
        insert report;

        Test.startTest();
        List<Expense_Report__c> results = ExpenseReportService.getReportsToApprove(UserInfo.getUserId());
        Test.stopTest();

        System.assert(!results.isEmpty());
    }
}
