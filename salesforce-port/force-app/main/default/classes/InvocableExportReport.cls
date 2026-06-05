public with sharing class InvocableExportReport {

    @InvocableMethod(label='Export Report to Accounting' description='Exports an approved expense report to a connected accounting provider' category='Accounting')
    public static List<Results> execute(List<Request> requests) {
        List<Results> responseList = new List<Results>();
        for (Request req : requests) {
            Results res = new Results();
            try {
                Accounting_Sync_Log__c log = AccountingSyncService.exportReport(req.reportId, req.provider);
                res.syncLogId = log.Id;
                res.status = log.Status__c;
                res.externalId = log.External_Id__c;
                res.isSuccess = log.Status__c == 'Success';
                res.errorMessage = log.Error_Message__c;
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

        @InvocableVariable(label='Provider' required=true)
        public String provider;
    }

    public class Results {
        @InvocableVariable(label='Sync Log Id')
        public Id syncLogId;

        @InvocableVariable(label='Status')
        public String status;

        @InvocableVariable(label='External Id')
        public String externalId;

        @InvocableVariable(label='Is Success')
        public Boolean isSuccess;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }
}
