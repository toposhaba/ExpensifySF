@isTest
private class ExpenseImportServiceTest {

    @TestSetup
    static void setupTestData() {
        Expense_Policy__c policy = new Expense_Policy__c(
            Name = 'Import Policy',
            Currency__c = 'USD',
            Type__c = 'Corporate',
            Approval_Mode__c = 'Basic',
            Categories_Enabled__c = true,
            Tags_Enabled__c = true
        );
        insert policy;

        Expense_Category__c category = new Expense_Category__c(
            Name = 'Travel',
            Policy__c = policy.Id,
            GL_Code__c = '5001',
            Enabled__c = true
        );
        insert category;

        Expense_Report__c report = new Expense_Report__c(
            Status__c = 'Open',
            Currency__c = 'USD',
            Policy__c = policy.Id
        );
        insert report;
    }

    private static Id policyId() {
        return [SELECT Id FROM Expense_Policy__c LIMIT 1].Id;
    }

    private static Id reportId() {
        return [SELECT Id FROM Expense_Report__c LIMIT 1].Id;
    }

    @isTest
    static void testImportValidRowsWithHeader() {
        String csv =
            'Date,Merchant,Amount,Currency,Category\n' +
            '2025-01-15,Starbucks,12.50,USD,Travel\n' +
            '2025-02-20,Uber,45.00,EUR,Travel\n';

        Test.startTest();
        ExpenseImportService.ImportSummary summary = ExpenseImportService.importCsv(csv, policyId(), reportId());
        Test.stopTest();

        System.assertEquals(2, summary.totalRows, 'Should have parsed two data rows');
        System.assertEquals(2, summary.successCount, 'Both rows should import');
        System.assertEquals(0, summary.errorCount, 'No errors expected');
        System.assertEquals(57.50, summary.totalAmount, 'Total amount should sum imported rows');
        System.assertEquals(2, summary.createdExpenseIds.size(), 'Two expenses created');

        List<Expense__c> expenses = [
            SELECT Merchant__c, Amount__c, Currency__c, Category__c, Report__c
            FROM Expense__c
            ORDER BY Amount__c ASC
        ];
        System.assertEquals(2, expenses.size());
        System.assertEquals('Starbucks', expenses[0].Merchant__c);
        System.assertEquals('USD', expenses[0].Currency__c);
        System.assertNotEquals(null, expenses[0].Category__c, 'Category should resolve by name');
        System.assertEquals('EUR', expenses[1].Currency__c);
    }

    @isTest
    static void testMalformedRowReported() {
        String csv =
            'Date,Merchant,Amount,Currency,Category\n' +
            '2025-01-15,Good Row,10.00,USD,Travel\n' +
            'not-a-date,Bad Date,20.00,USD,Travel\n' +
            '2025-03-01,No Amount,,USD,Travel\n' +
            '2025-03-02,Negative,-5.00,USD,Travel\n';

        Test.startTest();
        ExpenseImportService.ImportSummary summary = ExpenseImportService.importCsv(csv, policyId(), null);
        Test.stopTest();

        System.assertEquals(4, summary.totalRows);
        System.assertEquals(1, summary.successCount, 'Only the good row imports');
        System.assertEquals(3, summary.errorCount, 'Three malformed rows reported');

        Integer reportedErrors = 0;
        for (ExpenseImportService.RowResult row : summary.rows) {
            if (!row.isSuccess) {
                reportedErrors++;
                System.assertNotEquals(null, row.errorMessage, 'Failed rows carry an error message');
            }
        }
        System.assertEquals(3, reportedErrors);
    }

    @isTest
    static void testFutureDateRejected() {
        Date future = Date.today().addDays(10);
        String csv =
            'Date,Merchant,Amount\n' +
            String.valueOf(future) + ',Future Merchant,99.00\n';

        Test.startTest();
        ExpenseImportService.ImportSummary summary = ExpenseImportService.importCsv(csv, policyId(), null);
        Test.stopTest();

        System.assertEquals(1, summary.totalRows);
        System.assertEquals(0, summary.successCount);
        System.assertEquals(1, summary.errorCount);
        System.assert(summary.rows[0].errorMessage.contains('future'), 'Should report future date error');
    }

    @isTest
    static void testNoHeaderUsesPositionalMapping() {
        String csv =
            '2025-04-01,Hotel,150.00,USD\n' +
            '2025-04-02,Taxi,30.00,USD\n';

        Test.startTest();
        ExpenseImportService.ImportSummary summary = ExpenseImportService.importCsv(csv, policyId(), null);
        Test.stopTest();

        System.assertEquals(2, summary.totalRows, 'Both rows treated as data');
        System.assertEquals(2, summary.successCount);
        System.assertEquals(180.00, summary.totalAmount);
    }

    @isTest
    static void testQuotedValuesAndCurrencySymbols() {
        String csv =
            'Date,Merchant,Amount,Category\n' +
            '01/15/2025,"Smith, John & Co.","$1,234.56",Travel\n';

        Test.startTest();
        ExpenseImportService.ImportSummary summary = ExpenseImportService.importCsv(csv, policyId(), null);
        Test.stopTest();

        System.assertEquals(1, summary.successCount);
        Expense__c expense = [SELECT Merchant__c, Amount__c FROM Expense__c LIMIT 1];
        System.assertEquals('Smith, John & Co.', expense.Merchant__c, 'Quoted comma preserved');
        System.assertEquals(1234.56, expense.Amount__c, 'Currency symbols and separators stripped');
    }

    @isTest
    static void testEmptyCsvThrows() {
        Test.startTest();
        try {
            ExpenseImportService.importCsv('   ', policyId(), null);
            System.assert(false, 'Should have thrown for empty CSV');
        } catch (ExpenseImportService.ExpenseImportException e) {
            System.assert(e.getMessage().contains('No data'));
        }
        Test.stopTest();
    }

    @isTest
    static void testEuropeanDateFormat() {
        String csv =
            'Date,Merchant,Amount\n' +
            '25/12/2025,Festive,40.00\n' +
            '2025/06/30,Slash ISO,15.00\n' +
            '20250101,Compact,5.00\n';

        Test.startTest();
        ExpenseImportService.ImportSummary summary = ExpenseImportService.importCsv(csv, policyId(), null);
        Test.stopTest();

        System.assertEquals(3, summary.successCount, 'All recognized date formats import');
        System.assertEquals(60.00, summary.totalAmount);
    }

    @isTest
    static void testInvocableImportExpenses() {
        InvocableImportExpenses.Request req = new InvocableImportExpenses.Request();
        req.csvBody = 'Date,Merchant,Amount\n2025-05-05,Lunch,18.00\nbad,Broken,bad\n';
        req.policyId = policyId();
        req.reportId = reportId();

        Test.startTest();
        List<InvocableImportExpenses.Results> results = InvocableImportExpenses.execute(
            new List<InvocableImportExpenses.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        InvocableImportExpenses.Results res = results[0];
        System.assertEquals(2, res.totalRows);
        System.assertEquals(1, res.successCount);
        System.assertEquals(1, res.errorCount);
        System.assertEquals(false, res.isSuccess, 'Has at least one error');
        System.assertEquals(1, res.createdExpenseIds.size());
        System.assert(!res.errorMessages.isEmpty(), 'Error messages populated');
    }

    @isTest
    static void testAuraEntryPoint() {
        Test.startTest();
        ExpenseImportService.ImportSummary summary = ExpenseImportService.importExpenses(
            'Date,Merchant,Amount\n2025-07-07,Cafe,9.00\n',
            policyId(),
            null
        );
        Test.stopTest();

        System.assertEquals(1, summary.successCount);
        System.assertEquals(9.00, summary.totalAmount);
    }

    @isTest
    static void testAuraEntryPointThrowsHandled() {
        Test.startTest();
        try {
            ExpenseImportService.importExpenses('', policyId(), null);
            System.assert(false, 'Should have thrown AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }
}
