public with sharing class InvocableCreatePerDiemExpense {

    @InvocableMethod(label='Create Per Diem Expense' description='Creates a per diem expense based on destination rate and travel dates' category='Expense Management')
    public static List<Results> execute(List<Request> requests) {
        List<Results> responseList = new List<Results>();
        for (Request req : requests) {
            Results res = new Results();
            try {
                Expense__c expense = PerDiemService.createPerDiemExpense(
                    req.policyId, req.reportId, req.destination, req.startDate, req.endDate
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

        @InvocableVariable(label='Destination' required=true)
        public String destination;

        @InvocableVariable(label='Start Date' required=true)
        public Date startDate;

        @InvocableVariable(label='End Date' required=true)
        public Date endDate;
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
