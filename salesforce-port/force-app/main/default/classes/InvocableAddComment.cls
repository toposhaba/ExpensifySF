public with sharing class InvocableAddComment {

    @InvocableMethod(label='Add Comment' description='Adds a comment to an expense or expense report' category='Expense Management')
    public static List<Results> execute(List<Request> requests) {
        List<Results> responseList = new List<Results>();
        for (Request req : requests) {
            Results res = new Results();
            try {
                Expense_Comment__c comment = CommentService.addComment(req.parentId, req.body);
                res.commentId = comment.Id;
                res.isSuccess = true;
            } catch (Exception e) {
                res.isSuccess = false;
                res.errorMessage = e.getMessage();
            }
            responseList.add(res);
        }
        return responseList;
    }

    public class Request {
        @InvocableVariable(label='Parent Id' description='Id of the Expense or Expense Report' required=true)
        public Id parentId;

        @InvocableVariable(label='Body' description='Comment text' required=true)
        public String body;
    }

    public class Results {
        @InvocableVariable(label='Comment Id')
        public Id commentId;

        @InvocableVariable(label='Is Success')
        public Boolean isSuccess;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }
}
