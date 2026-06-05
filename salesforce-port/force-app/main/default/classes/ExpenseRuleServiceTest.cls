@isTest
private class ExpenseRuleServiceTest {

    @TestSetup
    static void setupData() {
        Expense_Policy__c policy = new Expense_Policy__c(
            Name = 'Rules Policy',
            Currency__c = 'USD',
            Type__c = 'Corporate',
            Approval_Mode__c = 'Basic'
        );
        insert policy;

        List<Expense_Category__c> categories = new List<Expense_Category__c>{
            new Expense_Category__c(Name = 'Travel', Policy__c = policy.Id, Enabled__c = true),
            new Expense_Category__c(Name = 'Meals', Policy__c = policy.Id, Enabled__c = true)
        };
        insert categories;

        Expense_Tag__c tag = new Expense_Tag__c(Name = 'Billable', Policy__c = policy.Id, Enabled__c = true);
        insert tag;
    }

    private static Expense_Policy__c getPolicy() {
        return [SELECT Id FROM Expense_Policy__c WHERE Name = 'Rules Policy' LIMIT 1];
    }

    private static Expense_Category__c getCategory(String name) {
        return [SELECT Id FROM Expense_Category__c WHERE Name = :name LIMIT 1];
    }

    private static Expense_Tag__c getTag() {
        return [SELECT Id FROM Expense_Tag__c WHERE Name = 'Billable' LIMIT 1];
    }

    private static Expense__c newExpense(Id policyId, String merchant) {
        return new Expense__c(
            Amount__c = 25,
            Currency__c = 'USD',
            Expense_Date__c = Date.today(),
            Expense_Type__c = 'Cash',
            Status__c = 'Draft',
            Merchant__c = merchant,
            Policy__c = policyId
        );
    }

    @isTest
    static void testCreateAndGetRule() {
        Expense_Policy__c policy = getPolicy();
        Expense_Category__c cat = getCategory('Travel');

        Test.startTest();
        ExpenseRuleService.createRule(policy.Id, 'Uber', 'Contains', cat.Id, null, true);
        Test.stopTest();

        List<Expense_Rule__c> rules = ExpenseRuleService.getRules(policy.Id);
        System.assertEquals(1, rules.size());
        System.assertEquals('Uber', rules[0].Merchant_Match__c);
        System.assertEquals('Contains', rules[0].Match_Type__c);
        System.assertEquals(cat.Id, rules[0].Apply_Category__c);
        System.assertEquals(true, rules[0].Enabled__c);
    }

    @isTest
    static void testCreateRuleDefaults() {
        Expense_Policy__c policy = getPolicy();
        Test.startTest();
        Expense_Rule__c rule = ExpenseRuleService.createRule(policy.Id, 'Delta', null, null, null, null);
        Test.stopTest();
        Expense_Rule__c saved = [SELECT Match_Type__c, Enabled__c FROM Expense_Rule__c WHERE Id = :rule.Id];
        System.assertEquals('Contains', saved.Match_Type__c);
        System.assertEquals(true, saved.Enabled__c);
    }

    @isTest
    static void testUpdateRule() {
        Expense_Policy__c policy = getPolicy();
        Expense_Category__c cat = getCategory('Travel');
        Expense_Tag__c tag = getTag();
        Expense_Rule__c rule = ExpenseRuleService.createRule(policy.Id, 'Uber', 'Contains', cat.Id, null, true);

        Test.startTest();
        ExpenseRuleService.updateRule(rule.Id, 'Lyft', 'Equals', null, tag.Id, false);
        Test.stopTest();

        Expense_Rule__c saved = [
            SELECT Merchant_Match__c, Match_Type__c, Apply_Category__c, Apply_Tag__c, Enabled__c
            FROM Expense_Rule__c WHERE Id = :rule.Id
        ];
        System.assertEquals('Lyft', saved.Merchant_Match__c);
        System.assertEquals('Equals', saved.Match_Type__c);
        System.assertEquals(null, saved.Apply_Category__c);
        System.assertEquals(tag.Id, saved.Apply_Tag__c);
        System.assertEquals(false, saved.Enabled__c);
    }

    @isTest
    static void testDeleteRule() {
        Expense_Policy__c policy = getPolicy();
        Expense_Rule__c rule = ExpenseRuleService.createRule(policy.Id, 'Uber', 'Contains', null, null, true);

        Test.startTest();
        ExpenseRuleService.deleteRule(rule.Id);
        Test.stopTest();

        System.assertEquals(0, ExpenseRuleService.getRules(policy.Id).size());
    }

    @isTest
    static void testApplyContains() {
        Expense_Policy__c policy = getPolicy();
        Expense_Category__c cat = getCategory('Travel');
        ExpenseRuleService.createRule(policy.Id, 'uber', 'Contains', cat.Id, null, true);

        Expense__c exp = newExpense(policy.Id, 'UBER TRIP 1234');
        insert exp;

        Test.startTest();
        ExpenseRuleService.applyRules(exp.Id);
        Test.stopTest();

        Expense__c saved = [SELECT Category__c FROM Expense__c WHERE Id = :exp.Id];
        System.assertEquals(cat.Id, saved.Category__c);
    }

    @isTest
    static void testApplyEquals() {
        Expense_Policy__c policy = getPolicy();
        Expense_Category__c cat = getCategory('Meals');
        ExpenseRuleService.createRule(policy.Id, 'Starbucks', 'Equals', cat.Id, null, true);

        Expense__c match = newExpense(policy.Id, 'Starbucks');
        Expense__c noMatch = newExpense(policy.Id, 'Starbucks Reserve');
        insert new List<Expense__c>{ match, noMatch };

        Test.startTest();
        ExpenseRuleService.applyRules(match.Id);
        ExpenseRuleService.applyRules(noMatch.Id);
        Test.stopTest();

        System.assertEquals(cat.Id, [SELECT Category__c FROM Expense__c WHERE Id = :match.Id].Category__c);
        System.assertEquals(null, [SELECT Category__c FROM Expense__c WHERE Id = :noMatch.Id].Category__c);
    }

    @isTest
    static void testApplyStartsWith() {
        Expense_Policy__c policy = getPolicy();
        Expense_Category__c cat = getCategory('Travel');
        ExpenseRuleService.createRule(policy.Id, 'Hotel', 'StartsWith', cat.Id, null, true);

        Expense__c match = newExpense(policy.Id, 'Hotel California');
        Expense__c noMatch = newExpense(policy.Id, 'Grand Hotel');
        insert new List<Expense__c>{ match, noMatch };

        Test.startTest();
        ExpenseRuleService.applyRules(match.Id);
        ExpenseRuleService.applyRules(noMatch.Id);
        Test.stopTest();

        System.assertEquals(cat.Id, [SELECT Category__c FROM Expense__c WHERE Id = :match.Id].Category__c);
        System.assertEquals(null, [SELECT Category__c FROM Expense__c WHERE Id = :noMatch.Id].Category__c);
    }

    @isTest
    static void testFirstMatchWins() {
        Expense_Policy__c policy = getPolicy();
        Expense_Category__c travel = getCategory('Travel');
        Expense_Category__c meals = getCategory('Meals');
        ExpenseRuleService.createRule(policy.Id, 'Air', 'Contains', travel.Id, null, true);
        ExpenseRuleService.createRule(policy.Id, 'Airport', 'Contains', meals.Id, null, true);

        Expense__c exp = newExpense(policy.Id, 'Airport Lounge');
        insert exp;

        Test.startTest();
        ExpenseRuleService.applyRules(exp.Id);
        Test.stopTest();

        System.assertEquals(travel.Id, [SELECT Category__c FROM Expense__c WHERE Id = :exp.Id].Category__c);
    }

    @isTest
    static void testNoMatchNoOp() {
        Expense_Policy__c policy = getPolicy();
        Expense_Category__c cat = getCategory('Travel');
        ExpenseRuleService.createRule(policy.Id, 'Uber', 'Contains', cat.Id, null, true);

        Expense__c exp = newExpense(policy.Id, 'Local Diner');
        insert exp;

        Test.startTest();
        ExpenseRuleService.applyRules(exp.Id);
        Test.stopTest();

        Expense__c saved = [SELECT Category__c, Tag__c FROM Expense__c WHERE Id = :exp.Id];
        System.assertEquals(null, saved.Category__c);
        System.assertEquals(null, saved.Tag__c);
    }

    @isTest
    static void testDisabledRuleIgnored() {
        Expense_Policy__c policy = getPolicy();
        Expense_Category__c cat = getCategory('Travel');
        ExpenseRuleService.createRule(policy.Id, 'Uber', 'Contains', cat.Id, null, false);

        Expense__c exp = newExpense(policy.Id, 'UBER TRIP');
        insert exp;

        Test.startTest();
        ExpenseRuleService.applyRules(exp.Id);
        Test.stopTest();

        System.assertEquals(null, [SELECT Category__c FROM Expense__c WHERE Id = :exp.Id].Category__c);
    }

    @isTest
    static void testBulkApplyInMemory() {
        Expense_Policy__c policy = getPolicy();
        Expense_Category__c travel = getCategory('Travel');
        Expense_Tag__c tag = getTag();
        ExpenseRuleService.createRule(policy.Id, 'Uber', 'Contains', travel.Id, tag.Id, true);

        List<Expense__c> expenses = new List<Expense__c>();
        for (Integer i = 0; i < 200; i++) {
            expenses.add(newExpense(policy.Id, 'Uber ride ' + i));
        }
        expenses.add(newExpense(policy.Id, 'Unmatched Vendor'));

        Test.startTest();
        ExpenseRuleService.applyRules(expenses);
        Test.stopTest();

        for (Integer i = 0; i < 200; i++) {
            System.assertEquals(travel.Id, expenses[i].Category__c);
            System.assertEquals(tag.Id, expenses[i].Tag__c);
        }
        System.assertEquals(null, expenses[200].Category__c);
    }

    @isTest
    static void testApplyTagOnly() {
        Expense_Policy__c policy = getPolicy();
        Expense_Tag__c tag = getTag();
        ExpenseRuleService.createRule(policy.Id, 'Uber', 'Contains', null, tag.Id, true);

        Expense__c exp = newExpense(policy.Id, 'Uber Eats');
        insert exp;

        Test.startTest();
        ExpenseRuleService.applyRules(exp.Id);
        Test.stopTest();

        Expense__c saved = [SELECT Category__c, Tag__c FROM Expense__c WHERE Id = :exp.Id];
        System.assertEquals(null, saved.Category__c);
        System.assertEquals(tag.Id, saved.Tag__c);
    }

    @isTest
    static void testInvocable() {
        Expense_Policy__c policy = getPolicy();
        Expense_Category__c cat = getCategory('Travel');
        ExpenseRuleService.createRule(policy.Id, 'Uber', 'Contains', cat.Id, null, true);

        Expense__c exp = newExpense(policy.Id, 'Uber Trip');
        insert exp;

        InvocableApplyExpenseRules.Request req = new InvocableApplyExpenseRules.Request();
        req.expenseId = exp.Id;

        Test.startTest();
        List<InvocableApplyExpenseRules.Results> results = InvocableApplyExpenseRules.execute(
            new List<InvocableApplyExpenseRules.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(true, results[0].isSuccess);
        System.assertEquals(cat.Id, results[0].categoryId);
        System.assertEquals(exp.Id, results[0].expenseId);
    }

    @isTest
    static void testInvocableError() {
        InvocableApplyExpenseRules.Request req = new InvocableApplyExpenseRules.Request();
        req.expenseId = null;

        Test.startTest();
        List<InvocableApplyExpenseRules.Results> results = InvocableApplyExpenseRules.execute(
            new List<InvocableApplyExpenseRules.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(false, results[0].isSuccess);
        System.assertNotEquals(null, results[0].errorMessage);
    }

    @isTest
    static void testValidation() {
        Test.startTest();
        try {
            ExpenseRuleService.getRules(null);
            System.assert(false, 'Should throw for missing policy');
        } catch (ExpenseRuleService.RuleException e) {
            System.assert(e.getMessage().contains('Policy'));
        }
        try {
            ExpenseRuleService.createRule(getPolicy().Id, '  ', 'Contains', null, null, true);
            System.assert(false, 'Should throw for blank merchant');
        } catch (ExpenseRuleService.RuleException e) {
            System.assert(e.getMessage().contains('Merchant'));
        }
        try {
            ExpenseRuleService.createRule(null, 'Uber', 'Contains', null, null, true);
            System.assert(false, 'Should throw for missing policy');
        } catch (ExpenseRuleService.RuleException e) {
            System.assert(e.getMessage().contains('Policy'));
        }
        try {
            ExpenseRuleService.updateRule(null, 'Uber', 'Contains', null, null, true);
            System.assert(false, 'Should throw for missing rule');
        } catch (ExpenseRuleService.RuleException e) {
            System.assert(e.getMessage().contains('Rule'));
        }
        try {
            ExpenseRuleService.deleteRule(null);
            System.assert(false, 'Should throw for missing rule');
        } catch (ExpenseRuleService.RuleException e) {
            System.assert(e.getMessage().contains('Rule'));
        }
        Test.stopTest();
    }

    @isTest
    static void testApplyRulesEmptyAndNullSafe() {
        Test.startTest();
        ExpenseRuleService.applyRules(new List<Expense__c>());
        ExpenseRuleService.applyRules((List<Expense__c>) null);
        Test.stopTest();
        System.assert(true);
    }
}
