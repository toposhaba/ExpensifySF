public with sharing class TaxService {

    public static Tax_Configuration__c createTaxConfig(Tax_Configuration__c config) {
        insert config;
        return config;
    }

    public static List<Tax_Configuration__c> getTaxConfigs(Id policyId) {
        return [
            SELECT Id, Name, Tax_Name__c, Rate__c, Code__c, Enabled__c, Is_Default__c
            FROM Tax_Configuration__c
            WHERE Policy__c = :policyId ORDER BY Name
        ];
    }

    public static void updateTaxConfig(Tax_Configuration__c config) {
        update config;
    }

    public static void deleteTaxConfig(Id configId) {
        delete [SELECT Id FROM Tax_Configuration__c WHERE Id = :configId];
    }

    public static void enableDisable(Id configId, Boolean enabled) {
        update new Tax_Configuration__c(Id = configId, Enabled__c = enabled);
    }

    public static Decimal calculateTax(Decimal amount, Id policyId, String taxCode) {
        List<Tax_Configuration__c> configs;
        if (String.isNotBlank(taxCode)) {
            configs = [SELECT Rate__c FROM Tax_Configuration__c WHERE Policy__c = :policyId AND Code__c = :taxCode AND Enabled__c = true LIMIT 1];
        } else {
            configs = [SELECT Rate__c FROM Tax_Configuration__c WHERE Policy__c = :policyId AND Is_Default__c = true AND Enabled__c = true LIMIT 1];
        }

        if (configs.isEmpty()) return 0;
        return (amount * configs[0].Rate__c / 100).setScale(2, RoundingMode.HALF_UP);
    }
}
