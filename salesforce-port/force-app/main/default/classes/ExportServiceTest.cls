@isTest
private class ExportServiceTest {

    private static User buildUser(String alias) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String uniq = alias + System.currentTimeMillis() + String.valueOf(Math.round(Math.random() * 100000));
        return new User(
            Alias = alias.left(8),
            Email = uniq + '@example.com',
            Username = uniq + '@example.com.invalid',
            LastName = 'Exporter',
            FirstName = alias,
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
    }

    private static User createExportUser() {
        User u = buildUser('exp');
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert u;
            PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'Expense_Admin' LIMIT 1];
            insert new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id);
        }
        return u;
    }

    private static Id seedReport() {
        Expense_Report__c report = new Expense_Report__c(
            Status__c = 'Open',
            Currency__c = 'USD'
        );
        insert report;

        List<Expense__c> expenses = new List<Expense__c>{
            new Expense__c(
                Amount__c = 25.50,
                Currency__c = 'USD',
                Merchant__c = 'Coffee, Tea & Co',
                Expense_Date__c = Date.today(),
                Expense_Type__c = 'Cash',
                Status__c = 'Draft',
                Billable__c = true,
                Reimbursable__c = true,
                Description__c = 'Line with "quotes" and, comma',
                Report__c = report.Id
            ),
            new Expense__c(
                Amount__c = 100.00,
                Currency__c = 'USD',
                Merchant__c = 'Hotel',
                Expense_Date__c = Date.today(),
                Expense_Type__c = 'Card',
                Status__c = 'Draft',
                Billable__c = false,
                Reimbursable__c = false,
                Report__c = report.Id
            )
        };
        insert expenses;
        return report.Id;
    }

    @isTest
    static void testGetReportCsvWithPermission() {
        User u = createExportUser();
        Id reportId = seedReport();
        String csv;
        System.runAs(u) {
            Test.startTest();
            csv = ExportService.getReportCsv(reportId);
            Test.stopTest();
        }

        System.assertNotEquals(null, csv, 'CSV should be returned');
        List<String> rows = csv.split('\n');
        System.assertEquals(3, rows.size(), 'Header plus two expense rows expected');
        System.assert(rows[0].contains('"Date"'), 'Header should contain Date column');
        System.assert(rows[0].contains('"Amount"'), 'Header should contain Amount column');
        System.assert(csv.contains('"Coffee, Tea & Co"'), 'Merchant with comma should be quoted');
        System.assert(csv.contains('""quotes""'), 'Embedded quotes should be escaped');
        System.assert(csv.contains('"Hotel"'), 'Second expense merchant should be present');
    }

    @isTest
    static void testCanExportTrue() {
        User u = createExportUser();
        Boolean allowed;
        System.runAs(u) {
            allowed = ExportService.canExport();
        }
        System.assertEquals(true, allowed, 'User with Expense_Admin should be allowed to export');
    }

    @isTest
    static void testGetReportCsvNoPermission() {
        User u = buildUser('noexp');
        Expense_Report__c report = new Expense_Report__c(Status__c = 'Open', Currency__c = 'USD');
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert u;
            insert report;
        }

        System.runAs(u) {
            System.assertEquals(false, ExportService.canExport(), 'User without permission should not export');
            Test.startTest();
            try {
                ExportService.getReportCsv(report.Id);
                System.assert(false, 'Should have thrown ExportException');
            } catch (ExportService.ExportException e) {
                System.assert(e.getMessage().contains('permission'), 'Exception should mention permission');
            }
            Test.stopTest();
        }
    }

    @isTest
    static void testBuildReportCsvNullReport() {
        User u = createExportUser();
        System.runAs(u) {
            Test.startTest();
            try {
                ExportService.buildReportCsv(null);
                System.assert(false, 'Should have thrown for null report');
            } catch (ExportService.ExportException e) {
                System.assert(e.getMessage().contains('report id'), 'Exception should mention report id');
            }
            Test.stopTest();
        }
    }

    @isTest
    static void testInvocableExportSuccess() {
        User u = createExportUser();
        Id reportId = seedReport();
        List<InvocableExportReportCsv.Results> results;
        System.runAs(u) {
            InvocableExportReportCsv.Request req = new InvocableExportReportCsv.Request();
            req.reportId = reportId;

            Test.startTest();
            results = InvocableExportReportCsv.execute(new List<InvocableExportReportCsv.Request>{ req });
            Test.stopTest();
        }

        System.assertEquals(1, results.size());
        System.assertEquals(true, results[0].isSuccess, 'Invocable should succeed');
        System.assert(results[0].csvContent.contains('"Hotel"'), 'CSV content should include expense data');
    }

    @isTest
    static void testInvocableExportFailure() {
        User u = buildUser('noinv');
        Expense_Report__c report = new Expense_Report__c(Status__c = 'Open', Currency__c = 'USD');
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert u;
            insert report;
        }

        List<InvocableExportReportCsv.Results> results;
        System.runAs(u) {
            InvocableExportReportCsv.Request req = new InvocableExportReportCsv.Request();
            req.reportId = report.Id;

            Test.startTest();
            results = InvocableExportReportCsv.execute(new List<InvocableExportReportCsv.Request>{ req });
            Test.stopTest();
        }

        System.assertEquals(1, results.size());
        System.assertEquals(false, results[0].isSuccess, 'Invocable should fail without permission');
        System.assertNotEquals(null, results[0].errorMessage, 'Error message should be populated');
    }
}
