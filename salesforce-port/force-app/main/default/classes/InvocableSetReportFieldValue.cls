public with sharing class InvocableSetReportFieldValue {

    @InvocableMethod(label='Set Report Field Value' description='Sets a custom report field value for an expense report with required and type validation' category='Expense Management')
    public static List<Results> execute(List<Request> requests) {
        List<Results> responseList = new List<Results>();
        for (Request req : requests) {
            Results res = new Results();
            try {
                Report_Field_Value__c value = ReportFieldService.setValue(
                    req.reportId, req.reportFieldId, req.value
                );
                res.reportFieldValueId = value.Id;
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
        @InvocableVariable(label='Report Id' required=true)
        public Id reportId;

        @InvocableVariable(label='Report Field Id' required=true)
        public Id reportFieldId;

        @InvocableVariable(label='Value' required=false)
        public String value;
    }

    public class Results {
        @InvocableVariable(label='Report Field Value Id')
        public Id reportFieldValueId;

        @InvocableVariable(label='Is Success')
        public Boolean isSuccess;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }
}
