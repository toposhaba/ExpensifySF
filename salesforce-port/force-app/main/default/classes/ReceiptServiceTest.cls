@isTest
private class ReceiptServiceTest {

    private static Expense__c createExpense() {
        Expense__c expense = new Expense__c(
            Amount__c = 50.00,
            Currency__c = 'USD',
            Merchant__c = 'Receipt Merchant',
            Expense_Date__c = Date.today(),
            Expense_Type__c = 'Cash',
            Status__c = 'Draft',
            Has_Receipt__c = false
        );
        insert expense;
        return expense;
    }

    private static ContentVersion createFile(String title) {
        ContentVersion cv = new ContentVersion(
            Title = title,
            PathOnClient = title + '.png',
            VersionData = Blob.valueOf('receipt-image-data')
        );
        insert cv;
        return [SELECT Id, ContentDocumentId, Title FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
    }

    @isTest
    static void testAttachReceiptSetsHasReceipt() {
        Expense__c expense = createExpense();
        ContentVersion cv = createFile('Receipt1');

        Test.startTest();
        Expense_Receipt__c receipt = ReceiptService.attachReceipt(expense.Id, cv.ContentDocumentId);
        Test.stopTest();

        System.assertNotEquals(null, receipt.Id, 'Receipt should be created');

        Expense__c updated = [SELECT Has_Receipt__c FROM Expense__c WHERE Id = :expense.Id];
        System.assertEquals(true, updated.Has_Receipt__c, 'Has_Receipt__c should be set');

        Expense_Receipt__c saved = [
            SELECT Content_Document_Id__c, Content_Version_Id__c, File_Name__c, File_URL__c, Scan_Status__c
            FROM Expense_Receipt__c WHERE Id = :receipt.Id
        ];
        System.assertEquals(cv.ContentDocumentId, saved.Content_Document_Id__c);
        System.assertEquals(cv.Id, saved.Content_Version_Id__c);
        System.assertEquals('Receipt1', saved.File_Name__c);
        System.assertEquals('Pending', saved.Scan_Status__c);
        System.assert(saved.File_URL__c.contains(cv.ContentDocumentId), 'File URL should reference the document');
    }

    @isTest
    static void testAttachCreatesContentDocumentLink() {
        Expense__c expense = createExpense();
        ContentVersion cv = createFile('Linked');

        Test.startTest();
        ReceiptService.attachReceipt(expense.Id, cv.ContentDocumentId);
        Test.stopTest();

        List<ContentDocumentLink> links = [
            SELECT Id FROM ContentDocumentLink
            WHERE LinkedEntityId = :expense.Id AND ContentDocumentId = :cv.ContentDocumentId
        ];
        System.assert(!links.isEmpty(), 'A ContentDocumentLink should exist');
    }

    @isTest
    static void testReplaceReceipt() {
        Expense__c expense = createExpense();
        ContentVersion original = createFile('Original');
        ContentVersion replacement = createFile('Replacement');

        Expense_Receipt__c receipt = ReceiptService.attachReceipt(expense.Id, original.ContentDocumentId);

        Test.startTest();
        Expense_Receipt__c replaced = ReceiptService.replaceReceipt(receipt.Id, replacement.ContentDocumentId);
        Test.stopTest();

        Expense_Receipt__c saved = [
            SELECT Content_Document_Id__c, File_Name__c, Scan_Status__c
            FROM Expense_Receipt__c WHERE Id = :replaced.Id
        ];
        System.assertEquals(replacement.ContentDocumentId, saved.Content_Document_Id__c);
        System.assertEquals('Replacement', saved.File_Name__c);
        System.assertEquals('Pending', saved.Scan_Status__c);

        Expense__c updated = [SELECT Has_Receipt__c FROM Expense__c WHERE Id = :expense.Id];
        System.assertEquals(true, updated.Has_Receipt__c);
    }

    @isTest
    static void testDetachReceiptClearsHasReceipt() {
        Expense__c expense = createExpense();
        ContentVersion cv = createFile('ToDetach');
        Expense_Receipt__c receipt = ReceiptService.attachReceipt(expense.Id, cv.ContentDocumentId);

        Test.startTest();
        ReceiptService.detachReceipt(receipt.Id);
        Test.stopTest();

        List<Expense_Receipt__c> remaining = [SELECT Id FROM Expense_Receipt__c WHERE Id = :receipt.Id];
        System.assert(remaining.isEmpty(), 'Receipt should be deleted');

        Expense__c updated = [SELECT Has_Receipt__c FROM Expense__c WHERE Id = :expense.Id];
        System.assertEquals(false, updated.Has_Receipt__c, 'Has_Receipt__c should be cleared');
    }

    @isTest
    static void testDetachKeepsHasReceiptWhenOthersExist() {
        Expense__c expense = createExpense();
        ContentVersion cv1 = createFile('First');
        ContentVersion cv2 = createFile('Second');
        Expense_Receipt__c r1 = ReceiptService.attachReceipt(expense.Id, cv1.ContentDocumentId);
        ReceiptService.attachReceipt(expense.Id, cv2.ContentDocumentId);

        Test.startTest();
        ReceiptService.detachReceipt(r1.Id);
        Test.stopTest();

        Expense__c updated = [SELECT Has_Receipt__c FROM Expense__c WHERE Id = :expense.Id];
        System.assertEquals(true, updated.Has_Receipt__c, 'Has_Receipt__c should remain true');
    }

    @isTest
    static void testUpdateScanStatus() {
        Expense__c expense = createExpense();
        ContentVersion cv = createFile('Scan');
        Expense_Receipt__c receipt = ReceiptService.attachReceipt(expense.Id, cv.ContentDocumentId);

        Test.startTest();
        ReceiptService.updateScanStatus(receipt.Id, ReceiptService.SCAN_STATUS_PROCESSING);
        ReceiptService.updateScanStatus(receipt.Id, ReceiptService.SCAN_STATUS_COMPLETED);
        Test.stopTest();

        Expense_Receipt__c saved = [SELECT Scan_Status__c FROM Expense_Receipt__c WHERE Id = :receipt.Id];
        System.assertEquals('Completed', saved.Scan_Status__c);
    }

    @isTest
    static void testUpdateScanStatusInvalid() {
        Expense__c expense = createExpense();
        ContentVersion cv = createFile('BadScan');
        Expense_Receipt__c receipt = ReceiptService.attachReceipt(expense.Id, cv.ContentDocumentId);

        Test.startTest();
        try {
            ReceiptService.updateScanStatus(receipt.Id, 'Nonsense');
            System.assert(false, 'Should have thrown');
        } catch (ReceiptService.ReceiptException e) {
            System.assert(e.getMessage().contains('Invalid scan status'));
        }
        Test.stopTest();
    }

    @isTest
    static void testGetReceiptsForExpense() {
        Expense__c expense = createExpense();
        ContentVersion cv = createFile('Listed');
        ReceiptService.attachReceipt(expense.Id, cv.ContentDocumentId);

        Test.startTest();
        List<Expense_Receipt__c> receipts = ReceiptService.getReceiptsForExpense(expense.Id);
        List<Expense_Receipt__c> none = ReceiptService.getReceiptsForExpense(null);
        Test.stopTest();

        System.assertEquals(1, receipts.size());
        System.assertEquals(0, none.size());
    }

    @isTest
    static void testValidationErrors() {
        ContentVersion cv = createFile('Validation');

        Test.startTest();
        try {
            ReceiptService.attachReceipt(null, cv.ContentDocumentId);
            System.assert(false, 'Should have thrown');
        } catch (ReceiptService.ReceiptException e) {
            System.assert(e.getMessage().contains('Expense Id is required'));
        }

        Expense__c expense = createExpense();
        try {
            ReceiptService.attachReceipt(expense.Id, null);
            System.assert(false, 'Should have thrown');
        } catch (ReceiptService.ReceiptException e) {
            System.assert(e.getMessage().contains('Content Document Id is required'));
        }

        try {
            ReceiptService.detachReceipt(null);
            System.assert(false, 'Should have thrown');
        } catch (ReceiptService.ReceiptException e) {
            System.assert(e.getMessage().contains('Receipt Id is required'));
        }
        Test.stopTest();
    }

    @isTest
    static void testInvocableAttachAndReplace() {
        Expense__c expense = createExpense();
        ContentVersion cv = createFile('InvocableAttach');
        ContentVersion cv2 = createFile('InvocableReplace');

        InvocableAttachReceipt.Request attachReq = new InvocableAttachReceipt.Request();
        attachReq.expenseId = expense.Id;
        attachReq.contentDocumentId = cv.ContentDocumentId;
        attachReq.scanStatus = 'Processing';

        Test.startTest();
        List<InvocableAttachReceipt.Results> attachResults =
            InvocableAttachReceipt.execute(new List<InvocableAttachReceipt.Request>{attachReq});

        InvocableAttachReceipt.Request replaceReq = new InvocableAttachReceipt.Request();
        replaceReq.receiptId = attachResults[0].receiptId;
        replaceReq.contentDocumentId = cv2.ContentDocumentId;
        List<InvocableAttachReceipt.Results> replaceResults =
            InvocableAttachReceipt.execute(new List<InvocableAttachReceipt.Request>{replaceReq});
        Test.stopTest();

        System.assertEquals(true, attachResults[0].isSuccess);
        System.assertNotEquals(null, attachResults[0].receiptId);
        System.assertEquals(true, replaceResults[0].isSuccess);

        Expense_Receipt__c saved = [
            SELECT Content_Document_Id__c, Scan_Status__c FROM Expense_Receipt__c WHERE Id = :replaceResults[0].receiptId
        ];
        System.assertEquals(cv2.ContentDocumentId, saved.Content_Document_Id__c);
    }

    @isTest
    static void testInvocableHandlesError() {
        InvocableAttachReceipt.Request badReq = new InvocableAttachReceipt.Request();
        badReq.expenseId = null;
        badReq.contentDocumentId = null;

        Test.startTest();
        List<InvocableAttachReceipt.Results> results =
            InvocableAttachReceipt.execute(new List<InvocableAttachReceipt.Request>{badReq});
        Test.stopTest();

        System.assertEquals(false, results[0].isSuccess);
        System.assertNotEquals(null, results[0].errorMessage);
    }
}
