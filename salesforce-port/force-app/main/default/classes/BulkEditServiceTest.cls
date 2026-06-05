@isTest
private class BulkEditServiceTest {

    @TestSetup
    static void setupTestData() {
        Expense_Policy__c policy = new Expense_Policy__c(
            Name = 'Bulk Edit Policy',
            Currency__c = 'USD',
            Type__c = 'Corporate',
            Approval_Mode__c = 'Basic'
        );
        insert policy;

        Expense_Category__c category = new Expense_Category__c(
            Name = 'Travel',
            Policy__c = policy.Id,
            GL_Code__c = '5001',
            Enabled__c = true
        );
        insert category;

        List<Expense__c> expenses = new List<Expense__c>();
        for (Integer i = 0; i < 4; i++) {
            expenses.add(new Expense__c(
                Amount__c = 25.00 * (i + 1),
                Currency__c = 'USD',
                Merchant__c = 'Merchant ' + i,
                Expense_Date__c = Date.today().addDays(-i),
                Expense_Type__c = 'Cash',
                Status__c = 'Draft',
                Reimbursable__c = true,
                Has_Receipt__c = false
            ));
        }
        insert expenses;
    }

    private static List<Id> allExpenseIds() {
        List<Id> ids = new List<Id>();
        for (Expense__c exp : [SELECT Id FROM Expense__c]) {
            ids.add(exp.Id);
        }
        return ids;
    }

    @isTest
    static void testBulkUpdateAppliedToAll() {
        List<Id> ids = allExpenseIds();
        Map<String, Object> fieldValues = new Map<String, Object>{
            'Merchant__c' => 'Bulk Merchant',
            'Billable__c' => true
        };

        Test.startTest();
        List<BulkEditService.BulkEditResult> results = BulkEditService.applyBulkEdit(ids, fieldValues);
        Test.stopTest();

        System.assertEquals(ids.size(), results.size(), 'Every expense should be reported');
        for (BulkEditService.BulkEditResult r : results) {
            System.assertEquals(true, r.isSuccess, 'Each record should succeed');
            System.assertEquals(null, r.errorMessage, 'No error expected');
        }

        List<Expense__c> updated = [SELECT Merchant__c, Billable__c FROM Expense__c];
        for (Expense__c exp : updated) {
            System.assertEquals('Bulk Merchant', exp.Merchant__c, 'Merchant should be applied in bulk');
            System.assertEquals(true, exp.Billable__c, 'Billable should be applied in bulk');
        }
    }

    @isTest
    static void testBulkUpdateLookupAndPicklist() {
        List<Id> ids = allExpenseIds();
        Expense_Category__c category = [SELECT Id FROM Expense_Category__c LIMIT 1];

        Map<String, Object> fieldValues = new Map<String, Object>{
            'Category__c' => category.Id,
            'Status__c' => 'Pending'
        };

        Test.startTest();
        List<BulkEditService.BulkEditResult> results = BulkEditService.applyBulkEdit(ids, fieldValues);
        Test.stopTest();

        for (BulkEditService.BulkEditResult r : results) {
            System.assertEquals(true, r.isSuccess, 'Lookup and picklist edit should succeed');
        }

        List<Expense__c> updated = [SELECT Category__c, Status__c FROM Expense__c];
        for (Expense__c exp : updated) {
            System.assertEquals(category.Id, exp.Category__c, 'Category lookup should be set');
            System.assertEquals('Pending', exp.Status__c, 'Status picklist should be set');
        }
    }

    private static Id deletedExpenseId() {
        Expense__c temp = new Expense__c(
            Amount__c = 10.00,
            Currency__c = 'USD',
            Merchant__c = 'Temp',
            Expense_Date__c = Date.today(),
            Expense_Type__c = 'Cash',
            Status__c = 'Draft'
        );
        insert temp;
        Id tempId = temp.Id;
        delete temp;
        return tempId;
    }

    @isTest
    static void testPartialFailureReporting() {
        List<Id> ids = allExpenseIds();
        ids.add(deletedExpenseId());

        Map<String, Object> fieldValues = new Map<String, Object>{
            'Merchant__c' => 'Partial Merchant'
        };

        Test.startTest();
        List<BulkEditService.BulkEditResult> results = BulkEditService.applyBulkEdit(ids, fieldValues);
        Test.stopTest();

        Integer successCount = 0;
        Integer failureCount = 0;
        for (BulkEditService.BulkEditResult r : results) {
            if (r.isSuccess) {
                successCount++;
            } else {
                failureCount++;
                System.assertNotEquals(null, r.errorMessage, 'Failures should carry a message');
            }
        }

        System.assertEquals(4, successCount, 'The four real expenses should succeed');
        System.assertEquals(1, failureCount, 'The missing id should fail');
    }

    @isTest
    static void testValidationBlocksFutureDate() {
        List<Id> ids = allExpenseIds();
        Map<String, Object> fieldValues = new Map<String, Object>{
            'Expense_Date__c' => Date.today().addDays(10)
        };

        Test.startTest();
        List<BulkEditService.BulkEditResult> results = BulkEditService.applyBulkEdit(ids, fieldValues);
        Test.stopTest();

        for (BulkEditService.BulkEditResult r : results) {
            System.assertEquals(false, r.isSuccess, 'Future date should fail validation');
            System.assert(r.errorMessage.contains('future'), 'Error should mention future date');
        }

        List<Expense__c> unchanged = [SELECT Expense_Date__c FROM Expense__c];
        for (Expense__c exp : unchanged) {
            System.assert(exp.Expense_Date__c <= Date.today(), 'No record should be updated to a future date');
        }
    }

    @isTest
    static void testValidationBlocksNonPositiveAmount() {
        List<Id> ids = allExpenseIds();
        Map<String, Object> fieldValues = new Map<String, Object>{
            'Amount__c' => 0
        };

        Test.startTest();
        List<BulkEditService.BulkEditResult> results = BulkEditService.applyBulkEdit(ids, fieldValues);
        Test.stopTest();

        for (BulkEditService.BulkEditResult r : results) {
            System.assertEquals(false, r.isSuccess, 'Zero amount should fail validation');
            System.assert(r.errorMessage.contains('greater than zero'), 'Error should mention amount rule');
        }
    }

    @isTest
    static void testStringCoercionFromLwc() {
        List<Id> ids = allExpenseIds();
        Map<String, Object> fieldValues = new Map<String, Object>{
            'Amount__c' => '99.50',
            'Billable__c' => 'true',
            'Expense_Date__c' => String.valueOf(Date.today())
        };

        Test.startTest();
        List<BulkEditService.BulkEditResult> results = BulkEditService.applyBulkEdit(ids, fieldValues);
        Test.stopTest();

        for (BulkEditService.BulkEditResult r : results) {
            System.assertEquals(true, r.isSuccess, 'String inputs should coerce and succeed');
        }

        List<Expense__c> updated = [SELECT Amount__c, Billable__c FROM Expense__c];
        for (Expense__c exp : updated) {
            System.assertEquals(99.50, exp.Amount__c, 'Amount string should be coerced to Decimal');
            System.assertEquals(true, exp.Billable__c, 'Boolean string should be coerced');
        }
    }

    @isTest
    static void testDisallowedFieldThrows() {
        List<Id> ids = allExpenseIds();
        Map<String, Object> fieldValues = new Map<String, Object>{
            'OwnerId' => UserInfo.getUserId()
        };

        Test.startTest();
        try {
            BulkEditService.applyBulkEdit(ids, fieldValues);
            System.assert(false, 'Should have thrown for a disallowed field');
        } catch (BulkEditService.BulkEditException e) {
            System.assert(e.getMessage().contains('not editable'), 'Expected not-editable error');
        }
        Test.stopTest();
    }

    @isTest
    static void testEmptyInputs() {
        Test.startTest();
        List<BulkEditService.BulkEditResult> noIds = BulkEditService.applyBulkEdit(new List<Id>(), new Map<String, Object>{ 'Merchant__c' => 'X' });
        System.assertEquals(0, noIds.size(), 'No ids should return empty results');

        try {
            BulkEditService.applyBulkEdit(allExpenseIds(), new Map<String, Object>());
            System.assert(false, 'Should have thrown for empty field map');
        } catch (BulkEditService.BulkEditException e) {
            System.assert(e.getMessage().contains('At least one field'), 'Expected required field error');
        }
        Test.stopTest();
    }

    @isTest
    static void testGetEditableExpenses() {
        Test.startTest();
        List<Expense__c> expenses = BulkEditService.getEditableExpenses();
        Test.stopTest();

        System.assertEquals(4, expenses.size(), 'Owner should see their four expenses');
    }

    @isTest
    static void testApplyEditsAuraWrapper() {
        List<Id> ids = allExpenseIds();

        Test.startTest();
        List<BulkEditService.BulkEditResult> results = BulkEditService.applyEdits(
            ids,
            new Map<String, Object>{ 'Merchant__c' => 'Aura Merchant' }
        );
        Test.stopTest();

        System.assertEquals(ids.size(), results.size(), 'Wrapper should return per-record results');
        for (BulkEditService.BulkEditResult r : results) {
            System.assertEquals(true, r.isSuccess);
        }
    }

    @isTest
    static void testApplyEditsAuraWrapperThrows() {
        Test.startTest();
        try {
            BulkEditService.applyEdits(allExpenseIds(), new Map<String, Object>{ 'OwnerId' => UserInfo.getUserId() });
            System.assert(false, 'Wrapper should surface the error');
        } catch (Exception e) {
            System.assert(true, 'AuraHandledException surfaced');
        }
        Test.stopTest();
    }

    @isTest
    static void testInvocableBulkEdit() {
        InvocableBulkEditExpenses.Request req = new InvocableBulkEditExpenses.Request();
        req.expenseIds = allExpenseIds();
        req.merchant = 'Invocable Merchant';
        req.status = 'Pending';

        Test.startTest();
        List<InvocableBulkEditExpenses.Results> results = InvocableBulkEditExpenses.execute(
            new List<InvocableBulkEditExpenses.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(true, results[0].isSuccess, 'Invocable bulk edit should succeed');
        System.assertEquals(4, results[0].successCount, 'All four expenses should update');
        System.assertEquals(0, results[0].failureCount, 'No failures expected');

        List<Expense__c> updated = [SELECT Merchant__c FROM Expense__c];
        for (Expense__c exp : updated) {
            System.assertEquals('Invocable Merchant', exp.Merchant__c);
        }
    }

    @isTest
    static void testInvocableReportsPartialFailure() {
        List<Id> ids = allExpenseIds();
        ids.add(deletedExpenseId());

        InvocableBulkEditExpenses.Request req = new InvocableBulkEditExpenses.Request();
        req.expenseIds = ids;
        req.merchant = 'Invocable Partial';

        Test.startTest();
        List<InvocableBulkEditExpenses.Results> results = InvocableBulkEditExpenses.execute(
            new List<InvocableBulkEditExpenses.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(false, results[0].isSuccess, 'Should report overall failure on partial errors');
        System.assertEquals(4, results[0].successCount);
        System.assertEquals(1, results[0].failureCount);
        System.assertEquals(1, results[0].failedExpenseIds.size(), 'Failed id should be captured');
        System.assertEquals(1, results[0].errorMessages.size(), 'Error message should be captured');
    }

    @isTest
    static void testInvocableHandlesNoFieldValues() {
        InvocableBulkEditExpenses.Request req = new InvocableBulkEditExpenses.Request();
        req.expenseIds = allExpenseIds();

        Test.startTest();
        List<InvocableBulkEditExpenses.Results> results = InvocableBulkEditExpenses.execute(
            new List<InvocableBulkEditExpenses.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(false, results[0].isSuccess, 'No field values should fail');
        System.assertNotEquals(null, results[0].errorMessage, 'Error message should be populated');
    }
}
