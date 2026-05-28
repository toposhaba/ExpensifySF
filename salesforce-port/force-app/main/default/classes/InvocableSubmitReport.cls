public with sharing class InvocableSubmitReport {

    @InvocableMethod(label='Submit Expense Report' description='Submits an expense report for approval with auto-approval check' category='Expense Management')
    public static List<Results> execute(List<Request> requests) {
        List<Results> responseList = new List<Results>();
        for (Request req : requests) {
            Results res = new Results();
            try {
                Expense_Report__c report = ExpenseReportService.submitReport(req.reportId);
                res.reportId = report.Id;
                res.newStatus = report.Status__c;
                res.approverId = report.Approver__c;
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

        @InvocableVariable(label='New Status')
        public String newStatus;

        @InvocableVariable(label='Approver Id')
        public Id approverId;

        @InvocableVariable(label='Is Success')
        public Boolean isSuccess;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }
}
