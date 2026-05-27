@isTest
private class ExpenseServiceTest {

    @TestSetup
    static void setupTestData() {
        Expense_Policy__c policy = new Expense_Policy__c(
            Name = 'Test Policy',
            Currency__c = 'USD',
            Type__c = 'Corporate',
            Approval_Mode__c = 'Basic',
            Max_Expense_Amount__c = 1000,
            Max_Expense_Age_Days__c = 90,
            Receipt_Required_Amount__c = 25,
            Categories_Enabled__c = true,
            Tags_Enabled__c = true
        );
        insert policy;

        Expense_Category__c category = new Expense_Category__c(
            Name = 'Travel',
            Policy__c = policy.Id,
            GL_Code__c = '5001',
            Enabled__c = true,
            Max_Amount__c = 500
        );
        insert category;

        Expense_Tag__c tag = new Expense_Tag__c(
            Name = 'Client Meeting',
            Policy__c = policy.Id,
            GL_Code__c = 'T001',
            Enabled__c = true
        );
        insert tag;

        Expense_Report__c report = new Expense_Report__c(
            Status__c = 'Open',
            Currency__c = 'USD',
            Policy__c = policy.Id
        );
        insert report;
    }

    @isTest
    static void testCreateExpense() {
        Expense_Policy__c policy = [SELECT Id FROM Expense_Policy__c LIMIT 1];
        Expense_Report__c report = [SELECT Id FROM Expense_Report__c LIMIT 1];
        Expense_Category__c category = [SELECT Id FROM Expense_Category__c LIMIT 1];

        Expense__c expense = new Expense__c(
            Amount__c = 50.00,
            Currency__c = 'USD',
            Merchant__c = 'Test Merchant',
            Expense_Date__c = Date.today(),
            Expense_Type__c = 'Cash',
            Status__c = 'Draft',
            Policy__c = policy.Id,
            Report__c = report.Id,
            Category__c = category.Id,
            Reimbursable__c = true,
            Has_Receipt__c = true
        );

        Test.startTest();
        Expense__c result = ExpenseService.createExpense(expense);
        Test.stopTest();

        System.assertNotEquals(null, result.Id);
        Expense__c saved = [SELECT Amount__c, Merchant__c FROM Expense__c WHERE Id = :result.Id];
        System.assertEquals(50.00, saved.Amount__c);
        System.assertEquals('Test Merchant', saved.Merchant__c);
    }

    @isTest
    static void testCreateExpenseViolation_OverLimit() {
        Expense_Policy__c policy = [SELECT Id FROM Expense_Policy__c LIMIT 1];

        Expense__c expense = new Expense__c(
            Amount__c = 1500.00,
            Currency__c = 'USD',
            Merchant__c = 'Expensive Merchant',
            Expense_Date__c = Date.today(),
            Expense_Type__c = 'Cash',
            Status__c = 'Draft',
            Policy__c = policy.Id,
            Reimbursable__c = true,
            Has_Receipt__c = true
        );

        Test.startTest();
        ExpenseService.createExpense(expense);
        Test.stopTest();

        List<Expense_Violation__c> violations = [
            SELECT Violation_Type__c FROM Expense_Violation__c WHERE Expense__c = :expense.Id
        ];
        System.assert(!violations.isEmpty(), 'Should have created a violation');

        Boolean hasOverLimit = false;
        for (Expense_Violation__c v : violations) {
            if (v.Violation_Type__c == 'Over_Limit') {
                hasOverLimit = true;
            }
        }
        System.assert(hasOverLimit, 'Should have Over_Limit violation');
    }

    @isTest
    static void testCreateExpenseViolation_ReceiptRequired() {
        Expense_Policy__c policy = [SELECT Id FROM Expense_Policy__c LIMIT 1];

        Expense__c expense = new Expense__c(
            Amount__c = 100.00,
            Currency__c = 'USD',
            Merchant__c = 'No Receipt Merchant',
            Expense_Date__c = Date.today(),
            Expense_Type__c = 'Cash',
            Status__c = 'Draft',
            Policy__c = policy.Id,
            Reimbursable__c = true,
            Has_Receipt__c = false
        );

        Test.startTest();
        ExpenseService.createExpense(expense);
        Test.stopTest();

        List<Expense_Violation__c> violations = [
            SELECT Violation_Type__c FROM Expense_Violation__c WHERE Expense__c = :expense.Id
        ];
        Boolean hasReceiptViolation = false;
        for (Expense_Violation__c v : violations) {
            if (v.Violation_Type__c == 'Receipt_Required') {
                hasReceiptViolation = true;
            }
        }
        System.assert(hasReceiptViolation, 'Should have Receipt_Required violation');
    }

    @isTest
    static void testCreateExpense_InvalidAmount() {
        Expense__c expense = new Expense__c(
            Amount__c = -10.00,
            Currency__c = 'USD',
            Expense_Date__c = Date.today(),
            Expense_Type__c = 'Cash',
            Status__c = 'Draft'
        );

        Test.startTest();
        try {
            ExpenseService.createExpense(expense);
            System.assert(false, 'Should have thrown exception');
        } catch (ExpenseService.ExpenseException e) {
            System.assert(e.getMessage().contains('Amount must be greater than zero'));
        }
        Test.stopTest();
    }

    @isTest
    static void testCreateExpense_FutureDate() {
        Expense__c expense = new Expense__c(
            Amount__c = 50.00,
            Currency__c = 'USD',
            Expense_Date__c = Date.today().addDays(5),
            Expense_Type__c = 'Cash',
            Status__c = 'Draft'
        );

        Test.startTest();
        try {
            ExpenseService.createExpense(expense);
            System.assert(false, 'Should have thrown exception');
        } catch (ExpenseService.ExpenseException e) {
            System.assert(e.getMessage().contains('future'));
        }
        Test.stopTest();
    }

    @isTest
    static void testUpdateExpense() {
        Expense_Policy__c policy = [SELECT Id FROM Expense_Policy__c LIMIT 1];

        Expense__c expense = new Expense__c(
            Amount__c = 50.00,
            Currency__c = 'USD',
            Merchant__c = 'Original',
            Expense_Date__c = Date.today(),
            Expense_Type__c = 'Cash',
            Status__c = 'Draft',
            Policy__c = policy.Id,
            Has_Receipt__c = true
        );
        insert expense;

        expense.Merchant__c = 'Updated Merchant';
        expense.Amount__c = 75.00;

        Test.startTest();
        Expense__c result = ExpenseService.updateExpense(expense);
        Test.stopTest();

        Expense__c saved = [SELECT Merchant__c, Amount__c FROM Expense__c WHERE Id = :result.Id];
        System.assertEquals('Updated Merchant', saved.Merchant__c);
        System.assertEquals(75.00, saved.Amount__c);
    }

    @isTest
    static void testDeleteExpense() {
        Expense_Report__c report = [SELECT Id FROM Expense_Report__c LIMIT 1];

        Expense__c expense = new Expense__c(
            Amount__c = 50.00,
            Currency__c = 'USD',
            Expense_Date__c = Date.today(),
            Expense_Type__c = 'Cash',
            Status__c = 'Draft',
            Report__c = report.Id
        );
        insert expense;

        Test.startTest();
        ExpenseService.deleteExpense(expense.Id);
        Test.stopTest();

        List<Expense__c> remaining = [SELECT Id FROM Expense__c WHERE Id = :expense.Id];
        System.assert(remaining.isEmpty(), 'Expense should be deleted');
    }

    @isTest
    static void testHoldAndUnhold() {
        Expense__c expense = new Expense__c(
            Amount__c = 50.00,
            Currency__c = 'USD',
            Expense_Date__c = Date.today(),
            Expense_Type__c = 'Cash',
            Status__c = 'Draft'
        );
        insert expense;

        Test.startTest();
        ExpenseService.holdExpense(expense.Id, 'Needs review');
        Test.stopTest();

        Expense__c held = [SELECT Status__c, Hold_Reason__c FROM Expense__c WHERE Id = :expense.Id];
        System.assertEquals('On_Hold', held.Status__c);
        System.assertEquals('Needs review', held.Hold_Reason__c);

        ExpenseService.unholdExpense(expense.Id);
        Expense__c unheld = [SELECT Status__c, Hold_Reason__c FROM Expense__c WHERE Id = :expense.Id];
        System.assertEquals('Pending', unheld.Status__c);
        System.assertEquals(null, unheld.Hold_Reason__c);
    }

    @isTest
    static void testGetExpensesByReport() {
        Expense_Report__c report = [SELECT Id FROM Expense_Report__c LIMIT 1];

        List<Expense__c> expenses = new List<Expense__c>();
        for (Integer i = 0; i < 5; i++) {
            expenses.add(new Expense__c(
                Amount__c = 10.00 * (i + 1),
                Currency__c = 'USD',
                Merchant__c = 'Merchant ' + i,
                Expense_Date__c = Date.today().addDays(-i),
                Expense_Type__c = 'Cash',
                Status__c = 'Draft',
                Report__c = report.Id
            ));
        }
        insert expenses;

        Test.startTest();
        List<Expense__c> results = ExpenseService.getExpensesByReport(report.Id);
        Test.stopTest();

        System.assertEquals(5, results.size());
    }

    @isTest
    static void testUpdateReportTotals() {
        Expense_Report__c report = [SELECT Id FROM Expense_Report__c LIMIT 1];

        List<Expense__c> expenses = new List<Expense__c>{
            new Expense__c(Amount__c = 100.00, Currency__c = 'USD', Expense_Date__c = Date.today(),
                          Expense_Type__c = 'Cash', Status__c = 'Draft', Report__c = report.Id, Reimbursable__c = true),
            new Expense__c(Amount__c = 200.00, Currency__c = 'USD', Expense_Date__c = Date.today(),
                          Expense_Type__c = 'Cash', Status__c = 'Draft', Report__c = report.Id, Reimbursable__c = false)
        };
        insert expenses;

        Test.startTest();
        ExpenseService.updateReportTotals(report.Id);
        Test.stopTest();

        Expense_Report__c updated = [SELECT Total_Amount__c, Expense_Count__c FROM Expense_Report__c WHERE Id = :report.Id];
        System.assertEquals(300.00, updated.Total_Amount__c);
        System.assertEquals(2, updated.Expense_Count__c);
    }

    @isTest
    static void testAssignToReport() {
        Expense_Report__c report = [SELECT Id FROM Expense_Report__c LIMIT 1];

        Expense__c expense = new Expense__c(
            Amount__c = 50.00,
            Currency__c = 'USD',
            Expense_Date__c = Date.today(),
            Expense_Type__c = 'Cash',
            Status__c = 'Draft'
        );
        insert expense;

        Test.startTest();
        ExpenseService.assignToReport(new List<Id>{ expense.Id }, report.Id);
        Test.stopTest();

        Expense__c updated = [SELECT Report__c FROM Expense__c WHERE Id = :expense.Id];
        System.assertEquals(report.Id, updated.Report__c);
    }
}
