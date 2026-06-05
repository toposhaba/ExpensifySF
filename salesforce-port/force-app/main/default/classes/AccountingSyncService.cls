public with sharing class AccountingSyncService {

    public class SyncException extends Exception {}

    private static final Set<Integer> SUCCESS_CODES = new Set<Integer>{200, 201, 202};

    @TestVisible
    private static Accounting_Connection__mdt connectionOverride;

    @TestVisible
    private static Map<String, String> glCodeOverride;

    public static Accounting_Sync_Log__c exportReport(Id reportId, String provider) {
        if (reportId == null) {
            throw new SyncException('Report Id is required');
        }
        if (String.isBlank(provider)) {
            throw new SyncException('Provider is required');
        }

        Expense_Report__c report = getReport(reportId);
        if (report.Status__c != 'Approved') {
            throw new SyncException('Only approved reports can be exported');
        }

        Accounting_Connection__mdt connection = getConnection(provider);
        if (connection == null || !connection.Is_Active__c) {
            throw new SyncException('No active accounting connection configured for provider ' + provider);
        }

        String payload = buildPayload(report, getGlCodeMap(provider));

        Accounting_Sync_Log__c log = new Accounting_Sync_Log__c(
            Report__c = reportId,
            Provider__c = provider,
            Payload__c = payload,
            Status__c = 'Pending',
            Synced_Date__c = Datetime.now()
        );

        try {
            HttpResponse response = sendToProvider(connection.Named_Credential__c, payload);
            log.Status_Code__c = response.getStatusCode();
            log.Response_Body__c = response.getBody();
            if (SUCCESS_CODES.contains(response.getStatusCode())) {
                log.Status__c = 'Success';
                log.External_Id__c = parseExternalId(response.getBody());
            } else {
                log.Status__c = 'Failed';
                log.Error_Message__c = 'Provider returned HTTP status ' + response.getStatusCode();
            }
        } catch (Exception e) {
            log.Status__c = 'Failed';
            log.Error_Message__c = e.getMessage();
        }

        saveLog(log);
        return log;
    }

    @TestVisible
    private static String buildPayload(Expense_Report__c report, Map<String, String> glCodes) {
        List<Expense__c> expenses = [
            SELECT Id, Name, Amount__c, Currency__c, Merchant__c, Expense_Date__c,
                   Category__c, Category__r.Name, Description__c, Reimbursable__c, Billable__c
            FROM Expense__c
            WHERE Report__c = :report.Id
            WITH SECURITY_ENFORCED
            ORDER BY Expense_Date__c ASC
        ];

        List<Map<String, Object>> lineItems = new List<Map<String, Object>>();
        for (Expense__c exp : expenses) {
            String categoryName = exp.Category__r != null ? exp.Category__r.Name : null;
            String glCode = categoryName != null && glCodes.containsKey(categoryName) ? glCodes.get(categoryName) : null;
            lineItems.add(new Map<String, Object>{
                'expenseId' => exp.Id,
                'merchant' => exp.Merchant__c,
                'amount' => exp.Amount__c,
                'currency' => exp.Currency__c,
                'category' => categoryName,
                'glCode' => glCode,
                'date' => exp.Expense_Date__c != null ? String.valueOf(exp.Expense_Date__c) : null,
                'description' => exp.Description__c,
                'reimbursable' => exp.Reimbursable__c,
                'billable' => exp.Billable__c
            });
        }

        Map<String, Object> payload = new Map<String, Object>{
            'reportId' => report.Id,
            'reportName' => report.Name,
            'status' => report.Status__c,
            'total' => report.Total_Amount__c,
            'currency' => report.Currency__c,
            'lineItems' => lineItems
        };
        return JSON.serialize(payload);
    }

    private static HttpResponse sendToProvider(String namedCredential, String payload) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:' + namedCredential + '/expenseReports');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        req.setTimeout(120000);
        req.setBody(payload);
        return new Http().send(req);
    }

    private static String parseExternalId(String body) {
        if (String.isBlank(body)) {
            return null;
        }
        try {
            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(body);
            Object externalId = parsed.containsKey('id') ? parsed.get('id') : parsed.get('Id');
            return externalId != null ? String.valueOf(externalId) : null;
        } catch (Exception e) {
            return null;
        }
    }

    private static Expense_Report__c getReport(Id reportId) {
        List<Expense_Report__c> reports = [
            SELECT Id, Name, Status__c, Total_Amount__c, Currency__c
            FROM Expense_Report__c
            WHERE Id = :reportId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        if (reports.isEmpty()) {
            throw new SyncException('Report not found');
        }
        return reports[0];
    }

    @TestVisible
    private static Accounting_Connection__mdt getConnection(String provider) {
        if (connectionOverride != null) {
            return connectionOverride;
        }
        List<Accounting_Connection__mdt> connections = [
            SELECT Provider__c, Named_Credential__c, Is_Active__c
            FROM Accounting_Connection__mdt
            WHERE Provider__c = :provider AND Is_Active__c = true
            LIMIT 1
        ];
        return connections.isEmpty() ? null : connections[0];
    }

    private static Map<String, String> getGlCodeMap(String provider) {
        if (glCodeOverride != null) {
            return glCodeOverride;
        }
        Map<String, String> glCodes = new Map<String, String>();
        for (GL_Code_Mapping__mdt mapping : [
            SELECT Category__c, GL_Code__c, Provider__c
            FROM GL_Code_Mapping__mdt
            WHERE Provider__c = :provider
        ]) {
            glCodes.put(mapping.Category__c, mapping.GL_Code__c);
        }
        return glCodes;
    }

    private static void saveLog(Accounting_Sync_Log__c log) {
        if (!Schema.SObjectType.Accounting_Sync_Log__c.isCreateable()) {
            throw new SyncException('Insufficient access to create accounting sync log');
        }
        insert log;
    }

    @AuraEnabled(cacheable=true)
    public static List<Accounting_Connection__mdt> getConnections() {
        return [
            SELECT MasterLabel, Provider__c, Named_Credential__c, Is_Active__c
            FROM Accounting_Connection__mdt
            ORDER BY Provider__c ASC
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Expense_Report__c> getApprovedReports() {
        return [
            SELECT Id, Name, Total_Amount__c, Currency__c, Status__c, Approved_Date__c
            FROM Expense_Report__c
            WHERE Status__c = 'Approved'
            WITH SECURITY_ENFORCED
            ORDER BY Approved_Date__c DESC
            LIMIT 200
        ];
    }

    @AuraEnabled
    public static Accounting_Sync_Log__c exportReportToProvider(Id reportId, String provider) {
        try {
            return exportReport(reportId, provider);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
