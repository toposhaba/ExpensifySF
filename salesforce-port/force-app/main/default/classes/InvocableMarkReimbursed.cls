public with sharing class InvocableMarkReimbursed {

    @InvocableMethod(label='Mark Report Reimbursed' description='Marks an approved expense report as reimbursed indicating payment has been processed' category='Expense Management')
    public static List<Results> execute(List<Request> requests) {
        List<Results> responseList = new List<Results>();
        for (Request req : requests) {
            Results res = new Results();
            try {
                ExpenseReportService.markReimbursed(req.reportId);
                res.reportId = req.reportId;
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
        @InvocableVariable(label='Report Id' required=true)
        public Id reportId;
    }

    public class Results {
        @InvocableVariable(label='Report Id')
        public Id reportId;

        @InvocableVariable(label='Is Success')
        public Boolean isSuccess;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }
}
