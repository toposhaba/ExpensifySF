public with sharing class InvocableApproveReport {

    @InvocableMethod(label='Approve Expense Report' description='Approves a submitted expense report and cascades status to child expenses' category='Expense Management')
    public static List<Results> execute(List<Request> requests) {
        List<Results> responseList = new List<Results>();
        for (Request req : requests) {
            Results res = new Results();
            try {
                Expense_Report__c report = ExpenseReportService.approveReport(req.reportId);
                res.reportId = report.Id;
                res.approvedDate = report.Approved_Date__c;
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

        @InvocableVariable(label='Approved Date')
        public Datetime approvedDate;

        @InvocableVariable(label='Is Success')
        public Boolean isSuccess;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }
}
