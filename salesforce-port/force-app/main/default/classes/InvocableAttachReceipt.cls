public with sharing class InvocableAttachReceipt {

    @InvocableMethod(label='Attach Receipt' description='Links a Salesforce File to an expense and creates a receipt record' category='Expense Management')
    public static List<Results> execute(List<Request> requests) {
        List<Results> responseList = new List<Results>();
        for (Request req : requests) {
            Results res = new Results();
            try {
                Expense_Receipt__c receipt;
                if (req.receiptId != null) {
                    receipt = ReceiptService.replaceReceipt(req.receiptId, req.contentDocumentId);
                } else {
                    receipt = ReceiptService.attachReceipt(req.expenseId, req.contentDocumentId);
                }
                if (String.isNotBlank(req.scanStatus)) {
                    receipt = ReceiptService.updateScanStatus(receipt.Id, req.scanStatus);
                }
                res.receiptId = receipt.Id;
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
        @InvocableVariable(label='Expense Id' required=false)
        public Id expenseId;

        @InvocableVariable(label='Content Document Id' required=true)
        public Id contentDocumentId;

        @InvocableVariable(label='Receipt Id' required=false)
        public Id receiptId;

        @InvocableVariable(label='Scan Status' required=false)
        public String scanStatus;
    }

    public class Results {
        @InvocableVariable(label='Receipt Id')
        public Id receiptId;

        @InvocableVariable(label='Is Success')
        public Boolean isSuccess;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }
}
