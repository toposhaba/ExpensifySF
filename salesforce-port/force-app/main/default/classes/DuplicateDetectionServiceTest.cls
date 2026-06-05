@isTest
private class DuplicateDetectionServiceTest {

    @TestSetup
    static void setupTestData() {
        Expense_Policy__c policy = new Expense_Policy__c(
            Name = 'Dup Policy',
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
    }

    private static Expense__c buildExpense(Decimal amount, String merchant, Date expenseDate, Id policyId, Id reportId) {
        return new Expense__c(
            Amount__c = amount,
            Currency__c = 'USD',
            Merchant__c = merchant,
            Expense_Date__c = expenseDate,
            Expense_Type__c = 'Cash',
            Status__c = 'Draft',
            Policy__c = policyId,
            Report__c = reportId,
            Reimbursable__c = true,
            Has_Receipt__c = true
        );
    }

    @isTest
    static void testDuplicateFound() {
        Expense_Policy__c policy = [SELECT Id FROM Expense_Policy__c LIMIT 1];
        Date today = Date.today();

        Expense__c original = buildExpense(50.00, 'Coffee Shop', today, policy.Id, null);
        Expense__c duplicate = buildExpense(50.00, 'coffee shop', today.addDays(1), policy.Id, null);
        insert new List<Expense__c>{ original, duplicate };

        Test.startTest();
        List<Expense_Violation__c> created = DuplicateDetectionService.detectDuplicates(original.Id);
        Test.stopTest();

        System.assertEquals(1, created.size(), 'Should flag one duplicate');

        List<Expense_Violation__c> violations = [
            SELECT Violation_Type__c, Status__c, Duplicate_Expense__c
            FROM Expense_Violation__c
            WHERE Expense__c = :original.Id
        ];
        System.assertEquals(1, violations.size());
        System.assertEquals('Duplicate', violations[0].Violation_Type__c);
        System.assertEquals('Open', violations[0].Status__c);
        System.assertEquals(duplicate.Id, violations[0].Duplicate_Expense__c);
    }

    @isTest
    static void testNoFalsePositiveDifferentAmount() {
        Expense_Policy__c policy = [SELECT Id FROM Expense_Policy__c LIMIT 1];
        Date today = Date.today();

        Expense__c original = buildExpense(50.00, 'Coffee Shop', today, policy.Id, null);
        Expense__c other = buildExpense(75.00, 'Coffee Shop', today, policy.Id, null);
        insert new List<Expense__c>{ original, other };

        Test.startTest();
        List<Expense_Violation__c> created = DuplicateDetectionService.detectDuplicates(original.Id);
        Test.stopTest();

        System.assertEquals(0, created.size(), 'Different amount must not be flagged');
    }

    @isTest
    static void testNoFalsePositiveDifferentMerchant() {
        Expense_Policy__c policy = [SELECT Id FROM Expense_Policy__c LIMIT 1];
        Date today = Date.today();

        Expense__c original = buildExpense(50.00, 'Coffee Shop', today, policy.Id, null);
        Expense__c other = buildExpense(50.00, 'Gas Station', today, policy.Id, null);
        insert new List<Expense__c>{ original, other };

        Test.startTest();
        List<Expense_Violation__c> created = DuplicateDetectionService.detectDuplicates(original.Id);
        Test.stopTest();

        System.assertEquals(0, created.size(), 'Different merchant must not be flagged');
    }

    @isTest
    static void testNoFalsePositiveOutsideDateWindow() {
        Expense_Policy__c policy = [SELECT Id FROM Expense_Policy__c LIMIT 1];
        Date today = Date.today();

        Expense__c original = buildExpense(50.00, 'Coffee Shop', today, policy.Id, null);
        Expense__c other = buildExpense(50.00, 'Coffee Shop', today.addDays(-30), policy.Id, null);
        insert new List<Expense__c>{ original, other };

        Test.startTest();
        List<Expense_Violation__c> created = DuplicateDetectionService.detectDuplicates(original.Id, 3);
        Test.stopTest();

        System.assertEquals(0, created.size(), 'Outside date window must not be flagged');
    }

    @isTest
    static void testNoFalsePositiveDifferentPolicy() {
        Expense_Policy__c policy = [SELECT Id FROM Expense_Policy__c LIMIT 1];
        Expense_Policy__c otherPolicy = new Expense_Policy__c(
            Name = 'Other Policy',
            Currency__c = 'USD',
            Type__c = 'Corporate',
            Approval_Mode__c = 'Basic'
        );
        insert otherPolicy;
        Date today = Date.today();

        Expense__c original = buildExpense(50.00, 'Coffee Shop', today, policy.Id, null);
        Expense__c other = buildExpense(50.00, 'Coffee Shop', today, otherPolicy.Id, null);
        insert new List<Expense__c>{ original, other };

        Test.startTest();
        List<Expense_Violation__c> created = DuplicateDetectionService.detectDuplicates(original.Id);
        Test.stopTest();

        System.assertEquals(0, created.size(), 'Different policy must not be flagged');
    }

    @isTest
    static void testNoDuplicateViolationsCreatedTwice() {
        Expense_Policy__c policy = [SELECT Id FROM Expense_Policy__c LIMIT 1];
        Date today = Date.today();

        Expense__c original = buildExpense(50.00, 'Coffee Shop', today, policy.Id, null);
        Expense__c duplicate = buildExpense(50.00, 'Coffee Shop', today, policy.Id, null);
        insert new List<Expense__c>{ original, duplicate };

        Test.startTest();
        DuplicateDetectionService.detectDuplicates(original.Id);
        List<Expense_Violation__c> secondRun = DuplicateDetectionService.detectDuplicates(original.Id);
        Test.stopTest();

        System.assertEquals(0, secondRun.size(), 'Second run should not re-create violations');
        Integer total = [
            SELECT COUNT()
            FROM Expense_Violation__c
            WHERE Expense__c = :original.Id AND Violation_Type__c = 'Duplicate'
        ];
        System.assertEquals(1, total, 'Only one violation should exist');
    }

    @isTest
    static void testResolveDuplicate() {
        Expense_Policy__c policy = [SELECT Id FROM Expense_Policy__c LIMIT 1];
        Date today = Date.today();

        Expense__c original = buildExpense(50.00, 'Coffee Shop', today, policy.Id, null);
        Expense__c duplicate = buildExpense(50.00, 'Coffee Shop', today, policy.Id, null);
        insert new List<Expense__c>{ original, duplicate };

        List<Expense_Violation__c> created = DuplicateDetectionService.detectDuplicates(original.Id);
        System.assertEquals(1, created.size());

        Test.startTest();
        DuplicateDetectionService.resolveDuplicate(created[0].Id);
        Test.stopTest();

        Expense_Violation__c resolved = [
            SELECT Status__c FROM Expense_Violation__c WHERE Id = :created[0].Id
        ];
        System.assertEquals('Resolved', resolved.Status__c);
    }

    @isTest
    static void testDismissDuplicate() {
        Expense_Policy__c policy = [SELECT Id FROM Expense_Policy__c LIMIT 1];
        Date today = Date.today();

        Expense__c original = buildExpense(50.00, 'Coffee Shop', today, policy.Id, null);
        Expense__c duplicate = buildExpense(50.00, 'Coffee Shop', today, policy.Id, null);
        insert new List<Expense__c>{ original, duplicate };

        List<Expense_Violation__c> created = DuplicateDetectionService.detectDuplicates(original.Id);

        Test.startTest();
        DuplicateDetectionService.dismissDuplicate(created[0].Id);
        Test.stopTest();

        Expense_Violation__c dismissed = [
            SELECT Status__c FROM Expense_Violation__c WHERE Id = :created[0].Id
        ];
        System.assertEquals('Dismissed', dismissed.Status__c);
    }

    @isTest
    static void testFindPotentialDuplicatesScopedByReport() {
        Expense_Report__c report = [SELECT Id FROM Expense_Report__c LIMIT 1];
        Date today = Date.today();

        Expense__c original = buildExpense(50.00, 'Coffee Shop', today, null, report.Id);
        Expense__c duplicate = buildExpense(50.00, 'Coffee Shop', today, null, report.Id);
        insert new List<Expense__c>{ original, duplicate };

        Test.startTest();
        List<Expense__c> dups = DuplicateDetectionService.findPotentialDuplicates(original.Id);
        Test.stopTest();

        System.assertEquals(1, dups.size(), 'Should find duplicate scoped by report');
        System.assertEquals(duplicate.Id, dups[0].Id);
    }

    @isTest
    static void testFindPotentialDuplicatesNoScopeReturnsEmpty() {
        Date today = Date.today();
        Expense__c orphan = buildExpense(50.00, 'Coffee Shop', today, null, null);
        insert orphan;

        Test.startTest();
        List<Expense__c> dups = DuplicateDetectionService.findPotentialDuplicates(orphan.Id);
        Test.stopTest();

        System.assertEquals(0, dups.size(), 'No policy or report means no scope to search');
    }

    @isTest
    static void testInvocableCheckDuplicates() {
        Expense_Policy__c policy = [SELECT Id FROM Expense_Policy__c LIMIT 1];
        Date today = Date.today();

        Expense__c original = buildExpense(50.00, 'Coffee Shop', today, policy.Id, null);
        Expense__c duplicate = buildExpense(50.00, 'Coffee Shop', today, policy.Id, null);
        insert new List<Expense__c>{ original, duplicate };

        InvocableCheckDuplicates.Request req = new InvocableCheckDuplicates.Request();
        req.expenseId = original.Id;
        req.dateWindowDays = 5;

        Test.startTest();
        List<InvocableCheckDuplicates.Results> results =
            InvocableCheckDuplicates.execute(new List<InvocableCheckDuplicates.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assert(results[0].isSuccess, 'Invocable should succeed');
        System.assert(results[0].hasDuplicates, 'Should report duplicates found');
        System.assertEquals(1, results[0].duplicatesFound);
        System.assertEquals(1, results[0].violationIds.size());
    }

    @isTest
    static void testInvocableHandlesError() {
        InvocableCheckDuplicates.Request req = new InvocableCheckDuplicates.Request();
        req.expenseId = null;

        Test.startTest();
        List<InvocableCheckDuplicates.Results> results =
            InvocableCheckDuplicates.execute(new List<InvocableCheckDuplicates.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(false, results[0].isSuccess, 'Null expense id should fail gracefully');
        System.assertNotEquals(null, results[0].errorMessage);
    }

    @isTest
    static void testControllerMethods() {
        Expense_Policy__c policy = [SELECT Id FROM Expense_Policy__c LIMIT 1];
        Date today = Date.today();

        Expense__c original = buildExpense(50.00, 'Coffee Shop', today, policy.Id, null);
        Expense__c duplicate = buildExpense(50.00, 'Coffee Shop', today, policy.Id, null);
        insert new List<Expense__c>{ original, duplicate };

        Test.startTest();
        Integer found = DuplicateDetectionService.checkForDuplicates(original.Id);
        List<Expense_Violation__c> violations = DuplicateDetectionService.getDuplicateViolationsForExpense(original.Id);
        DuplicateDetectionService.keepDuplicate(violations[0].Id);
        DuplicateDetectionService.removeDuplicateViolation(violations[0].Id);
        Test.stopTest();

        System.assertEquals(1, found);
        System.assertEquals(1, violations.size());
        Expense_Violation__c finalState = [
            SELECT Status__c FROM Expense_Violation__c WHERE Id = :violations[0].Id
        ];
        System.assertEquals('Resolved', finalState.Status__c);
    }
}
