public with sharing class CommentService {

    public static final Integer MAX_BODY_LENGTH = 32000;

    @AuraEnabled
    public static Expense_Comment__c addComment(Id parentId, String body) {
        if (parentId == null) {
            throw new CommentException('Parent record Id is required');
        }
        String trimmedBody = body == null ? null : body.trim();
        if (String.isBlank(trimmedBody)) {
            throw new CommentException('Comment body cannot be empty');
        }
        if (trimmedBody.length() > MAX_BODY_LENGTH) {
            throw new CommentException('Comment exceeds the maximum length of ' + MAX_BODY_LENGTH + ' characters');
        }

        String parentType = parentId.getSObjectType().getDescribe().getName();
        Expense_Comment__c comment = new Expense_Comment__c(
            Body__c = trimmedBody,
            Author__c = UserInfo.getUserId()
        );

        if (parentType == 'Expense__c') {
            comment.Expense__c = parentId;
            comment.Report__c = resolveReportForExpense(parentId);
        } else if (parentType == 'Expense_Report__c') {
            throw new CommentException(
                'Report-level comments require Expense_Comment__c.Expense__c to be an optional lookup. ' +
                'Comment on an expense within the report instead.'
            );
        } else {
            throw new CommentException('Unsupported parent type: ' + parentType);
        }

        insertComment(comment);
        return comment;
    }

    @AuraEnabled
    public static Expense_Comment__c editComment(Id commentId, String body) {
        if (commentId == null) {
            throw new CommentException('Comment Id is required');
        }
        String trimmedBody = body == null ? null : body.trim();
        if (String.isBlank(trimmedBody)) {
            throw new CommentException('Comment body cannot be empty');
        }
        if (trimmedBody.length() > MAX_BODY_LENGTH) {
            throw new CommentException('Comment exceeds the maximum length of ' + MAX_BODY_LENGTH + ' characters');
        }

        requireComment(commentId);

        if (!Schema.sObjectType.Expense_Comment__c.fields.Body__c.isUpdateable()) {
            throw new CommentException('Insufficient access to edit comments');
        }
        Expense_Comment__c comment = new Expense_Comment__c(
            Id = commentId,
            Body__c = trimmedBody
        );
        update comment;
        return comment;
    }

    @AuraEnabled
    public static void deleteComment(Id commentId) {
        if (commentId == null) {
            throw new CommentException('Comment Id is required');
        }
        Expense_Comment__c existing = requireComment(commentId);
        if (!Schema.sObjectType.Expense_Comment__c.isDeletable()) {
            throw new CommentException('Insufficient access to delete comments');
        }
        delete existing;
    }

    @AuraEnabled(cacheable=true)
    public static List<Expense_Comment__c> getCommentsForExpense(Id expenseId) {
        if (expenseId == null) {
            return new List<Expense_Comment__c>();
        }
        return [
            SELECT Id, Name, Body__c, Expense__c, Report__c,
                   Author__c, Author__r.Name, CreatedById, CreatedDate, LastModifiedDate
            FROM Expense_Comment__c
            WHERE Expense__c = :expenseId
            WITH SECURITY_ENFORCED
            ORDER BY CreatedDate ASC
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Expense_Comment__c> getCommentsForReport(Id reportId) {
        if (reportId == null) {
            return new List<Expense_Comment__c>();
        }
        return [
            SELECT Id, Name, Body__c, Expense__c, Expense__r.Name, Report__c,
                   Author__c, Author__r.Name, CreatedById, CreatedDate, LastModifiedDate
            FROM Expense_Comment__c
            WHERE Report__c = :reportId
            WITH SECURITY_ENFORCED
            ORDER BY CreatedDate ASC
        ];
    }

    private static Id resolveReportForExpense(Id expenseId) {
        List<Expense__c> expenses = [
            SELECT Id, Report__c
            FROM Expense__c
            WHERE Id = :expenseId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        if (expenses.isEmpty()) {
            throw new CommentException('Expense not found');
        }
        return expenses[0].Report__c;
    }

    private static Expense_Comment__c requireComment(Id commentId) {
        List<Expense_Comment__c> comments = [
            SELECT Id, Body__c, Expense__c, Report__c, Author__c
            FROM Expense_Comment__c
            WHERE Id = :commentId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        if (comments.isEmpty()) {
            throw new CommentException('Comment not found');
        }
        return comments[0];
    }

    private static void insertComment(Expense_Comment__c comment) {
        if (!Schema.sObjectType.Expense_Comment__c.isCreateable()) {
            throw new CommentException('Insufficient access to create comments');
        }
        SObjectAccessDecision decision = Security.stripInaccessible(
            AccessType.CREATABLE,
            new List<Expense_Comment__c>{ comment }
        );
        if (decision.getRemovedFields().containsKey('Expense_Comment__c')) {
            throw new CommentException('Insufficient field access to create comments');
        }
        insert comment;
    }

    public class CommentException extends Exception {}
}
