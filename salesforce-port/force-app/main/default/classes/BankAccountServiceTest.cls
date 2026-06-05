@isTest
private class BankAccountServiceTest {

    private static Bank_Account__c buildAccount(String accountName, Boolean isDefault) {
        return new Bank_Account__c(
            Account_Name__c = accountName,
            Account_Number__c = '000123456789',
            Routing_Number__c = '021000021',
            Bank_Name__c = 'Test Bank',
            Owner__c = UserInfo.getUserId(),
            Is_Default__c = isDefault
        );
    }

    @isTest
    static void testAddBankAccountDefaultsStatus() {
        Bank_Account__c account = buildAccount('Checking', false);

        Test.startTest();
        Bank_Account__c created = BankAccountService.addBankAccount(account);
        Test.stopTest();

        System.assertNotEquals(null, created.Id, 'Bank account should be inserted');
        Bank_Account__c saved = [SELECT Status__c, Owner__c FROM Bank_Account__c WHERE Id = :created.Id];
        System.assertEquals('Pending', saved.Status__c, 'New account should default to Pending');
        System.assertEquals(UserInfo.getUserId(), saved.Owner__c, 'Owner should default to running user');
    }

    @isTest
    static void testAddBankAccountRequiresRecord() {
        Test.startTest();
        try {
            BankAccountService.addBankAccount(null);
            System.assert(false, 'Should have thrown for null record');
        } catch (BankAccountService.BankAccountException e) {
            System.assert(e.getMessage().contains('required'), 'Expected required error');
        }
        Test.stopTest();
    }

    @isTest
    static void testVerifyTransition() {
        Bank_Account__c account = buildAccount('Savings', false);
        insert account;

        Test.startTest();
        Bank_Account__c verified = BankAccountService.verifyBankAccount(account.Id, true);
        Test.stopTest();

        System.assertEquals('Verified', verified.Status__c, 'Account should transition to Verified');

        Bank_Account__c saved = [SELECT Status__c FROM Bank_Account__c WHERE Id = :account.Id];
        System.assertEquals('Verified', saved.Status__c, 'Verified status should persist');
    }

    @isTest
    static void testVerifyFailureTransition() {
        Bank_Account__c account = buildAccount('Failing', false);
        insert account;

        Test.startTest();
        Bank_Account__c result = BankAccountService.verifyBankAccount(account.Id, false);
        Test.stopTest();

        System.assertEquals('Failed', result.Status__c, 'Unsuccessful verification should set Failed');
    }

    @isTest
    static void testVerifyAlreadyVerifiedThrows() {
        Bank_Account__c account = buildAccount('Already', false);
        account.Status__c = 'Verified';
        insert account;

        Test.startTest();
        try {
            BankAccountService.verifyBankAccount(account.Id, true);
            System.assert(false, 'Should have thrown for already verified account');
        } catch (BankAccountService.BankAccountException e) {
            System.assert(e.getMessage().contains('already verified'), 'Expected already verified error');
        }
        Test.stopTest();
    }

    @isTest
    static void testSingleDefaultEnforcementOnInsert() {
        Bank_Account__c first = buildAccount('First Default', true);
        BankAccountService.addBankAccount(first);

        Bank_Account__c second = buildAccount('Second Default', true);

        Test.startTest();
        BankAccountService.addBankAccount(second);
        Test.stopTest();

        List<Bank_Account__c> defaults = [
            SELECT Id FROM Bank_Account__c
            WHERE Owner__c = :UserInfo.getUserId() AND Is_Default__c = true
        ];
        System.assertEquals(1, defaults.size(), 'Only one account should remain default');
        System.assertEquals(second.Id, defaults[0].Id, 'The most recent default should win');
    }

    @isTest
    static void testSetDefaultBankAccount() {
        Bank_Account__c first = buildAccount('First', true);
        BankAccountService.addBankAccount(first);
        Bank_Account__c second = buildAccount('Second', false);
        BankAccountService.addBankAccount(second);

        Test.startTest();
        BankAccountService.setDefaultBankAccount(second.Id);
        Test.stopTest();

        Map<Id, Bank_Account__c> byId = new Map<Id, Bank_Account__c>([
            SELECT Id, Is_Default__c FROM Bank_Account__c
        ]);
        System.assertEquals(false, byId.get(first.Id).Is_Default__c, 'First should no longer be default');
        System.assertEquals(true, byId.get(second.Id).Is_Default__c, 'Second should now be default');
    }

    @isTest
    static void testListBankAccounts() {
        BankAccountService.addBankAccount(buildAccount('One', false));
        BankAccountService.addBankAccount(buildAccount('Two', true));

        Test.startTest();
        List<Bank_Account__c> results = BankAccountService.listBankAccounts(UserInfo.getUserId());
        List<Bank_Account__c> mine = BankAccountService.getMyBankAccounts();
        Test.stopTest();

        System.assertEquals(2, results.size(), 'Both accounts should be listed for the owner');
        System.assertEquals(2, mine.size(), 'getMyBankAccounts should return the running user accounts');
        System.assertEquals(true, results[0].Is_Default__c, 'Default account should be ordered first');
    }

    @isTest
    static void testCreateBankAccountAura() {
        Test.startTest();
        Bank_Account__c created = BankAccountService.createBankAccount(
            'Aura Account', '987654321', '021000021', 'Aura Bank', null, true
        );
        Test.stopTest();

        System.assertNotEquals(null, created.Id, 'Aura create should insert a record');
        System.assertEquals(true, created.Is_Default__c, 'Aura create should honor default flag');
    }

    @isTest
    static void testAuraWrappersHandleErrors() {
        Test.startTest();
        try {
            BankAccountService.markVerified(null, true);
            System.assert(false, 'Should have thrown for null id');
        } catch (Exception e) {
            System.assert(true, 'Aura wrapper surfaced the error');
        }
        try {
            BankAccountService.makeDefault(null);
            System.assert(false, 'Should have thrown for null id');
        } catch (Exception e) {
            System.assert(true, 'Aura wrapper surfaced the error');
        }
        Test.stopTest();
    }

    @isTest
    static void testInvocableVerify() {
        Bank_Account__c account = buildAccount('Invocable', false);
        insert account;

        InvocableVerifyBankAccount.Request req = new InvocableVerifyBankAccount.Request();
        req.bankAccountId = account.Id;
        req.isVerified = true;

        Test.startTest();
        List<InvocableVerifyBankAccount.Results> results = InvocableVerifyBankAccount.execute(
            new List<InvocableVerifyBankAccount.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(true, results[0].isSuccess, 'Verification should succeed');
        System.assertEquals('Verified', results[0].status, 'Status should be Verified');
    }

    @isTest
    static void testInvocableVerifyReportsFailure() {
        InvocableVerifyBankAccount.Request req = new InvocableVerifyBankAccount.Request();
        req.bankAccountId = null;
        req.isVerified = true;

        Test.startTest();
        List<InvocableVerifyBankAccount.Results> results = InvocableVerifyBankAccount.execute(
            new List<InvocableVerifyBankAccount.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(false, results[0].isSuccess, 'Missing id should fail');
        System.assertNotEquals(null, results[0].errorMessage, 'Error message should be populated');
    }
}
