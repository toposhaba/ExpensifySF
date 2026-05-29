public with sharing class InvocableImportExpenses {

    @InvocableMethod(label='Import Expenses from CSV' description='Imports expenses from CSV content into the system' category='Expense Management')
    public static List<Results> execute(List<Request> requests) {
        List<Results> responseList = new List<Results>();
        for (Request req : requests) {
            Results res = new Results();
            try {
                List<Expense__c> imported = ImportExportService.importFromCsv(req.csvContent, req.policyId, req.reportId);
                res.importedCount = imported.size();
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
        @InvocableVariable(label='CSV Content' required=true)
        public String csvContent;

        @InvocableVariable(label='Policy Id' required=false)
        public Id policyId;

        @InvocableVariable(label='Report Id' required=false)
        public Id reportId;
    }

    public class Results {
        @InvocableVariable(label='Imported Count')
        public Integer importedCount;

        @InvocableVariable(label='Is Success')
        public Boolean isSuccess;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }
}
