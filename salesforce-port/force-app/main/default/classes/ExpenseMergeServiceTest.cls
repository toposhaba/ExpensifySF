@isTest
private class ExpenseMergeServiceTest {

    @TestSetup
    static void setupTestData() {
        Expense_Policy__c policy = new Expense_Policy__c(
            Name = 'Merge Policy',
            Currency__c = 'USD',
            Type__c = 'Corporate',
            Approval_Mode__c = 'Basic'
        );
        insert policy;

        Expense_Category__c category = new Expense_Category__c(
            Name = 'Meals',
            Policy__c = policy.Id,
            GL_Code__c = '6001',
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

    private static Expense__c buildExpense(String merchant, Decimal amount) {
        return new Expense__c(
            Amount__c = amount,
            Currency__c = 'USD',
            Merchant__c = merchant,
            Expense_Date__c = Date.today(),
            Expense_Type__c = 'Cash',
            Status__c = 'Draft',
            Reimbursable__c = true,
            Has_Receipt__c = false
        );
    }

    @isTest
    static void testMergeKeepsSelectedValues() {
        Expense__c survivor = buildExpense('Survivor Merchant', 100.00);
        Expense__c other = buildExpense('Other Merchant', 250.00);
        insert new List<Expense__c>{ survivor, other };

        Map<String, Id> selections = new Map<String, Id>{
            'Amount__c' => other.Id,
            'Merchant__c' => other.Id,
            'Description__c' => survivor.Id
        };

        Test.startTest();
        Expense__c merged = ExpenseMergeService.mergeExpenses(survivor.Id, other.Id, selections);
        Test.stopTest();

        System.assertEquals(survivor.Id, merged.Id, 'Survivor record should be kept');

        Expense__c saved = [SELECT Amount__c, Merchant__c FROM Expense__c WHERE Id = :survivor.Id];
        System.assertEquals(250.00, saved.Amount__c, 'Amount should come from the other expense');
        System.assertEquals('Other Merchant', saved.Merchant__c, 'Merchant should come from the other expense');

        List<Expense__c> remaining = [SELECT Id FROM Expense__c WHERE Id = :other.Id];
        System.assert(remaining.isEmpty(), 'The other expense should be deleted');
    }

    @isTest
    static void testMergeDefaultsToSurvivorValues() {
        Expense__c survivor = buildExpense('Keep Me', 100.00);
        Expense__c other = buildExpense('Drop Me', 250.00);
        insert new List<Expense__c>{ survivor, other };

        Test.startTest();
        Expense__c merged = ExpenseMergeService.mergeExpenses(survivor.Id, other.Id, new Map<String, Id>());
        Test.stopTest();

        Expense__c saved = [SELECT Amount__c, Merchant__c FROM Expense__c WHERE Id = :survivor.Id];
        System.assertEquals(100.00, saved.Amount__c, 'Amount should default to survivor value');
        System.assertEquals('Keep Me', saved.Merchant__c, 'Merchant should default to survivor value');
    }

    @isTest
    static void testReattachesRelatedRecords() {
        Expense__c survivor = buildExpense('Survivor', 100.00);
        Expense__c other = buildExpense('Other', 75.00);
        insert new List<Expense__c>{ survivor, other };

        insert new Expense_Receipt__c(Expense__c = other.Id, File_URL__c = 'https://example.com/r.png', Scan_Status__c = 'Completed');
        insert new Expense_Split__c(Parent_Expense__c = other.Id, Split_Amount__c = 75.00, Split_User__c = UserInfo.getUserId());
        insert new Expense_Comment__c(Expense__c = other.Id, Body__c = 'Original note');

        Test.startTest();
        ExpenseMergeService.mergeExpenses(survivor.Id, other.Id, new Map<String, Id>());
        Test.stopTest();

        List<Expense_Receipt__c> receipts = [SELECT Id FROM Expense_Receipt__c WHERE Expense__c = :survivor.Id];
        System.assertEquals(1, receipts.size(), 'Receipt should be reattached to survivor');

        List<Expense_Split__c> splits = [SELECT Id FROM Expense_Split__c WHERE Parent_Expense__c = :survivor.Id];
        System.assertEquals(1, splits.size(), 'Split should be reattached to survivor');

        List<Expense_Comment__c> comments = [SELECT Id FROM Expense_Comment__c WHERE Expense__c = :survivor.Id];
        System.assertEquals(1, comments.size(), 'Comment should be reattached to survivor');

        List<Expense__c> remaining = [SELECT Id FROM Expense__c WHERE Id = :other.Id];
        System.assert(remaining.isEmpty(), 'The other expense should be deleted');
    }

    @isTest
    static void testMergeUpdatesReportTotals() {
        Expense_Report__c report = [SELECT Id FROM Expense_Report__c LIMIT 1];

        Expense__c survivor = buildExpense('Survivor', 100.00);
        survivor.Report__c = report.Id;
        Expense__c other = buildExpense('Other', 250.00);
        other.Report__c = report.Id;
        insert new List<Expense__c>{ survivor, other };

        Test.startTest();
        ExpenseMergeService.mergeExpenses(survivor.Id, other.Id, new Map<String, Id>{ 'Amount__c' => other.Id });
        Test.stopTest();

        Expense_Report__c updated = [SELECT Total_Amount__c, Expense_Count__c FROM Expense_Report__c WHERE Id = :report.Id];
        System.assertEquals(250.00, updated.Total_Amount__c, 'Report total should reflect the single survivor amount');
        System.assertEquals(1, updated.Expense_Count__c, 'Report should contain only the survivor');
    }

    @isTest
    static void testMergeSelfThrows() {
        Expense__c survivor = buildExpense('Solo', 100.00);
        insert survivor;

        Test.startTest();
        try {
            ExpenseMergeService.mergeExpenses(survivor.Id, survivor.Id, null);
            System.assert(false, 'Should have thrown for self merge');
        } catch (ExpenseMergeService.MergeException e) {
            System.assert(e.getMessage().contains('itself'), 'Expected self-merge error');
        }
        Test.stopTest();
    }

    @isTest
    static void testMergeNullThrows() {
        Test.startTest();
        try {
            ExpenseMergeService.mergeExpenses(null, null, null);
            System.assert(false, 'Should have thrown for null ids');
        } catch (ExpenseMergeService.MergeException e) {
            System.assert(e.getMessage().contains('required'), 'Expected required ids error');
        }
        Test.stopTest();
    }

    @isTest
    static void testGetExpensesForMerge() {
        Expense__c first = buildExpense('First', 100.00);
        Expense__c second = buildExpense('Second', 200.00);
        insert new List<Expense__c>{ first, second };

        Test.startTest();
        List<Expense__c> results = ExpenseMergeService.getExpensesForMerge(first.Id, second.Id);
        Test.stopTest();

        System.assertEquals(2, results.size(), 'Both expenses should be returned for comparison');
    }

    @isTest
    static void testAuraMergeWrapper() {
        Expense__c survivor = buildExpense('Survivor', 100.00);
        Expense__c other = buildExpense('Other', 300.00);
        insert new List<Expense__c>{ survivor, other };

        Test.startTest();
        Id mergedId = ExpenseMergeService.applyMerge(
            survivor.Id,
            other.Id,
            new List<String>{ 'Amount__c' },
            new List<Id>{ other.Id }
        );
        Test.stopTest();

        System.assertEquals(survivor.Id, mergedId, 'Wrapper should return survivor id');
        Expense__c saved = [SELECT Amount__c FROM Expense__c WHERE Id = :survivor.Id];
        System.assertEquals(300.00, saved.Amount__c, 'Amount should be merged from the other expense');
    }

    @isTest
    static void testAuraMergeWrapperHandlesError() {
        Expense__c survivor = buildExpense('Survivor', 100.00);
        insert survivor;

        Test.startTest();
        try {
            ExpenseMergeService.applyMerge(survivor.Id, survivor.Id, null, null);
            System.assert(false, 'Should have thrown for self merge');
        } catch (Exception e) {
            System.assert(true, 'Aura wrapper surfaced the error');
        }
        Test.stopTest();
    }

    @isTest
    static void testInvocableMerge() {
        Expense__c survivor = buildExpense('Survivor', 100.00);
        Expense__c other = buildExpense('Other', 400.00);
        insert new List<Expense__c>{ survivor, other };

        InvocableMergeExpenses.Request req = new InvocableMergeExpenses.Request();
        req.survivorExpenseId = survivor.Id;
        req.otherExpenseId = other.Id;
        req.fieldNames = new List<String>{ 'Amount__c', 'Merchant__c' };
        req.fieldSourceExpenseIds = new List<Id>{ other.Id, other.Id };

        Test.startTest();
        List<InvocableMergeExpenses.Results> results = InvocableMergeExpenses.execute(
            new List<InvocableMergeExpenses.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(true, results[0].isSuccess, 'Merge should succeed');
        System.assertEquals(survivor.Id, results[0].mergedExpenseId, 'Survivor id should be returned');

        Expense__c saved = [SELECT Amount__c, Merchant__c FROM Expense__c WHERE Id = :survivor.Id];
        System.assertEquals(400.00, saved.Amount__c);
        System.assertEquals('Other', saved.Merchant__c);
    }

    @isTest
    static void testInvocableMergeReportsFailure() {
        Expense__c survivor = buildExpense('Survivor', 100.00);
        insert survivor;

        InvocableMergeExpenses.Request req = new InvocableMergeExpenses.Request();
        req.survivorExpenseId = survivor.Id;
        req.otherExpenseId = survivor.Id;

        Test.startTest();
        List<InvocableMergeExpenses.Results> results = InvocableMergeExpenses.execute(
            new List<InvocableMergeExpenses.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(false, results[0].isSuccess, 'Self merge should fail');
        System.assertNotEquals(null, results[0].errorMessage, 'Error message should be populated');
    }
}
