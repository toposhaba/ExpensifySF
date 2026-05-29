public with sharing class AccountingIntegrationService {

    public static final String QBO_NAMED_CREDENTIAL = 'callout:QuickBooks_Online';
    public static final String XERO_NAMED_CREDENTIAL = 'callout:Xero';
    public static final String NETSUITE_NAMED_CREDENTIAL = 'callout:NetSuite';
    public static final String SAGE_NAMED_CREDENTIAL = 'callout:Sage_Intacct';

    public static Map<String, Object> syncToQuickBooks(Id reportId) {
        Expense_Report__c report = [
            SELECT Id, Name, Total_Amount__c, Currency__c, Status__c, OwnerId, Owner.Name
            FROM Expense_Report__c WHERE Id = :reportId LIMIT 1
        ];

        List<Expense__c> expenses = [
            SELECT Id, Amount__c, Currency__c, Merchant__c, Expense_Date__c,
                   Category__r.Name, Category__r.GL_Code__c, Description__c, Tax_Amount__c
            FROM Expense__c WHERE Report__c = :reportId
        ];

        Map<String, Object> payload = buildQBOPayload(report, expenses);
        String jsonBody = JSON.serialize(payload);

        HttpRequest req = new HttpRequest();
        req.setEndpoint(QBO_NAMED_CREDENTIAL + '/v3/company/{companyId}/purchase');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        req.setBody(jsonBody);

        HttpResponse res = new Http().send(req);
        logIntegration('QuickBooks_Online', reportId, req, res);

        if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
            return (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        } else {
            throw new IntegrationException('QBO sync failed: ' + res.getStatusCode() + ' ' + res.getBody());
        }
    }

    public static Map<String, Object> syncToXero(Id reportId) {
        Expense_Report__c report = [
            SELECT Id, Name, Total_Amount__c, Currency__c, Status__c, OwnerId, Owner.Name
            FROM Expense_Report__c WHERE Id = :reportId LIMIT 1
        ];

        List<Expense__c> expenses = [
            SELECT Id, Amount__c, Currency__c, Merchant__c, Expense_Date__c,
                   Category__r.Name, Category__r.GL_Code__c, Description__c, Tax_Amount__c
            FROM Expense__c WHERE Report__c = :reportId
        ];

        Map<String, Object> payload = buildXeroPayload(report, expenses);
        String jsonBody = JSON.serialize(payload);

        HttpRequest req = new HttpRequest();
        req.setEndpoint(XERO_NAMED_CREDENTIAL + '/api.xro/2.0/ExpenseClaims');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(jsonBody);

        HttpResponse res = new Http().send(req);
        logIntegration('Xero', reportId, req, res);

        if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
            return (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        } else {
            throw new IntegrationException('Xero sync failed: ' + res.getStatusCode() + ' ' + res.getBody());
        }
    }

    public static Map<String, Object> syncToNetSuite(Id reportId) {
        Expense_Report__c report = [
            SELECT Id, Name, Total_Amount__c, Currency__c, Status__c, OwnerId, Owner.Name
            FROM Expense_Report__c WHERE Id = :reportId LIMIT 1
        ];

        List<Expense__c> expenses = [
            SELECT Id, Amount__c, Currency__c, Merchant__c, Expense_Date__c,
                   Category__r.Name, Category__r.GL_Code__c, Description__c, Tax_Amount__c
            FROM Expense__c WHERE Report__c = :reportId
        ];

        Map<String, Object> payload = buildNetSuitePayload(report, expenses);
        String jsonBody = JSON.serialize(payload);

        HttpRequest req = new HttpRequest();
        req.setEndpoint(NETSUITE_NAMED_CREDENTIAL + '/services/rest/record/v1/expenseReport');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(jsonBody);

        HttpResponse res = new Http().send(req);
        logIntegration('NetSuite', reportId, req, res);

        if (res.getStatusCode() == 200 || res.getStatusCode() == 201 || res.getStatusCode() == 204) {
            return (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        } else {
            throw new IntegrationException('NetSuite sync failed: ' + res.getStatusCode() + ' ' + res.getBody());
        }
    }

    public static Map<String, Object> syncToSageIntacct(Id reportId) {
        Expense_Report__c report = [
            SELECT Id, Name, Total_Amount__c, Currency__c, Status__c, OwnerId, Owner.Name
            FROM Expense_Report__c WHERE Id = :reportId LIMIT 1
        ];

        List<Expense__c> expenses = [
            SELECT Id, Amount__c, Currency__c, Merchant__c, Expense_Date__c,
                   Category__r.Name, Category__r.GL_Code__c, Description__c, Tax_Amount__c
            FROM Expense__c WHERE Report__c = :reportId
        ];

        String xmlBody = buildSageIntacctPayload(report, expenses);

        HttpRequest req = new HttpRequest();
        req.setEndpoint(SAGE_NAMED_CREDENTIAL + '/ia/xml/xmlgw.phtml');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/xml');
        req.setBody(xmlBody);

        HttpResponse res = new Http().send(req);
        logIntegration('Sage_Intacct', reportId, req, res);

        if (res.getStatusCode() == 200) {
            return new Map<String, Object>{ 'status' => 'success', 'response' => res.getBody() };
        } else {
            throw new IntegrationException('Sage Intacct sync failed: ' + res.getStatusCode() + ' ' + res.getBody());
        }
    }

    private static Map<String, Object> buildQBOPayload(Expense_Report__c report, List<Expense__c> expenses) {
        List<Map<String, Object>> lines = new List<Map<String, Object>>();
        for (Expense__c exp : expenses) {
            Map<String, Object> line = new Map<String, Object>{
                'Amount' => exp.Amount__c,
                'Description' => exp.Description__c != null ? exp.Description__c : exp.Merchant__c,
                'DetailType' => 'AccountBasedExpenseLineDetail'
            };
            Map<String, Object> detail = new Map<String, Object>();
            if (exp.Category__r != null && exp.Category__r.GL_Code__c != null) {
                detail.put('AccountRef', new Map<String, Object>{ 'value' => exp.Category__r.GL_Code__c });
            }
            line.put('AccountBasedExpenseLineDetail', detail);
            lines.add(line);
        }

        return new Map<String, Object>{
            'PaymentType' => 'Cash',
            'TotalAmt' => report.Total_Amount__c,
            'TxnDate' => String.valueOf(Date.today()),
            'DocNumber' => report.Name,
            'Line' => lines
        };
    }

    private static Map<String, Object> buildXeroPayload(Expense_Report__c report, List<Expense__c> expenses) {
        List<Map<String, Object>> receipts = new List<Map<String, Object>>();
        for (Expense__c exp : expenses) {
            Map<String, Object> receipt = new Map<String, Object>{
                'Date' => String.valueOf(exp.Expense_Date__c),
                'Total' => exp.Amount__c,
                'Reference' => exp.Merchant__c
            };
            if (exp.Category__r != null && exp.Category__r.GL_Code__c != null) {
                receipt.put('AccountCode', exp.Category__r.GL_Code__c);
            }
            receipts.add(receipt);
        }

        return new Map<String, Object>{
            'ExpenseClaims' => new List<Map<String, Object>>{
                new Map<String, Object>{
                    'Status' => 'SUBMITTED',
                    'Receipts' => receipts
                }
            }
        };
    }

    private static Map<String, Object> buildNetSuitePayload(Expense_Report__c report, List<Expense__c> expenses) {
        List<Map<String, Object>> expenseLines = new List<Map<String, Object>>();
        for (Expense__c exp : expenses) {
            Map<String, Object> line = new Map<String, Object>{
                'amount' => exp.Amount__c,
                'memo' => exp.Description__c != null ? exp.Description__c : exp.Merchant__c,
                'expenseDate' => String.valueOf(exp.Expense_Date__c),
                'currency' => new Map<String, Object>{ 'refName' => exp.Currency__c }
            };
            if (exp.Category__r != null && exp.Category__r.GL_Code__c != null) {
                line.put('category', new Map<String, Object>{ 'refName' => exp.Category__r.GL_Code__c });
            }
            expenseLines.add(line);
        }

        return new Map<String, Object>{
            'tranId' => report.Name,
            'total' => report.Total_Amount__c,
            'expenseList' => new Map<String, Object>{ 'expense' => expenseLines }
        };
    }

    private static String buildSageIntacctPayload(Expense_Report__c report, List<Expense__c> expenses) {
        String xml = '<?xml version="1.0" encoding="UTF-8"?>';
        xml += '<request><operation><content><function controlid="export-' + report.Id + '">';
        xml += '<create><EEXPENSES>';
        xml += '<DESCRIPTION>' + report.Name + '</DESCRIPTION>';
        xml += '<BASECURR>' + report.Currency__c + '</BASECURR>';
        xml += '<EXPENSESITEMS>';

        for (Expense__c exp : expenses) {
            xml += '<EXPENSESITEM>';
            xml += '<AMOUNT>' + exp.Amount__c + '</AMOUNT>';
            xml += '<EXPENSEDATE>' + String.valueOf(exp.Expense_Date__c).replace('-', '/') + '</EXPENSEDATE>';
            xml += '<MEMO>' + (exp.Merchant__c != null ? exp.Merchant__c : '') + '</MEMO>';
            if (exp.Category__r != null && exp.Category__r.GL_Code__c != null) {
                xml += '<GLACCOUNTNO>' + exp.Category__r.GL_Code__c + '</GLACCOUNTNO>';
            }
            xml += '</EXPENSESITEM>';
        }

        xml += '</EXPENSESITEMS></EEXPENSES></create></function></content></operation></request>';
        return xml;
    }

    private static void logIntegration(String provider, Id reportId, HttpRequest req, HttpResponse res) {
        Integration_Log__c log = new Integration_Log__c(
            Provider__c = provider,
            Report__c = reportId,
            Request_Body__c = req.getBody().left(131072),
            Response_Status__c = res.getStatusCode(),
            Response_Body__c = res.getBody().left(131072),
            Timestamp__c = Datetime.now(),
            Success__c = (res.getStatusCode() >= 200 && res.getStatusCode() < 300)
        );
        insert log;
    }

    public class IntegrationException extends Exception {}
}
