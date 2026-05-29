public with sharing class ImportExportService {

    public static List<Expense__c> importFromCsv(String csvContent, Id policyId, Id reportId) {
        List<Expense__c> expenses = new List<Expense__c>();
        List<String> lines = csvContent.split('\n');

        if (lines.size() < 2) {
            throw new ImportException('CSV must have a header row and at least one data row');
        }

        List<String> headers = parseCsvLine(lines[0]);
        Map<String, Integer> headerMap = new Map<String, Integer>();
        for (Integer i = 0; i < headers.size(); i++) {
            headerMap.put(headers[i].trim().toLowerCase(), i);
        }

        for (Integer i = 1; i < lines.size(); i++) {
            String line = lines[i].trim();
            if (String.isBlank(line)) continue;

            List<String> values = parseCsvLine(line);
            Expense__c exp = new Expense__c(
                Policy__c = policyId,
                Report__c = reportId,
                Status__c = 'Draft',
                Expense_Type__c = 'Cash'
            );

            if (headerMap.containsKey('amount') && values.size() > headerMap.get('amount')) {
                String amt = values[headerMap.get('amount')].replaceAll('[^0-9.-]', '');
                if (String.isNotBlank(amt)) exp.Amount__c = Decimal.valueOf(amt);
            }
            if (headerMap.containsKey('merchant') && values.size() > headerMap.get('merchant')) {
                exp.Merchant__c = values[headerMap.get('merchant')].trim();
            }
            if (headerMap.containsKey('date') && values.size() > headerMap.get('date')) {
                try { exp.Expense_Date__c = Date.valueOf(values[headerMap.get('date')].trim()); }
                catch (Exception e) { exp.Expense_Date__c = Date.today(); }
            }
            if (headerMap.containsKey('currency') && values.size() > headerMap.get('currency')) {
                exp.Currency__c = values[headerMap.get('currency')].trim();
            } else {
                exp.Currency__c = 'USD';
            }
            if (headerMap.containsKey('description') && values.size() > headerMap.get('description')) {
                exp.Description__c = values[headerMap.get('description')].trim();
            }

            if (exp.Amount__c != null && exp.Amount__c > 0) {
                expenses.add(exp);
            }
        }

        if (!expenses.isEmpty()) {
            insert expenses;
            if (reportId != null) {
                ExpenseService.updateReportTotals(reportId);
            }
        }
        return expenses;
    }

    public static String exportReportToCsv(Id reportId) {
        List<Expense__c> expenses = [
            SELECT Name, Amount__c, Currency__c, Merchant__c, Expense_Date__c,
                   Category__r.Name, Tag__r.Name, Description__c, Billable__c,
                   Reimbursable__c, Tax_Amount__c, Expense_Type__c, Status__c
            FROM Expense__c WHERE Report__c = :reportId ORDER BY Expense_Date__c
        ];

        String csv = 'Expense #,Amount,Currency,Merchant,Date,Category,Tag,Description,Billable,Reimbursable,Tax,Type,Status\n';
        for (Expense__c exp : expenses) {
            csv += '"' + exp.Name + '",';
            csv += exp.Amount__c + ',';
            csv += exp.Currency__c + ',';
            csv += '"' + (exp.Merchant__c != null ? exp.Merchant__c : '') + '",';
            csv += exp.Expense_Date__c + ',';
            csv += '"' + (exp.Category__r != null ? exp.Category__r.Name : '') + '",';
            csv += '"' + (exp.Tag__r != null ? exp.Tag__r.Name : '') + '",';
            csv += '"' + (exp.Description__c != null ? exp.Description__c.replaceAll('"', '""') : '') + '",';
            csv += exp.Billable__c + ',';
            csv += exp.Reimbursable__c + ',';
            csv += (exp.Tax_Amount__c != null ? String.valueOf(exp.Tax_Amount__c) : '0') + ',';
            csv += exp.Expense_Type__c + ',';
            csv += exp.Status__c + '\n';
        }
        return csv;
    }

    public static Id exportReportToPdf(Id reportId) {
        Expense_Report__c report = [
            SELECT Id, Name, Total_Amount__c, Currency__c, Status__c, OwnerId, Owner.Name
            FROM Expense_Report__c WHERE Id = :reportId LIMIT 1
        ];

        String html = '<html><body>';
        html += '<h1>Expense Report: ' + report.Name + '</h1>';
        html += '<p>Owner: ' + report.Owner.Name + '</p>';
        html += '<p>Total: ' + report.Total_Amount__c + ' ' + report.Currency__c + '</p>';
        html += '<p>Status: ' + report.Status__c + '</p>';
        html += '<table border="1"><tr><th>Date</th><th>Merchant</th><th>Amount</th><th>Category</th><th>Status</th></tr>';

        List<Expense__c> expenses = [
            SELECT Expense_Date__c, Merchant__c, Amount__c, Currency__c, Category__r.Name, Status__c
            FROM Expense__c WHERE Report__c = :reportId ORDER BY Expense_Date__c
        ];
        for (Expense__c exp : expenses) {
            html += '<tr><td>' + exp.Expense_Date__c + '</td><td>' + (exp.Merchant__c != null ? exp.Merchant__c : '') + '</td>';
            html += '<td>' + exp.Amount__c + ' ' + exp.Currency__c + '</td>';
            html += '<td>' + (exp.Category__r != null ? exp.Category__r.Name : '') + '</td>';
            html += '<td>' + exp.Status__c + '</td></tr>';
        }
        html += '</table></body></html>';

        ContentVersion cv = new ContentVersion(
            Title = report.Name + '_Export.pdf',
            PathOnClient = report.Name + '_Export.html',
            VersionData = Blob.valueOf(html),
            FirstPublishLocationId = reportId
        );
        insert cv;
        return cv.Id;
    }

    private static List<String> parseCsvLine(String line) {
        List<String> result = new List<String>();
        Boolean inQuotes = false;
        String current = '';

        for (Integer i = 0; i < line.length(); i++) {
            String ch = line.substring(i, i + 1);
            if (ch == '"') {
                inQuotes = !inQuotes;
            } else if (ch == ',' && !inQuotes) {
                result.add(current);
                current = '';
            } else {
                current += ch;
            }
        }
        result.add(current);
        return result;
    }

    public class ImportException extends Exception {}
}
