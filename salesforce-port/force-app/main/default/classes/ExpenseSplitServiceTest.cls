@isTest
private class ExpenseSplitServiceTest {

    private static Expense__c buildExpense(Decimal amount) {
        return new Expense__c(
            Amount__c = amount,
            Currency__c = 'USD',
            Merchant__c = 'Split Merchant',
            Expense_Date__c = Date.today(),
            Expense_Type__c = 'Cash',
            Status__c = 'Draft',
            Reimbursable__c = true,
            Has_Receipt__c = false
        );
    }

    private static ExpenseSplitService.SplitInput amountInput(Id userId, Decimal amount) {
        ExpenseSplitService.SplitInput input = new ExpenseSplitService.SplitInput();
        input.userId = userId;
        input.amount = amount;
        return input;
    }

    private static ExpenseSplitService.SplitInput shareInput(Id userId, Decimal share) {
        ExpenseSplitService.SplitInput input = new ExpenseSplitService.SplitInput();
        input.userId = userId;
        input.share = share;
        return input;
    }

    @isTest
    static void testEvenSplitByShare() {
        Expense__c parent = buildExpense(100.00);
        insert parent;
        Id userId = UserInfo.getUserId();

        List<ExpenseSplitService.SplitInput> inputs = new List<ExpenseSplitService.SplitInput>{
            shareInput(userId, null),
            shareInput(userId, null),
            shareInput(userId, null),
            shareInput(userId, null)
        };

        Test.startTest();
        List<Expense_Split__c> splits = ExpenseSplitService.createSplits(parent.Id, inputs, 'Share');
        Test.stopTest();

        System.assertEquals(4, splits.size(), 'Four splits should be created');
        Decimal total = 0;
        for (Expense_Split__c split : splits) {
            System.assertEquals(25.00, split.Split_Amount__c, 'Even split should be 25.00 each');
            total += split.Split_Amount__c;
        }
        System.assertEquals(100.00, total, 'Splits should sum to parent amount');
    }

    @isTest
    static void testShareSplitWithRoundingRemainder() {
        Expense__c parent = buildExpense(100.00);
        insert parent;
        Id userId = UserInfo.getUserId();

        List<ExpenseSplitService.SplitInput> inputs = new List<ExpenseSplitService.SplitInput>{
            shareInput(userId, 1),
            shareInput(userId, 1),
            shareInput(userId, 1)
        };

        Test.startTest();
        List<Expense_Split__c> splits = ExpenseSplitService.createSplits(parent.Id, inputs, 'Share');
        Test.stopTest();

        Decimal total = 0;
        for (Expense_Split__c split : splits) {
            total += split.Split_Amount__c;
        }
        System.assertEquals(100.00, total, 'Rounded shares must still sum to parent amount');
        System.assertEquals(33.34, splits.get(2).Split_Amount__c, 'Last split should absorb the rounding remainder');
    }

    @isTest
    static void testWeightedShareSplit() {
        Expense__c parent = buildExpense(120.00);
        insert parent;
        Id userId = UserInfo.getUserId();

        List<ExpenseSplitService.SplitInput> inputs = new List<ExpenseSplitService.SplitInput>{
            shareInput(userId, 1),
            shareInput(userId, 3)
        };

        Test.startTest();
        List<Expense_Split__c> splits = ExpenseSplitService.createSplits(parent.Id, inputs, 'Share');
        Test.stopTest();

        System.assertEquals(30.00, splits.get(0).Split_Amount__c, 'First share is one quarter');
        System.assertEquals(90.00, splits.get(1).Split_Amount__c, 'Second share is three quarters');
    }

    @isTest
    static void testCustomAmountSplit() {
        Expense__c parent = buildExpense(100.00);
        insert parent;
        Id userId = UserInfo.getUserId();

        List<ExpenseSplitService.SplitInput> inputs = new List<ExpenseSplitService.SplitInput>{
            amountInput(userId, 60.00),
            amountInput(userId, 40.00)
        };

        Test.startTest();
        List<Expense_Split__c> splits = ExpenseSplitService.createSplits(parent.Id, inputs, 'Amount');
        Test.stopTest();

        System.assertEquals(2, splits.size(), 'Two splits should be created');
        System.assertEquals(60.00, splits.get(0).Split_Amount__c, 'First custom amount preserved');
        System.assertEquals(40.00, splits.get(1).Split_Amount__c, 'Second custom amount preserved');
        System.assertEquals(60.00, splits.get(0).Split_Percentage__c, 'Percentage derived from amount');
    }

    @isTest
    static void testSumMismatchThrows() {
        Expense__c parent = buildExpense(100.00);
        insert parent;
        Id userId = UserInfo.getUserId();

        List<ExpenseSplitService.SplitInput> inputs = new List<ExpenseSplitService.SplitInput>{
            amountInput(userId, 60.00),
            amountInput(userId, 30.00)
        };

        Test.startTest();
        try {
            ExpenseSplitService.createSplits(parent.Id, inputs, 'Amount');
            System.assert(false, 'Should have thrown for sum mismatch');
        } catch (ExpenseSplitService.SplitException e) {
            System.assert(e.getMessage().contains('must equal'), 'Expected sum mismatch error');
        }
        Test.stopTest();
    }

    @isTest
    static void testNullParentThrows() {
        Id userId = UserInfo.getUserId();
        Test.startTest();
        try {
            ExpenseSplitService.createSplits(null, new List<ExpenseSplitService.SplitInput>{ amountInput(userId, 10) }, 'Amount');
            System.assert(false, 'Should have thrown for null parent');
        } catch (ExpenseSplitService.SplitException e) {
            System.assert(e.getMessage().contains('required'), 'Expected required parent error');
        }
        Test.stopTest();
    }

    @isTest
    static void testEmptyInputsThrows() {
        Expense__c parent = buildExpense(50.00);
        insert parent;
        Test.startTest();
        try {
            ExpenseSplitService.createSplits(parent.Id, new List<ExpenseSplitService.SplitInput>(), 'Amount');
            System.assert(false, 'Should have thrown for empty inputs');
        } catch (ExpenseSplitService.SplitException e) {
            System.assert(e.getMessage().contains('At least one'), 'Expected empty inputs error');
        }
        Test.stopTest();
    }

    @isTest
    static void testInvalidAmountThrows() {
        Expense__c parent = buildExpense(50.00);
        insert parent;
        Id userId = UserInfo.getUserId();
        Test.startTest();
        try {
            ExpenseSplitService.createSplits(parent.Id, new List<ExpenseSplitService.SplitInput>{ amountInput(userId, 0) }, 'Amount');
            System.assert(false, 'Should have thrown for non-positive amount');
        } catch (ExpenseSplitService.SplitException e) {
            System.assert(e.getMessage().contains('greater than zero'), 'Expected positive amount error');
        }
        Test.stopTest();
    }

    @isTest
    static void testListSplits() {
        Expense__c parent = buildExpense(100.00);
        insert parent;
        Id userId = UserInfo.getUserId();
        ExpenseSplitService.createSplits(parent.Id, new List<ExpenseSplitService.SplitInput>{
            amountInput(userId, 50.00),
            amountInput(userId, 50.00)
        }, 'Amount');

        Test.startTest();
        List<Expense_Split__c> splits = ExpenseSplitService.listSplits(parent.Id);
        Test.stopTest();

        System.assertEquals(2, splits.size(), 'Both splits should be returned');
    }

    @isTest
    static void testGetParentExpense() {
        Expense__c parent = buildExpense(75.00);
        insert parent;

        Test.startTest();
        Expense__c result = ExpenseSplitService.getParentExpense(parent.Id);
        Test.stopTest();

        System.assertEquals(75.00, result.Amount__c, 'Parent amount should be returned');
    }

    @isTest
    static void testCreateSplitsApexSuccess() {
        Expense__c parent = buildExpense(100.00);
        insert parent;
        Id userId = UserInfo.getUserId();

        Test.startTest();
        List<Expense_Split__c> splits = ExpenseSplitService.createSplitsApex(parent.Id, new List<ExpenseSplitService.SplitInput>{
            amountInput(userId, 100.00)
        }, 'Amount');
        Test.stopTest();

        System.assertEquals(1, splits.size(), 'One split should be created via Aura wrapper');
    }

    @isTest
    static void testCreateSplitsApexError() {
        Expense__c parent = buildExpense(100.00);
        insert parent;
        Id userId = UserInfo.getUserId();

        Test.startTest();
        try {
            ExpenseSplitService.createSplitsApex(parent.Id, new List<ExpenseSplitService.SplitInput>{
                amountInput(userId, 10.00)
            }, 'Amount');
            System.assert(false, 'Should have thrown for sum mismatch via Aura wrapper');
        } catch (Exception e) {
            System.assert(true, 'Aura wrapper surfaced the error');
        }
        Test.stopTest();
    }

    @isTest
    static void testInvocableSplitSuccess() {
        Expense__c parent = buildExpense(100.00);
        insert parent;
        Id userId = UserInfo.getUserId();

        InvocableSplitExpense.Request req = new InvocableSplitExpense.Request();
        req.parentExpenseId = parent.Id;
        req.mode = 'Amount';
        req.splitUserIds = new List<Id>{ userId, userId };
        req.splitAmounts = new List<Decimal>{ 70.00, 30.00 };

        Test.startTest();
        List<InvocableSplitExpense.Results> results = InvocableSplitExpense.execute(
            new List<InvocableSplitExpense.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(true, results.get(0).isSuccess, 'Invocable split should succeed');
        System.assertEquals(2, results.get(0).splitCount, 'Two splits should be created');
    }

    @isTest
    static void testInvocableSplitFailure() {
        Expense__c parent = buildExpense(100.00);
        insert parent;
        Id userId = UserInfo.getUserId();

        InvocableSplitExpense.Request req = new InvocableSplitExpense.Request();
        req.parentExpenseId = parent.Id;
        req.mode = 'Amount';
        req.splitUserIds = new List<Id>{ userId };
        req.splitAmounts = new List<Decimal>{ 25.00 };

        Test.startTest();
        List<InvocableSplitExpense.Results> results = InvocableSplitExpense.execute(
            new List<InvocableSplitExpense.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(false, results.get(0).isSuccess, 'Invocable split should fail on mismatch');
        System.assertNotEquals(null, results.get(0).errorMessage, 'Error message should be populated');
    }

    @isTest
    static void testInvocableShareMode() {
        Expense__c parent = buildExpense(90.00);
        insert parent;
        Id userId = UserInfo.getUserId();

        InvocableSplitExpense.Request req = new InvocableSplitExpense.Request();
        req.parentExpenseId = parent.Id;
        req.mode = 'Share';
        req.splitUserIds = new List<Id>{ userId, userId, userId };
        req.splitShares = new List<Decimal>{ 1, 1, 1 };

        Test.startTest();
        List<InvocableSplitExpense.Results> results = InvocableSplitExpense.execute(
            new List<InvocableSplitExpense.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(true, results.get(0).isSuccess, 'Share-mode invocable split should succeed');
        System.assertEquals(3, results.get(0).splitCount, 'Three splits should be created');
    }
}
