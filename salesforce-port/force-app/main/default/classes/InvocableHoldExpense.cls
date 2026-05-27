public with sharing class InvocableHoldExpense {

    @InvocableMethod(label='Hold Expense' description='Places an expense on hold with a reason preventing it from being submitted or approved' category='Expense Management')
    public static List<Results> execute(List<Request> requests) {
        List<Results> responseList = new List<Results>();
        for (Request req : requests) {
            Results res = new Results();
            try {
                ExpenseService.holdExpense(req.expenseId, req.holdReason);
                res.expenseId = req.expenseId;
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
        @InvocableVariable(label='Expense Id' required=true)
        public Id expenseId;

        @InvocableVariable(label='Hold Reason' required=true)
        public String holdReason;
    }

    public class Results {
        @InvocableVariable(label='Expense Id')
        public Id expenseId;

        @InvocableVariable(label='Is Success')
        public Boolean isSuccess;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }
}
