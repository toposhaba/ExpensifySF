public with sharing class InvoiceService {

    public static Invoice__c createInvoice(Invoice__c invoice) {
        validateInvoice(invoice);
        if (String.isBlank(invoice.Status__c)) {
            invoice.Status__c = 'Draft';
        }
        if (String.isBlank(invoice.Currency__c)) {
            invoice.Currency__c = 'USD';
        }
        if (!Schema.sObjectType.Invoice__c.isCreateable()) {
            throw new InvoiceException('Insufficient permissions to create invoices');
        }
        insert invoice;
        return invoice;
    }

    public static Invoice__c sendInvoice(Id invoiceId) {
        Invoice__c invoice = [
            SELECT Id, Status__c, Recipient_Email__c, Issued_Date__c, Amount__c
            FROM Invoice__c
            WHERE Id = :invoiceId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        if (invoice.Status__c != 'Draft') {
            throw new InvoiceException('Only draft invoices can be sent');
        }
        if (String.isBlank(invoice.Recipient_Email__c)) {
            throw new InvoiceException('A recipient email is required before sending');
        }
        if (invoice.Amount__c == null || invoice.Amount__c <= 0) {
            throw new InvoiceException('Amount must be greater than zero before sending');
        }
        if (!Schema.sObjectType.Invoice__c.isUpdateable()) {
            throw new InvoiceException('Insufficient permissions to update invoices');
        }

        invoice.Status__c = 'Sent';
        if (invoice.Issued_Date__c == null) {
            invoice.Issued_Date__c = Date.today();
        }
        update invoice;
        return invoice;
    }

    public static Invoice__c markPaid(Id invoiceId) {
        Invoice__c invoice = [
            SELECT Id, Status__c
            FROM Invoice__c
            WHERE Id = :invoiceId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        if (invoice.Status__c != 'Sent') {
            throw new InvoiceException('Only sent invoices can be marked as paid');
        }
        if (!Schema.sObjectType.Invoice__c.isUpdateable()) {
            throw new InvoiceException('Insufficient permissions to update invoices');
        }

        invoice.Status__c = 'Paid';
        update invoice;
        return invoice;
    }

    public static Invoice__c getInvoice(Id invoiceId) {
        return [
            SELECT Id, Name, Status__c, Amount__c, Currency__c, Recipient_Email__c,
                   Due_Date__c, Issued_Date__c, Policy__c, Policy__r.Name,
                   Report__c, Report__r.Name, OwnerId, CreatedDate
            FROM Invoice__c
            WHERE Id = :invoiceId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Invoice__c> getMyInvoices() {
        Id currentUserId = UserInfo.getUserId();
        return [
            SELECT Id, Name, Status__c, Amount__c, Currency__c, Recipient_Email__c,
                   Due_Date__c, Issued_Date__c, Policy__c, Policy__r.Name,
                   Report__c, Report__r.Name, CreatedDate
            FROM Invoice__c
            WHERE OwnerId = :currentUserId
            WITH SECURITY_ENFORCED
            ORDER BY CreatedDate DESC
            LIMIT 200
        ];
    }

    @AuraEnabled
    public static Invoice__c createInvoiceRecord(Invoice__c invoice) {
        try {
            return createInvoice(invoice);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Invoice__c sendInvoiceRecord(Id invoiceId) {
        try {
            return sendInvoice(invoiceId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Invoice__c markInvoicePaid(Id invoiceId) {
        try {
            return markPaid(invoiceId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static void validateInvoice(Invoice__c invoice) {
        if (invoice.Amount__c == null || invoice.Amount__c <= 0) {
            throw new InvoiceException('Amount must be greater than zero');
        }
        if (String.isBlank(invoice.Recipient_Email__c)) {
            throw new InvoiceException('Recipient email is required');
        }
        if (!Pattern.matches('^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$', invoice.Recipient_Email__c)) {
            throw new InvoiceException('Recipient email is not valid');
        }
        if (invoice.Due_Date__c != null && invoice.Issued_Date__c != null
            && invoice.Due_Date__c < invoice.Issued_Date__c) {
            throw new InvoiceException('Due date cannot be before the issued date');
        }
    }

    public class InvoiceException extends Exception {}
}
