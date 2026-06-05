public with sharing class InvocableExportReportCsv {

    @InvocableMethod(label='Export Report to CSV' description='Builds CSV text for the expenses on a report, gated by the Can Export Data permission' category='Expense Management')
    public static List<Results> execute(List<Request> requests) {
        List<Results> responseList = new List<Results>();
        for (Request req : requests) {
            Results res = new Results();
            try {
                res.csvContent = ExportService.buildReportCsv(req.reportId);
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
        @InvocableVariable(label='CSV Content')
        public String csvContent;

        @InvocableVariable(label='Is Success')
        public Boolean isSuccess;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }
}
