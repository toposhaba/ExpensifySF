public with sharing class ExpenseSplitService {

    public class SplitException extends Exception {}

    public class SplitInput {
        @AuraEnabled public Id userId { get; set; }
        @AuraEnabled public Decimal amount { get; set; }
        @AuraEnabled public Decimal share { get; set; }
    }

    private static final String MODE_AMOUNT = 'Amount';
    private static final String MODE_SHARE = 'Share';
    private static final Decimal TOLERANCE = 0.01;

    private static final Set<String> SPLIT_FIELDS = new Set<String>{
        'Parent_Expense__c', 'Split_User__c', 'Split_Amount__c', 'Split_Percentage__c'
    };

    public static List<Expense_Split__c> createSplits(Id parentExpenseId, List<SplitInput> inputs, String mode) {
        if (parentExpenseId == null) {
            throw new SplitException('Parent expense Id is required');
        }
        if (inputs == null || inputs.isEmpty()) {
            throw new SplitException('At least one split is required');
        }

        assertExpenseReadable();
        assertSplitCreateable();

        Expense__c parent = loadParent(parentExpenseId);
        Decimal parentAmount = parent.Amount__c;
        if (parentAmount == null || parentAmount <= 0) {
            throw new SplitException('Parent expense amount must be greater than zero');
        }

        String splitMode = String.isBlank(mode) ? MODE_AMOUNT : mode;
        List<Expense_Split__c> splits;
        if (splitMode == MODE_SHARE) {
            splits = buildShareSplits(parentExpenseId, parentAmount, inputs);
        } else {
            splits = buildAmountSplits(parentExpenseId, parentAmount, inputs);
        }

        validateSum(splits, parentAmount);
        insert splits;
        return splits;
    }

    public static List<Expense_Split__c> buildAmountSplits(Id parentExpenseId, Decimal parentAmount, List<SplitInput> inputs) {
        List<Expense_Split__c> splits = new List<Expense_Split__c>();
        for (SplitInput input : inputs) {
            if (input.userId == null) {
                throw new SplitException('Each split requires a user');
            }
            if (input.amount == null || input.amount <= 0) {
                throw new SplitException('Each split amount must be greater than zero');
            }
            Decimal amount = input.amount.setScale(2, System.RoundingMode.HALF_UP);
            splits.add(new Expense_Split__c(
                Parent_Expense__c = parentExpenseId,
                Split_User__c = input.userId,
                Split_Amount__c = amount,
                Split_Percentage__c = parentAmount == 0 ? 0 : (amount / parentAmount * 100).setScale(2, System.RoundingMode.HALF_UP)
            ));
        }
        return splits;
    }

    public static List<Expense_Split__c> buildShareSplits(Id parentExpenseId, Decimal parentAmount, List<SplitInput> inputs) {
        List<Decimal> shares = new List<Decimal>();
        Decimal totalShares = 0;
        for (SplitInput input : inputs) {
            if (input.userId == null) {
                throw new SplitException('Each split requires a user');
            }
            Decimal share = (input.share == null || input.share <= 0) ? 1 : input.share;
            shares.add(share);
            totalShares += share;
        }

        List<Expense_Split__c> splits = new List<Expense_Split__c>();
        Decimal allocated = 0;
        for (Integer i = 0; i < inputs.size(); i++) {
            Decimal amount;
            if (i == inputs.size() - 1) {
                amount = (parentAmount - allocated).setScale(2, System.RoundingMode.HALF_UP);
            } else {
                amount = (parentAmount * shares.get(i) / totalShares).setScale(2, System.RoundingMode.HALF_UP);
                allocated += amount;
            }
            splits.add(new Expense_Split__c(
                Parent_Expense__c = parentExpenseId,
                Split_User__c = inputs.get(i).userId,
                Split_Amount__c = amount,
                Split_Percentage__c = (shares.get(i) / totalShares * 100).setScale(2, System.RoundingMode.HALF_UP)
            ));
        }
        return splits;
    }

    public static void validateSum(List<Expense_Split__c> splits, Decimal parentAmount) {
        Decimal total = 0;
        for (Expense_Split__c split : splits) {
            if (split.Split_Amount__c != null) {
                total += split.Split_Amount__c;
            }
        }
        if (Math.abs(total - parentAmount) > TOLERANCE) {
            throw new SplitException('Split amounts (' + total + ') must equal the parent expense amount (' + parentAmount + ')');
        }
    }

    private static Expense__c loadParent(Id parentExpenseId) {
        List<Expense__c> parents = [
            SELECT Id, Amount__c, Currency__c
            FROM Expense__c
            WHERE Id = :parentExpenseId
            LIMIT 1
        ];
        if (parents.isEmpty()) {
            throw new SplitException('Parent expense could not be found');
        }
        return parents.get(0);
    }

    private static void assertExpenseReadable() {
        if (!Schema.SObjectType.Expense__c.isAccessible()) {
            throw new SplitException('Insufficient access to read expenses');
        }
    }

    private static void assertSplitCreateable() {
        Schema.DescribeSObjectResult describe = Schema.SObjectType.Expense_Split__c;
        if (!describe.isCreateable()) {
            throw new SplitException('Insufficient access to create expense splits');
        }
        Map<String, Schema.SObjectField> fieldMap = describe.fields.getMap();
        for (String fieldName : SPLIT_FIELDS) {
            Schema.SObjectField field = fieldMap.get(fieldName.toLowerCase());
            if (field == null || !field.getDescribe().isCreateable()) {
                throw new SplitException('Insufficient access to create field ' + fieldName);
            }
        }
    }

    private static void assertSplitReadable() {
        Schema.DescribeSObjectResult describe = Schema.SObjectType.Expense_Split__c;
        if (!describe.isAccessible()) {
            throw new SplitException('Insufficient access to read expense splits');
        }
        Map<String, Schema.SObjectField> fieldMap = describe.fields.getMap();
        for (String fieldName : SPLIT_FIELDS) {
            Schema.SObjectField field = fieldMap.get(fieldName.toLowerCase());
            if (field == null || !field.getDescribe().isAccessible()) {
                throw new SplitException('Insufficient access to read field ' + fieldName);
            }
        }
    }

    public static List<SplitInput> buildInputs(List<Id> userIds, List<Decimal> amounts, List<Decimal> shares) {
        List<SplitInput> inputs = new List<SplitInput>();
        if (userIds == null) {
            return inputs;
        }
        for (Integer i = 0; i < userIds.size(); i++) {
            SplitInput input = new SplitInput();
            input.userId = userIds.get(i);
            if (amounts != null && i < amounts.size()) {
                input.amount = amounts.get(i);
            }
            if (shares != null && i < shares.size()) {
                input.share = shares.get(i);
            }
            inputs.add(input);
        }
        return inputs;
    }

    @AuraEnabled
    public static List<Expense_Split__c> createSplitsApex(Id parentExpenseId, List<SplitInput> inputs, String mode) {
        try {
            return createSplits(parentExpenseId, inputs, mode);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Expense_Split__c> listSplits(Id parentExpenseId) {
        assertSplitReadable();
        return [
            SELECT Id, Name, Parent_Expense__c, Split_User__c, Split_User__r.Name,
                   Split_Amount__c, Split_Percentage__c
            FROM Expense_Split__c
            WHERE Parent_Expense__c = :parentExpenseId
            ORDER BY CreatedDate ASC
        ];
    }

    @AuraEnabled(cacheable=true)
    public static Expense__c getParentExpense(Id parentExpenseId) {
        assertExpenseReadable();
        return [
            SELECT Id, Name, Amount__c, Currency__c, Merchant__c
            FROM Expense__c
            WHERE Id = :parentExpenseId
            LIMIT 1
        ];
    }
}
