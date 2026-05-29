public with sharing class InvocableSyncToAccounting {

    @InvocableMethod(label='Sync Report to Accounting' description='Syncs an approved expense report to an external accounting system via Named Credentials' category='Expense Management')
    public static List<Results> execute(List<Request> requests) {
        List<Results> responseList = new List<Results>();
        for (Request req : requests) {
            Results res = new Results();
            try {
                Map<String, Object> response;
                switch on req.provider {
                    when 'QuickBooks' {
                        response = AccountingIntegrationService.syncToQuickBooks(req.reportId);
                    }
                    when 'Xero' {
                        response = AccountingIntegrationService.syncToXero(req.reportId);
                    }
                    when 'NetSuite' {
                        response = AccountingIntegrationService.syncToNetSuite(req.reportId);
                    }
                    when 'SageIntacct' {
                        response = AccountingIntegrationService.syncToSageIntacct(req.reportId);
                    }
                    when else {
                        throw new AccountingIntegrationService.IntegrationException('Unknown provider: ' + req.provider);
                    }
                }
                res.externalId = response != null ? String.valueOf(response.get('Id')) : null;
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

        @InvocableVariable(label='Provider (QuickBooks, Xero, NetSuite, SageIntacct)' required=true)
        public String provider;
    }

    public class Results {
        @InvocableVariable(label='External Id')
        public String externalId;

        @InvocableVariable(label='Is Success')
        public Boolean isSuccess;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }
}
