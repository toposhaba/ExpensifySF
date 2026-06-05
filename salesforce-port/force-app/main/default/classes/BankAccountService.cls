public with sharing class BankAccountService {

    public class BankAccountException extends Exception {}

    public static Bank_Account__c addBankAccount(Bank_Account__c bankAccount) {
        if (bankAccount == null) {
            throw new BankAccountException('A bank account record is required');
        }
        assertCreateable();

        if (String.isBlank(bankAccount.Account_Name__c)) {
            throw new BankAccountException('Account name is required');
        }
        if (bankAccount.Owner__c == null) {
            bankAccount.Owner__c = UserInfo.getUserId();
        }
        if (String.isBlank(bankAccount.Status__c)) {
            bankAccount.Status__c = 'Pending';
        }

        if (bankAccount.Is_Default__c == true) {
            clearExistingDefaults(bankAccount.Owner__c, null);
        }

        insert bankAccount;
        return bankAccount;
    }

    public static Bank_Account__c verifyBankAccount(Id bankAccountId, Boolean isVerified) {
        if (bankAccountId == null) {
            throw new BankAccountException('A bank account Id is required');
        }
        assertUpdateable();

        Bank_Account__c bankAccount = getById(bankAccountId);
        if (bankAccount.Status__c == 'Verified') {
            throw new BankAccountException('Bank account is already verified');
        }

        bankAccount.Status__c = isVerified == true ? 'Verified' : 'Failed';
        update bankAccount;
        return bankAccount;
    }

    public static Bank_Account__c setDefaultBankAccount(Id bankAccountId) {
        if (bankAccountId == null) {
            throw new BankAccountException('A bank account Id is required');
        }
        assertUpdateable();

        Bank_Account__c bankAccount = getById(bankAccountId);
        clearExistingDefaults(bankAccount.Owner__c, bankAccountId);

        bankAccount.Is_Default__c = true;
        update bankAccount;
        return bankAccount;
    }

    public static List<Bank_Account__c> listBankAccounts(Id ownerId) {
        Id targetOwner = ownerId != null ? ownerId : UserInfo.getUserId();
        return [
            SELECT Id, Name, Owner__c, Owner__r.Name, Policy__c, Policy__r.Name,
                   Account_Name__c, Account_Number__c, Routing_Number__c,
                   Bank_Name__c, Status__c, Is_Default__c, CreatedDate
            FROM Bank_Account__c
            WHERE Owner__c = :targetOwner
            ORDER BY Is_Default__c DESC, CreatedDate DESC
            LIMIT 200
        ];
    }

    private static Bank_Account__c getById(Id bankAccountId) {
        List<Bank_Account__c> records = [
            SELECT Id, Owner__c, Policy__c, Account_Name__c, Account_Number__c,
                   Routing_Number__c, Bank_Name__c, Status__c, Is_Default__c
            FROM Bank_Account__c
            WHERE Id = :bankAccountId
            LIMIT 1
        ];
        if (records.isEmpty()) {
            throw new BankAccountException('Bank account not found');
        }
        return records[0];
    }

    private static void clearExistingDefaults(Id ownerId, Id excludeId) {
        if (ownerId == null) {
            return;
        }
        List<Bank_Account__c> currentDefaults = [
            SELECT Id, Is_Default__c
            FROM Bank_Account__c
            WHERE Owner__c = :ownerId AND Is_Default__c = true
        ];
        List<Bank_Account__c> toUpdate = new List<Bank_Account__c>();
        for (Bank_Account__c account : currentDefaults) {
            if (account.Id != excludeId) {
                account.Is_Default__c = false;
                toUpdate.add(account);
            }
        }
        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }

    private static void assertCreateable() {
        Schema.DescribeSObjectResult describe = Schema.SObjectType.Bank_Account__c;
        if (!describe.isCreateable()) {
            throw new BankAccountException('Insufficient access to create bank accounts');
        }
    }

    private static void assertUpdateable() {
        Schema.DescribeSObjectResult describe = Schema.SObjectType.Bank_Account__c;
        if (!describe.isUpdateable()) {
            throw new BankAccountException('Insufficient access to update bank accounts');
        }
    }

    @AuraEnabled
    public static Bank_Account__c createBankAccount(
        String accountName,
        String accountNumber,
        String routingNumber,
        String bankName,
        Id policyId,
        Boolean isDefault
    ) {
        try {
            Bank_Account__c bankAccount = new Bank_Account__c(
                Account_Name__c = accountName,
                Account_Number__c = accountNumber,
                Routing_Number__c = routingNumber,
                Bank_Name__c = bankName,
                Policy__c = policyId,
                Is_Default__c = isDefault == true
            );
            return addBankAccount(bankAccount);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Bank_Account__c markVerified(Id bankAccountId, Boolean isVerified) {
        try {
            return verifyBankAccount(bankAccountId, isVerified);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Bank_Account__c makeDefault(Id bankAccountId) {
        try {
            return setDefaultBankAccount(bankAccountId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Bank_Account__c> getMyBankAccounts() {
        return listBankAccounts(UserInfo.getUserId());
    }
}
