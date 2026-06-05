public with sharing class WalletService {

    public class WalletException extends Exception {}

    public static Wallet__c getWallet(Id walletId) {
        if (walletId == null) {
            throw new WalletException('Wallet Id is required');
        }
        assertWalletReadable();
        List<Wallet__c> wallets = [
            SELECT Id, Name, Owner__c, Owner__r.Name, Balance__c, Currency__c, Status__c
            FROM Wallet__c
            WHERE Id = :walletId
            LIMIT 1
        ];
        if (wallets.isEmpty()) {
            throw new WalletException('Wallet not found');
        }
        return wallets[0];
    }

    public static Wallet__c getWalletByOwner(Id ownerId) {
        if (ownerId == null) {
            throw new WalletException('Owner Id is required');
        }
        assertWalletReadable();
        List<Wallet__c> wallets = [
            SELECT Id, Name, Owner__c, Owner__r.Name, Balance__c, Currency__c, Status__c
            FROM Wallet__c
            WHERE Owner__c = :ownerId
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];
        return wallets.isEmpty() ? null : wallets[0];
    }

    public static Wallet__c createWallet(Wallet__c wallet) {
        if (wallet == null) {
            throw new WalletException('Wallet record is required');
        }
        if (wallet.Owner__c == null) {
            throw new WalletException('Wallet owner is required');
        }
        if (wallet.Currency__c == null) {
            wallet.Currency__c = 'USD';
        }
        if (wallet.Status__c == null) {
            wallet.Status__c = 'Active';
        }
        if (wallet.Balance__c == null) {
            wallet.Balance__c = 0;
        }
        assertWalletCreateable();
        insert wallet;
        return wallet;
    }

    public static Wallet__c getOrCreateWallet(Id ownerId, String currencyCode) {
        Wallet__c existing = getWalletByOwner(ownerId);
        if (existing != null) {
            return existing;
        }
        Wallet__c wallet = new Wallet__c(
            Owner__c = ownerId,
            Currency__c = currencyCode != null ? currencyCode : 'USD',
            Status__c = 'Active',
            Balance__c = 0
        );
        return createWallet(wallet);
    }

    public static Wallet__c creditBalance(Id walletId, Decimal amount) {
        if (amount == null || amount <= 0) {
            throw new WalletException('Credit amount must be greater than zero');
        }
        Wallet__c wallet = getWallet(walletId);
        Decimal current = wallet.Balance__c != null ? wallet.Balance__c : 0;
        Wallet__c toUpdate = new Wallet__c(
            Id = wallet.Id,
            Balance__c = current + amount
        );
        assertWalletUpdateable();
        update toUpdate;
        wallet.Balance__c = toUpdate.Balance__c;
        return wallet;
    }

    public static Wallet__c debitBalance(Id walletId, Decimal amount) {
        if (amount == null || amount <= 0) {
            throw new WalletException('Debit amount must be greater than zero');
        }
        Wallet__c wallet = getWallet(walletId);
        Decimal current = wallet.Balance__c != null ? wallet.Balance__c : 0;
        if (current < amount) {
            throw new WalletException('Insufficient funds');
        }
        Wallet__c toUpdate = new Wallet__c(
            Id = wallet.Id,
            Balance__c = current - amount
        );
        assertWalletUpdateable();
        update toUpdate;
        wallet.Balance__c = toUpdate.Balance__c;
        return wallet;
    }

    public static List<Payment__c> listPayments(Id walletId) {
        if (walletId == null) {
            throw new WalletException('Wallet Id is required');
        }
        assertPaymentReadable();
        return [
            SELECT Id, Name, Amount__c, Payment_Method__c, Status__c, Payment_Date__c,
                   Report__c, Report__r.Name, Wallet__c
            FROM Payment__c
            WHERE Wallet__c = :walletId
            ORDER BY CreatedDate DESC
            LIMIT 200
        ];
    }

    public static Payment__c processPayment(Id walletId, Id reportId, Decimal amount, String paymentMethod) {
        if (reportId == null) {
            throw new WalletException('Report Id is required');
        }
        if (amount == null || amount <= 0) {
            throw new WalletException('Payment amount must be greater than zero');
        }

        Wallet__c wallet = getWallet(walletId);
        if (wallet.Status__c != 'Active') {
            throw new WalletException('Wallet is not active');
        }

        Payment__c payment = new Payment__c(
            Wallet__c = wallet.Id,
            Report__c = reportId,
            Amount__c = amount,
            Payment_Method__c = paymentMethod != null ? paymentMethod : 'ACH',
            Status__c = 'Pending',
            Payment_Date__c = Date.today()
        );

        assertPaymentCreateable();

        Savepoint sp = Database.setSavepoint();
        try {
            debitBalance(wallet.Id, amount);
            payment.Status__c = 'Completed';
            insert payment;
        } catch (Exception e) {
            Database.rollback(sp);
            if (e instanceof WalletException) {
                throw e;
            }
            throw new WalletException('Payment failed: ' + e.getMessage());
        }
        return payment;
    }

    @AuraEnabled(cacheable=true)
    public static Wallet__c getWalletForCurrentUser() {
        try {
            return getOrCreateWallet(UserInfo.getUserId(), 'USD');
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Payment__c> getPaymentsForWallet(Id walletId) {
        try {
            return listPayments(walletId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static void assertWalletReadable() {
        if (!Schema.SObjectType.Wallet__c.isAccessible()) {
            throw new WalletException('Insufficient access to read wallets');
        }
    }

    private static void assertWalletCreateable() {
        if (!Schema.SObjectType.Wallet__c.isCreateable()) {
            throw new WalletException('Insufficient access to create wallets');
        }
    }

    private static void assertWalletUpdateable() {
        if (!Schema.SObjectType.Wallet__c.isUpdateable()) {
            throw new WalletException('Insufficient access to update wallets');
        }
    }

    private static void assertPaymentReadable() {
        if (!Schema.SObjectType.Payment__c.isAccessible()) {
            throw new WalletException('Insufficient access to read payments');
        }
    }

    private static void assertPaymentCreateable() {
        if (!Schema.SObjectType.Payment__c.isCreateable()) {
            throw new WalletException('Insufficient access to create payments');
        }
    }
}
