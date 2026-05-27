public with sharing class InvocableRemovePolicyMember {

    @InvocableMethod(label='Remove Policy Member' description='Removes a user from an expense policy with last-admin protection' category='Expense Management')
    public static List<Results> execute(List<Request> requests) {
        List<Results> responseList = new List<Results>();
        for (Request req : requests) {
            Results res = new Results();
            try {
                PolicyService.removeMember(req.policyId, req.userId);
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

        @InvocableVariable(label='User Id' required=true)
        public Id userId;
    }

    public class Results {
        @InvocableVariable(label='Is Success')
        public Boolean isSuccess;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }
}
