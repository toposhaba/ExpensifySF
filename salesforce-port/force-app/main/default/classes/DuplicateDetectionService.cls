public with sharing class DuplicateDetectionService {

    public static List<Expense__c> findDuplicates(Id expenseId) {
        Expense__c source = [
            SELECT Id, Amount__c, Merchant__c, Expense_Date__c, Currency__c, OwnerId
            FROM Expense__c WHERE Id = :expenseId LIMIT 1
        ];

        return [
            SELECT Id, Name, Amount__c, Merchant__c, Expense_Date__c, Currency__c,
                   Category__r.Name, Status__c, Report__c, Report__r.Name
            FROM Expense__c
            WHERE Id != :expenseId
            AND OwnerId = :source.OwnerId
            AND Amount__c = :source.Amount__c
            AND Expense_Date__c = :source.Expense_Date__c
            AND (Merchant__c = :source.Merchant__c OR Merchant__c = null)
            ORDER BY CreatedDate DESC
            LIMIT 10
        ];
    }

    public static List<List<Expense__c>> findAllDuplicatesForUser(Id userId) {
        List<Expense__c> expenses = [
            SELECT Id, Name, Amount__c, Merchant__c, Expense_Date__c, Currency__c, Status__c
            FROM Expense__c
            WHERE OwnerId = :userId AND Status__c != 'Approved'
            ORDER BY Expense_Date__c DESC, Amount__c
            LIMIT 500
        ];

        Map<String, List<Expense__c>> groups = new Map<String, List<Expense__c>>();
        for (Expense__c exp : expenses) {
            String key = exp.Amount__c + '_' + exp.Expense_Date__c + '_' + (exp.Merchant__c != null ? exp.Merchant__c : '');
            if (!groups.containsKey(key)) {
                groups.put(key, new List<Expense__c>());
            }
            groups.get(key).add(exp);
        }

        List<List<Expense__c>> duplicateSets = new List<List<Expense__c>>();
        for (String key : groups.keySet()) {
            if (groups.get(key).size() > 1) {
                duplicateSets.add(groups.get(key));
            }
        }
        return duplicateSets;
    }

    public static Expense__c mergeExpenses(Id keepId, List<Id> mergeIds) {
        Expense__c keep = [
            SELECT Id, Amount__c, Merchant__c, Expense_Date__c, Currency__c,
                   Category__c, Tag__c, Description__c, Report__c, Has_Receipt__c,
                   Receipt_URL__c, Billable__c, Reimbursable__c, Tax_Amount__c
            FROM Expense__c WHERE Id = :keepId LIMIT 1
        ];

        List<Expense__c> toMerge = [
            SELECT Id, Description__c, Category__c, Tag__c, Has_Receipt__c,
                   Receipt_URL__c, Report__c
            FROM Expense__c WHERE Id IN :mergeIds
        ];

        for (Expense__c src : toMerge) {
            if (keep.Category__c == null && src.Category__c != null) {
                keep.Category__c = src.Category__c;
            }
            if (keep.Tag__c == null && src.Tag__c != null) {
                keep.Tag__c = src.Tag__c;
            }
            if (String.isBlank(keep.Description__c) && String.isNotBlank(src.Description__c)) {
                keep.Description__c = src.Description__c;
            }
            if (!keep.Has_Receipt__c && src.Has_Receipt__c) {
                keep.Has_Receipt__c = true;
                keep.Receipt_URL__c = src.Receipt_URL__c;
            }
        }
        update keep;

        List<Expense_Violation__c> violations = [SELECT Id FROM Expense_Violation__c WHERE Expense__c IN :mergeIds];
        if (!violations.isEmpty()) delete violations;

        List<Expense_Comment__c> comments = [SELECT Id FROM Expense_Comment__c WHERE Expense__c IN :mergeIds];
        if (!comments.isEmpty()) delete comments;

        delete [SELECT Id FROM Expense__c WHERE Id IN :mergeIds];

        if (keep.Report__c != null) {
            ExpenseService.updateReportTotals(keep.Report__c);
        }

        return keep;
    }

    public static void markAsDuplicate(Id expenseId) {
        Expense_Violation__c violation = new Expense_Violation__c(
            Expense__c = expenseId,
            Violation_Type__c = 'Duplicate',
            Message__c = 'This expense appears to be a duplicate'
        );
        insert violation;
    }
}
