public with sharing class CommentService {

    public static Expense_Comment__c addComment(Id expenseId, String body) {
        Expense_Comment__c comment = new Expense_Comment__c(
            Expense__c = expenseId,
            Body__c = body
        );
        insert comment;
        return comment;
    }

    public static List<Expense_Comment__c> getComments(Id expenseId) {
        return [
            SELECT Id, Body__c, CreatedById, CreatedBy.Name, CreatedDate
            FROM Expense_Comment__c
            WHERE Expense__c = :expenseId
            ORDER BY CreatedDate ASC
        ];
    }

    public static void deleteComment(Id commentId) {
        delete [SELECT Id FROM Expense_Comment__c WHERE Id = :commentId LIMIT 1];
    }

    public static Expense_Comment__c editComment(Id commentId, String newBody) {
        Expense_Comment__c comment = new Expense_Comment__c(Id = commentId, Body__c = newBody);
        update comment;
        return comment;
    }
}
