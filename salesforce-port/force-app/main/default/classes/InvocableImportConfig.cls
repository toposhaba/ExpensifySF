public with sharing class InvocableImportConfig {

    @InvocableMethod(label='Import Policy Configuration from CSV' description='Bulk upserts categories, tags, or members for a policy from CSV data' category='Expense Management')
    public static List<Results> execute(List<Request> requests) {
        List<Results> responseList = new List<Results>();
        for (Request req : requests) {
            Results res = new Results();
            try {
                ConfigImportService.ImportSummary summary = ConfigImportService.runImport(req.csvBody, req.policyId, req.importType);
                res.importType = summary.importType;
                res.totalRows = summary.totalRows;
                res.successCount = summary.successCount;
                res.errorCount = summary.errorCount;
                res.createdCount = summary.createdCount;
                res.updatedCount = summary.updatedCount;
                res.recordIds = summary.recordIds;
                res.errorMessages = new List<String>();
                for (ConfigImportService.RowResult row : summary.rows) {
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
                res.createdCount = 0;
                res.updatedCount = 0;
                res.errorMessages = new List<String>{ e.getMessage() };
            }
            responseList.add(res);
        }
        return responseList;
    }

    public class Request {
        @InvocableVariable(label='CSV Body' required=true)
        public String csvBody;

        @InvocableVariable(label='Policy Id' required=true)
        public Id policyId;

        @InvocableVariable(label='Import Type' description='Categories, Tags, or Members' required=true)
        public String importType;
    }

    public class Results {
        @InvocableVariable(label='Is Success')
        public Boolean isSuccess;

        @InvocableVariable(label='Import Type')
        public String importType;

        @InvocableVariable(label='Total Rows')
        public Integer totalRows;

        @InvocableVariable(label='Success Count')
        public Integer successCount;

        @InvocableVariable(label='Error Count')
        public Integer errorCount;

        @InvocableVariable(label='Created Count')
        public Integer createdCount;

        @InvocableVariable(label='Updated Count')
        public Integer updatedCount;

        @InvocableVariable(label='Record Ids')
        public List<String> recordIds;

        @InvocableVariable(label='Error Messages')
        public List<String> errorMessages;
    }
}
