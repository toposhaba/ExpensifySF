@isTest
private class AccountingSyncServiceTest {

    private class MockSuccess implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            System.assertEquals('POST', req.getMethod());
            System.assert(req.getEndpoint().startsWith('callout:'));
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(201);
            res.setBody('{"id":"EXT-123","status":"posted"}');
            return res;
        }
    }

    private class MockFailure implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"error":"server error"}');
            return res;
        }
    }

    private class MockNonJson implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('not-json');
            return res;
        }
    }

    private class MockThrows implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            throw new CalloutException('Connection timed out');
        }
    }

    @TestSetup
    static void setupTestData() {
        Expense_Policy__c policy = new Expense_Policy__c(
            Name = 'Accounting Policy',
            Currency__c = 'USD',
            Type__c = 'Corporate'
        );
        insert policy;

        Expense_Category__c category = new Expense_Category__c(
            Name = 'Travel',
            GL_Code__c = '6000',
            Enabled__c = true,
            Policy__c = policy.Id
        );
        insert category;

        Expense_Report__c report = new Expense_Report__c(
            Status__c = 'Approved',
            Currency__c = 'USD',
            Total_Amount__c = 150.00,
            Approved_Date__c = Datetime.now()
        );
        insert report;

        Expense__c expense = new Expense__c(
            Amount__c = 150.00,
            Currency__c = 'USD',
            Merchant__c = 'United Airlines',
            Expense_Date__c = Date.today(),
            Expense_Type__c = 'Cash',
            Status__c = 'Approved',
            Category__c = category.Id,
            Reimbursable__c = true,
            Report__c = report.Id
        );
        insert expense;
    }

    private static void setActiveConnection() {
        AccountingSyncService.connectionOverride = new Accounting_Connection__mdt(
            Provider__c = 'QuickBooksOnline',
            Named_Credential__c = 'QuickBooksOnline_NC',
            Is_Active__c = true
        );
        AccountingSyncService.glCodeOverride = new Map<String, String>{'Travel' => '6000'};
    }

    @isTest
    static void testExportReportSuccess() {
        Expense_Report__c report = [SELECT Id FROM Expense_Report__c LIMIT 1];
        setActiveConnection();

        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        Test.startTest();
        Accounting_Sync_Log__c log = AccountingSyncService.exportReport(report.Id, 'QuickBooksOnline');
        Test.stopTest();

        System.assertEquals('Success', log.Status__c);
        System.assertEquals(201, log.Status_Code__c);
        System.assertEquals('EXT-123', log.External_Id__c);
        System.assertEquals('QuickBooksOnline', log.Provider__c);

        Accounting_Sync_Log__c saved = [
            SELECT Status__c, External_Id__c, Payload__c FROM Accounting_Sync_Log__c WHERE Id = :log.Id
        ];
        System.assertEquals('Success', saved.Status__c);
        System.assert(saved.Payload__c.contains('"glCode":"6000"'));
        System.assert(saved.Payload__c.contains('"category":"Travel"'));
    }

    @isTest
    static void testBuildPayloadMapping() {
        Expense_Report__c report = [
            SELECT Id, Name, Status__c, Total_Amount__c, Currency__c FROM Expense_Report__c LIMIT 1
        ];

        Test.startTest();
        String payload = AccountingSyncService.buildPayload(report, new Map<String, String>{'Travel' => '6000'});
        Test.stopTest();

        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(payload);
        System.assertEquals('USD', parsed.get('currency'));
        List<Object> lineItems = (List<Object>) parsed.get('lineItems');
        System.assertEquals(1, lineItems.size());
        Map<String, Object> line = (Map<String, Object>) lineItems[0];
        System.assertEquals('6000', line.get('glCode'));
        System.assertEquals('Travel', line.get('category'));
        System.assertEquals('United Airlines', line.get('merchant'));
    }

    @isTest
    static void testBuildPayloadUnmappedCategory() {
        Expense_Report__c report = [
            SELECT Id, Name, Status__c, Total_Amount__c, Currency__c FROM Expense_Report__c LIMIT 1
        ];

        Test.startTest();
        String payload = AccountingSyncService.buildPayload(report, new Map<String, String>());
        Test.stopTest();

        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(payload);
        List<Object> lineItems = (List<Object>) parsed.get('lineItems');
        Map<String, Object> line = (Map<String, Object>) lineItems[0];
        System.assertEquals(null, line.get('glCode'));
    }

    @isTest
    static void testExportReportFailureStatus() {
        Expense_Report__c report = [SELECT Id FROM Expense_Report__c LIMIT 1];
        setActiveConnection();

        Test.setMock(HttpCalloutMock.class, new MockFailure());
        Test.startTest();
        Accounting_Sync_Log__c log = AccountingSyncService.exportReport(report.Id, 'QuickBooksOnline');
        Test.stopTest();

        System.assertEquals('Failed', log.Status__c);
        System.assertEquals(500, log.Status_Code__c);
        System.assert(log.Error_Message__c.contains('500'));
    }

    @isTest
    static void testExportReportCalloutException() {
        Expense_Report__c report = [SELECT Id FROM Expense_Report__c LIMIT 1];
        setActiveConnection();

        Test.setMock(HttpCalloutMock.class, new MockThrows());
        Test.startTest();
        Accounting_Sync_Log__c log = AccountingSyncService.exportReport(report.Id, 'QuickBooksOnline');
        Test.stopTest();

        System.assertEquals('Failed', log.Status__c);
        System.assert(log.Error_Message__c.contains('timed out'));
    }

    @isTest
    static void testExportReportNonJsonBody() {
        Expense_Report__c report = [SELECT Id FROM Expense_Report__c LIMIT 1];
        setActiveConnection();

        Test.setMock(HttpCalloutMock.class, new MockNonJson());
        Test.startTest();
        Accounting_Sync_Log__c log = AccountingSyncService.exportReport(report.Id, 'QuickBooksOnline');
        Test.stopTest();

        System.assertEquals('Success', log.Status__c);
        System.assertEquals(null, log.External_Id__c);
    }

    @isTest
    static void testExportReportNotApproved() {
        Expense_Report__c report = new Expense_Report__c(
            Status__c = 'Open',
            Currency__c = 'USD'
        );
        insert report;
        setActiveConnection();

        Test.startTest();
        try {
            AccountingSyncService.exportReport(report.Id, 'QuickBooksOnline');
            System.assert(false, 'Should throw exception');
        } catch (AccountingSyncService.SyncException e) {
            System.assert(e.getMessage().contains('approved'));
        }
        Test.stopTest();
    }

    @isTest
    static void testExportReportNoConnection() {
        Expense_Report__c report = [SELECT Id FROM Expense_Report__c LIMIT 1];

        Test.startTest();
        try {
            AccountingSyncService.exportReport(report.Id, 'QuickBooksOnline');
            System.assert(false, 'Should throw exception');
        } catch (AccountingSyncService.SyncException e) {
            System.assert(e.getMessage().contains('No active accounting connection'));
        }
        Test.stopTest();
    }

    @isTest
    static void testExportReportMissingArgs() {
        Test.startTest();
        try {
            AccountingSyncService.exportReport(null, 'QuickBooksOnline');
            System.assert(false, 'Should throw exception');
        } catch (AccountingSyncService.SyncException e) {
            System.assert(e.getMessage().contains('Report Id is required'));
        }

        Expense_Report__c report = [SELECT Id FROM Expense_Report__c LIMIT 1];
        try {
            AccountingSyncService.exportReport(report.Id, null);
            System.assert(false, 'Should throw exception');
        } catch (AccountingSyncService.SyncException e) {
            System.assert(e.getMessage().contains('Provider is required'));
        }
        Test.stopTest();
    }

    @isTest
    static void testGetConnectionQuery() {
        Test.startTest();
        Accounting_Connection__mdt connection = AccountingSyncService.getConnection('QuickBooksOnline');
        List<Accounting_Connection__mdt> connections = AccountingSyncService.getConnections();
        Test.stopTest();

        System.assertNotEquals(null, connections);
    }

    @isTest
    static void testGetApprovedReports() {
        Test.startTest();
        List<Expense_Report__c> reports = AccountingSyncService.getApprovedReports();
        Test.stopTest();

        System.assert(!reports.isEmpty());
    }

    @isTest
    static void testExportReportToProvider() {
        Expense_Report__c report = [SELECT Id FROM Expense_Report__c LIMIT 1];
        setActiveConnection();

        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        Test.startTest();
        Accounting_Sync_Log__c log = AccountingSyncService.exportReportToProvider(report.Id, 'QuickBooksOnline');
        Test.stopTest();

        System.assertEquals('Success', log.Status__c);
    }

    @isTest
    static void testExportReportToProviderError() {
        Test.startTest();
        try {
            AccountingSyncService.exportReportToProvider(null, 'QuickBooksOnline');
            System.assert(false, 'Should throw exception');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @isTest
    static void testInvocableExportReport() {
        Expense_Report__c report = [SELECT Id FROM Expense_Report__c LIMIT 1];
        setActiveConnection();

        InvocableExportReport.Request req = new InvocableExportReport.Request();
        req.reportId = report.Id;
        req.provider = 'QuickBooksOnline';

        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        Test.startTest();
        List<InvocableExportReport.Results> results = InvocableExportReport.execute(
            new List<InvocableExportReport.Request>{req}
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(true, results[0].isSuccess);
        System.assertEquals('EXT-123', results[0].externalId);
    }

    @isTest
    static void testInvocableExportReportError() {
        InvocableExportReport.Request req = new InvocableExportReport.Request();
        req.reportId = null;
        req.provider = 'QuickBooksOnline';

        Test.startTest();
        List<InvocableExportReport.Results> results = InvocableExportReport.execute(
            new List<InvocableExportReport.Request>{req}
        );
        Test.stopTest();

        System.assertEquals(false, results[0].isSuccess);
        System.assertNotEquals(null, results[0].errorMessage);
    }
}
