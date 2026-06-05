public with sharing class InvocableCreatePerDiem {

    @InvocableMethod(label='Create Per Diem Expense' description='Creates a per diem expense from a policy destination rate multiplied by the number of days' category='Expense Management')
    public static List<Results> execute(List<Request> requests) {
        List<Results> responseList = new List<Results>();
        for (Request req : requests) {
            Results res = new Results();
            try {
                Expense__c created = PerDiemService.createPerDiemExpense(
                    req.policyId,
                    req.destination,
                    req.numberOfDays,
                    req.expenseDate,
                    req.reportId
                );
                res.expenseId = created.Id;
                res.amount = created.Amount__c;
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

        @InvocableVariable(label='Destination' required=true)
        public String destination;

        @InvocableVariable(label='Number Of Days' required=true)
        public Integer numberOfDays;

        @InvocableVariable(label='Expense Date' required=false)
        public Date expenseDate;

        @InvocableVariable(label='Report Id' required=false)
        public Id reportId;
    }

    public class Results {
        @InvocableVariable(label='Expense Id')
        public Id expenseId;

        @InvocableVariable(label='Amount')
        public Decimal amount;

        @InvocableVariable(label='Is Success')
        public Boolean isSuccess;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }
}
