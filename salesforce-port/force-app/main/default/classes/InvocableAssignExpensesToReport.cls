public with sharing class InvocableAssignExpensesToReport {

    @InvocableMethod(label='Assign Expenses to Report' description='Assigns one or more expenses to an expense report and recalculates report totals' category='Expense Management')
    public static List<Results> execute(List<Request> requests) {
        List<Results> responseList = new List<Results>();
        for (Request req : requests) {
            Results res = new Results();
            try {
                ExpenseService.assignToReport(req.expenseIds, req.reportId);
                res.reportId = req.reportId;
                res.assignedCount = req.expenseIds.size();
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
        @InvocableVariable(label='Expense Ids' required=true)
        public List<Id> expenseIds;

        @InvocableVariable(label='Report Id' required=true)
        public Id reportId;
    }

    public class Results {
        @InvocableVariable(label='Report Id')
        public Id reportId;

        @InvocableVariable(label='Assigned Count')
        public Integer assignedCount;

        @InvocableVariable(label='Is Success')
        public Boolean isSuccess;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }
}
