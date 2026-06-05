public with sharing class InvocableImportCardTransactions {

    @InvocableMethod(label='Import Card Transactions' description='Imports company card feed transactions from CSV with de-duplication' category='Company Cards')
    public static List<Results> execute(List<Request> requests) {
        List<Results> responseList = new List<Results>();
        for (Request req : requests) {
            Results res = new Results();
            try {
                CardService.ImportResult result = CardService.importCsv(req.cardId, req.csvBody);
                res.totalRows = result.totalRows;
                res.importedCount = result.importedCount;
                res.duplicateCount = result.duplicateCount;
                res.errorCount = result.errorCount;
                res.errorMessages = result.errors;
                res.createdTransactionIds = new List<String>();
                for (Id txnId : result.createdTransactionIds) {
                    res.createdTransactionIds.add(String.valueOf(txnId));
                }
                res.isSuccess = result.errorCount == 0;
            } catch (Exception e) {
                res.isSuccess = false;
                res.totalRows = 0;
                res.importedCount = 0;
                res.duplicateCount = 0;
                res.errorCount = 0;
                res.errorMessages = new List<String>{ e.getMessage() };
            }
            responseList.add(res);
        }
        return responseList;
    }

    public class Request {
        @InvocableVariable(label='Card Id' required=true)
        public Id cardId;

        @InvocableVariable(label='CSV Body' required=true)
        public String csvBody;
    }

    public class Results {
        @InvocableVariable(label='Is Success')
        public Boolean isSuccess;

        @InvocableVariable(label='Total Rows')
        public Integer totalRows;

        @InvocableVariable(label='Imported Count')
        public Integer importedCount;

        @InvocableVariable(label='Duplicate Count')
        public Integer duplicateCount;

        @InvocableVariable(label='Error Count')
        public Integer errorCount;

        @InvocableVariable(label='Created Transaction Ids')
        public List<String> createdTransactionIds;

        @InvocableVariable(label='Error Messages')
        public List<String> errorMessages;
    }
}
