@isTest
private class WalletServiceTest {

    private static Wallet__c buildWallet(Decimal balance) {
        Wallet__c wallet = new Wallet__c(
            Owner__c = UserInfo.getUserId(),
            Currency__c = 'USD',
            Status__c = 'Active',
            Balance__c = balance
        );
        insert wallet;
        return wallet;
    }

    private static Expense_Report__c buildReport() {
        Expense_Report__c report = new Expense_Report__c(
            Status__c = 'Approved',
            Currency__c = 'USD'
        );
        insert report;
        return report;
    }

    @isTest
    static void testCreateWalletDefaults() {
        Wallet__c wallet = new Wallet__c(Owner__c = UserInfo.getUserId());

        Test.startTest();
        Wallet__c created = WalletService.createWallet(wallet);
        Test.stopTest();

        Wallet__c saved = [SELECT Currency__c, Status__c, Balance__c FROM Wallet__c WHERE Id = :created.Id];
        System.assertEquals('USD', saved.Currency__c, 'Currency should default to USD');
        System.assertEquals('Active', saved.Status__c, 'Status should default to Active');
        System.assertEquals(0, saved.Balance__c, 'Balance should default to zero');
    }

    @isTest
    static void testGetOrCreateWalletReuses() {
        Wallet__c first = WalletService.getOrCreateWallet(UserInfo.getUserId(), 'USD');

        Test.startTest();
        Wallet__c second = WalletService.getOrCreateWallet(UserInfo.getUserId(), 'USD');
        Test.stopTest();

        System.assertEquals(first.Id, second.Id, 'Existing wallet should be reused');
        Integer count = [SELECT COUNT() FROM Wallet__c WHERE Owner__c = :UserInfo.getUserId()];
        System.assertEquals(1, count, 'Only one wallet should exist for the owner');
    }

    @isTest
    static void testCreditBalance() {
        Wallet__c wallet = buildWallet(100.00);

        Test.startTest();
        WalletService.creditBalance(wallet.Id, 50.00);
        Test.stopTest();

        Wallet__c saved = [SELECT Balance__c FROM Wallet__c WHERE Id = :wallet.Id];
        System.assertEquals(150.00, saved.Balance__c, 'Credit should add to the balance');
    }

    @isTest
    static void testDebitBalance() {
        Wallet__c wallet = buildWallet(100.00);

        Test.startTest();
        WalletService.debitBalance(wallet.Id, 40.00);
        Test.stopTest();

        Wallet__c saved = [SELECT Balance__c FROM Wallet__c WHERE Id = :wallet.Id];
        System.assertEquals(60.00, saved.Balance__c, 'Debit should subtract from the balance');
    }

    @isTest
    static void testDebitInsufficientFundsThrows() {
        Wallet__c wallet = buildWallet(25.00);

        Test.startTest();
        try {
            WalletService.debitBalance(wallet.Id, 100.00);
            System.assert(false, 'Should have thrown for insufficient funds');
        } catch (WalletService.WalletException e) {
            System.assert(e.getMessage().contains('Insufficient'), 'Expected insufficient funds error');
        }
        Test.stopTest();

        Wallet__c saved = [SELECT Balance__c FROM Wallet__c WHERE Id = :wallet.Id];
        System.assertEquals(25.00, saved.Balance__c, 'Balance should be unchanged after failed debit');
    }

    @isTest
    static void testCreditNonPositiveThrows() {
        Wallet__c wallet = buildWallet(10.00);

        Test.startTest();
        try {
            WalletService.creditBalance(wallet.Id, 0);
            System.assert(false, 'Should have thrown for non-positive credit');
        } catch (WalletService.WalletException e) {
            System.assert(e.getMessage().contains('greater than zero'), 'Expected positive amount error');
        }
        Test.stopTest();
    }

    @isTest
    static void testProcessPaymentLinksAndDebits() {
        Wallet__c wallet = buildWallet(500.00);
        Expense_Report__c report = buildReport();

        Test.startTest();
        Payment__c payment = WalletService.processPayment(wallet.Id, report.Id, 200.00, 'ACH');
        Test.stopTest();

        Payment__c saved = [
            SELECT Wallet__c, Report__c, Amount__c, Status__c
            FROM Payment__c WHERE Id = :payment.Id
        ];
        System.assertEquals(wallet.Id, saved.Wallet__c, 'Payment should be linked to the wallet');
        System.assertEquals(report.Id, saved.Report__c, 'Payment should be linked to the report');
        System.assertEquals(200.00, saved.Amount__c, 'Payment amount should match');
        System.assertEquals('Completed', saved.Status__c, 'Payment should be completed');

        Wallet__c updated = [SELECT Balance__c FROM Wallet__c WHERE Id = :wallet.Id];
        System.assertEquals(300.00, updated.Balance__c, 'Wallet balance should be debited by the payment amount');
    }

    @isTest
    static void testProcessPaymentInsufficientFundsRollsBack() {
        Wallet__c wallet = buildWallet(50.00);
        Expense_Report__c report = buildReport();

        Test.startTest();
        try {
            WalletService.processPayment(wallet.Id, report.Id, 200.00, 'ACH');
            System.assert(false, 'Should have thrown for insufficient funds');
        } catch (WalletService.WalletException e) {
            System.assert(e.getMessage().contains('Insufficient'), 'Expected insufficient funds error');
        }
        Test.stopTest();

        Integer payments = [SELECT COUNT() FROM Payment__c WHERE Wallet__c = :wallet.Id];
        System.assertEquals(0, payments, 'No payment should be created on failure');
        Wallet__c saved = [SELECT Balance__c FROM Wallet__c WHERE Id = :wallet.Id];
        System.assertEquals(50.00, saved.Balance__c, 'Balance should be restored after rollback');
    }

    @isTest
    static void testListPayments() {
        Wallet__c wallet = buildWallet(500.00);
        Expense_Report__c report = buildReport();
        WalletService.processPayment(wallet.Id, report.Id, 100.00, 'ACH');
        WalletService.processPayment(wallet.Id, report.Id, 75.00, 'Check');

        Test.startTest();
        List<Payment__c> payments = WalletService.listPayments(wallet.Id);
        Test.stopTest();

        System.assertEquals(2, payments.size(), 'Both payments should be returned for the wallet');
    }

    @isTest
    static void testGetWalletNotFoundThrows() {
        Test.startTest();
        try {
            WalletService.getWallet(null);
            System.assert(false, 'Should have thrown for null wallet id');
        } catch (WalletService.WalletException e) {
            System.assert(e.getMessage().contains('required'), 'Expected required id error');
        }
        Test.stopTest();
    }

    @isTest
    static void testAuraWrappers() {
        Test.startTest();
        Wallet__c wallet = WalletService.getWalletForCurrentUser();
        List<Payment__c> payments = WalletService.getPaymentsForWallet(wallet.Id);
        Test.stopTest();

        System.assertNotEquals(null, wallet.Id, 'Wallet should be returned for current user');
        System.assertEquals(0, payments.size(), 'New wallet should have no payments');
    }

    @isTest
    static void testInvocableProcessWalletPayment() {
        Wallet__c wallet = buildWallet(500.00);
        Expense_Report__c report = buildReport();

        InvocableProcessWalletPayment.Request req = new InvocableProcessWalletPayment.Request();
        req.walletId = wallet.Id;
        req.reportId = report.Id;
        req.amount = 150.00;
        req.paymentMethod = 'Wire';

        Test.startTest();
        List<InvocableProcessWalletPayment.Results> results = InvocableProcessWalletPayment.execute(
            new List<InvocableProcessWalletPayment.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(true, results[0].isSuccess, 'Payment should succeed');
        System.assertEquals(350.00, results[0].remainingBalance, 'Remaining balance should reflect the debit');
        System.assertNotEquals(null, results[0].paymentId, 'Payment id should be populated');
    }

    @isTest
    static void testInvocableCreatesWalletFromOwner() {
        Expense_Report__c report = buildReport();

        InvocableProcessWalletPayment.Request req = new InvocableProcessWalletPayment.Request();
        req.ownerId = UserInfo.getUserId();
        req.reportId = report.Id;
        req.amount = 10.00;

        WalletService.getOrCreateWallet(UserInfo.getUserId(), 'USD');
        WalletService.creditBalance(
            WalletService.getWalletByOwner(UserInfo.getUserId()).Id,
            100.00
        );

        Test.startTest();
        List<InvocableProcessWalletPayment.Results> results = InvocableProcessWalletPayment.execute(
            new List<InvocableProcessWalletPayment.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(true, results[0].isSuccess, 'Payment should succeed using owner-resolved wallet');
        System.assertNotEquals(null, results[0].walletId, 'Wallet id should be resolved');
    }

    @isTest
    static void testInvocableReportsFailure() {
        Wallet__c wallet = buildWallet(10.00);
        Expense_Report__c report = buildReport();

        InvocableProcessWalletPayment.Request req = new InvocableProcessWalletPayment.Request();
        req.walletId = wallet.Id;
        req.reportId = report.Id;
        req.amount = 999.00;

        Test.startTest();
        List<InvocableProcessWalletPayment.Results> results = InvocableProcessWalletPayment.execute(
            new List<InvocableProcessWalletPayment.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(false, results[0].isSuccess, 'Payment should fail for insufficient funds');
        System.assertNotEquals(null, results[0].errorMessage, 'Error message should be populated');
    }
}
