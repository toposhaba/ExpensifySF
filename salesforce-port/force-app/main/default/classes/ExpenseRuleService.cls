public with sharing class ExpenseRuleService {

    public class RuleException extends Exception {}

    @AuraEnabled(cacheable=true)
    public static List<Expense_Rule__c> getRules(Id policyId) {
        if (policyId == null) {
            throw new RuleException('Policy is required');
        }
        return [
            SELECT Id, Name, Policy__c, Merchant_Match__c, Match_Type__c,
                   Apply_Category__c, Apply_Category__r.Name,
                   Apply_Tag__c, Apply_Tag__r.Name, Enabled__c
            FROM Expense_Rule__c
            WHERE Policy__c = :policyId
            WITH USER_MODE
            ORDER BY Name ASC
        ];
    }

    @AuraEnabled
    public static Expense_Rule__c createRule(Id policyId, String merchantMatch, String matchType, Id applyCategoryId, Id applyTagId, Boolean enabled) {
        if (policyId == null) {
            throw new RuleException('Policy is required');
        }
        if (String.isBlank(merchantMatch)) {
            throw new RuleException('Merchant match is required');
        }
        Expense_Rule__c rule = new Expense_Rule__c(
            Policy__c = policyId,
            Merchant_Match__c = merchantMatch,
            Match_Type__c = String.isBlank(matchType) ? 'Contains' : matchType,
            Apply_Category__c = applyCategoryId,
            Apply_Tag__c = applyTagId,
            Enabled__c = enabled == null ? true : enabled
        );
        insert as user rule;
        return rule;
    }

    @AuraEnabled
    public static Expense_Rule__c updateRule(Id ruleId, String merchantMatch, String matchType, Id applyCategoryId, Id applyTagId, Boolean enabled) {
        if (ruleId == null) {
            throw new RuleException('Rule is required');
        }
        Expense_Rule__c rule = new Expense_Rule__c(Id = ruleId);
        if (String.isNotBlank(merchantMatch)) {
            rule.Merchant_Match__c = merchantMatch;
        }
        if (String.isNotBlank(matchType)) {
            rule.Match_Type__c = matchType;
        }
        rule.Apply_Category__c = applyCategoryId;
        rule.Apply_Tag__c = applyTagId;
        if (enabled != null) {
            rule.Enabled__c = enabled;
        }
        update as user rule;
        return rule;
    }

    @AuraEnabled
    public static void deleteRule(Id ruleId) {
        if (ruleId == null) {
            throw new RuleException('Rule is required');
        }
        List<Expense_Rule__c> rules = [
            SELECT Id FROM Expense_Rule__c WHERE Id = :ruleId WITH USER_MODE LIMIT 1
        ];
        if (rules.isEmpty()) {
            throw new RuleException('Rule not found');
        }
        delete as user rules;
    }

    @AuraEnabled
    public static Expense__c applyRules(Id expenseId) {
        if (expenseId == null) {
            throw new RuleException('Expense is required');
        }
        List<Expense__c> expenses = [
            SELECT Id, Merchant__c, Policy__c, Category__c, Tag__c
            FROM Expense__c
            WHERE Id = :expenseId
            WITH USER_MODE
            LIMIT 1
        ];
        if (expenses.isEmpty()) {
            throw new RuleException('Expense not found');
        }
        applyRules(expenses);
        update as user expenses;
        return expenses[0];
    }

    public static void applyRules(List<Expense__c> expenses) {
        if (expenses == null || expenses.isEmpty()) {
            return;
        }

        Set<Id> policyIds = new Set<Id>();
        for (Expense__c exp : expenses) {
            if (exp.Policy__c != null && String.isNotBlank(exp.Merchant__c)) {
                policyIds.add(exp.Policy__c);
            }
        }
        if (policyIds.isEmpty()) {
            return;
        }

        Map<Id, List<Expense_Rule__c>> rulesByPolicy = new Map<Id, List<Expense_Rule__c>>();
        for (Expense_Rule__c rule : [
            SELECT Id, Policy__c, Merchant_Match__c, Match_Type__c,
                   Apply_Category__c, Apply_Tag__c, Enabled__c
            FROM Expense_Rule__c
            WHERE Policy__c IN :policyIds AND Enabled__c = true
            ORDER BY Name ASC
        ]) {
            if (!rulesByPolicy.containsKey(rule.Policy__c)) {
                rulesByPolicy.put(rule.Policy__c, new List<Expense_Rule__c>());
            }
            rulesByPolicy.get(rule.Policy__c).add(rule);
        }

        for (Expense__c exp : expenses) {
            if (exp.Policy__c == null || String.isBlank(exp.Merchant__c)) {
                continue;
            }
            List<Expense_Rule__c> rules = rulesByPolicy.get(exp.Policy__c);
            if (rules == null) {
                continue;
            }
            for (Expense_Rule__c rule : rules) {
                if (matches(exp.Merchant__c, rule)) {
                    if (rule.Apply_Category__c != null) {
                        exp.Category__c = rule.Apply_Category__c;
                    }
                    if (rule.Apply_Tag__c != null) {
                        exp.Tag__c = rule.Apply_Tag__c;
                    }
                    break;
                }
            }
        }
    }

    private static Boolean matches(String merchant, Expense_Rule__c rule) {
        if (String.isBlank(merchant) || String.isBlank(rule.Merchant_Match__c)) {
            return false;
        }
        String source = merchant.toLowerCase();
        String target = rule.Merchant_Match__c.toLowerCase();
        if (rule.Match_Type__c == 'Equals') {
            return source.equals(target);
        }
        if (rule.Match_Type__c == 'StartsWith') {
            return source.startsWith(target);
        }
        return source.contains(target);
    }
}
