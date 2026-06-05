@isTest
private class InvoiceServiceTest {

    @TestSetup
    static void setupTestData() {
        Expense_Policy__c policy = new Expense_Policy__c(
            Name = 'Invoice Policy',
            Currency__c = 'USD',
            Type__c = 'Corporate',
            Approval_Mode__c = 'Basic',
            Categories_Enabled__c = true,
            Tags_Enabled__c = true
        );
        insert policy;

        Expense_Report__c report = new Expense_Report__c(
            Status__c = 'Open',
            Currency__c = 'USD',
            Policy__c = policy.Id
        );
        insert report;
    }

    private static Id policyId() {
        return [SELECT Id FROM Expense_Policy__c LIMIT 1].Id;
    }

    private static Id reportId() {
        return [SELECT Id FROM Expense_Report__c LIMIT 1].Id;
    }

    private static Invoice__c buildInvoice() {
        return new Invoice__c(
            Amount__c = 250.00,
            Currency__c = 'USD',
            Recipient_Email__c = 'client@example.com',
            Policy__c = policyId(),
            Report__c = reportId(),
            Due_Date__c = Date.today().addDays(30)
        );
    }

    @isTest
    static void testCreateInvoiceDefaults() {
        Invoice__c invoice = new Invoice__c(
            Amount__c = 100.00,
            Recipient_Email__c = 'a@b.com',
            Policy__c = policyId()
        );

        Test.startTest();
        Invoice__c created = InvoiceService.createInvoice(invoice);
        Test.stopTest();

        System.assertNotEquals(null, created.Id, 'Invoice should be inserted');
        Invoice__c stored = InvoiceService.getInvoice(created.Id);
        System.assertEquals('Draft', stored.Status__c, 'New invoice should default to Draft');
        System.assertEquals('USD', stored.Currency__c, 'Currency should default to USD');
    }

    @isTest
    static void testCreateInvoiceValidationAmount() {
        Invoice__c invoice = new Invoice__c(
            Amount__c = 0,
            Recipient_Email__c = 'a@b.com'
        );

        Test.startTest();
        try {
            InvoiceService.createInvoice(invoice);
            System.assert(false, 'Should have thrown for non-positive amount');
        } catch (InvoiceService.InvoiceException e) {
            System.assert(e.getMessage().contains('greater than zero'), 'Amount error expected');
        }
        Test.stopTest();
    }

    @isTest
    static void testCreateInvoiceValidationEmail() {
        Invoice__c missing = new Invoice__c(Amount__c = 10);
        Invoice__c invalid = new Invoice__c(Amount__c = 10, Recipient_Email__c = 'not-an-email');

        Test.startTest();
        try {
            InvoiceService.createInvoice(missing);
            System.assert(false, 'Should have thrown for missing email');
        } catch (InvoiceService.InvoiceException e) {
            System.assert(e.getMessage().contains('required'), 'Missing email error expected');
        }
        try {
            InvoiceService.createInvoice(invalid);
            System.assert(false, 'Should have thrown for invalid email');
        } catch (InvoiceService.InvoiceException e) {
            System.assert(e.getMessage().contains('not valid'), 'Invalid email error expected');
        }
        Test.stopTest();
    }

    @isTest
    static void testCreateInvoiceDueDateBeforeIssued() {
        Invoice__c invoice = new Invoice__c(
            Amount__c = 50,
            Recipient_Email__c = 'a@b.com',
            Issued_Date__c = Date.today(),
            Due_Date__c = Date.today().addDays(-5)
        );

        Test.startTest();
        try {
            InvoiceService.createInvoice(invoice);
            System.assert(false, 'Should have thrown for due before issued');
        } catch (InvoiceService.InvoiceException e) {
            System.assert(e.getMessage().contains('Due date'), 'Due date error expected');
        }
        Test.stopTest();
    }

    @isTest
    static void testSendInvoiceTransition() {
        Invoice__c created = InvoiceService.createInvoice(buildInvoice());

        Test.startTest();
        Invoice__c sent = InvoiceService.sendInvoice(created.Id);
        Test.stopTest();

        System.assertEquals('Sent', sent.Status__c, 'Status should transition to Sent');
        System.assertNotEquals(null, sent.Issued_Date__c, 'Issued date should be set on send');
    }

    @isTest
    static void testSendInvoiceRequiresDraft() {
        Invoice__c created = InvoiceService.createInvoice(buildInvoice());
        InvoiceService.sendInvoice(created.Id);

        Test.startTest();
        try {
            InvoiceService.sendInvoice(created.Id);
            System.assert(false, 'Should not send an already-sent invoice');
        } catch (InvoiceService.InvoiceException e) {
            System.assert(e.getMessage().contains('draft'), 'Only draft can be sent');
        }
        Test.stopTest();
    }

    @isTest
    static void testSendInvoiceRequiresEmail() {
        Invoice__c invoice = new Invoice__c(
            Amount__c = 75,
            Recipient_Email__c = 'temp@example.com',
            Policy__c = policyId()
        );
        Invoice__c created = InvoiceService.createInvoice(invoice);
        update new Invoice__c(Id = created.Id, Recipient_Email__c = null);

        Test.startTest();
        try {
            InvoiceService.sendInvoice(created.Id);
            System.assert(false, 'Should require recipient email before sending');
        } catch (InvoiceService.InvoiceException e) {
            System.assert(e.getMessage().contains('recipient email'), 'Recipient email required on send');
        }
        Test.stopTest();
    }

    @isTest
    static void testMarkPaidTransition() {
        Invoice__c created = InvoiceService.createInvoice(buildInvoice());
        InvoiceService.sendInvoice(created.Id);

        Test.startTest();
        Invoice__c paid = InvoiceService.markPaid(created.Id);
        Test.stopTest();

        System.assertEquals('Paid', paid.Status__c, 'Status should transition to Paid');
    }

    @isTest
    static void testMarkPaidRequiresSent() {
        Invoice__c created = InvoiceService.createInvoice(buildInvoice());

        Test.startTest();
        try {
            InvoiceService.markPaid(created.Id);
            System.assert(false, 'Draft invoice cannot be marked paid');
        } catch (InvoiceService.InvoiceException e) {
            System.assert(e.getMessage().contains('sent'), 'Only sent can be paid');
        }
        Test.stopTest();
    }

    @isTest
    static void testGetMyInvoices() {
        InvoiceService.createInvoice(buildInvoice());
        InvoiceService.createInvoice(buildInvoice());

        Test.startTest();
        List<Invoice__c> invoices = InvoiceService.getMyInvoices();
        Test.stopTest();

        System.assertEquals(2, invoices.size(), 'Owner should see both invoices');
    }

    @isTest
    static void testAuraWrappers() {
        Test.startTest();
        Invoice__c created = InvoiceService.createInvoiceRecord(buildInvoice());
        Invoice__c sent = InvoiceService.sendInvoiceRecord(created.Id);
        Invoice__c paid = InvoiceService.markInvoicePaid(created.Id);
        Test.stopTest();

        System.assertEquals('Sent', sent.Status__c);
        System.assertEquals('Paid', paid.Status__c);
    }

    @isTest
    static void testAuraWrapperHandlesError() {
        Test.startTest();
        try {
            InvoiceService.createInvoiceRecord(new Invoice__c(Amount__c = 0, Recipient_Email__c = 'a@b.com'));
            System.assert(false, 'Should have thrown AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @isTest
    static void testInvocableCreatesAndSends() {
        InvocableSendInvoice.Request req = new InvocableSendInvoice.Request();
        req.amount = 320.00;
        req.currencyCode = 'EUR';
        req.recipientEmail = 'invocable@example.com';
        req.policyId = policyId();
        req.reportId = reportId();
        req.dueDate = Date.today().addDays(15);

        Test.startTest();
        List<InvocableSendInvoice.Results> results = InvocableSendInvoice.execute(
            new List<InvocableSendInvoice.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        InvocableSendInvoice.Results res = results[0];
        System.assertEquals(true, res.isSuccess, 'Invocable should succeed');
        System.assertEquals('Sent', res.status, 'Created invoice should be Sent');
        System.assertNotEquals(null, res.invoiceId);
        System.assertNotEquals(null, res.issuedDate);
    }

    @isTest
    static void testInvocableSendsExisting() {
        Invoice__c created = InvoiceService.createInvoice(buildInvoice());
        InvocableSendInvoice.Request req = new InvocableSendInvoice.Request();
        req.invoiceId = created.Id;

        Test.startTest();
        List<InvocableSendInvoice.Results> results = InvocableSendInvoice.execute(
            new List<InvocableSendInvoice.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals('Sent', results[0].status);
        System.assertEquals(created.Id, results[0].invoiceId);
    }

    @isTest
    static void testInvocableReportsError() {
        InvocableSendInvoice.Request req = new InvocableSendInvoice.Request();
        req.amount = -1;
        req.recipientEmail = 'bad@example.com';

        Test.startTest();
        List<InvocableSendInvoice.Results> results = InvocableSendInvoice.execute(
            new List<InvocableSendInvoice.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(false, results[0].isSuccess);
        System.assertNotEquals(null, results[0].errorMessage);
    }
}
