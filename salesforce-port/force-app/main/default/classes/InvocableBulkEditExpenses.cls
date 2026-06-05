public with sharing class InvocableBulkEditExpenses {

    @InvocableMethod(label='Bulk Edit Expenses' description='Applies a set of field values to many expenses in bulk with per-record success reporting' category='Expense Management')
    public static List<Results> execute(List<Request> requests) {
        List<Results> responseList = new List<Results>();
        for (Request req : requests) {
            Results res = new Results();
            res.failedExpenseIds = new List<Id>();
            res.errorMessages = new List<String>();
            try {
                Map<String, Object> fieldValues = buildFieldValues(req);
                List<BulkEditService.BulkEditResult> editResults = BulkEditService.applyBulkEdit(req.expenseIds, fieldValues);

                Integer successCount = 0;
                Integer failureCount = 0;
                for (BulkEditService.BulkEditResult r : editResults) {
                    if (r.isSuccess) {
                        successCount++;
                    } else {
                        failureCount++;
                        res.failedExpenseIds.add(r.expenseId);
                        res.errorMessages.add(r.errorMessage);
                    }
                }

                res.totalProcessed = editResults.size();
                res.successCount = successCount;
                res.failureCount = failureCount;
                res.isSuccess = failureCount == 0;
            } catch (Exception e) {
                res.totalProcessed = 0;
                res.successCount = 0;
                res.failureCount = req.expenseIds == null ? 0 : req.expenseIds.size();
                res.isSuccess = false;
                res.errorMessage = e.getMessage();
            }
            responseList.add(res);
        }
        return responseList;
    }

    private static Map<String, Object> buildFieldValues(Request req) {
        Map<String, Object> fieldValues = new Map<String, Object>();
        if (req.amount != null) {
            fieldValues.put('Amount__c', req.amount);
        }
        if (req.currencyCode != null) {
            fieldValues.put('Currency__c', req.currencyCode);
        }
        if (req.merchant != null) {
            fieldValues.put('Merchant__c', req.merchant);
        }
        if (req.expenseDate != null) {
            fieldValues.put('Expense_Date__c', req.expenseDate);
        }
        if (req.categoryId != null) {
            fieldValues.put('Category__c', req.categoryId);
        }
        if (req.tagId != null) {
            fieldValues.put('Tag__c', req.tagId);
        }
        if (req.description != null) {
            fieldValues.put('Description__c', req.description);
        }
        if (req.expenseType != null) {
            fieldValues.put('Expense_Type__c', req.expenseType);
        }
        if (req.status != null) {
            fieldValues.put('Status__c', req.status);
        }
        if (req.billable != null) {
            fieldValues.put('Billable__c', req.billable);
        }
        if (req.reimbursable != null) {
            fieldValues.put('Reimbursable__c', req.reimbursable);
        }
        return fieldValues;
    }

    public class Request {
        @InvocableVariable(label='Expense Ids' required=true)
        public List<Id> expenseIds;

        @InvocableVariable(label='Amount' required=false)
        public Decimal amount;

        @InvocableVariable(label='Currency Code' required=false)
        public String currencyCode;

        @InvocableVariable(label='Merchant' required=false)
        public String merchant;

        @InvocableVariable(label='Expense Date' required=false)
        public Date expenseDate;

        @InvocableVariable(label='Category Id' required=false)
        public Id categoryId;

        @InvocableVariable(label='Tag Id' required=false)
        public Id tagId;

        @InvocableVariable(label='Description' required=false)
        public String description;

        @InvocableVariable(label='Expense Type' required=false)
        public String expenseType;

        @InvocableVariable(label='Status' required=false)
        public String status;

        @InvocableVariable(label='Billable' required=false)
        public Boolean billable;

        @InvocableVariable(label='Reimbursable' required=false)
        public Boolean reimbursable;
    }

    public class Results {
        @InvocableVariable(label='Total Processed')
        public Integer totalProcessed;

        @InvocableVariable(label='Success Count')
        public Integer successCount;

        @InvocableVariable(label='Failure Count')
        public Integer failureCount;

        @InvocableVariable(label='Failed Expense Ids')
        public List<Id> failedExpenseIds;

        @InvocableVariable(label='Error Messages')
        public List<String> errorMessages;

        @InvocableVariable(label='Is Success')
        public Boolean isSuccess;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }
}
