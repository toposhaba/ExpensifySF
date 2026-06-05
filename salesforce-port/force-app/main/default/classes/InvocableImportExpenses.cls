public with sharing class InvocableImportExpenses {

    @InvocableMethod(label='Import Expenses from CSV' description='Parses CSV transaction data into Expense records with per-row validation' category='Expense Management')
    public static List<Results> execute(List<Request> requests) {
        List<Results> responseList = new List<Results>();
        for (Request req : requests) {
            Results res = new Results();
            try {
                ExpenseImportService.ImportSummary summary = ExpenseImportService.importCsv(req.csvBody, req.policyId, req.reportId);
                res.totalRows = summary.totalRows;
                res.successCount = summary.successCount;
                res.errorCount = summary.errorCount;
                res.totalAmount = summary.totalAmount;
                res.createdExpenseIds = summary.createdExpenseIds;
                res.errorMessages = new List<String>();
                for (ExpenseImportService.RowResult row : summary.rows) {
                    if (!row.isSuccess) {
                        res.errorMessages.add('Row ' + row.rowNumber + ': ' + row.errorMessage);
                    }
                }
                res.isSuccess = summary.errorCount == 0;
            } catch (Exception e) {
                res.isSuccess = false;
                res.totalRows = 0;
                res.successCount = 0;
                res.errorCount = 0;
                res.errorMessages = new List<String>{ e.getMessage() };
            }
            responseList.add(res);
        }
        return responseList;
    }

    public class Request {
        @InvocableVariable(label='CSV Body' required=true)
        public String csvBody;

        @InvocableVariable(label='Policy Id' required=false)
        public Id policyId;

        @InvocableVariable(label='Report Id' required=false)
        public Id reportId;
    }

    public class Results {
        @InvocableVariable(label='Is Success')
        public Boolean isSuccess;

        @InvocableVariable(label='Total Rows')
        public Integer totalRows;

        @InvocableVariable(label='Success Count')
        public Integer successCount;

        @InvocableVariable(label='Error Count')
        public Integer errorCount;

        @InvocableVariable(label='Total Amount')
        public Decimal totalAmount;

        @InvocableVariable(label='Created Expense Ids')
        public List<String> createdExpenseIds;

        @InvocableVariable(label='Error Messages')
        public List<String> errorMessages;
    }
}
