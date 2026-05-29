public with sharing class BankAccountService {

    public static Bank_Account__c addBankAccount(Bank_Account__c account) {
        account.Status__c = account.Status__c != null ? account.Status__c : 'Pending_Verification';
        insert account;
        return account;
    }

    public static void verifyAccount(Id accountId) {
        update new Bank_Account__c(Id = accountId, Status__c = 'Verified', Verified_Date__c = Date.today());
    }

    public static void deactivateAccount(Id accountId) {
        update new Bank_Account__c(Id = accountId, Status__c = 'Inactive');
    }

    public static List<Bank_Account__c> getUserAccounts(Id userId) {
        return [
            SELECT Id, Name, Bank_Name__c, Account_Type__c, Last_Four__c,
                   Routing_Number__c, Status__c, Is_Default__c, Policy__c, Policy__r.Name
            FROM Bank_Account__c WHERE OwnerId = :userId ORDER BY Is_Default__c DESC, Name
        ];
    }

    public static List<Bank_Account__c> getPolicyAccounts(Id policyId) {
        return [
            SELECT Id, Name, Bank_Name__c, Account_Type__c, Last_Four__c, Status__c, Is_Default__c
            FROM Bank_Account__c WHERE Policy__c = :policyId AND Status__c = 'Verified'
        ];
    }

    public static void setDefault(Id accountId, Id userId) {
        List<Bank_Account__c> current = [
            SELECT Id FROM Bank_Account__c WHERE OwnerId = :userId AND Is_Default__c = true
        ];
        for (Bank_Account__c ba : current) {
            ba.Is_Default__c = false;
        }
        if (!current.isEmpty()) update current;
        update new Bank_Account__c(Id = accountId, Is_Default__c = true);
    }

    public static Wallet__c getOrCreateWallet(Id userId) {
        List<Wallet__c> wallets = [
            SELECT Id, Balance__c, Status__c, Tier__c FROM Wallet__c WHERE OwnerId = :userId LIMIT 1
        ];
        if (!wallets.isEmpty()) return wallets[0];

        Wallet__c wallet = new Wallet__c(
            OwnerId = userId,
            Balance__c = 0,
            Status__c = 'Active',
            Tier__c = 'Basic'
        );
        insert wallet;
        return wallet;
    }

    public static void processReimbursement(Id reportId, Id bankAccountId) {
        Expense_Report__c report = [
            SELECT Id, Reimbursable_Total__c, Status__c FROM Expense_Report__c WHERE Id = :reportId LIMIT 1
        ];

        if (report.Status__c != 'Approved') {
            throw new BankException('Report must be approved before reimbursement');
        }

        Payment__c payment = new Payment__c(
            Report__c = reportId,
            Amount__c = report.Reimbursable_Total__c,
            Payment_Method__c = 'ACH',
            Status__c = 'Processing',
            Payment_Date__c = Date.today()
        );
        insert payment;

        ExpenseReportService.markReimbursed(reportId);
    }

    public class BankException extends Exception {}
}
