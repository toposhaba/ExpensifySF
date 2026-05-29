public with sharing class InvocableMergeExpenses {

    @InvocableMethod(label='Merge Duplicate Expenses' description='Merges duplicate expenses into one keeping the best data from each' category='Expense Management')
    public static List<Results> execute(List<Request> requests) {
        List<Results> responseList = new List<Results>();
        for (Request req : requests) {
            Results res = new Results();
            try {
                Expense__c merged = DuplicateDetectionService.mergeExpenses(req.keepExpenseId, req.mergeExpenseIds);
                res.mergedExpenseId = merged.Id;
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
        @InvocableVariable(label='Expense Id to Keep' required=true)
        public Id keepExpenseId;

        @InvocableVariable(label='Expense Ids to Merge' required=true)
        public List<Id> mergeExpenseIds;
    }

    public class Results {
        @InvocableVariable(label='Merged Expense Id')
        public Id mergedExpenseId;

        @InvocableVariable(label='Is Success')
        public Boolean isSuccess;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }
}
