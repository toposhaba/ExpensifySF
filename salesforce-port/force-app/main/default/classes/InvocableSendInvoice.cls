public with sharing class InvocableSendInvoice {

    @InvocableMethod(label='Send Invoice' description='Creates and sends an invoice, or sends an existing draft invoice' category='Invoicing')
    public static List<Results> execute(List<Request> requests) {
        List<Results> responseList = new List<Results>();
        for (Request req : requests) {
            Results res = new Results();
            try {
                Invoice__c invoice;
                if (req.invoiceId != null) {
                    invoice = InvoiceService.sendInvoice(req.invoiceId);
                } else {
                    Invoice__c toCreate = new Invoice__c(
                        Amount__c = req.amount,
                        Currency__c = req.currencyCode != null ? req.currencyCode : 'USD',
                        Recipient_Email__c = req.recipientEmail,
                        Policy__c = req.policyId,
                        Report__c = req.reportId,
                        Due_Date__c = req.dueDate
                    );
                    Invoice__c created = InvoiceService.createInvoice(toCreate);
                    invoice = InvoiceService.sendInvoice(created.Id);
                }
                res.invoiceId = invoice.Id;
                res.status = invoice.Status__c;
                res.issuedDate = invoice.Issued_Date__c;
                res.isSuccess = true;
            } catch (Exception e) {
                res.isSuccess = false;
                res.errorMessage = e.getMessage();
            }
            responseList.add(res);
        }
        return responseList;
    }

    public class Request {
        @InvocableVariable(label='Invoice Id' required=false)
        public Id invoiceId;

        @InvocableVariable(label='Amount' required=false)
        public Decimal amount;

        @InvocableVariable(label='Currency Code' required=false)
        public String currencyCode;

        @InvocableVariable(label='Recipient Email' required=false)
        public String recipientEmail;

        @InvocableVariable(label='Policy Id' required=false)
        public Id policyId;

        @InvocableVariable(label='Report Id' required=false)
        public Id reportId;

        @InvocableVariable(label='Due Date' required=false)
        public Date dueDate;
    }

    public class Results {
        @InvocableVariable(label='Invoice Id')
        public Id invoiceId;

        @InvocableVariable(label='Status')
        public String status;

        @InvocableVariable(label='Issued Date')
        public Date issuedDate;

        @InvocableVariable(label='Is Success')
        public Boolean isSuccess;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }
}
