@isTest
private class ConfigImportServiceTest {

    @TestSetup
    static void setupTestData() {
        Expense_Policy__c policy = new Expense_Policy__c(
            Name = 'Config Policy',
            Currency__c = 'USD',
            Type__c = 'Corporate',
            Approval_Mode__c = 'Basic',
            Categories_Enabled__c = true,
            Tags_Enabled__c = true
        );
        PolicyService.createPolicy(policy);

        insert new Expense_Category__c(
            Name = 'Travel',
            Policy__c = policy.Id,
            GL_Code__c = '5000',
            Enabled__c = true
        );
    }

    private static Id policyId() {
        return [SELECT Id FROM Expense_Policy__c LIMIT 1].Id;
    }

    private static User createUser(String alias, String email) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            FirstName = 'Cfg',
            LastName = alias,
            Email = email,
            Username = alias + System.now().getTime() + '@configimport.test.invalid',
            Alias = alias.left(8),
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert u;
        return u;
    }

    @isTest
    static void testCategoriesImported() {
        String csv =
            'Name,GL Code,Enabled,Max Amount,Receipt Required\n' +
            'Meals,5100,true,75.00,true\n' +
            'Lodging,5200,yes,250,no\n';

        Test.startTest();
        ConfigImportService.ImportSummary summary = ConfigImportService.runImport(csv, policyId(), 'Categories');
        Test.stopTest();

        System.assertEquals('Categories', summary.importType);
        System.assertEquals(2, summary.totalRows);
        System.assertEquals(2, summary.successCount, 'Both categories should import');
        System.assertEquals(2, summary.createdCount);
        System.assertEquals(0, summary.errorCount);

        Map<String, Expense_Category__c> byName = new Map<String, Expense_Category__c>();
        for (Expense_Category__c c : [
            SELECT Name, GL_Code__c, Enabled__c, Max_Amount__c, Receipt_Required__c
            FROM Expense_Category__c WHERE Policy__c = :policyId()
        ]) {
            byName.put(c.Name, c);
        }
        System.assert(byName.containsKey('Meals'), 'Meals category created');
        System.assertEquals('5100', byName.get('Meals').GL_Code__c);
        System.assertEquals(75.00, byName.get('Meals').Max_Amount__c);
        System.assertEquals(true, byName.get('Meals').Receipt_Required__c);
        System.assertEquals(false, byName.get('Lodging').Receipt_Required__c);
    }

    @isTest
    static void testCategoryUpsertUpdatesExisting() {
        String csv =
            'Name,GL Code,Enabled\n' +
            'Travel,9999,false\n';

        Test.startTest();
        ConfigImportService.ImportSummary summary = ConfigImportService.runImport(csv, policyId(), 'Categories');
        Test.stopTest();

        System.assertEquals(1, summary.successCount);
        System.assertEquals(0, summary.createdCount);
        System.assertEquals(1, summary.updatedCount, 'Existing Travel should update, not duplicate');

        List<Expense_Category__c> travel = [
            SELECT GL_Code__c, Enabled__c FROM Expense_Category__c
            WHERE Policy__c = :policyId() AND Name = 'Travel'
        ];
        System.assertEquals(1, travel.size(), 'No duplicate created');
        System.assertEquals('9999', travel[0].GL_Code__c);
        System.assertEquals(false, travel[0].Enabled__c);
    }

    @isTest
    static void testTagsImported() {
        String csv =
            'Name,GL Code,Enabled\n' +
            'Project Alpha,T100,true\n' +
            'Project Beta,T200,false\n';

        Test.startTest();
        ConfigImportService.ImportSummary summary = ConfigImportService.runImport(csv, policyId(), 'Tags');
        Test.stopTest();

        System.assertEquals('Tags', summary.importType);
        System.assertEquals(2, summary.successCount, 'Both tags should import');
        System.assertEquals(2, summary.createdCount);
        System.assertEquals(2, [SELECT COUNT() FROM Expense_Tag__c WHERE Policy__c = :policyId()]);
    }

    @isTest
    static void testMembersImported() {
        User u1;
        User u2;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            u1 = createUser('cfgmemb1', 'cfgmember1@configimport.test.invalid');
            u2 = createUser('cfgmemb2', 'cfgmember2@configimport.test.invalid');
        }

        String csv =
            'Email,Role\n' +
            'cfgmember1@configimport.test.invalid,Approver\n' +
            'cfgmember2@configimport.test.invalid,Member\n';

        Test.startTest();
        ConfigImportService.ImportSummary summary = ConfigImportService.runImport(csv, policyId(), 'Members');
        Test.stopTest();

        System.assertEquals('Members', summary.importType);
        System.assertEquals(2, summary.totalRows);
        System.assertEquals(2, summary.successCount, 'Both members should import');
        System.assertEquals(2, summary.createdCount);
        System.assertEquals(0, summary.errorCount);

        Map<Id, String> roleByUser = new Map<Id, String>();
        for (Policy_Member__c pm : [
            SELECT User__c, Role__c FROM Policy_Member__c WHERE Policy__c = :policyId()
        ]) {
            roleByUser.put(pm.User__c, pm.Role__c);
        }
        System.assertEquals('Approver', roleByUser.get(u1.Id));
        System.assertEquals('Member', roleByUser.get(u2.Id));
    }

    @isTest
    static void testMemberRoleUpdatedAndUnknownUserReported() {
        User u1;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            u1 = createUser('cfgmemb3', 'cfgmember3@configimport.test.invalid');
        }
        insert new Policy_Member__c(Policy__c = policyId(), User__c = u1.Id, Role__c = 'Member');

        String csv =
            'Email,Role\n' +
            'cfgmember3@configimport.test.invalid,Approver\n' +
            'ghost@configimport.test.invalid,Member\n';

        Test.startTest();
        ConfigImportService.ImportSummary summary = ConfigImportService.runImport(csv, policyId(), 'Members');
        Test.stopTest();

        System.assertEquals(2, summary.totalRows);
        System.assertEquals(1, summary.successCount);
        System.assertEquals(1, summary.updatedCount, 'Existing membership role updated');
        System.assertEquals(1, summary.errorCount, 'Unknown user reported');

        Policy_Member__c updated = [
            SELECT Role__c FROM Policy_Member__c WHERE User__c = :u1.Id LIMIT 1
        ];
        System.assertEquals('Approver', updated.Role__c);

        Boolean unknownReported = false;
        for (ConfigImportService.RowResult row : summary.rows) {
            if (!row.isSuccess && row.errorMessage != null && row.errorMessage.contains('No active user')) {
                unknownReported = true;
            }
        }
        System.assert(unknownReported, 'Unknown user error reported with message');
    }

    @isTest
    static void testMalformedRowReported() {
        String csv =
            'Name,GL Code\n' +
            'Good Cat,5300\n' +
            ',5400\n' +
            'Good Cat,5500\n';

        Test.startTest();
        ConfigImportService.ImportSummary summary = ConfigImportService.runImport(csv, policyId(), 'Categories');
        Test.stopTest();

        System.assertEquals(3, summary.totalRows);
        System.assertEquals(1, summary.successCount, 'Only the first valid unique row imports');
        System.assertEquals(2, summary.errorCount, 'Blank name and duplicate reported');

        Integer reported = 0;
        for (ConfigImportService.RowResult row : summary.rows) {
            if (!row.isSuccess) {
                reported++;
                System.assertNotEquals(null, row.errorMessage, 'Failed rows carry an error message');
            }
        }
        System.assertEquals(2, reported);
    }

    @isTest
    static void testNoHeaderPositionalMapping() {
        String csv =
            'Office Supplies,6100\n' +
            'Software,6200\n';

        Test.startTest();
        ConfigImportService.ImportSummary summary = ConfigImportService.runImport(csv, policyId(), 'Categories');
        Test.stopTest();

        System.assertEquals(2, summary.totalRows, 'Both rows treated as data without header');
        System.assertEquals(2, summary.successCount);
    }

    @isTest
    static void testInvocableImportConfig() {
        InvocableImportConfig.Request req = new InvocableImportConfig.Request();
        req.csvBody = 'Name,GL Code\nClient A,T900\n,T901\n';
        req.policyId = policyId();
        req.importType = 'Tags';

        Test.startTest();
        List<InvocableImportConfig.Results> results = InvocableImportConfig.execute(
            new List<InvocableImportConfig.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        InvocableImportConfig.Results res = results[0];
        System.assertEquals('Tags', res.importType);
        System.assertEquals(2, res.totalRows);
        System.assertEquals(1, res.successCount);
        System.assertEquals(1, res.errorCount);
        System.assertEquals(false, res.isSuccess);
        System.assert(!res.errorMessages.isEmpty(), 'Error messages populated');
    }

    @isTest
    static void testAuraEntryPointAndErrors() {
        Test.startTest();
        ConfigImportService.ImportSummary summary = ConfigImportService.importConfig(
            'Name\nNew Cat\n', policyId(), 'Categories'
        );
        System.assertEquals(1, summary.successCount);

        try {
            ConfigImportService.importConfig('', policyId(), 'Categories');
            System.assert(false, 'Should throw for empty CSV');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        try {
            ConfigImportService.runImport('Name\nX\n', policyId(), 'Bogus');
            System.assert(false, 'Should throw for unsupported type');
        } catch (ConfigImportService.ConfigImportException e) {
            System.assert(e.getMessage().contains('Unsupported'));
        }

        try {
            ConfigImportService.runImport('Name\nX\n', null, 'Categories');
            System.assert(false, 'Should throw for missing policy');
        } catch (ConfigImportService.ConfigImportException e) {
            System.assert(e.getMessage().contains('policy'));
        }
        Test.stopTest();
    }
}
