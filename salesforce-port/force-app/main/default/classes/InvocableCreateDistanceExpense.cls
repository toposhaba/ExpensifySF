public with sharing class InvocableCreateDistanceExpense {

    @InvocableMethod(label='Create Distance Expense' description='Creates a mileage/distance expense with automatic rate calculation' category='Expense Management')
    public static List<Results> execute(List<Request> requests) {
        List<Results> responseList = new List<Results>();
        for (Request req : requests) {
            Results res = new Results();
            try {
                Expense__c expense = DistanceExpenseService.createDistanceExpense(
                    req.policyId, req.reportId, req.distance, req.unit != null ? req.unit : 'mi'
                );
                res.expenseId = expense.Id;
                res.calculatedAmount = expense.Amount__c;
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

        @InvocableVariable(label='Report Id' required=false)
        public Id reportId;

        @InvocableVariable(label='Distance' required=true)
        public Decimal distance;

        @InvocableVariable(label='Unit (mi or km)' required=false)
        public String unit;
    }

    public class Results {
        @InvocableVariable(label='Expense Id')
        public Id expenseId;

        @InvocableVariable(label='Calculated Amount')
        public Decimal calculatedAmount;

        @InvocableVariable(label='Is Success')
        public Boolean isSuccess;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }
}
