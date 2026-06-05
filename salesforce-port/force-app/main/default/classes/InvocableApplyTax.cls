public with sharing class InvocableApplyTax {

    @InvocableMethod(label='Apply Tax' description='Computes and applies a tax rate to an expense, setting tax amount and tax rate' category='Expense Management')
    public static List<Results> execute(List<Request> requests) {
        List<Results> responseList = new List<Results>();
        for (Request req : requests) {
            Results res = new Results();
            try {
                Expense__c expense = TaxService.computeTax(req.expenseId, req.taxRateId);
                res.expenseId = expense.Id;
                res.taxAmount = expense.Tax_Amount__c;
                res.taxRate = expense.Tax_Rate__c;
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
        @InvocableVariable(label='Expense Id' required=true)
        public Id expenseId;

        @InvocableVariable(label='Tax Rate Id' required=true)
        public Id taxRateId;
    }

    public class Results {
        @InvocableVariable(label='Expense Id')
        public Id expenseId;

        @InvocableVariable(label='Tax Amount')
        public Decimal taxAmount;

        @InvocableVariable(label='Tax Rate')
        public Decimal taxRate;

        @InvocableVariable(label='Is Success')
        public Boolean isSuccess;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }
}
