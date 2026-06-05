public with sharing class InvocableProcessWalletPayment {

    @InvocableMethod(label='Process Wallet Payment' description='Debits a wallet balance and records a payment against an expense report' category='Wallet')
    public static List<Results> execute(List<Request> requests) {
        List<Results> responseList = new List<Results>();
        for (Request req : requests) {
            Results res = new Results();
            try {
                Id walletId = req.walletId;
                if (walletId == null && req.ownerId != null) {
                    walletId = WalletService.getOrCreateWallet(req.ownerId, req.currencyCode).Id;
                }
                Payment__c payment = WalletService.processPayment(
                    walletId,
                    req.reportId,
                    req.amount,
                    req.paymentMethod
                );
                Wallet__c wallet = WalletService.getWallet(walletId);
                res.paymentId = payment.Id;
                res.walletId = walletId;
                res.remainingBalance = wallet.Balance__c;
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
        @InvocableVariable(label='Wallet Id' required=false)
        public Id walletId;

        @InvocableVariable(label='Owner Id' required=false)
        public Id ownerId;

        @InvocableVariable(label='Report Id' required=true)
        public Id reportId;

        @InvocableVariable(label='Amount' required=true)
        public Decimal amount;

        @InvocableVariable(label='Payment Method' required=false)
        public String paymentMethod;

        @InvocableVariable(label='Currency Code' required=false)
        public String currencyCode;
    }

    public class Results {
        @InvocableVariable(label='Payment Id')
        public Id paymentId;

        @InvocableVariable(label='Wallet Id')
        public Id walletId;

        @InvocableVariable(label='Remaining Balance')
        public Decimal remainingBalance;

        @InvocableVariable(label='Is Success')
        public Boolean isSuccess;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }
}
