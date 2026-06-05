public with sharing class BulkEditService {

    public class BulkEditException extends Exception {}

    public class BulkEditResult {
        @AuraEnabled public Id expenseId;
        @AuraEnabled public Boolean isSuccess;
        @AuraEnabled public String errorMessage;

        public BulkEditResult(Id expenseId, Boolean isSuccess, String errorMessage) {
            this.expenseId = expenseId;
            this.isSuccess = isSuccess;
            this.errorMessage = errorMessage;
        }
    }

    private static final Set<String> EDITABLE_FIELDS = new Set<String>{
        'amount__c', 'currency__c', 'merchant__c', 'expense_date__c', 'category__c',
        'tag__c', 'description__c', 'billable__c', 'reimbursable__c', 'expense_type__c',
        'tax_amount__c', 'tax_rate__c', 'policy__c', 'report__c', 'status__c', 'hold_reason__c'
    };

    public static List<BulkEditResult> applyBulkEdit(List<Id> expenseIds, Map<String, Object> fieldValues) {
        List<BulkEditResult> results = new List<BulkEditResult>();
        if (expenseIds == null || expenseIds.isEmpty()) {
            return results;
        }
        if (fieldValues == null || fieldValues.isEmpty()) {
            throw new BulkEditException('At least one field value is required');
        }

        if (!Schema.SObjectType.Expense__c.isUpdateable()) {
            throw new BulkEditException('Insufficient access to update expenses');
        }

        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Expense__c.fields.getMap();
        Map<String, Object> coercedValues = new Map<String, Object>();
        for (String rawField : fieldValues.keySet()) {
            String fieldKey = rawField == null ? null : rawField.toLowerCase();
            if (fieldKey == null || !EDITABLE_FIELDS.contains(fieldKey) || !fieldMap.containsKey(fieldKey)) {
                throw new BulkEditException('Field is not editable in bulk: ' + rawField);
            }
            Schema.DescribeFieldResult dfr = fieldMap.get(fieldKey).getDescribe();
            if (!dfr.isUpdateable()) {
                throw new BulkEditException('Insufficient field access to update: ' + dfr.getName());
            }
            coercedValues.put(dfr.getName(), coerceValue(dfr.getType(), fieldValues.get(rawField)));
        }

        List<Id> uniqueIds = new List<Id>(new Set<Id>(expenseIds));

        Map<Id, Expense__c> existing = new Map<Id, Expense__c>([
            SELECT Id, Amount__c, Expense_Date__c
            FROM Expense__c
            WHERE Id IN :uniqueIds
        ]);

        Boolean editingAmount = coercedValues.containsKey('Amount__c');
        Boolean editingDate = coercedValues.containsKey('Expense_Date__c');
        Decimal newAmount = editingAmount ? (Decimal) coercedValues.get('Amount__c') : null;
        Date newDate = editingDate ? (Date) coercedValues.get('Expense_Date__c') : null;

        Map<Id, BulkEditResult> resultsById = new Map<Id, BulkEditResult>();
        List<Expense__c> toUpdate = new List<Expense__c>();
        Map<Integer, Id> indexToId = new Map<Integer, Id>();

        for (Id expId : uniqueIds) {
            if (!existing.containsKey(expId)) {
                resultsById.put(expId, new BulkEditResult(expId, false, 'Expense not found'));
                continue;
            }
            Expense__c current = existing.get(expId);
            Decimal effectiveAmount = editingAmount ? newAmount : current.Amount__c;
            Date effectiveDate = editingDate ? newDate : current.Expense_Date__c;

            String validationError = validate(effectiveAmount, effectiveDate);
            if (validationError != null) {
                resultsById.put(expId, new BulkEditResult(expId, false, validationError));
                continue;
            }

            Expense__c record = new Expense__c(Id = expId);
            for (String fieldName : coercedValues.keySet()) {
                record.put(fieldName, coercedValues.get(fieldName));
            }
            indexToId.put(toUpdate.size(), expId);
            toUpdate.add(record);
        }

        if (!toUpdate.isEmpty()) {
            List<Database.SaveResult> saveResults = Database.update(toUpdate, false);
            for (Integer i = 0; i < saveResults.size(); i++) {
                Id expId = indexToId.get(i);
                Database.SaveResult sr = saveResults.get(i);
                if (sr.isSuccess()) {
                    resultsById.put(expId, new BulkEditResult(expId, true, null));
                } else {
                    resultsById.put(expId, new BulkEditResult(expId, false, formatErrors(sr.getErrors())));
                }
            }
        }

        for (Id expId : uniqueIds) {
            if (resultsById.containsKey(expId)) {
                results.add(resultsById.get(expId));
            }
        }
        return results;
    }

    private static String validate(Decimal amount, Date expenseDate) {
        if (amount == null || amount <= 0) {
            return 'Amount must be greater than zero';
        }
        if (expenseDate == null) {
            return 'Expense date is required';
        }
        if (expenseDate > Date.today()) {
            return 'Expense date cannot be in the future';
        }
        return null;
    }

    private static Object coerceValue(Schema.DisplayType fieldType, Object raw) {
        if (raw == null) {
            return null;
        }
        String asString = String.valueOf(raw);
        if (String.isBlank(asString)) {
            return null;
        }
        switch on fieldType {
            when CURRENCY, DOUBLE, PERCENT {
                return (raw instanceof Decimal) ? (Decimal) raw : Decimal.valueOf(asString);
            }
            when INTEGER, LONG {
                return (raw instanceof Integer) ? (Integer) raw : Integer.valueOf(asString);
            }
            when BOOLEAN {
                return (raw instanceof Boolean) ? (Boolean) raw : Boolean.valueOf(asString);
            }
            when DATE {
                return (raw instanceof Date) ? (Date) raw : Date.valueOf(asString);
            }
            when DATETIME {
                return (raw instanceof Datetime) ? (Datetime) raw : Datetime.valueOf(asString);
            }
            when REFERENCE {
                return (Id) asString;
            }
            when else {
                return asString;
            }
        }
    }

    private static String formatErrors(List<Database.Error> errors) {
        List<String> messages = new List<String>();
        for (Database.Error err : errors) {
            messages.add(err.getMessage());
        }
        return String.join(messages, '; ');
    }

    @AuraEnabled(cacheable=true)
    public static List<Expense__c> getEditableExpenses() {
        return [
            SELECT Id, Name, Amount__c, Currency__c, Merchant__c, Expense_Date__c,
                   Category__c, Category__r.Name, Tag__c, Tag__r.Name, Description__c,
                   Billable__c, Reimbursable__c, Status__c, Expense_Type__c,
                   Report__c, Report__r.Name
            FROM Expense__c
            WHERE OwnerId = :UserInfo.getUserId()
            ORDER BY Expense_Date__c DESC
            LIMIT 200
        ];
    }

    @AuraEnabled
    public static List<BulkEditResult> applyEdits(List<Id> expenseIds, Map<String, Object> fieldValues) {
        try {
            return applyBulkEdit(expenseIds, fieldValues);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
