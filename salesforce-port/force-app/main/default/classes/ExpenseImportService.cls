public with sharing class ExpenseImportService {

    private static final Map<String, Integer> DEFAULT_COLUMNS = new Map<String, Integer>{
        'date' => 0,
        'merchant' => 1,
        'amount' => 2,
        'currency' => 3,
        'category' => 4
    };

    @AuraEnabled
    public static ImportSummary importExpenses(String csvBody, Id policyId, Id reportId) {
        try {
            return importCsv(csvBody, policyId, reportId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    public static ImportSummary importCsv(String csvBody, Id policyId, Id reportId) {
        if (!Schema.sObjectType.Expense__c.isCreateable()) {
            throw new ExpenseImportException('Insufficient permissions to create expenses');
        }

        ImportSummary summary = new ImportSummary();

        List<List<String>> parsed = parseCsv(csvBody);
        if (parsed.isEmpty()) {
            throw new ExpenseImportException('No data found in CSV');
        }

        Map<String, Integer> colMap = buildColumnMap(parsed[0]);
        Boolean hasHeader = !colMap.isEmpty();
        if (!hasHeader) {
            colMap = DEFAULT_COLUMNS;
        }

        Integer startRow = hasHeader ? 1 : 0;

        List<Expense__c> toInsert = new List<Expense__c>();
        List<RowResult> validResults = new List<RowResult>();
        List<String> categoryKeyForInsert = new List<String>();
        Set<String> categoryNames = new Set<String>();

        for (Integer r = startRow; r < parsed.size(); r++) {
            List<String> cells = parsed[r];
            RowResult rr = new RowResult();
            rr.rowNumber = r + 1;
            summary.totalRows++;

            String rawDate = getCell(cells, colMap, 'date');
            String rawAmount = getCell(cells, colMap, 'amount');
            String merchant = getCell(cells, colMap, 'merchant');
            String currencyCode = getCell(cells, colMap, 'currency');
            String categoryName = getCell(cells, colMap, 'category');
            String description = getCell(cells, colMap, 'description');

            rr.merchant = String.isNotBlank(merchant) ? merchant.trim() : null;

            try {
                Date parsedDate = parseDate(rawDate);
                if (parsedDate == null) {
                    throw new ExpenseImportException('Invalid or missing date: "' + rawDate + '"');
                }

                Decimal amount = parseAmount(rawAmount);
                if (amount == null) {
                    throw new ExpenseImportException('Invalid or missing amount: "' + rawAmount + '"');
                }
                if (amount <= 0) {
                    throw new ExpenseImportException('Amount must be greater than zero');
                }
                if (parsedDate > Date.today()) {
                    throw new ExpenseImportException('Expense date cannot be in the future');
                }

                rr.amount = amount;
                rr.expenseDate = String.valueOf(parsedDate);

                String cleanCurrency = 'USD';
                if (String.isNotBlank(currencyCode)) {
                    String candidate = currencyCode.trim().toUpperCase();
                    if (candidate.length() == 3) {
                        cleanCurrency = candidate;
                    }
                }

                Expense__c expense = new Expense__c(
                    Amount__c = amount,
                    Currency__c = cleanCurrency,
                    Merchant__c = rr.merchant,
                    Expense_Date__c = parsedDate,
                    Description__c = String.isNotBlank(description) ? description.trim() : null,
                    Expense_Type__c = 'Cash',
                    Status__c = 'Draft',
                    Reimbursable__c = true,
                    Billable__c = false,
                    Has_Receipt__c = false,
                    Policy__c = policyId,
                    Report__c = reportId
                );

                toInsert.add(expense);
                validResults.add(rr);

                String categoryKey = null;
                if (String.isNotBlank(categoryName)) {
                    categoryKey = categoryName.trim().toLowerCase();
                    categoryNames.add(categoryKey);
                }
                categoryKeyForInsert.add(categoryKey);

                rr.isSuccess = true;
            } catch (Exception e) {
                rr.isSuccess = false;
                rr.errorMessage = e.getMessage();
                summary.errorCount++;
            }

            summary.rows.add(rr);
        }

        Map<String, Id> categoryIdByName = resolveCategories(categoryNames, policyId);

        for (Integer k = 0; k < toInsert.size(); k++) {
            String key = categoryKeyForInsert[k];
            if (key != null && categoryIdByName.containsKey(key)) {
                toInsert[k].Category__c = categoryIdByName.get(key);
            }
        }

        if (!toInsert.isEmpty()) {
            try {
                ExpenseService.createExpenses(toInsert);
                for (Integer k = 0; k < toInsert.size(); k++) {
                    RowResult rr = validResults[k];
                    rr.expenseId = toInsert[k].Id;
                    summary.createdExpenseIds.add(String.valueOf(toInsert[k].Id));
                    summary.successCount++;
                    summary.totalAmount += toInsert[k].Amount__c;
                }
            } catch (Exception e) {
                for (RowResult rr : validResults) {
                    rr.isSuccess = false;
                    rr.errorMessage = e.getMessage();
                    summary.errorCount++;
                }
            }
        }

        return summary;
    }

    private static Map<String, Id> resolveCategories(Set<String> categoryNames, Id policyId) {
        Map<String, Id> categoryIdByName = new Map<String, Id>();
        if (categoryNames.isEmpty() || policyId == null) {
            return categoryIdByName;
        }
        for (Expense_Category__c category : [
            SELECT Id, Name
            FROM Expense_Category__c
            WHERE Policy__c = :policyId AND Name IN :categoryNames
        ]) {
            categoryIdByName.put(category.Name.toLowerCase(), category.Id);
        }
        return categoryIdByName;
    }

    private static String getCell(List<String> cells, Map<String, Integer> colMap, String role) {
        if (!colMap.containsKey(role)) {
            return null;
        }
        Integer idx = colMap.get(role);
        if (idx < 0 || idx >= cells.size()) {
            return null;
        }
        return cells[idx];
    }

    private static Map<String, Integer> buildColumnMap(List<String> headerRow) {
        Map<String, Integer> colMap = new Map<String, Integer>();
        for (Integer idx = 0; idx < headerRow.size(); idx++) {
            String raw = headerRow[idx];
            String header = raw == null ? '' : raw.trim().toLowerCase();
            String role = roleForHeader(header);
            if (role != null && !colMap.containsKey(role)) {
                colMap.put(role, idx);
            }
        }
        return colMap;
    }

    private static String roleForHeader(String header) {
        if (header == 'date' || header == 'transaction date' || header == 'expense date' || header == 'created' || header == 'posted date') {
            return 'date';
        }
        if (header == 'merchant' || header == 'payee' || header == 'vendor' || header == 'name') {
            return 'merchant';
        }
        if (header == 'amount' || header == 'total' || header == 'value' || header == 'debit') {
            return 'amount';
        }
        if (header == 'currency' || header == 'currency code') {
            return 'currency';
        }
        if (header == 'category') {
            return 'category';
        }
        if (header == 'description' || header == 'memo' || header == 'note' || header == 'notes' || header == 'comment') {
            return 'description';
        }
        return null;
    }

    @TestVisible
    private static List<List<String>> parseCsv(String csvText) {
        List<List<String>> rows = new List<List<String>>();
        if (String.isBlank(csvText)) {
            return rows;
        }

        List<String> currentRow = new List<String>();
        String field = '';
        Boolean inQuotes = false;
        Integer len = csvText.length();
        Integer i = 0;

        while (i < len) {
            String c = csvText.substring(i, i + 1);

            if (inQuotes) {
                if (c == '"') {
                    if (i + 1 < len && csvText.substring(i + 1, i + 2) == '"') {
                        field += '"';
                        i += 2;
                        continue;
                    }
                    inQuotes = false;
                    i++;
                    continue;
                }
                field += c;
                i++;
                continue;
            }

            if (c == '"') {
                inQuotes = true;
                i++;
                continue;
            }
            if (c == ',') {
                currentRow.add(field);
                field = '';
                i++;
                continue;
            }
            if (c == '\n' || c == '\r') {
                if (c == '\r' && i + 1 < len && csvText.substring(i + 1, i + 2) == '\n') {
                    i++;
                }
                currentRow.add(field);
                field = '';
                rows.add(currentRow);
                currentRow = new List<String>();
                i++;
                continue;
            }

            field += c;
            i++;
        }

        currentRow.add(field);
        rows.add(currentRow);

        List<List<String>> cleaned = new List<List<String>>();
        for (List<String> row : rows) {
            Boolean allEmpty = true;
            for (String value : row) {
                if (String.isNotBlank(value)) {
                    allEmpty = false;
                    break;
                }
            }
            if (!allEmpty) {
                cleaned.add(row);
            }
        }
        return cleaned;
    }

    @TestVisible
    private static Decimal parseAmount(String input) {
        if (String.isBlank(input)) {
            return null;
        }
        String trimmed = input.trim();
        Boolean negative = trimmed.startsWith('(') && trimmed.endsWith(')');
        String cleaned = trimmed.replaceAll('[^0-9.\\-]', '');
        if (String.isBlank(cleaned) || cleaned == '-' || cleaned == '.') {
            return null;
        }
        try {
            Decimal value = Decimal.valueOf(cleaned);
            if (negative) {
                value = -Math.abs(value);
            }
            return value;
        } catch (Exception e) {
            return null;
        }
    }

    @TestVisible
    private static Date parseDate(String input) {
        if (String.isBlank(input)) {
            return null;
        }
        String s = input.trim();

        if (s.length() > 10 && s.substring(4, 5) == '-') {
            s = s.substring(0, 10);
        }

        if (Pattern.matches('\\d{4}-\\d{1,2}-\\d{1,2}', s)) {
            List<String> p = s.split('-');
            return safeDate(Integer.valueOf(p[0]), Integer.valueOf(p[1]), Integer.valueOf(p[2]));
        }
        if (Pattern.matches('\\d{4}/\\d{1,2}/\\d{1,2}', s)) {
            List<String> p = s.split('/');
            return safeDate(Integer.valueOf(p[0]), Integer.valueOf(p[1]), Integer.valueOf(p[2]));
        }
        if (Pattern.matches('\\d{1,2}/\\d{1,2}/\\d{4}', s)) {
            List<String> p = s.split('/');
            return resolveAmbiguousDate(Integer.valueOf(p[0]), Integer.valueOf(p[1]), Integer.valueOf(p[2]));
        }
        if (Pattern.matches('\\d{1,2}-\\d{1,2}-\\d{4}', s)) {
            List<String> p = s.split('-');
            return resolveAmbiguousDate(Integer.valueOf(p[0]), Integer.valueOf(p[1]), Integer.valueOf(p[2]));
        }
        if (Pattern.matches('\\d{8}', s)) {
            return safeDate(Integer.valueOf(s.substring(0, 4)), Integer.valueOf(s.substring(4, 6)), Integer.valueOf(s.substring(6, 8)));
        }
        return null;
    }

    private static Date resolveAmbiguousDate(Integer first, Integer second, Integer year) {
        if (first > 12 && second <= 12) {
            return safeDate(year, second, first);
        }
        return safeDate(year, first, second);
    }

    private static Date safeDate(Integer year, Integer month, Integer day) {
        if (month < 1 || month > 12 || day < 1 || day > 31) {
            return null;
        }
        return Date.newInstance(year, month, day);
    }

    public class ImportSummary {
        @AuraEnabled public Integer totalRows = 0;
        @AuraEnabled public Integer successCount = 0;
        @AuraEnabled public Integer errorCount = 0;
        @AuraEnabled public Decimal totalAmount = 0;
        @AuraEnabled public List<RowResult> rows = new List<RowResult>();
        @AuraEnabled public List<String> createdExpenseIds = new List<String>();
    }

    public class RowResult {
        @AuraEnabled public Integer rowNumber;
        @AuraEnabled public Boolean isSuccess = false;
        @AuraEnabled public String merchant;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String expenseDate;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public Id expenseId;
    }

    public class ExpenseImportException extends Exception {}
}
