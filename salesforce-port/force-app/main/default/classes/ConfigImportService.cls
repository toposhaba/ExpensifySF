public with sharing class ConfigImportService {

    public static final String TYPE_CATEGORIES = 'Categories';
    public static final String TYPE_TAGS = 'Tags';
    public static final String TYPE_MEMBERS = 'Members';

    private static final Set<String> MEMBER_ROLES = new Set<String>{ 'Admin', 'Approver', 'Member', 'Auditor' };

    @AuraEnabled
    public static ImportSummary importConfig(String csvBody, Id policyId, String importType) {
        try {
            return runImport(csvBody, policyId, importType);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    public static ImportSummary runImport(String csvBody, Id policyId, String importType) {
        if (policyId == null) {
            throw new ConfigImportException('A policy is required');
        }
        String normalizedType = normalizeType(importType);

        List<List<String>> parsed = parseCsv(csvBody);
        if (parsed.isEmpty()) {
            throw new ConfigImportException('No data found in CSV');
        }

        Map<String, Integer> colMap = buildColumnMap(parsed[0]);
        Boolean hasHeader = !colMap.isEmpty();
        Integer startRow = hasHeader ? 1 : 0;

        if (normalizedType == TYPE_MEMBERS) {
            return importMembers(parsed, colMap, hasHeader, startRow, policyId);
        }
        return importNamedRecords(parsed, colMap, hasHeader, startRow, policyId, normalizedType);
    }

    private static ImportSummary importNamedRecords(
        List<List<String>> parsed,
        Map<String, Integer> colMap,
        Boolean hasHeader,
        Integer startRow,
        Id policyId,
        String normalizedType
    ) {
        Boolean isCategories = normalizedType == TYPE_CATEGORIES;
        SObjectType sObjType = isCategories ? Expense_Category__c.SObjectType : Expense_Tag__c.SObjectType;
        if (!sObjType.getDescribe().isCreateable() || !sObjType.getDescribe().isUpdateable()) {
            throw new ConfigImportException('Insufficient permissions to manage ' + normalizedType);
        }

        ImportSummary summary = new ImportSummary();
        summary.importType = normalizedType;

        Map<String, Id> existingByName = new Map<String, Id>();
        if (isCategories) {
            for (Expense_Category__c c : PolicyService.getCategories(policyId)) {
                existingByName.put(c.Name.toLowerCase(), c.Id);
            }
        } else {
            for (Expense_Tag__c t : PolicyService.getTags(policyId)) {
                existingByName.put(t.Name.toLowerCase(), t.Id);
            }
        }

        List<SObject> toInsert = new List<SObject>();
        List<RowResult> insertResults = new List<RowResult>();
        List<SObject> toUpdate = new List<SObject>();
        List<RowResult> updateResults = new List<RowResult>();
        Set<String> seenNames = new Set<String>();

        for (Integer r = startRow; r < parsed.size(); r++) {
            List<String> cells = parsed[r];
            RowResult rr = new RowResult();
            rr.rowNumber = r + 1;
            summary.totalRows++;

            try {
                String name = getCell(cells, colMap, 'name', 0);
                if (String.isBlank(name)) {
                    throw new ConfigImportException('Name is required');
                }
                name = name.trim();
                rr.name = name;

                String key = name.toLowerCase();
                if (seenNames.contains(key)) {
                    throw new ConfigImportException('Duplicate name in file: "' + name + '"');
                }
                seenNames.add(key);

                String glCode = trimToNull(getCell(cells, colMap, 'glcode', 1));
                Boolean enabled = parseBoolean(getCell(cells, colMap, 'enabled', 2), true);

                SObject record;
                if (isCategories) {
                    Decimal maxAmount = parseDecimal(getCell(cells, colMap, 'maxamount', 3));
                    Boolean receiptRequired = parseBoolean(getCell(cells, colMap, 'receiptrequired', 4), false);
                    record = new Expense_Category__c(
                        Name = name,
                        Policy__c = policyId,
                        GL_Code__c = glCode,
                        Enabled__c = enabled,
                        Max_Amount__c = maxAmount,
                        Receipt_Required__c = receiptRequired
                    );
                } else {
                    record = new Expense_Tag__c(
                        Name = name,
                        Policy__c = policyId,
                        GL_Code__c = glCode,
                        Enabled__c = enabled
                    );
                }

                if (existingByName.containsKey(key)) {
                    record.put('Id', existingByName.get(key));
                    rr.action = 'Updated';
                    toUpdate.add(record);
                    updateResults.add(rr);
                } else {
                    rr.action = 'Created';
                    toInsert.add(record);
                    insertResults.add(rr);
                }
            } catch (Exception e) {
                rr.isSuccess = false;
                rr.errorMessage = e.getMessage();
                summary.errorCount++;
            }

            summary.rows.add(rr);
        }

        commitInserts(toInsert, insertResults, summary);
        commitUpdates(toUpdate, updateResults, summary);
        return summary;
    }

    private static ImportSummary importMembers(
        List<List<String>> parsed,
        Map<String, Integer> colMap,
        Boolean hasHeader,
        Integer startRow,
        Id policyId
    ) {
        if (!Policy_Member__c.SObjectType.getDescribe().isCreateable()
            || !Policy_Member__c.SObjectType.getDescribe().isUpdateable()) {
            throw new ConfigImportException('Insufficient permissions to manage members');
        }

        ImportSummary summary = new ImportSummary();
        summary.importType = TYPE_MEMBERS;

        List<RowResult> pending = new List<RowResult>();
        List<String> emailForRow = new List<String>();
        List<String> roleForRow = new List<String>();
        Set<String> emails = new Set<String>();

        for (Integer r = startRow; r < parsed.size(); r++) {
            List<String> cells = parsed[r];
            RowResult rr = new RowResult();
            rr.rowNumber = r + 1;
            summary.totalRows++;

            try {
                String email = trimToNull(getCell(cells, colMap, 'email', 0));
                if (String.isBlank(email)) {
                    throw new ConfigImportException('Email is required');
                }
                email = email.toLowerCase();
                rr.name = email;

                String role = trimToNull(getCell(cells, colMap, 'role', 1));
                role = role == null ? 'Member' : role;
                if (!MEMBER_ROLES.contains(role)) {
                    throw new ConfigImportException('Invalid role: "' + role + '"');
                }

                pending.add(rr);
                emailForRow.add(email);
                roleForRow.add(role);
                emails.add(email);
            } catch (Exception e) {
                rr.isSuccess = false;
                rr.errorMessage = e.getMessage();
                summary.errorCount++;
                summary.rows.add(rr);
            }
        }

        Map<String, Id> userIdByEmail = new Map<String, Id>();
        if (!emails.isEmpty()) {
            for (User u : [SELECT Id, Email FROM User WHERE Email IN :emails AND IsActive = true]) {
                userIdByEmail.put(u.Email.toLowerCase(), u.Id);
            }
        }

        Map<Id, Id> existingMemberIdByUser = new Map<Id, Id>();
        Map<Id, String> existingRoleByUser = new Map<Id, String>();
        for (Policy_Member__c pm : PolicyService.getMembers(policyId)) {
            existingMemberIdByUser.put(pm.User__c, pm.Id);
            existingRoleByUser.put(pm.User__c, pm.Role__c);
        }

        List<Policy_Member__c> toInsert = new List<Policy_Member__c>();
        List<RowResult> insertResults = new List<RowResult>();
        List<Policy_Member__c> toUpdate = new List<Policy_Member__c>();
        List<RowResult> updateResults = new List<RowResult>();
        Set<Id> seenUsers = new Set<Id>();

        for (Integer i = 0; i < pending.size(); i++) {
            RowResult rr = pending[i];
            try {
                Id userId = userIdByEmail.get(emailForRow[i]);
                if (userId == null) {
                    throw new ConfigImportException('No active user found for email: "' + emailForRow[i] + '"');
                }
                if (seenUsers.contains(userId)) {
                    throw new ConfigImportException('Duplicate user in file: "' + emailForRow[i] + '"');
                }
                seenUsers.add(userId);

                String role = roleForRow[i];
                if (existingMemberIdByUser.containsKey(userId)) {
                    rr.action = 'Updated';
                    toUpdate.add(new Policy_Member__c(Id = existingMemberIdByUser.get(userId), Role__c = role));
                    updateResults.add(rr);
                } else {
                    rr.action = 'Created';
                    toInsert.add(new Policy_Member__c(Policy__c = policyId, User__c = userId, Role__c = role));
                    insertResults.add(rr);
                }
            } catch (Exception e) {
                rr.isSuccess = false;
                rr.errorMessage = e.getMessage();
                summary.errorCount++;
            }
            summary.rows.add(rr);
        }

        commitInserts(toInsert, insertResults, summary);
        commitUpdates(toUpdate, updateResults, summary);
        return summary;
    }

    private static void commitInserts(List<SObject> records, List<RowResult> results, ImportSummary summary) {
        if (records.isEmpty()) {
            return;
        }
        List<Database.SaveResult> saveResults = Database.insert(records, false);
        for (Integer i = 0; i < saveResults.size(); i++) {
            applySaveResult(saveResults[i], results[i], summary, true);
        }
    }

    private static void commitUpdates(List<SObject> records, List<RowResult> results, ImportSummary summary) {
        if (records.isEmpty()) {
            return;
        }
        List<Database.SaveResult> saveResults = Database.update(records, false);
        for (Integer i = 0; i < saveResults.size(); i++) {
            applySaveResult(saveResults[i], results[i], summary, false);
        }
    }

    private static void applySaveResult(Database.SaveResult sr, RowResult rr, ImportSummary summary, Boolean isInsert) {
        if (sr.isSuccess()) {
            rr.isSuccess = true;
            rr.recordId = sr.getId();
            summary.recordIds.add(String.valueOf(sr.getId()));
            summary.successCount++;
            if (isInsert) {
                summary.createdCount++;
            } else {
                summary.updatedCount++;
            }
        } else {
            rr.isSuccess = false;
            rr.action = null;
            List<String> messages = new List<String>();
            for (Database.Error err : sr.getErrors()) {
                messages.add(err.getMessage());
            }
            rr.errorMessage = String.join(messages, '; ');
            summary.errorCount++;
        }
    }

    private static String normalizeType(String importType) {
        if (String.isBlank(importType)) {
            throw new ConfigImportException('Import type is required');
        }
        String value = importType.trim().toLowerCase();
        if (value == 'categories' || value == 'category') {
            return TYPE_CATEGORIES;
        }
        if (value == 'tags' || value == 'tag') {
            return TYPE_TAGS;
        }
        if (value == 'members' || value == 'member') {
            return TYPE_MEMBERS;
        }
        throw new ConfigImportException('Unsupported import type: "' + importType + '"');
    }

    private static String getCell(List<String> cells, Map<String, Integer> colMap, String role, Integer positional) {
        Integer idx = colMap.containsKey(role) ? colMap.get(role) : positional;
        if (idx == null || idx < 0 || idx >= cells.size()) {
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
        if (header == 'name' || header == 'category' || header == 'tag' || header == 'category name' || header == 'tag name') {
            return 'name';
        }
        if (header == 'gl code' || header == 'glcode' || header == 'gl' || header == 'code') {
            return 'glcode';
        }
        if (header == 'enabled' || header == 'active' || header == 'is enabled') {
            return 'enabled';
        }
        if (header == 'max amount' || header == 'maxamount' || header == 'limit' || header == 'max') {
            return 'maxamount';
        }
        if (header == 'receipt required' || header == 'receiptrequired' || header == 'receipt') {
            return 'receiptrequired';
        }
        if (header == 'email' || header == 'user' || header == 'user email' || header == 'username') {
            return 'email';
        }
        if (header == 'role') {
            return 'role';
        }
        return null;
    }

    private static String trimToNull(String value) {
        return String.isBlank(value) ? null : value.trim();
    }

    private static Boolean parseBoolean(String value, Boolean fallback) {
        if (String.isBlank(value)) {
            return fallback;
        }
        String v = value.trim().toLowerCase();
        if (v == 'true' || v == 'yes' || v == 'y' || v == '1' || v == 'enabled' || v == 'active') {
            return true;
        }
        if (v == 'false' || v == 'no' || v == 'n' || v == '0' || v == 'disabled' || v == 'inactive') {
            return false;
        }
        return fallback;
    }

    private static Decimal parseDecimal(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        String cleaned = value.trim().replaceAll('[^0-9.\\-]', '');
        if (String.isBlank(cleaned) || cleaned == '-' || cleaned == '.') {
            return null;
        }
        try {
            return Decimal.valueOf(cleaned);
        } catch (Exception e) {
            return null;
        }
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

    public class ImportSummary {
        @AuraEnabled public String importType;
        @AuraEnabled public Integer totalRows = 0;
        @AuraEnabled public Integer successCount = 0;
        @AuraEnabled public Integer errorCount = 0;
        @AuraEnabled public Integer createdCount = 0;
        @AuraEnabled public Integer updatedCount = 0;
        @AuraEnabled public List<RowResult> rows = new List<RowResult>();
        @AuraEnabled public List<String> recordIds = new List<String>();
    }

    public class RowResult {
        @AuraEnabled public Integer rowNumber;
        @AuraEnabled public Boolean isSuccess = false;
        @AuraEnabled public String name;
        @AuraEnabled public String action;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public Id recordId;
    }

    public class ConfigImportException extends Exception {}
}
