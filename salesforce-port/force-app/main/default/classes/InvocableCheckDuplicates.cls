public with sharing class InvocableCheckDuplicates {

    @InvocableMethod(label='Check Duplicate Expenses' description='Finds potential duplicate expenses within the same policy or report by matching amount, date proximity and merchant, and creates Duplicate violation records' category='Expense Management')
    public static List<Results> execute(List<Request> requests) {
        List<Results> responseList = new List<Results>();
        for (Request req : requests) {
            Results res = new Results();
            try {
                if (req.expenseId == null) {
                    throw new IllegalArgumentException('Expense Id is required');
                }
                Integer window = req.dateWindowDays != null
                    ? req.dateWindowDays
                    : DuplicateDetectionService.DEFAULT_DATE_WINDOW_DAYS;

                List<Expense_Violation__c> created = DuplicateDetectionService.detectDuplicates(req.expenseId, window);

                List<Id> violationIds = new List<Id>();
                for (Expense_Violation__c violation : created) {
                    violationIds.add(violation.Id);
                }

                res.duplicatesFound = created.size();
                res.violationIds = violationIds;
                res.hasDuplicates = !created.isEmpty();
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

        @InvocableVariable(label='Date Window Days' required=false)
        public Integer dateWindowDays;
    }

    public class Results {
        @InvocableVariable(label='Duplicates Found')
        public Integer duplicatesFound;

        @InvocableVariable(label='Has Duplicates')
        public Boolean hasDuplicates;

        @InvocableVariable(label='Violation Ids')
        public List<Id> violationIds;

        @InvocableVariable(label='Is Success')
        public Boolean isSuccess;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }
}
