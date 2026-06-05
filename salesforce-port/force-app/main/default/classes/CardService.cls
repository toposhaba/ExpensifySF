public with sharing class CardService {

    private static final Map<String, Integer> DEFAULT_COLUMNS = new Map<String, Integer>{
        'date' => 0,
        'merchant' => 1,
        'amount' => 2,
        'currency' => 3
    };

    @AuraEnabled(cacheable=true)
    public static List<Card__c> getCards(Id policyId) {
        if (!Schema.sObjectType.Card__c.isAccessible()) {
            throw new AuraHandledException('Insufficient permissions to view cards');
        }
        return [
            SELECT Id, Name, Card_Name__c, Last_Four__c, Feed_Provider__c,
                   Is_Active__c, Cardholder__c, Cardholder__r.Name, Policy__c
            FROM Card__c
            WHERE Policy__c = :policyId
            ORDER BY Card_Name__c ASC NULLS LAST
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Card_Transaction__c> getTransactions(Id cardId) {
        if (!Schema.sObjectType.Card_Transaction__c.isAccessible()) {
            throw new AuraHandledException('Insufficient permissions to view card transactions');
        }
        return [
            SELECT Id, Name, Posted_Date__c, Merchant__c, Amount__c, Currency__c,
                   Status__c, Matched_Expense__c, Matched_Expense__r.Name, Card__c
            FROM Card_Transaction__c
            WHERE Card__c = :cardId
            ORDER BY Posted_Date__c DESC
        ];
    }

    @AuraEnabled
    public static ImportResult importFromCsv(Id cardId, String csvBody) {
        try {
            return importCsv(cardId, csvBody);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    public static ImportResult importCsv(Id cardId, String csvBody) {
        return importTransactions(cardId, parseRows(csvBody));
    }

    public static ImportResult importTransactions(Id cardId, List<TransactionInput> inputs) {
        if (!Schema.sObjectType.Card_Transaction__c.isCreateable()) {
            throw new CardServiceException('Insufficient permissions to create card transactions');
        }
        if (cardId == null) {
            throw new CardServiceException('A card is required to import transactions');
        }

        ImportResult result = new ImportResult();
        if (inputs == null || inputs.isEmpty()) {
            return result;
        }

        Set<String> existingKeys = loadExistingKeys(cardId);
        Set<String> batchKeys = new Set<String>();
        List<Card_Transaction__c> toInsert = new List<Card_Transaction__c>();

        for (TransactionInput input : inputs) {
            result.totalRows++;
            try {
                if (input.amount == null) {
                    throw new CardServiceException('Amount is required');
                }
                if (input.postedDate == null) {
                    throw new CardServiceException('Posted date is required');
                }

                String merchant = String.isNotBlank(input.merchant) ? input.merchant.trim() : null;
                String currencyCode = normalizeCurrency(input.currencyCode);
                String key = dedupeKey(input.postedDate, input.amount, merchant);

                if (existingKeys.contains(key) || batchKeys.contains(key)) {
                    result.duplicateCount++;
                    continue;
                }
                batchKeys.add(key);

                toInsert.add(new Card_Transaction__c(
                    Card__c = cardId,
                    Posted_Date__c = input.postedDate,
                    Merchant__c = merchant,
                    Amount__c = input.amount,
                    Currency__c = currencyCode,
                    Status__c = 'Unmatched'
                ));
            } catch (Exception e) {
                result.errorCount++;
                result.errors.add(e.getMessage());
            }
        }

        if (!toInsert.isEmpty()) {
            insert toInsert;
            for (Card_Transaction__c txn : toInsert) {
                result.importedCount++;
                result.createdTransactionIds.add(txn.Id);
            }
        }

        return result;
    }

    @AuraEnabled
    public static Card_Transaction__c matchTransaction(Id transactionId, Id expenseId) {
        try {
            return linkOrCreate(transactionId, expenseId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    public static Card_Transaction__c linkOrCreate(Id transactionId, Id expenseId) {
        if (!Schema.sObjectType.Card_Transaction__c.isUpdateable()) {
            throw new CardServiceException('Insufficient permissions to update card transactions');
        }

        Card_Transaction__c txn = [
            SELECT Id, Card__c, Posted_Date__c, Merchant__c, Amount__c,
                   Currency__c, Status__c, Matched_Expense__c, Card__r.Policy__c
            FROM Card_Transaction__c
            WHERE Id = :transactionId
            LIMIT 1
        ];

        Id targetExpenseId = expenseId;
        if (targetExpenseId == null) {
            Expense__c expense = new Expense__c(
                Amount__c = txn.Amount__c,
                Currency__c = normalizeCurrency(txn.Currency__c),
                Merchant__c = txn.Merchant__c,
                Expense_Date__c = txn.Posted_Date__c,
                Expense_Type__c = 'Card',
                Reimbursable__c = false,
                Billable__c = false,
                Has_Receipt__c = false,
                Policy__c = txn.Card__r.Policy__c
            );
            Expense__c created = ExpenseService.createExpense(expense);
            targetExpenseId = created.Id;
        }

        txn.Matched_Expense__c = targetExpenseId;
        txn.Status__c = 'Matched';
        update txn;
        return txn;
    }

    public static Card__c createCard(Card__c card) {
        if (!Schema.sObjectType.Card__c.isCreateable()) {
            throw new CardServiceException('Insufficient permissions to create cards');
        }
        insert card;
        return card;
    }

    private static Set<String> loadExistingKeys(Id cardId) {
        Set<String> keys = new Set<String>();
        for (Card_Transaction__c txn : [
            SELECT Posted_Date__c, Amount__c, Merchant__c
            FROM Card_Transaction__c
            WHERE Card__c = :cardId
        ]) {
            keys.add(dedupeKey(txn.Posted_Date__c, txn.Amount__c, txn.Merchant__c));
        }
        return keys;
    }

    private static String dedupeKey(Date postedDate, Decimal amount, String merchant) {
        String datePart = postedDate == null ? '' : String.valueOf(postedDate);
        String amountPart = amount == null ? '' : amount.setScale(2).toPlainString();
        String merchantPart = String.isBlank(merchant) ? '' : merchant.trim().toLowerCase();
        return datePart + '|' + amountPart + '|' + merchantPart;
    }

    private static String normalizeCurrency(String input) {
        if (String.isNotBlank(input)) {
            String candidate = input.trim().toUpperCase();
            if (candidate.length() == 3) {
                return candidate;
            }
        }
        return 'USD';
    }

    @TestVisible
    private static List<TransactionInput> parseRows(String csvBody) {
        List<TransactionInput> inputs = new List<TransactionInput>();
        List<List<String>> parsed = parseCsv(csvBody);
        if (parsed.isEmpty()) {
            throw new CardServiceException('No data found in CSV');
        }

        Map<String, Integer> colMap = buildColumnMap(parsed[0]);
        Boolean hasHeader = !colMap.isEmpty();
        if (!hasHeader) {
            colMap = DEFAULT_COLUMNS;
        }
        Integer startRow = hasHeader ? 1 : 0;

        for (Integer r = startRow; r < parsed.size(); r++) {
            List<String> cells = parsed[r];
            TransactionInput input = new TransactionInput();
            input.postedDate = parseDate(getCell(cells, colMap, 'date'));
            input.merchant = getCell(cells, colMap, 'merchant');
            input.amount = parseAmount(getCell(cells, colMap, 'amount'));
            input.currencyCode = getCell(cells, colMap, 'currency');
            inputs.add(input);
        }
        return inputs;
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
        if (header == 'date' || header == 'transaction date' || header == 'posted date' || header == 'posting date') {
            return 'date';
        }
        if (header == 'merchant' || header == 'payee' || header == 'vendor' || header == 'description' || header == 'name') {
            return 'merchant';
        }
        if (header == 'amount' || header == 'total' || header == 'value' || header == 'debit') {
            return 'amount';
        }
        if (header == 'currency' || header == 'currency code') {
            return 'currency';
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

    public class TransactionInput {
        @AuraEnabled public Date postedDate;
        @AuraEnabled public String merchant;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String currencyCode;
    }

    public class ImportResult {
        @AuraEnabled public Integer totalRows = 0;
        @AuraEnabled public Integer importedCount = 0;
        @AuraEnabled public Integer duplicateCount = 0;
        @AuraEnabled public Integer errorCount = 0;
        @AuraEnabled public List<String> errors = new List<String>();
        @AuraEnabled public List<Id> createdTransactionIds = new List<Id>();
    }

    public class CardServiceException extends Exception {}
}
