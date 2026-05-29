public with sharing class CardService {

    public static Card__c issueCard(Id policyId, Id userId, Decimal spendLimit, String cardName) {
        Card__c card = new Card__c(
            Name = cardName,
            Policy__c = policyId,
            Cardholder__c = userId,
            Status__c = 'Active',
            Spend_Limit__c = spendLimit,
            Total_Spend__c = 0,
            Available_Spend__c = spendLimit,
            Card_Type__c = 'Virtual',
            Issued_Date__c = Date.today()
        );
        insert card;
        return card;
    }

    public static void freezeCard(Id cardId) {
        update new Card__c(Id = cardId, Status__c = 'Frozen');
    }

    public static void unfreezeCard(Id cardId) {
        update new Card__c(Id = cardId, Status__c = 'Active');
    }

    public static void updateSpendLimit(Id cardId, Decimal newLimit) {
        Card__c card = [SELECT Total_Spend__c FROM Card__c WHERE Id = :cardId LIMIT 1];
        update new Card__c(
            Id = cardId,
            Spend_Limit__c = newLimit,
            Available_Spend__c = newLimit - card.Total_Spend__c
        );
    }

    public static void reportFraud(Id cardId, String description) {
        update new Card__c(Id = cardId, Status__c = 'Fraud_Reported', Fraud_Description__c = description);
    }

    public static void cancelCard(Id cardId) {
        update new Card__c(Id = cardId, Status__c = 'Cancelled');
    }

    public static List<Card__c> getCardsByPolicy(Id policyId) {
        return [
            SELECT Id, Name, Cardholder__c, Cardholder__r.Name, Status__c,
                   Spend_Limit__c, Total_Spend__c, Available_Spend__c, Card_Type__c,
                   Last_Four__c, Issued_Date__c
            FROM Card__c WHERE Policy__c = :policyId ORDER BY Name
        ];
    }

    public static List<Card__c> getCardsByUser(Id userId) {
        return [
            SELECT Id, Name, Status__c, Spend_Limit__c, Total_Spend__c,
                   Available_Spend__c, Card_Type__c, Last_Four__c, Policy__r.Name
            FROM Card__c WHERE Cardholder__c = :userId ORDER BY Name
        ];
    }

    public static Card_Transaction__c recordTransaction(Id cardId, Decimal amount, String merchant, Date txnDate, String mccCode) {
        Card__c card = [SELECT Id, Status__c, Available_Spend__c, Total_Spend__c FROM Card__c WHERE Id = :cardId LIMIT 1];

        if (card.Status__c != 'Active') {
            throw new CardException('Card is not active');
        }
        if (card.Available_Spend__c != null && amount > card.Available_Spend__c) {
            throw new CardException('Transaction exceeds available spend limit');
        }

        Card_Transaction__c txn = new Card_Transaction__c(
            Card__c = cardId,
            Amount__c = amount,
            Merchant__c = merchant,
            Transaction_Date__c = txnDate,
            MCC_Code__c = mccCode,
            Status__c = 'Posted'
        );
        insert txn;

        card.Total_Spend__c = (card.Total_Spend__c != null ? card.Total_Spend__c : 0) + amount;
        card.Available_Spend__c = card.Spend_Limit__c - card.Total_Spend__c;
        update card;

        return txn;
    }

    public static List<Card_Transaction__c> getTransactions(Id cardId) {
        return [
            SELECT Id, Name, Amount__c, Merchant__c, Transaction_Date__c, MCC_Code__c, Status__c, Expense__c
            FROM Card_Transaction__c WHERE Card__c = :cardId ORDER BY Transaction_Date__c DESC LIMIT 200
        ];
    }

    public static Expense__c convertToExpense(Id transactionId, Id reportId, Id categoryId) {
        Card_Transaction__c txn = [
            SELECT Amount__c, Merchant__c, Transaction_Date__c, Card__c, Card__r.Policy__c
            FROM Card_Transaction__c WHERE Id = :transactionId LIMIT 1
        ];

        Expense__c expense = new Expense__c(
            Amount__c = txn.Amount__c,
            Currency__c = 'USD',
            Merchant__c = txn.Merchant__c,
            Expense_Date__c = txn.Transaction_Date__c,
            Expense_Type__c = 'Card',
            Status__c = 'Draft',
            Policy__c = txn.Card__r.Policy__c,
            Report__c = reportId,
            Category__c = categoryId,
            Reimbursable__c = false
        );
        expense = ExpenseService.createExpense(expense);

        update new Card_Transaction__c(Id = transactionId, Expense__c = expense.Id);
        return expense;
    }

    public class CardException extends Exception {}
}
