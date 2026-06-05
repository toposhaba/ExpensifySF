public with sharing class InvocableApplyExpenseRules {

    @InvocableMethod(label='Apply Expense Rules' description='Applies policy coding rules to set category and tag from the first matching merchant rule' category='Expense Management')
    public static List<Results> execute(List<Request> requests) {
        List<Results> responseList = new List<Results>();
        for (Request req : requests) {
            Results res = new Results();
            try {
                Expense__c updated = ExpenseRuleService.applyRules(req.expenseId);
                res.expenseId = updated.Id;
                res.categoryId = updated.Category__c;
                res.tagId = updated.Tag__c;
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
    }

    public class Results {
        @InvocableVariable(label='Expense Id')
        public Id expenseId;

        @InvocableVariable(label='Category Id')
        public Id categoryId;

        @InvocableVariable(label='Tag Id')
        public Id tagId;

        @InvocableVariable(label='Is Success')
        public Boolean isSuccess;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }
}
