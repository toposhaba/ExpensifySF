public with sharing class InvocableApplyExpenseRules {

    @InvocableMethod(label='Apply Expense Rules' description='Applies auto-categorization rules to expenses based on merchant patterns' category='Expense Management')
    public static List<Results> execute(List<Request> requests) {
        List<Results> responseList = new List<Results>();
        for (Request req : requests) {
            Results res = new Results();
            try {
                ExpenseRuleService.applyRules(req.expenseIds);
                res.processedCount = req.expenseIds.size();
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
        @InvocableVariable(label='Expense Ids' required=true)
        public List<Id> expenseIds;
    }

    public class Results {
        @InvocableVariable(label='Processed Count')
        public Integer processedCount;

        @InvocableVariable(label='Is Success')
        public Boolean isSuccess;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }
}
