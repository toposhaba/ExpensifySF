public with sharing class InvoiceService {

    public static Invoice__c createInvoice(Invoice__c invoice) {
        if (invoice.Status__c == null) invoice.Status__c = 'Draft';
        if (invoice.Due_Date__c == null) invoice.Due_Date__c = Date.today().addDays(30);
        insert invoice;
        return invoice;
    }

    public static Invoice__c sendInvoice(Id invoiceId) {
        Invoice__c inv = [SELECT Id, Status__c, Recipient_Email__c FROM Invoice__c WHERE Id = :invoiceId LIMIT 1];
        if (inv.Status__c != 'Draft') {
            throw new InvoiceException('Only draft invoices can be sent');
        }
        inv.Status__c = 'Sent';
        inv.Sent_Date__c = Date.today();
        update inv;
        return inv;
    }

    public static Invoice__c markPaid(Id invoiceId) {
        Invoice__c inv = new Invoice__c(Id = invoiceId, Status__c = 'Paid', Paid_Date__c = Date.today());
        update inv;
        return inv;
    }

    public static List<Invoice__c> getInvoicesByPolicy(Id policyId) {
        return [
            SELECT Id, Name, Amount__c, Currency__c, Status__c, Recipient_Email__c,
                   Recipient_Name__c, Due_Date__c, Sent_Date__c, Paid_Date__c, Description__c
            FROM Invoice__c WHERE Policy__c = :policyId ORDER BY CreatedDate DESC LIMIT 100
        ];
    }

    public class InvoiceException extends Exception {}
}
