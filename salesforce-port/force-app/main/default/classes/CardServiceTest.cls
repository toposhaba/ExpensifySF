@isTest
private class CardServiceTest {

    @TestSetup
    static void setupTestData() {
        Expense_Policy__c policy = new Expense_Policy__c(
            Name = 'Card Policy',
            Currency__c = 'USD',
            Type__c = 'Corporate',
            Approval_Mode__c = 'Basic',
            Categories_Enabled__c = true,
            Tags_Enabled__c = true
        );
        insert policy;

        Card__c card = new Card__c(
            Card_Name__c = 'Corporate Visa',
            Last_Four__c = '4242',
            Feed_Provider__c = 'Visa',
            Is_Active__c = true,
            Cardholder__c = UserInfo.getUserId(),
            Policy__c = policy.Id
        );
        insert card;
    }

    private static Id cardId() {
        return [SELECT Id FROM Card__c LIMIT 1].Id;
    }

    private static Id policyId() {
        return [SELECT Id FROM Expense_Policy__c LIMIT 1].Id;
    }

    @isTest
    static void testImportFromCsvWithHeader() {
        String csv =
            'Date,Merchant,Amount,Currency\n' +
            '2025-01-15,Starbucks,12.50,USD\n' +
            '2025-02-20,Uber,45.00,EUR\n';

        Test.startTest();
        CardService.ImportResult result = CardService.importCsv(cardId(), csv);
        Test.stopTest();

        System.assertEquals(2, result.totalRows, 'Two data rows parsed');
        System.assertEquals(2, result.importedCount, 'Both rows imported');
        System.assertEquals(0, result.duplicateCount, 'No duplicates on first import');
        System.assertEquals(0, result.errorCount, 'No errors expected');
        System.assertEquals(2, result.createdTransactionIds.size(), 'Two transactions created');

        List<Card_Transaction__c> txns = [
            SELECT Merchant__c, Amount__c, Currency__c, Status__c
            FROM Card_Transaction__c
            ORDER BY Amount__c ASC
        ];
        System.assertEquals(2, txns.size());
        System.assertEquals('Starbucks', txns[0].Merchant__c);
        System.assertEquals('USD', txns[0].Currency__c);
        System.assertEquals('Unmatched', txns[0].Status__c, 'New transactions start unmatched');
        System.assertEquals('EUR', txns[1].Currency__c);
    }

    @isTest
    static void testDedupeSkipsRepeatedTransactions() {
        String csv =
            'Date,Merchant,Amount,Currency\n' +
            '2025-03-01,Hotel,150.00,USD\n';

        CardService.importCsv(cardId(), csv);

        Test.startTest();
        CardService.ImportResult second = CardService.importCsv(cardId(), csv);
        Test.stopTest();

        System.assertEquals(1, second.totalRows);
        System.assertEquals(0, second.importedCount, 'Repeated row not imported');
        System.assertEquals(1, second.duplicateCount, 'Repeated row flagged as duplicate');
        System.assertEquals(1, [SELECT COUNT() FROM Card_Transaction__c], 'Only one transaction stored');
    }

    @isTest
    static void testDedupeWithinSameBatch() {
        String csv =
            'Date,Merchant,Amount,Currency\n' +
            '2025-04-10,Taxi,20.00,USD\n' +
            '2025-04-10,Taxi,20.00,USD\n';

        Test.startTest();
        CardService.ImportResult result = CardService.importCsv(cardId(), csv);
        Test.stopTest();

        System.assertEquals(2, result.totalRows);
        System.assertEquals(1, result.importedCount, 'Only first occurrence imported');
        System.assertEquals(1, result.duplicateCount, 'Second occurrence deduped');
    }

    @isTest
    static void testImportErrorRows() {
        String csv =
            'Date,Merchant,Amount,Currency\n' +
            '2025-05-01,Good,10.00,USD\n' +
            'not-a-date,Bad Date,20.00,USD\n' +
            '2025-05-03,No Amount,,USD\n';

        Test.startTest();
        CardService.ImportResult result = CardService.importCsv(cardId(), csv);
        Test.stopTest();

        System.assertEquals(3, result.totalRows);
        System.assertEquals(1, result.importedCount, 'Only the valid row imports');
        System.assertEquals(2, result.errorCount, 'Two invalid rows reported');
        System.assertEquals(2, result.errors.size(), 'Error messages captured');
    }

    @isTest
    static void testMatchTransactionLinksExistingExpense() {
        CardService.importCsv(cardId(), 'Date,Merchant,Amount,Currency\n2025-06-01,Lunch,18.00,USD\n');
        Card_Transaction__c txn = [SELECT Id FROM Card_Transaction__c LIMIT 1];

        Expense__c expense = new Expense__c(
            Amount__c = 18.00,
            Currency__c = 'USD',
            Merchant__c = 'Lunch',
            Expense_Date__c = Date.newInstance(2025, 6, 1),
            Expense_Type__c = 'Card',
            Policy__c = policyId()
        );
        Expense__c created = ExpenseService.createExpense(expense);

        Test.startTest();
        Card_Transaction__c matched = CardService.matchTransaction(txn.Id, created.Id);
        Test.stopTest();

        System.assertEquals('Matched', matched.Status__c, 'Status flips to Matched');
        System.assertEquals(created.Id, matched.Matched_Expense__c, 'Linked to provided expense');
        System.assertEquals(1, [SELECT COUNT() FROM Expense__c], 'No new expense created when linking');
    }

    @isTest
    static void testMatchTransactionCreatesExpense() {
        CardService.importCsv(cardId(), 'Date,Merchant,Amount,Currency\n2025-07-01,Office Supplies,75.25,USD\n');
        Card_Transaction__c txn = [SELECT Id FROM Card_Transaction__c LIMIT 1];

        Test.startTest();
        Card_Transaction__c matched = CardService.matchTransaction(txn.Id, null);
        Test.stopTest();

        System.assertEquals('Matched', matched.Status__c, 'Status flips to Matched');
        System.assertNotEquals(null, matched.Matched_Expense__c, 'A new expense was linked');

        Expense__c expense = [
            SELECT Amount__c, Merchant__c, Expense_Type__c, Policy__c
            FROM Expense__c
            WHERE Id = :matched.Matched_Expense__c
            LIMIT 1
        ];
        System.assertEquals(75.25, expense.Amount__c, 'Expense amount copied from transaction');
        System.assertEquals('Office Supplies', expense.Merchant__c);
        System.assertEquals('Card', expense.Expense_Type__c);
        System.assertEquals(policyId(), expense.Policy__c, 'Expense inherits card policy');
    }

    @isTest
    static void testImportTransactionsFromList() {
        CardService.TransactionInput input = new CardService.TransactionInput();
        input.postedDate = Date.newInstance(2025, 8, 1);
        input.merchant = 'Direct List';
        input.amount = 99.99;
        input.currencyCode = 'gbp';

        Test.startTest();
        CardService.ImportResult result = CardService.importTransactions(
            cardId(),
            new List<CardService.TransactionInput>{ input }
        );
        Test.stopTest();

        System.assertEquals(1, result.importedCount);
        Card_Transaction__c txn = [SELECT Currency__c, Merchant__c FROM Card_Transaction__c LIMIT 1];
        System.assertEquals('GBP', txn.Currency__c, 'Currency normalized to upper case');
        System.assertEquals('Direct List', txn.Merchant__c);
    }

    @isTest
    static void testInvocableImportCardTransactions() {
        InvocableImportCardTransactions.Request req = new InvocableImportCardTransactions.Request();
        req.cardId = cardId();
        req.csvBody = 'Date,Merchant,Amount,Currency\n2025-09-09,Cafe,9.00,USD\nbad,Broken,bad,USD\n';

        Test.startTest();
        List<InvocableImportCardTransactions.Results> results =
            InvocableImportCardTransactions.execute(new List<InvocableImportCardTransactions.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, results.size());
        InvocableImportCardTransactions.Results res = results[0];
        System.assertEquals(2, res.totalRows);
        System.assertEquals(1, res.importedCount);
        System.assertEquals(1, res.errorCount);
        System.assertEquals(false, res.isSuccess, 'Has at least one error');
        System.assertEquals(1, res.createdTransactionIds.size());
    }

    @isTest
    static void testGetCardsAndTransactions() {
        CardService.importCsv(cardId(), 'Date,Merchant,Amount,Currency\n2025-10-01,Read Test,5.00,USD\n');

        Test.startTest();
        List<Card__c> cards = CardService.getCards(policyId());
        List<Card_Transaction__c> txns = CardService.getTransactions(cardId());
        Test.stopTest();

        System.assertEquals(1, cards.size(), 'Card returned for policy');
        System.assertEquals('Corporate Visa', cards[0].Card_Name__c);
        System.assertEquals(1, txns.size(), 'Transaction returned for card');
    }

    @isTest
    static void testNoHeaderPositionalMapping() {
        String csv =
            '2025-11-01,Positional,30.00,USD\n' +
            '20251102,Compact,5.00,USD\n';

        Test.startTest();
        CardService.ImportResult result = CardService.importCsv(cardId(), csv);
        Test.stopTest();

        System.assertEquals(2, result.totalRows, 'Both rows treated as data');
        System.assertEquals(2, result.importedCount);
    }

    @isTest
    static void testEmptyCsvThrows() {
        Test.startTest();
        try {
            CardService.importCsv(cardId(), '   ');
            System.assert(false, 'Should have thrown for empty CSV');
        } catch (CardService.CardServiceException e) {
            System.assert(e.getMessage().contains('No data'), 'Reports empty CSV');
        }
        Test.stopTest();
    }

    @isTest
    static void testImportFromCsvAuraEntryPoint() {
        Test.startTest();
        CardService.ImportResult result = CardService.importFromCsv(
            cardId(),
            'Date,Merchant,Amount,Currency\n2025-12-01,Aura,11.00,USD\n'
        );
        Test.stopTest();

        System.assertEquals(1, result.importedCount);
    }

    @isTest
    static void testImportFromCsvAuraThrowsHandled() {
        Test.startTest();
        try {
            CardService.importFromCsv(cardId(), '');
            System.assert(false, 'Should have thrown AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @isTest
    static void testCreateCard() {
        Card__c card = new Card__c(
            Card_Name__c = 'Secondary Card',
            Last_Four__c = '1111',
            Feed_Provider__c = 'Mastercard',
            Is_Active__c = true,
            Policy__c = policyId()
        );

        Test.startTest();
        Card__c created = CardService.createCard(card);
        Test.stopTest();

        System.assertNotEquals(null, created.Id, 'Card inserted');
    }
}
