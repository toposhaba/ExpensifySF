public with sharing class InvocableSplitExpense {

    @InvocableMethod(label='Split Expense' description='Splits a parent expense into multiple expense splits by amount or share' category='Expense Management')
    public static List<Results> execute(List<Request> requests) {
        List<Results> responseList = new List<Results>();
        for (Request req : requests) {
            Results res = new Results();
            try {
                List<ExpenseSplitService.SplitInput> inputs = ExpenseSplitService.buildInputs(
                    req.splitUserIds, req.splitAmounts, req.splitShares
                );
                List<Expense_Split__c> splits = ExpenseSplitService.createSplits(
                    req.parentExpenseId, inputs, req.mode
                );
                List<Id> ids = new List<Id>();
                for (Expense_Split__c split : splits) {
                    ids.add(split.Id);
                }
                res.splitIds = ids;
                res.splitCount = ids.size();
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
        @InvocableVariable(label='Parent Expense Id' required=true)
        public Id parentExpenseId;

        @InvocableVariable(label='Mode' description='Amount or Share' required=false)
        public String mode;

        @InvocableVariable(label='Split User Ids' required=true)
        public List<Id> splitUserIds;

        @InvocableVariable(label='Split Amounts' required=false)
        public List<Decimal> splitAmounts;

        @InvocableVariable(label='Split Shares' required=false)
        public List<Decimal> splitShares;
    }

    public class Results {
        @InvocableVariable(label='Split Ids')
        public List<Id> splitIds;

        @InvocableVariable(label='Split Count')
        public Integer splitCount;

        @InvocableVariable(label='Is Success')
        public Boolean isSuccess;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }
}
