public with sharing class ExpenseMergeService {

    public class MergeException extends Exception {}

    private static final Set<String> MERGEABLE_FIELDS = new Set<String>{
        'Amount__c', 'Currency__c', 'Merchant__c', 'Expense_Date__c', 'Category__c',
        'Tag__c', 'Description__c', 'Billable__c', 'Reimbursable__c', 'Tax_Amount__c',
        'Tax_Rate__c', 'Expense_Type__c', 'Distance__c', 'Distance_Unit__c',
        'Receipt_URL__c', 'Has_Receipt__c', 'Policy__c', 'Report__c', 'Hold_Reason__c'
    };

    public static Expense__c mergeExpenses(Id survivorId, Id otherId, Map<String, Id> fieldSelections) {
        if (survivorId == null || otherId == null) {
            throw new MergeException('Both expense Ids are required');
        }
        if (survivorId == otherId) {
            throw new MergeException('Cannot merge an expense with itself');
        }

        assertExpenseAccess();

        List<Id> targetIds = new List<Id>{ survivorId, otherId };
        Map<Id, Expense__c> expensesById = new Map<Id, Expense__c>([
            SELECT Id, Amount__c, Currency__c, Merchant__c, Expense_Date__c, Category__c,
                   Tag__c, Description__c, Billable__c, Reimbursable__c, Tax_Amount__c,
                   Tax_Rate__c, Expense_Type__c, Distance__c, Distance_Unit__c,
                   Receipt_URL__c, Has_Receipt__c, Policy__c, Report__c, Hold_Reason__c
            FROM Expense__c
            WHERE Id IN :targetIds
        ]);

        if (!expensesById.containsKey(survivorId) || !expensesById.containsKey(otherId)) {
            throw new MergeException('One or both expenses could not be found');
        }

        Expense__c survivor = expensesById.get(survivorId);
        Expense__c other = expensesById.get(otherId);

        if (fieldSelections != null) {
            for (String field : fieldSelections.keySet()) {
                if (!MERGEABLE_FIELDS.contains(field)) {
                    continue;
                }
                if (fieldSelections.get(field) == otherId) {
                    survivor.put(field, other.get(field));
                }
            }
        }

        Set<Id> affectedReports = new Set<Id>();
        if (survivor.Report__c != null) {
            affectedReports.add(survivor.Report__c);
        }
        if (other.Report__c != null) {
            affectedReports.add(other.Report__c);
        }

        Savepoint sp = Database.setSavepoint();
        try {
            reattachChildren(survivorId, otherId);
            update survivor;
            delete other;
        } catch (Exception e) {
            Database.rollback(sp);
            throw new MergeException('Merge failed: ' + e.getMessage());
        }

        for (Id reportId : affectedReports) {
            ExpenseService.updateReportTotals(reportId);
        }

        return survivor;
    }

    private static void reattachChildren(Id survivorId, Id otherId) {
        List<SObject> clones = new List<SObject>();

        if (Schema.SObjectType.Expense_Receipt__c.isAccessible() && Schema.SObjectType.Expense_Receipt__c.isCreateable()) {
            for (Expense_Receipt__c receipt : [
                SELECT File_URL__c, Scan_Status__c
                FROM Expense_Receipt__c
                WHERE Expense__c = :otherId
            ]) {
                clones.add(new Expense_Receipt__c(
                    Expense__c = survivorId,
                    File_URL__c = receipt.File_URL__c,
                    Scan_Status__c = receipt.Scan_Status__c
                ));
            }
        }

        if (Schema.SObjectType.Expense_Split__c.isAccessible() && Schema.SObjectType.Expense_Split__c.isCreateable()) {
            for (Expense_Split__c split : [
                SELECT Split_Amount__c, Split_User__c
                FROM Expense_Split__c
                WHERE Parent_Expense__c = :otherId
            ]) {
                clones.add(new Expense_Split__c(
                    Parent_Expense__c = survivorId,
                    Split_Amount__c = split.Split_Amount__c,
                    Split_User__c = split.Split_User__c
                ));
            }
        }

        if (Schema.SObjectType.Expense_Comment__c.isAccessible() && Schema.SObjectType.Expense_Comment__c.isCreateable()) {
            for (Expense_Comment__c comment : [
                SELECT Body__c
                FROM Expense_Comment__c
                WHERE Expense__c = :otherId
            ]) {
                clones.add(new Expense_Comment__c(
                    Expense__c = survivorId,
                    Body__c = comment.Body__c
                ));
            }
        }

        if (!clones.isEmpty()) {
            insert clones;
        }
    }

    private static void assertExpenseAccess() {
        Schema.DescribeSObjectResult describe = Schema.SObjectType.Expense__c;
        if (!describe.isAccessible()) {
            throw new MergeException('Insufficient access to read expenses');
        }
        if (!describe.isUpdateable()) {
            throw new MergeException('Insufficient access to update expenses');
        }
        if (!describe.isDeletable()) {
            throw new MergeException('Insufficient access to delete expenses');
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Expense__c> getExpensesForMerge(Id firstExpenseId, Id secondExpenseId) {
        List<Id> targetIds = new List<Id>{ firstExpenseId, secondExpenseId };
        return [
            SELECT Id, Name, Amount__c, Currency__c, Merchant__c, Expense_Date__c,
                   Category__c, Category__r.Name, Tag__c, Tag__r.Name, Description__c,
                   Billable__c, Reimbursable__c, Tax_Amount__c, Tax_Rate__c,
                   Expense_Type__c, Distance__c, Distance_Unit__c, Receipt_URL__c,
                   Has_Receipt__c, Status__c, Policy__c, Report__c, Report__r.Name
            FROM Expense__c
            WHERE Id IN :targetIds
        ];
    }

    @AuraEnabled
    public static Id applyMerge(Id survivorId, Id otherId, List<String> fieldNames, List<Id> fieldSourceExpenseIds) {
        try {
            Map<String, Id> fieldSelections = buildSelectionMap(fieldNames, fieldSourceExpenseIds);
            Expense__c survivor = mergeExpenses(survivorId, otherId, fieldSelections);
            return survivor.Id;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    public static Map<String, Id> buildSelectionMap(List<String> fieldNames, List<Id> fieldSourceExpenseIds) {
        Map<String, Id> fieldSelections = new Map<String, Id>();
        if (fieldNames == null || fieldSourceExpenseIds == null) {
            return fieldSelections;
        }
        Integer size = Math.min(fieldNames.size(), fieldSourceExpenseIds.size());
        for (Integer i = 0; i < size; i++) {
            fieldSelections.put(fieldNames.get(i), fieldSourceExpenseIds.get(i));
        }
        return fieldSelections;
    }
}
