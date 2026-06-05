public with sharing class InvocableCreateDistanceExpense {

    @InvocableMethod(label='Create Distance Expense' description='Resolves the distance rate for a policy and creates a mileage expense' category='Expense Management')
    public static List<Results> execute(List<Request> requests) {
        List<Results> responseList = new List<Results>();
        for (Request req : requests) {
            Results res = new Results();
            try {
                Expense__c expense = DistanceService.createDistanceExpense(
                    req.policyId,
                    req.distance,
                    req.unit,
                    req.expenseDate,
                    req.merchant,
                    req.description,
                    req.reportId
                );
                res.expenseId = expense.Id;
                res.amount = expense.Amount__c;
                res.currencyCode = expense.Currency__c;
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
        @InvocableVariable(label='Policy Id' required=true)
        public Id policyId;

        @InvocableVariable(label='Distance' required=true)
        public Decimal distance;

        @InvocableVariable(label='Unit' required=false)
        public String unit;

        @InvocableVariable(label='Expense Date' required=false)
        public Date expenseDate;

        @InvocableVariable(label='Merchant' required=false)
        public String merchant;

        @InvocableVariable(label='Description' required=false)
        public String description;

        @InvocableVariable(label='Report Id' required=false)
        public Id reportId;
    }

    public class Results {
        @InvocableVariable(label='Expense Id')
        public Id expenseId;

        @InvocableVariable(label='Amount')
        public Decimal amount;

        @InvocableVariable(label='Currency Code')
        public String currencyCode;

        @InvocableVariable(label='Is Success')
        public Boolean isSuccess;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }
}
