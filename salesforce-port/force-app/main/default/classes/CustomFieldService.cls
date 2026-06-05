public with sharing class CustomFieldService {

    public static Report_Custom_Field__c createField(Report_Custom_Field__c field) {
        insert field;
        return field;
    }

    public static List<Report_Custom_Field__c> getFields(Id policyId) {
        return [
            SELECT Id, Name, Field_Label__c, Field_Type__c, Required__c, Enabled__c,
                   Picklist_Values__c, Default_Value__c
            FROM Report_Custom_Field__c WHERE Policy__c = :policyId ORDER BY Name
        ];
    }

    public static void deleteField(Id fieldId) {
        delete [SELECT Id FROM Report_Field_Value__c WHERE Custom_Field__c = :fieldId];
        delete [SELECT Id FROM Report_Custom_Field__c WHERE Id = :fieldId];
    }

    public static Report_Field_Value__c setFieldValue(Id reportId, Id fieldId, String value) {
        List<Report_Field_Value__c> existing = [
            SELECT Id FROM Report_Field_Value__c
            WHERE Report__c = :reportId AND Custom_Field__c = :fieldId LIMIT 1
        ];

        Report_Field_Value__c fv;
        if (!existing.isEmpty()) {
            fv = new Report_Field_Value__c(Id = existing[0].Id, Value__c = value);
        } else {
            fv = new Report_Field_Value__c(
                Report__c = reportId,
                Custom_Field__c = fieldId,
                Value__c = value
            );
        }
        upsert fv;
        return fv;
    }

    public static Map<Id, String> getFieldValues(Id reportId) {
        Map<Id, String> values = new Map<Id, String>();
        for (Report_Field_Value__c fv : [
            SELECT Custom_Field__c, Value__c FROM Report_Field_Value__c WHERE Report__c = :reportId
        ]) {
            values.put(fv.Custom_Field__c, fv.Value__c);
        }
        return values;
    }
}
