public with sharing class ExportService {

    private static final String EXPORT_PERMISSION = 'Can_Export_Data';

    @AuraEnabled(cacheable=true)
    public static Boolean canExport() {
        return FeatureManagement.checkPermission(EXPORT_PERMISSION);
    }

    @AuraEnabled
    public static String getReportCsv(Id reportId) {
        return buildReportCsv(reportId);
    }

    public static String buildReportCsv(Id reportId) {
        if (!canExport()) {
            throw new ExportException('You do not have permission to export data');
        }
        if (reportId == null) {
            throw new ExportException('A report id is required to export');
        }
        if (!Schema.sObjectType.Expense__c.isAccessible()) {
            throw new ExportException('Insufficient access to export expenses');
        }

        List<Expense__c> expenses = ExpenseService.getExpensesByReport(reportId);

        List<String> headers = new List<String>{
            'Date', 'Merchant', 'Category', 'Tag', 'Amount', 'Currency',
            'Status', 'Type', 'Billable', 'Reimbursable', 'Description'
        };

        List<String> lines = new List<String>();
        lines.add(toCsvRow(headers));

        for (Expense__c exp : expenses) {
            List<String> cells = new List<String>{
                exp.Expense_Date__c == null ? '' : String.valueOf(exp.Expense_Date__c),
                exp.Merchant__c,
                exp.Category__r != null ? exp.Category__r.Name : '',
                exp.Tag__r != null ? exp.Tag__r.Name : '',
                exp.Amount__c == null ? '' : String.valueOf(exp.Amount__c),
                exp.Currency__c,
                exp.Status__c,
                exp.Expense_Type__c,
                String.valueOf(exp.Billable__c == true),
                String.valueOf(exp.Reimbursable__c == true),
                exp.Description__c
            };
            lines.add(toCsvRow(cells));
        }

        return String.join(lines, '\n');
    }

    private static String toCsvRow(List<String> cells) {
        List<String> escaped = new List<String>();
        for (String cell : cells) {
            escaped.add(escapeCsv(cell));
        }
        return String.join(escaped, ',');
    }

    private static String escapeCsv(String value) {
        if (value == null) {
            return '""';
        }
        String result = value.replace('"', '""');
        return '"' + result + '"';
    }

    public class ExportException extends Exception {}
}
