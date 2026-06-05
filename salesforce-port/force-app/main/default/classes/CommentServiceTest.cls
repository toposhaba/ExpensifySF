@isTest
private class CommentServiceTest {

    @TestSetup
    static void setupTestData() {
        Expense_Policy__c policy = new Expense_Policy__c(
            Name = 'Comment Test Policy',
            Currency__c = 'USD',
            Type__c = 'Corporate',
            Approval_Mode__c = 'Basic'
        );
        insert policy;

        Expense_Report__c report = new Expense_Report__c(
            Status__c = 'Open',
            Currency__c = 'USD',
            Policy__c = policy.Id
        );
        insert report;

        List<Expense__c> expenses = new List<Expense__c>{
            new Expense__c(
                Amount__c = 75.00,
                Currency__c = 'USD',
                Merchant__c = 'Reported Merchant',
                Expense_Date__c = Date.today(),
                Expense_Type__c = 'Cash',
                Status__c = 'Draft',
                Report__c = report.Id
            ),
            new Expense__c(
                Amount__c = 25.00,
                Currency__c = 'USD',
                Merchant__c = 'Standalone Merchant',
                Expense_Date__c = Date.today(),
                Expense_Type__c = 'Cash',
                Status__c = 'Draft'
            )
        };
        insert expenses;
    }

    private static Expense__c reportedExpense() {
        return [SELECT Id, Report__c FROM Expense__c WHERE Report__c != null LIMIT 1];
    }

    private static Expense__c standaloneExpense() {
        return [SELECT Id, Report__c FROM Expense__c WHERE Report__c = null LIMIT 1];
    }

    @isTest
    static void testAddCommentToExpense() {
        Expense__c expense = reportedExpense();

        Test.startTest();
        Expense_Comment__c comment = CommentService.addComment(expense.Id, '  Looks good to me  ');
        Test.stopTest();

        System.assertNotEquals(null, comment.Id, 'Comment should be created');

        Expense_Comment__c saved = [
            SELECT Body__c, Expense__c, Report__c, Author__c
            FROM Expense_Comment__c WHERE Id = :comment.Id
        ];
        System.assertEquals('Looks good to me', saved.Body__c, 'Body should be trimmed');
        System.assertEquals(expense.Id, saved.Expense__c, 'Expense should be linked');
        System.assertEquals(expense.Report__c, saved.Report__c, 'Report should be derived from the expense');
        System.assertEquals(UserInfo.getUserId(), saved.Author__c, 'Author should be the running user');
    }

    @isTest
    static void testAddCommentToStandaloneExpense() {
        Expense__c expense = standaloneExpense();

        Test.startTest();
        Expense_Comment__c comment = CommentService.addComment(expense.Id, 'No report yet');
        Test.stopTest();

        Expense_Comment__c saved = [SELECT Report__c FROM Expense_Comment__c WHERE Id = :comment.Id];
        System.assertEquals(null, saved.Report__c, 'Report should be null when expense is unreported');
    }

    @isTest
    static void testListOrdering() {
        Expense__c expense = reportedExpense();

        Expense_Comment__c first = new Expense_Comment__c(
            Expense__c = expense.Id, Report__c = expense.Report__c, Body__c = 'oldest', Author__c = UserInfo.getUserId()
        );
        Expense_Comment__c second = new Expense_Comment__c(
            Expense__c = expense.Id, Report__c = expense.Report__c, Body__c = 'middle', Author__c = UserInfo.getUserId()
        );
        Expense_Comment__c third = new Expense_Comment__c(
            Expense__c = expense.Id, Report__c = expense.Report__c, Body__c = 'newest', Author__c = UserInfo.getUserId()
        );
        insert new List<Expense_Comment__c>{ third, first, second };

        Test.setCreatedDate(first.Id, DateTime.now().addMinutes(-30));
        Test.setCreatedDate(second.Id, DateTime.now().addMinutes(-20));
        Test.setCreatedDate(third.Id, DateTime.now().addMinutes(-10));

        Test.startTest();
        List<Expense_Comment__c> comments = CommentService.getCommentsForExpense(expense.Id);
        Test.stopTest();

        System.assertEquals(3, comments.size(), 'All comments should be returned');
        System.assertEquals('oldest', comments[0].Body__c, 'Oldest comment should be first');
        System.assertEquals('middle', comments[1].Body__c, 'Middle comment should be second');
        System.assertEquals('newest', comments[2].Body__c, 'Newest comment should be last');
    }

    @isTest
    static void testGetCommentsForReport() {
        Expense__c expense = reportedExpense();
        CommentService.addComment(expense.Id, 'Report thread comment');

        Test.startTest();
        List<Expense_Comment__c> reportComments = CommentService.getCommentsForReport(expense.Report__c);
        List<Expense_Comment__c> none = CommentService.getCommentsForReport(null);
        Test.stopTest();

        System.assertEquals(1, reportComments.size(), 'Report thread should aggregate expense comments');
        System.assertEquals('Report thread comment', reportComments[0].Body__c);
        System.assertEquals(0, none.size(), 'Null report should return an empty list');
    }

    @isTest
    static void testEditComment() {
        Expense__c expense = reportedExpense();
        Expense_Comment__c comment = CommentService.addComment(expense.Id, 'Original text');

        Test.startTest();
        CommentService.editComment(comment.Id, '  Updated text  ');
        Test.stopTest();

        Expense_Comment__c saved = [SELECT Body__c FROM Expense_Comment__c WHERE Id = :comment.Id];
        System.assertEquals('Updated text', saved.Body__c, 'Body should be updated and trimmed');
    }

    @isTest
    static void testDeleteComment() {
        Expense__c expense = reportedExpense();
        Expense_Comment__c comment = CommentService.addComment(expense.Id, 'Delete me');

        Test.startTest();
        CommentService.deleteComment(comment.Id);
        Test.stopTest();

        List<Expense_Comment__c> remaining = [SELECT Id FROM Expense_Comment__c WHERE Id = :comment.Id];
        System.assert(remaining.isEmpty(), 'Comment should be deleted');
    }

    @isTest
    static void testGetCommentsNullExpense() {
        Test.startTest();
        List<Expense_Comment__c> result = CommentService.getCommentsForExpense(null);
        Test.stopTest();
        System.assertEquals(0, result.size(), 'Null expense should return an empty list');
    }

    @isTest
    static void testAddValidation() {
        Expense__c expense = reportedExpense();
        Expense_Report__c report = [SELECT Id FROM Expense_Report__c LIMIT 1];
        Expense_Policy__c policy = [SELECT Id FROM Expense_Policy__c LIMIT 1];

        Test.startTest();
        try {
            CommentService.addComment(null, 'body');
            System.assert(false, 'Should have thrown for null parent');
        } catch (CommentService.CommentException e) {
            System.assert(e.getMessage().contains('Parent record Id is required'), e.getMessage());
        }

        try {
            CommentService.addComment(expense.Id, '   ');
            System.assert(false, 'Should have thrown for blank body');
        } catch (CommentService.CommentException e) {
            System.assert(e.getMessage().contains('cannot be empty'), e.getMessage());
        }

        try {
            CommentService.addComment(expense.Id, 'a'.repeat(CommentService.MAX_BODY_LENGTH + 1));
            System.assert(false, 'Should have thrown for oversized body');
        } catch (CommentService.CommentException e) {
            System.assert(e.getMessage().contains('maximum length'), e.getMessage());
        }

        try {
            CommentService.addComment(report.Id, 'body');
            System.assert(false, 'Should have thrown for report parent');
        } catch (CommentService.CommentException e) {
            System.assert(e.getMessage().contains('Report-level comments'), e.getMessage());
        }

        try {
            CommentService.addComment(policy.Id, 'body');
            System.assert(false, 'Should have thrown for unsupported parent');
        } catch (CommentService.CommentException e) {
            System.assert(e.getMessage().contains('Unsupported parent type'), e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testEditAndDeleteValidation() {
        Test.startTest();
        try {
            CommentService.editComment(null, 'body');
            System.assert(false, 'Should have thrown for null comment id');
        } catch (CommentService.CommentException e) {
            System.assert(e.getMessage().contains('Comment Id is required'), e.getMessage());
        }

        try {
            CommentService.deleteComment(null);
            System.assert(false, 'Should have thrown for null comment id');
        } catch (CommentService.CommentException e) {
            System.assert(e.getMessage().contains('Comment Id is required'), e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testInvocableAddComment() {
        Expense__c expense = reportedExpense();

        InvocableAddComment.Request req = new InvocableAddComment.Request();
        req.parentId = expense.Id;
        req.body = 'Invocable comment';

        Test.startTest();
        List<InvocableAddComment.Results> results =
            InvocableAddComment.execute(new List<InvocableAddComment.Request>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].isSuccess, 'Invocable add should succeed');
        System.assertNotEquals(null, results[0].commentId, 'Comment Id should be returned');
    }

    @isTest
    static void testInvocableHandlesError() {
        InvocableAddComment.Request req = new InvocableAddComment.Request();
        req.parentId = null;
        req.body = null;

        Test.startTest();
        List<InvocableAddComment.Results> results =
            InvocableAddComment.execute(new List<InvocableAddComment.Request>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].isSuccess, 'Invocable should report failure');
        System.assertNotEquals(null, results[0].errorMessage, 'Error message should be populated');
    }
}
