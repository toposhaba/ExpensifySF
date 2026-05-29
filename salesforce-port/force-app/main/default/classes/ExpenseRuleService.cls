public with sharing class ExpenseRuleService {

    public static Expense_Rule__c createRule(Expense_Rule__c rule) {
        insert rule;
        return rule;
    }

    public static List<Expense_Rule__c> getRules(Id policyId) {
        return [
            SELECT Id, Name, Merchant_Pattern__c, Category__c, Category__r.Name,
                   Tag__c, Tag__r.Name, Billable__c, Reimbursable__c, Enabled__c, Description__c
            FROM Expense_Rule__c WHERE Policy__c = :policyId ORDER BY Name
        ];
    }

    public static void deleteRule(Id ruleId) {
        delete [SELECT Id FROM Expense_Rule__c WHERE Id = :ruleId];
    }

    public static void applyRules(List<Id> expenseIds) {
        List<Expense__c> expenses = [
            SELECT Id, Merchant__c, Policy__c, Category__c, Tag__c, Billable__c, Reimbursable__c
            FROM Expense__c WHERE Id IN :expenseIds AND Policy__c != null
        ];

        Set<Id> policyIds = new Set<Id>();
        for (Expense__c exp : expenses) policyIds.add(exp.Policy__c);

        Map<Id, List<Expense_Rule__c>> rulesByPolicy = new Map<Id, List<Expense_Rule__c>>();
        for (Expense_Rule__c rule : [
            SELECT Id, Policy__c, Merchant_Pattern__c, Category__c, Tag__c, Billable__c, Reimbursable__c
            FROM Expense_Rule__c WHERE Policy__c IN :policyIds AND Enabled__c = true ORDER BY Name
        ]) {
            if (!rulesByPolicy.containsKey(rule.Policy__c)) {
                rulesByPolicy.put(rule.Policy__c, new List<Expense_Rule__c>());
            }
            rulesByPolicy.get(rule.Policy__c).add(rule);
        }

        List<Expense__c> toUpdate = new List<Expense__c>();
        for (Expense__c exp : expenses) {
            List<Expense_Rule__c> rules = rulesByPolicy.get(exp.Policy__c);
            if (rules == null) continue;

            for (Expense_Rule__c rule : rules) {
                if (matchesMerchant(exp.Merchant__c, rule.Merchant_Pattern__c)) {
                    Boolean changed = false;
                    if (rule.Category__c != null && exp.Category__c == null) {
                        exp.Category__c = rule.Category__c;
                        changed = true;
                    }
                    if (rule.Tag__c != null && exp.Tag__c == null) {
                        exp.Tag__c = rule.Tag__c;
                        changed = true;
                    }
                    if (rule.Billable__c != null) {
                        exp.Billable__c = rule.Billable__c;
                        changed = true;
                    }
                    if (rule.Reimbursable__c != null) {
                        exp.Reimbursable__c = rule.Reimbursable__c;
                        changed = true;
                    }
                    if (changed) toUpdate.add(exp);
                    break;
                }
            }
        }
        if (!toUpdate.isEmpty()) update toUpdate;
    }

    private static Boolean matchesMerchant(String merchant, String pattern) {
        if (String.isBlank(merchant) || String.isBlank(pattern)) return false;
        String lowerMerchant = merchant.toLowerCase();
        String lowerPattern = pattern.toLowerCase();

        if (lowerPattern.contains('*')) {
            String regex = lowerPattern.replaceAll('\\*', '.*');
            return Pattern.matches(regex, lowerMerchant);
        }
        return lowerMerchant.contains(lowerPattern);
    }
}
