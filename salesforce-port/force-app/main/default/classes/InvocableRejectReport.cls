public with sharing class InvocableRejectReport {

    @InvocableMethod(label='Reject Expense Report' description='Rejects a submitted expense report with a reason and cascades status to child expenses' category='Expense Management')
    public static List<Results> execute(List<Request> requests) {
        List<Results> responseList = new List<Results>();
        for (Request req : requests) {
            Results res = new Results();
            try {
                Expense_Report__c report = ExpenseReportService.rejectReport(req.reportId, req.reason);
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

        @InvocableVariable(label='Rejection Reason' required=true)
        public String reason;
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
