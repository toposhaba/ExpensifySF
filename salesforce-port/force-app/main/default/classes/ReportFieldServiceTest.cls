@isTest
private class ReportFieldServiceTest {

    private static Expense_Policy__c createPolicy() {
        Expense_Policy__c policy = new Expense_Policy__c(
            Name = 'Report Field Policy',
            Currency__c = 'USD'
        );
        insert policy;
        return policy;
    }

    private static Expense_Report__c createReport(Id policyId) {
        Expense_Report__c report = new Expense_Report__c(
            Status__c = 'Open',
            Currency__c = 'USD',
            Policy__c = policyId
        );
        insert report;
        return report;
    }

    private static Report_Field__c buildFieldDef(Id policyId, String name, String type, Boolean required) {
        return new Report_Field__c(
            Name = name,
            Policy__c = policyId,
            Field_Type__c = type,
            Required__c = required
        );
    }

    @isTest
    static void testCreateAndGetFieldDefs() {
        Expense_Policy__c policy = createPolicy();

        Test.startTest();
        Report_Field__c created = ReportFieldService.createFieldDef(
            buildFieldDef(policy.Id, 'Cost Center', ReportFieldService.TYPE_TEXT, false)
        );
        Test.stopTest();

        System.assertNotEquals(null, created.Id, 'Field def should be created');

        List<Report_Field__c> defs = ReportFieldService.getFieldDefs(policy.Id);
        System.assertEquals(1, defs.size(), 'Should return one field def');
        System.assertEquals('Cost Center', defs[0].Name);
        System.assertEquals('Text', defs[0].Field_Type__c);
        System.assertEquals(0, ReportFieldService.getFieldDefs(null).size(), 'Null policy returns empty');
    }

    @isTest
    static void testUpdateAndDeleteFieldDef() {
        Expense_Policy__c policy = createPolicy();
        Report_Field__c created = ReportFieldService.createFieldDef(
            buildFieldDef(policy.Id, 'Project', ReportFieldService.TYPE_TEXT, false)
        );

        Test.startTest();
        created.Field_Type__c = ReportFieldService.TYPE_DROPDOWN;
        created.Options__c = 'Alpha\nBeta';
        Report_Field__c updated = ReportFieldService.updateFieldDef(created);

        ReportFieldService.deleteFieldDef(updated.Id);
        Test.stopTest();

        System.assertEquals('Dropdown', updated.Field_Type__c);
        System.assertEquals(0, ReportFieldService.getFieldDefs(policy.Id).size(), 'Field def should be deleted');
    }

    @isTest
    static void testSetAndGetValue() {
        Expense_Policy__c policy = createPolicy();
        Expense_Report__c report = createReport(policy.Id);
        Report_Field__c def = ReportFieldService.createFieldDef(
            buildFieldDef(policy.Id, 'Cost Center', ReportFieldService.TYPE_TEXT, false)
        );

        Test.startTest();
        Report_Field_Value__c first = ReportFieldService.setValue(report.Id, def.Id, 'CC-100');
        Report_Field_Value__c second = ReportFieldService.setValue(report.Id, def.Id, 'CC-200');
        Test.stopTest();

        System.assertEquals(first.Id, second.Id, 'Setting again should upsert the same record');

        List<Report_Field_Value__c> values = ReportFieldService.getValues(report.Id);
        System.assertEquals(1, values.size(), 'One value expected');
        System.assertEquals('CC-200', values[0].Value__c, 'Value should be updated');
        System.assertEquals(0, ReportFieldService.getValues(null).size(), 'Null report returns empty');
    }

    @isTest
    static void testRequiredValidationOnSet() {
        Expense_Policy__c policy = createPolicy();
        Expense_Report__c report = createReport(policy.Id);
        Report_Field__c def = ReportFieldService.createFieldDef(
            buildFieldDef(policy.Id, 'Mandatory', ReportFieldService.TYPE_TEXT, true)
        );

        Test.startTest();
        try {
            ReportFieldService.setValue(report.Id, def.Id, '');
            System.assert(false, 'Should have thrown for required field');
        } catch (ReportFieldService.ReportFieldException e) {
            System.assert(e.getMessage().contains('value is required'), e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testValidateRequiredValues() {
        Expense_Policy__c policy = createPolicy();
        Expense_Report__c report = createReport(policy.Id);
        Report_Field__c def = ReportFieldService.createFieldDef(
            buildFieldDef(policy.Id, 'Mandatory', ReportFieldService.TYPE_TEXT, true)
        );

        Test.startTest();
        try {
            ReportFieldService.validateRequiredValues(report.Id, policy.Id);
            System.assert(false, 'Should have thrown for missing required value');
        } catch (ReportFieldService.ReportFieldException e) {
            System.assert(e.getMessage().contains('Required report field missing'), e.getMessage());
        }

        ReportFieldService.setValue(report.Id, def.Id, 'Provided');
        ReportFieldService.validateRequiredValues(report.Id, policy.Id);
        Test.stopTest();
    }

    @isTest
    static void testTypeValidation() {
        Expense_Policy__c policy = createPolicy();
        Expense_Report__c report = createReport(policy.Id);
        Report_Field__c numberDef = ReportFieldService.createFieldDef(
            buildFieldDef(policy.Id, 'Budget', ReportFieldService.TYPE_NUMBER, false)
        );
        Report_Field__c dateDef = ReportFieldService.createFieldDef(
            buildFieldDef(policy.Id, 'Due', ReportFieldService.TYPE_DATE, false)
        );
        Report_Field__c dropdownDef = buildFieldDef(policy.Id, 'Region', ReportFieldService.TYPE_DROPDOWN, false);
        dropdownDef.Options__c = 'North\nSouth';
        dropdownDef = ReportFieldService.createFieldDef(dropdownDef);

        Test.startTest();
        ReportFieldService.setValue(report.Id, numberDef.Id, '123.45');
        ReportFieldService.setValue(report.Id, dateDef.Id, '2026-01-15');
        ReportFieldService.setValue(report.Id, dropdownDef.Id, 'North');

        try {
            ReportFieldService.setValue(report.Id, numberDef.Id, 'abc');
            System.assert(false, 'Should reject non-number');
        } catch (ReportFieldService.ReportFieldException e) {
            System.assert(e.getMessage().contains('must be a number'), e.getMessage());
        }

        try {
            ReportFieldService.setValue(report.Id, dropdownDef.Id, 'East');
            System.assert(false, 'Should reject invalid option');
        } catch (ReportFieldService.ReportFieldException e) {
            System.assert(e.getMessage().contains('not a valid option'), e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testCreateValidationErrors() {
        Expense_Policy__c policy = createPolicy();

        Test.startTest();
        try {
            ReportFieldService.createFieldDef(null);
            System.assert(false, 'Should throw');
        } catch (ReportFieldService.ReportFieldException e) {
            System.assert(e.getMessage().contains('Field definition is required'));
        }

        try {
            ReportFieldService.createFieldDef(
                buildFieldDef(policy.Id, 'Bad', 'Bogus', false)
            );
            System.assert(false, 'Should throw on invalid type');
        } catch (ReportFieldService.ReportFieldException e) {
            System.assert(e.getMessage().contains('Invalid field type'));
        }

        try {
            ReportFieldService.setValue(null, null, 'x');
            System.assert(false, 'Should throw');
        } catch (ReportFieldService.ReportFieldException e) {
            System.assert(e.getMessage().contains('Report Id is required'));
        }
        Test.stopTest();
    }

    @isTest
    static void testInvocableSetValue() {
        Expense_Policy__c policy = createPolicy();
        Expense_Report__c report = createReport(policy.Id);
        Report_Field__c def = ReportFieldService.createFieldDef(
            buildFieldDef(policy.Id, 'Cost Center', ReportFieldService.TYPE_TEXT, true)
        );

        InvocableSetReportFieldValue.Request req = new InvocableSetReportFieldValue.Request();
        req.reportId = report.Id;
        req.reportFieldId = def.Id;
        req.value = 'CC-900';

        InvocableSetReportFieldValue.Request badReq = new InvocableSetReportFieldValue.Request();
        badReq.reportId = report.Id;
        badReq.reportFieldId = def.Id;
        badReq.value = '';

        Test.startTest();
        List<InvocableSetReportFieldValue.Results> results =
            InvocableSetReportFieldValue.execute(new List<InvocableSetReportFieldValue.Request>{ req, badReq });
        Test.stopTest();

        System.assertEquals(true, results[0].isSuccess, 'First request should succeed');
        System.assertNotEquals(null, results[0].reportFieldValueId);
        System.assertEquals(false, results[1].isSuccess, 'Required validation should fail');
        System.assertNotEquals(null, results[1].errorMessage);
    }
}
