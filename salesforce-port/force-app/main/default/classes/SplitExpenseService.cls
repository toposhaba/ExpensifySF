public with sharing class SplitExpenseService {

    public static List<Expense_Split__c> splitExpense(Id parentExpenseId, List<SplitDetail> splits) {
        Expense__c parent = [SELECT Id, Amount__c, Currency__c FROM Expense__c WHERE Id = :parentExpenseId LIMIT 1];

        Decimal totalSplit = 0;
        for (SplitDetail sd : splits) {
            totalSplit += sd.amount;
        }
        if (Math.abs(totalSplit - parent.Amount__c) > 0.01) {
            throw new SplitException('Split amounts must equal the total expense amount');
        }

        List<Expense_Split__c> splitRecords = new List<Expense_Split__c>();
        for (SplitDetail sd : splits) {
            splitRecords.add(new Expense_Split__c(
                Parent_Expense__c = parentExpenseId,
                Split_Amount__c = sd.amount,
                Split_User__c = sd.userId
            ));
        }
        insert splitRecords;
        return splitRecords;
    }

    public static List<Expense_Split__c> getSplits(Id parentExpenseId) {
        return [
            SELECT Id, Split_Amount__c, Split_User__c, Split_User__r.Name, CreatedDate
            FROM Expense_Split__c
            WHERE Parent_Expense__c = :parentExpenseId
            ORDER BY CreatedDate
        ];
    }

    public static void deleteSplits(Id parentExpenseId) {
        List<Expense_Split__c> splits = [
            SELECT Id FROM Expense_Split__c WHERE Parent_Expense__c = :parentExpenseId
        ];
        if (!splits.isEmpty()) delete splits;
    }

    public class SplitDetail {
        public Id userId;
        public Decimal amount;

        public SplitDetail(Id userId, Decimal amount) {
            this.userId = userId;
            this.amount = amount;
        }
    }

    public class SplitException extends Exception {}
}
