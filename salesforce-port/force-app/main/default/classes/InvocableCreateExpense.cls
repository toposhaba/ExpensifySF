public with sharing class InvocableCreateExpense {

    @InvocableMethod(label='Create Expense' description='Creates an expense with validation and policy violation checking' category='Expense Management')
    public static List<Results> execute(List<Request> requests) {
        List<Results> responseList = new List<Results>();
        for (Request req : requests) {
            Results res = new Results();
            try {
                Expense__c expense = new Expense__c(
                    Amount__c = req.amount,
                    Currency__c = req.currencyCode != null ? req.currencyCode : 'USD',
                    Merchant__c = req.merchant,
                    Expense_Date__c = req.expenseDate,
                    Category__c = req.categoryId,
                    Tag__c = req.tagId,
                    Description__c = req.description,
                    Billable__c = req.billable != null ? req.billable : false,
                    Reimbursable__c = req.reimbursable != null ? req.reimbursable : true,
                    Expense_Type__c = req.expenseType != null ? req.expenseType : 'Cash',
                    Policy__c = req.policyId,
                    Report__c = req.reportId,
                    Has_Receipt__c = req.hasReceipt != null ? req.hasReceipt : false,
                    Distance__c = req.distance,
                    Distance_Unit__c = req.distanceUnit
                );
                Expense__c created = ExpenseService.createExpense(expense);
                res.expenseId = created.Id;
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
        @InvocableVariable(label='Amount' required=true)
        public Decimal amount;

        @InvocableVariable(label='Currency Code' required=false)
        public String currencyCode;

        @InvocableVariable(label='Merchant' required=false)
        public String merchant;

        @InvocableVariable(label='Expense Date' required=true)
        public Date expenseDate;

        @InvocableVariable(label='Category Id' required=false)
        public Id categoryId;

        @InvocableVariable(label='Tag Id' required=false)
        public Id tagId;

        @InvocableVariable(label='Description' required=false)
        public String description;

        @InvocableVariable(label='Billable' required=false)
        public Boolean billable;

        @InvocableVariable(label='Reimbursable' required=false)
        public Boolean reimbursable;

        @InvocableVariable(label='Expense Type' required=false)
        public String expenseType;

        @InvocableVariable(label='Policy Id' required=false)
        public Id policyId;

        @InvocableVariable(label='Report Id' required=false)
        public Id reportId;

        @InvocableVariable(label='Has Receipt' required=false)
        public Boolean hasReceipt;

        @InvocableVariable(label='Distance' required=false)
        public Decimal distance;

        @InvocableVariable(label='Distance Unit' required=false)
        public String distanceUnit;
    }

    public class Results {
        @InvocableVariable(label='Expense Id')
        public Id expenseId;

        @InvocableVariable(label='Is Success')
        public Boolean isSuccess;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }
}
