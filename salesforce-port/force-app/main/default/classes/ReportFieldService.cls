public with sharing class ReportFieldService {

    public static final String TYPE_TEXT = 'Text';
    public static final String TYPE_NUMBER = 'Number';
    public static final String TYPE_DATE = 'Date';
    public static final String TYPE_DROPDOWN = 'Dropdown';

    private static final Set<String> VALID_TYPES = new Set<String>{
        TYPE_TEXT, TYPE_NUMBER, TYPE_DATE, TYPE_DROPDOWN
    };

    @AuraEnabled
    public static Report_Field__c createFieldDef(Report_Field__c fieldDef) {
        if (fieldDef == null) {
            throw new ReportFieldException('Field definition is required');
        }
        if (fieldDef.Policy__c == null) {
            throw new ReportFieldException('Policy is required');
        }
        if (String.isBlank(fieldDef.Name)) {
            throw new ReportFieldException('Field name is required');
        }
        validateFieldType(fieldDef.Field_Type__c);

        if (!Schema.sObjectType.Report_Field__c.isCreateable()) {
            throw new ReportFieldException('Insufficient access to create report fields');
        }
        SObjectAccessDecision decision = Security.stripInaccessible(
            AccessType.CREATABLE, new List<Report_Field__c>{ fieldDef }
        );
        insert decision.getRecords();
        return (Report_Field__c) decision.getRecords()[0];
    }

    @AuraEnabled
    public static Report_Field__c updateFieldDef(Report_Field__c fieldDef) {
        if (fieldDef == null || fieldDef.Id == null) {
            throw new ReportFieldException('Field definition Id is required');
        }
        if (fieldDef.Field_Type__c != null) {
            validateFieldType(fieldDef.Field_Type__c);
        }
        if (!Schema.sObjectType.Report_Field__c.isUpdateable()) {
            throw new ReportFieldException('Insufficient access to update report fields');
        }
        SObjectAccessDecision decision = Security.stripInaccessible(
            AccessType.UPDATABLE, new List<Report_Field__c>{ fieldDef }
        );
        update decision.getRecords();
        return (Report_Field__c) decision.getRecords()[0];
    }

    @AuraEnabled
    public static void deleteFieldDef(Id fieldDefId) {
        if (fieldDefId == null) {
            throw new ReportFieldException('Field definition Id is required');
        }
        if (!Schema.sObjectType.Report_Field__c.isDeletable()) {
            throw new ReportFieldException('Insufficient access to delete report fields');
        }
        List<Report_Field__c> existing = [
            SELECT Id FROM Report_Field__c WHERE Id = :fieldDefId WITH SECURITY_ENFORCED LIMIT 1
        ];
        if (existing.isEmpty()) {
            throw new ReportFieldException('Report field not found');
        }
        delete existing;
    }

    @AuraEnabled(cacheable=true)
    public static List<Report_Field__c> getFieldDefs(Id policyId) {
        if (policyId == null) {
            return new List<Report_Field__c>();
        }
        return [
            SELECT Id, Name, Policy__c, Field_Type__c, Options__c,
                   Default_Value__c, Required__c, CreatedDate
            FROM Report_Field__c
            WHERE Policy__c = :policyId
            WITH SECURITY_ENFORCED
            ORDER BY Name
        ];
    }

    public static Report_Field__c getFieldDef(Id fieldDefId) {
        List<Report_Field__c> defs = [
            SELECT Id, Name, Policy__c, Field_Type__c, Options__c,
                   Default_Value__c, Required__c
            FROM Report_Field__c
            WHERE Id = :fieldDefId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        if (defs.isEmpty()) {
            throw new ReportFieldException('Report field not found');
        }
        return defs[0];
    }

    @AuraEnabled
    public static Report_Field_Value__c setValue(Id reportId, Id fieldDefId, String value) {
        if (reportId == null) {
            throw new ReportFieldException('Report Id is required');
        }
        if (fieldDefId == null) {
            throw new ReportFieldException('Report field Id is required');
        }

        Report_Field__c fieldDef = getFieldDef(fieldDefId);

        if (fieldDef.Required__c == true && String.isBlank(value)) {
            throw new ReportFieldException('A value is required for ' + fieldDef.Name);
        }
        validateValueForType(fieldDef, value);

        List<Report_Field_Value__c> existing = [
            SELECT Id, Value__c
            FROM Report_Field_Value__c
            WHERE Report__c = :reportId AND Report_Field__c = :fieldDefId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        Report_Field_Value__c record;
        if (existing.isEmpty()) {
            record = new Report_Field_Value__c(
                Report__c = reportId,
                Report_Field__c = fieldDefId,
                Value__c = value
            );
            if (!Schema.sObjectType.Report_Field_Value__c.isCreateable()) {
                throw new ReportFieldException('Insufficient access to create report field values');
            }
            SObjectAccessDecision decision = Security.stripInaccessible(
                AccessType.CREATABLE, new List<Report_Field_Value__c>{ record }
            );
            insert decision.getRecords();
            return (Report_Field_Value__c) decision.getRecords()[0];
        }

        record = new Report_Field_Value__c(Id = existing[0].Id, Value__c = value);
        if (!Schema.sObjectType.Report_Field_Value__c.isUpdateable()) {
            throw new ReportFieldException('Insufficient access to update report field values');
        }
        SObjectAccessDecision decision = Security.stripInaccessible(
            AccessType.UPDATABLE, new List<Report_Field_Value__c>{ record }
        );
        update decision.getRecords();
        return (Report_Field_Value__c) decision.getRecords()[0];
    }

    @AuraEnabled(cacheable=true)
    public static List<Report_Field_Value__c> getValues(Id reportId) {
        if (reportId == null) {
            return new List<Report_Field_Value__c>();
        }
        return [
            SELECT Id, Name, Report__c, Report_Field__c, Report_Field__r.Name,
                   Report_Field__r.Field_Type__c, Report_Field__r.Required__c, Value__c
            FROM Report_Field_Value__c
            WHERE Report__c = :reportId
            WITH SECURITY_ENFORCED
            ORDER BY Report_Field__r.Name
        ];
    }

    public static void validateRequiredValues(Id reportId, Id policyId) {
        if (reportId == null || policyId == null) {
            return;
        }
        List<Report_Field__c> requiredDefs = [
            SELECT Id, Name
            FROM Report_Field__c
            WHERE Policy__c = :policyId AND Required__c = true
            WITH SECURITY_ENFORCED
        ];
        if (requiredDefs.isEmpty()) {
            return;
        }

        Map<Id, Report_Field_Value__c> valuesByField = new Map<Id, Report_Field_Value__c>();
        for (Report_Field_Value__c rfv : getValues(reportId)) {
            valuesByField.put(rfv.Report_Field__c, rfv);
        }

        for (Report_Field__c def : requiredDefs) {
            Report_Field_Value__c rfv = valuesByField.get(def.Id);
            if (rfv == null || String.isBlank(rfv.Value__c)) {
                throw new ReportFieldException('Required report field missing a value: ' + def.Name);
            }
        }
    }

    private static void validateFieldType(String fieldType) {
        if (String.isBlank(fieldType) || !VALID_TYPES.contains(fieldType)) {
            throw new ReportFieldException('Invalid field type: ' + fieldType);
        }
    }

    private static void validateValueForType(Report_Field__c fieldDef, String value) {
        if (String.isBlank(value)) {
            return;
        }
        if (fieldDef.Field_Type__c == TYPE_NUMBER) {
            try {
                Decimal.valueOf(value.trim());
            } catch (Exception e) {
                throw new ReportFieldException('Value must be a number for ' + fieldDef.Name);
            }
        } else if (fieldDef.Field_Type__c == TYPE_DATE) {
            try {
                Date.valueOf(value.trim());
            } catch (Exception e) {
                throw new ReportFieldException('Value must be a date (YYYY-MM-DD) for ' + fieldDef.Name);
            }
        } else if (fieldDef.Field_Type__c == TYPE_DROPDOWN) {
            if (!parseOptions(fieldDef.Options__c).contains(value)) {
                throw new ReportFieldException('Value is not a valid option for ' + fieldDef.Name);
            }
        }
    }

    private static Set<String> parseOptions(String options) {
        Set<String> result = new Set<String>();
        if (String.isBlank(options)) {
            return result;
        }
        for (String option : options.split('\n')) {
            String trimmed = option.trim();
            if (String.isNotBlank(trimmed)) {
                result.add(trimmed);
            }
        }
        return result;
    }

    public class ReportFieldException extends Exception {}
}
