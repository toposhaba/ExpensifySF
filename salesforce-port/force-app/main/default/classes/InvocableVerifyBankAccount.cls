public with sharing class InvocableVerifyBankAccount {

    @InvocableMethod(label='Verify Bank Account' description='Transitions a bank account to Verified or Failed status' category='Bank Accounts')
    public static List<Results> execute(List<Request> requests) {
        List<Results> responseList = new List<Results>();
        for (Request req : requests) {
            Results res = new Results();
            try {
                Boolean verified = req.isVerified != null ? req.isVerified : true;
                Bank_Account__c bankAccount = BankAccountService.verifyBankAccount(req.bankAccountId, verified);
                res.bankAccountId = bankAccount.Id;
                res.status = bankAccount.Status__c;
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
        @InvocableVariable(label='Bank Account Id' required=true)
        public Id bankAccountId;

        @InvocableVariable(label='Is Verified' required=false)
        public Boolean isVerified;
    }

    public class Results {
        @InvocableVariable(label='Bank Account Id')
        public Id bankAccountId;

        @InvocableVariable(label='Status')
        public String status;

        @InvocableVariable(label='Is Success')
        public Boolean isSuccess;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }
}
