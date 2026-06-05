public with sharing class InvocableConvertCurrency {

    @InvocableMethod(label='Convert Currency' description='Converts an amount between currencies and optionally stores the converted amount on an expense' category='Expense Management')
    public static List<Results> execute(List<Request> requests) {
        List<Results> responseList = new List<Results>();
        for (Request req : requests) {
            Results res = new Results();
            try {
                if (req.expenseId != null) {
                    Expense__c updated = CurrencyService.setConvertedAmount(req.expenseId, req.toCurrency);
                    res.expenseId = updated.Id;
                    res.convertedAmount = updated.Converted_Amount__c;
                } else {
                    res.convertedAmount = CurrencyService.convert(req.amount, req.fromCurrency, req.toCurrency);
                }
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
        @InvocableVariable(label='Expense Id' required=false)
        public Id expenseId;

        @InvocableVariable(label='Amount' required=false)
        public Decimal amount;

        @InvocableVariable(label='From Currency' required=false)
        public String fromCurrency;

        @InvocableVariable(label='To Currency' required=true)
        public String toCurrency;
    }

    public class Results {
        @InvocableVariable(label='Expense Id')
        public Id expenseId;

        @InvocableVariable(label='Converted Amount')
        public Decimal convertedAmount;

        @InvocableVariable(label='Is Success')
        public Boolean isSuccess;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }
}
