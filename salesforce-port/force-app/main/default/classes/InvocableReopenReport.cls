public with sharing class InvocableReopenReport {

    @InvocableMethod(label='Reopen Expense Report' description='Reopens a rejected or closed expense report back to Open status' category='Expense Management')
    public static List<Results> execute(List<Request> requests) {
        List<Results> responseList = new List<Results>();
        for (Request req : requests) {
            Results res = new Results();
            try {
                Expense_Report__c report = ExpenseReportService.reopenReport(req.reportId);
                res.reportId = report.Id;
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
