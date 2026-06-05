public with sharing class InvocableMergeExpenses {

    @InvocableMethod(label='Merge Expenses' description='Merges two expenses into one survivor, reattaching related records and deleting the other' category='Expense Management')
    public static List<Results> execute(List<Request> requests) {
        List<Results> responseList = new List<Results>();
        for (Request req : requests) {
            Results res = new Results();
            try {
                Map<String, Id> fieldSelections = ExpenseMergeService.buildSelectionMap(req.fieldNames, req.fieldSourceExpenseIds);
                Expense__c survivor = ExpenseMergeService.mergeExpenses(req.survivorExpenseId, req.otherExpenseId, fieldSelections);
                res.mergedExpenseId = survivor.Id;
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
        @InvocableVariable(label='Survivor Expense Id' required=true)
        public Id survivorExpenseId;

        @InvocableVariable(label='Other Expense Id' required=true)
        public Id otherExpenseId;

        @InvocableVariable(label='Field Names' required=false)
        public List<String> fieldNames;

        @InvocableVariable(label='Field Source Expense Ids' required=false)
        public List<Id> fieldSourceExpenseIds;
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
