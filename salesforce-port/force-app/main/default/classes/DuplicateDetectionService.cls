public with sharing class DuplicateDetectionService {

    public static final Integer DEFAULT_DATE_WINDOW_DAYS = 3;
    private static final Integer CANDIDATE_LIMIT = 200;

    public static List<Expense__c> findPotentialDuplicates(Id expenseId) {
        return findPotentialDuplicates(expenseId, DEFAULT_DATE_WINDOW_DAYS);
    }

    public static List<Expense__c> findPotentialDuplicates(Id expenseId, Integer dateWindowDays) {
        Expense__c source = getSourceExpense(expenseId);
        if (source == null) {
            return new List<Expense__c>();
        }
        if (source.Policy__c == null && source.Report__c == null) {
            return new List<Expense__c>();
        }

        Integer window = (dateWindowDays == null || dateWindowDays < 0) ? DEFAULT_DATE_WINDOW_DAYS : dateWindowDays;
        Date minDate = source.Expense_Date__c.addDays(-window);
        Date maxDate = source.Expense_Date__c.addDays(window);

        Map<String, Object> binds = new Map<String, Object>{
            'sourceId' => source.Id,
            'amount' => source.Amount__c,
            'curr' => source.Currency__c,
            'minDate' => minDate,
            'maxDate' => maxDate
        };

        String soql =
            'SELECT Id, Name, Amount__c, Currency__c, Merchant__c, Expense_Date__c, ' +
            'Category__c, Tag__c, Status__c, Policy__c, Report__c, OwnerId ' +
            'FROM Expense__c ' +
            'WHERE Id != :sourceId ' +
            'AND Amount__c = :amount ' +
            'AND Currency__c = :curr ' +
            'AND Expense_Date__c >= :minDate ' +
            'AND Expense_Date__c <= :maxDate ';

        if (source.Policy__c != null) {
            soql += 'AND Policy__c = :scopeId ';
            binds.put('scopeId', source.Policy__c);
        } else {
            soql += 'AND Report__c = :scopeId ';
            binds.put('scopeId', source.Report__c);
        }

        soql += 'ORDER BY Expense_Date__c DESC LIMIT ' + CANDIDATE_LIMIT;

        List<Expense__c> candidates = Database.queryWithBinds(soql, binds, AccessLevel.USER_MODE);

        List<Expense__c> duplicates = new List<Expense__c>();
        for (Expense__c candidate : candidates) {
            if (merchantMatches(source.Merchant__c, candidate.Merchant__c)) {
                duplicates.add(candidate);
            }
        }
        return duplicates;
    }

    public static List<Expense_Violation__c> detectDuplicates(Id expenseId) {
        return detectDuplicates(expenseId, DEFAULT_DATE_WINDOW_DAYS);
    }

    public static List<Expense_Violation__c> detectDuplicates(Id expenseId, Integer dateWindowDays) {
        List<Expense__c> duplicates = findPotentialDuplicates(expenseId, dateWindowDays);
        if (duplicates.isEmpty()) {
            return new List<Expense_Violation__c>();
        }

        Set<Id> alreadyFlagged = new Set<Id>();
        for (Expense_Violation__c existing : [
            SELECT Duplicate_Expense__c
            FROM Expense_Violation__c
            WHERE Expense__c = :expenseId
            AND Violation_Type__c = 'Duplicate'
            AND Status__c = 'Open'
            AND Duplicate_Expense__c != null
            WITH USER_MODE
        ]) {
            alreadyFlagged.add(existing.Duplicate_Expense__c);
        }

        List<Expense_Violation__c> toInsert = new List<Expense_Violation__c>();
        for (Expense__c duplicate : duplicates) {
            if (alreadyFlagged.contains(duplicate.Id)) {
                continue;
            }
            toInsert.add(new Expense_Violation__c(
                Expense__c = expenseId,
                Duplicate_Expense__c = duplicate.Id,
                Violation_Type__c = 'Duplicate',
                Status__c = 'Open',
                Message__c = buildMessage(duplicate)
            ));
        }

        if (!toInsert.isEmpty()) {
            Database.insert(toInsert, AccessLevel.USER_MODE);
        }
        return toInsert;
    }

    public static void resolveDuplicate(Id violationId) {
        updateViolationStatus(violationId, 'Resolved');
    }

    public static void dismissDuplicate(Id violationId) {
        updateViolationStatus(violationId, 'Dismissed');
    }

    public static List<Expense_Violation__c> getDuplicateViolations(Id expenseId) {
        return [
            SELECT Id, Violation_Type__c, Message__c, Status__c, Duplicate_Expense__c,
                   Duplicate_Expense__r.Name, Duplicate_Expense__r.Merchant__c,
                   Duplicate_Expense__r.Amount__c, Duplicate_Expense__r.Currency__c,
                   Duplicate_Expense__r.Expense_Date__c, CreatedDate
            FROM Expense_Violation__c
            WHERE Expense__c = :expenseId
            AND Violation_Type__c = 'Duplicate'
            WITH USER_MODE
            ORDER BY Status__c, CreatedDate DESC
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Expense_Violation__c> getDuplicateViolationsForExpense(Id expenseId) {
        return getDuplicateViolations(expenseId);
    }

    @AuraEnabled
    public static Integer checkForDuplicates(Id expenseId) {
        return detectDuplicates(expenseId).size();
    }

    @AuraEnabled
    public static void keepDuplicate(Id violationId) {
        dismissDuplicate(violationId);
    }

    @AuraEnabled
    public static void removeDuplicateViolation(Id violationId) {
        resolveDuplicate(violationId);
    }

    private static Expense__c getSourceExpense(Id expenseId) {
        List<Expense__c> records = [
            SELECT Id, Amount__c, Currency__c, Merchant__c, Expense_Date__c, Policy__c, Report__c
            FROM Expense__c
            WHERE Id = :expenseId
            WITH USER_MODE
            LIMIT 1
        ];
        return records.isEmpty() ? null : records[0];
    }

    private static void updateViolationStatus(Id violationId, String status) {
        Expense_Violation__c violation = new Expense_Violation__c(
            Id = violationId,
            Status__c = status
        );
        Database.update(violation, AccessLevel.USER_MODE);
    }

    private static Boolean merchantMatches(String sourceMerchant, String candidateMerchant) {
        Boolean sourceBlank = String.isBlank(sourceMerchant);
        Boolean candidateBlank = String.isBlank(candidateMerchant);
        if (sourceBlank && candidateBlank) {
            return true;
        }
        if (sourceBlank || candidateBlank) {
            return false;
        }
        return sourceMerchant.trim().equalsIgnoreCase(candidateMerchant.trim());
    }

    private static String buildMessage(Expense__c duplicate) {
        String merchant = String.isBlank(duplicate.Merchant__c) ? 'unknown merchant' : duplicate.Merchant__c;
        return 'Potential duplicate of ' + duplicate.Name + ' (' + merchant + ', ' +
               duplicate.Currency__c + ' ' + duplicate.Amount__c + ' on ' +
               String.valueOf(duplicate.Expense_Date__c) + ')';
    }
}
